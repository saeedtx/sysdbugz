#!/bin/bash

# This script is used to log the output of a command to a given directory into a log file
# with a timestamped log file name
# Parameters: log_dir, interval, command..

LOG_DIR=$1; INTERVAL=$2
shift 2

usage () {
	echo "Usage1: $0 <log_dir> <interval> <tag1> <command1> <tag2> <command2> ..."
	echo "Usage2: $0 <conf_file>"
	echo "Interval format: T:N where N is the log amount and T is the interval in seconds"
	echo "N is optional. If not provided, the script will run indefinitely."
	exit 1
}

[ -z $1 ] && usage

if [ -f $1 ]; then
	echo "using conf file $1"
	source $1
	LOG_DIR=$SYSMON_LOG_DIR
	INTERVAL=$SYSMON_INTERVAL
else
	SYSMON_CMDS=()
	while [ $# -gt 1 ]; do
		echo found command \"$1\" : \"$2\"
		SYSMON_CMDS+=("$1")
		SYSMON_CMDS+=("$2")
		shift 2
	done
fi

if [ -z "$LOG_DIR" ] || [ -z "$INTERVAL" ] || [ -z "${#SYSMON_CMDS[@]}" ]; then
	echo "LOG_DIR=$LOG_DIR"
	echo "INTERVAL=$INTERVAL"
	echo "SYSMON_CMDS=${SYSMON_CMDS[@]}"
	echo "Error: Missing required parameters"
	usage
fi

# Extract log count and interval
INTERVAL_TIME=$(echo "$INTERVAL" | cut -d':' -f1)
if [[ "$INTERVAL" == *:* ]]; then
	LOG_COUNT=$(echo "$INTERVAL" | cut -d':' -f2)
else
	LOG_COUNT=0
fi

# Check if INTERVAL_TIME is a number
if ! [[ "$LOG_COUNT" =~ ^[0-9]+$ ]]; then
	echo "Error: Interval time must be a number."
	exit 1
fi

# Check if LOG_AMOUNT is a number if provided
if [ -n "$LOG_COUNT" ] && ! [[ "$LOG_COUNT" =~ ^[0-9]+$ ]]; then
	echo "Error: Log count must be a number."
	exit 1
fi

set -e

# remove any trailing slashes
LOG_DIR=$(echo $LOG_DIR | sed 's:/*$::')
LOG_DIR=${LOG_DIR}-$(date +"%Y%m%d_%H%M%S")
export SYSMON_LOG_DIR=$LOG_DIR

mkdir -p "$LOG_DIR"

sysmon_msg() {
	local log_type="$1"
	local message="$2"
	echo $(date '+%Y-%m-%d %H:%M:%S.%3N') "$timestamp [$log_type]: $message" | tee -a ${LOG_DIR}/run.log
}

travers_commands()
{
	# pass the name of the array as the first argument
	local array_name="$1"
	eval "local COMMANDS_LIST=(\"\${$array_name[@]}\")"
	local FUN=$2
	local FUN_ARGS=${@:3}
	local TITLE=""
	local CMD=""

	for ((i = 0; i < ${#COMMANDS_LIST[@]}; i+=2)); do
		TITLE="${COMMANDS_LIST[i]}"
		CMD="${COMMANDS_LIST[i+1]}"
		sysmon_msg "INFO" "	$TITLE: $CMD"
		$FUN "$TITLE" "$CMD" $FUN_ARGS &
	done
	wait
}

RUN_COUNTER=0

sysmon_msg INFO "LOG_DIR: $LOG_DIR"
sysmon_msg INFO "INTERVAL: $INTERVAL_TIME"
sysmon_msg INFO "LOG_COUNT: $LOG_COUNT"

sysmon_msg "INFO" "Commands to monitor every $INTERVAL_TIME seconds, DIR: $LOG_DIR"
make_command_dir()
{
	local title=$1;	local cmd=$2; local PARENT_DIR=${3:-$LOG_DIR}
	mkdir -p ${PARENT_DIR}/${title}
	echo "$cmd" >> ${PARENT_DIR}/${title}/commandline.txt
}
travers_commands SYSMON_CMDS make_command_dir $LOG_DIR

exec_pre_post_commands()
{
	local title=$1;	local cmd=$2; local PARENT_DIR=${LOG_DIR}/${3}
	mkdir -p ${PARENT_DIR}/
	LOG_FILE=${PARENT_DIR}/${title}.txt

	echo "## command line: $cmd" > ${LOG_FILE}
	eval "$cmd" >> "$LOG_FILE" 2>&1 || {
		err_code=$?
		sysmon_msg "Error" "Command '$cmd' failed with exit code $err_code"
		sysmon_msg "Error" "$(cat $LOG_FILE)"
	}
}

on_terminate() {
	local exit_code=$?
	if [ $exit_code -ne 0 ] && [ $exit_code -ne 143 ] && [ $exit_code -ne 130 ]; then
		sysmon_msg "Error" "Command '${BASH_COMMAND}' failed on line ${BASH_LINENO[0]} with exit code ${exit_code}."
	fi

	if [ $exit_code -eq 143 ] || [ $exit_code -eq 130 ]; then
		exit_code=0
	fi
	sysmon_msg INFO "Terminating script with exit code $exit_code"
	set +e
	# kill all child processes
	pkill -P $$

	[ ${#SYSMON_POST_CMDS[@]} -gt 0 ] && {
		sysmon_msg "INFO" "Post monitor commands:"
		travers_commands SYSMON_POST_CMDS exec_pre_post_commands post
	}

	sysmon_msg INFO "DUMP LOGS: $LOG_DIR"
	exit $exit_code
}
trap 'on_terminate' SIGINT SIGTERM ERR

[ ${#SYSMON_PRE_CMDS[@]} -gt 0 ] && {
	sysmon_msg "INFO" "Pre monitor Commands:"
	travers_commands SYSMON_PRE_CMDS exec_pre_post_commands pre
}

exec_mon_cmd() {
	local title=$1
	local cmd=$2
	TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
	LOG_FILE="${LOG_DIR}/${title}/sysmon_dump_${TIMESTAMP}.txt"
	eval "$cmd" > "$LOG_FILE" 2>&1 || {
		err_code=$?
		sysmon_msg "Error" "Command '$cmd' failed with exit code $err_code"
		sysmon_msg "Error" "$(cat $LOG_FILE)"
		exit $err_code
	}

	[ -n "${SYSMON_ANALYZE[$title]}" ] && {
		sysmon_msg INFO "SYSMON_LOG: Analyzing log file: cat $LOG_FILE | ${SYSMON_ANALYZE[$title]}"
		cat $LOG_FILE | eval "${SYSMON_ANALYZE[$title]}"
	}
}

sysmon_msg INFO "Starting sysmon_log.sh script"
while [ "$LOG_COUNT" -eq 0 ] || [ "$RUN_COUNTER" -lt "$LOG_COUNT" ]; do

	travers_commands SYSMON_CMDS exec_mon_cmd
	sleep "$INTERVAL_TIME"
	RUN_COUNTER=$((RUN_COUNTER + 1))
done
