#!/bin/bash

# This script is used to log the output of a command to a given directory into a log file
# with a timestamped log file name
# Parameters: log_dir, interval, command..

LOG_DIR=$1; INTERVAL=$2
shift 2
COMMAND="$@"

usage () {
	echo "Usage1: $0 <log_dir> <interval> <command>"
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
	COMMAND=$SYSMON_CMD
fi

if [ -z "$LOG_DIR" ] || [ -z "$INTERVAL" ] || [ -z "$COMMAND" ]; then
	echo "LOG_DIR=$LOG_DIR"
	echo "INTERVAL=$INTERVAL"
	echo "COMMAND=$COMMAND"
	echo "Error: Missing required parameters"
	usage
fi

# Extract log amount and interval
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

LOG_DIR=${LOG_DIR}-$(date +"%Y%m%d_%H%M%S")
export SYSMON_LOG_DIR=$LOG_DIR

mkdir -p "$LOG_DIR"
echo "$COMMAND" > ${LOG_DIR}/commandline.txt

sysmon_msg() {
	local log_type="$1"
	local message="$2"
	echo $(date '+%Y-%m-%d %H:%M:%S.%3N') "$timestamp [$log_type]: $message" | tee -a ${LOG_DIR}/run.log
}

travers_commands()
{
	local fun=$1
	local title=""
	local cmd=""

	for ((i = 0; i < ${#SYSMON_CMDS[@]}; i+=2)); do
		title="${SYSMON_CMDS[i]}"
		cmd="${SYSMON_CMDS[i+1]}"
		sysmon_msg "INFO" "	$title: $cmd"
		$fun "$title" "$cmd"
	done
}

RUN_COUNTER=0

sysmon_msg INFO "MAIN_COMMAND: $COMMAND"
sysmon_msg INFO "LOG_DIR: $LOG_DIR"
sysmon_msg INFO "INTERVAL: $INTERVAL_TIME"
sysmon_msg INFO "LOG_COUNT: $LOG_COUNT"

make_command_dir()
{
	local title=$1;	local cmd=$2
	mkdir -p ${LOG_DIR}/${title}
	echo "$cmd" >> ${LOG_DIR}/${title}/commandline.txt
}

if [ ${#SYSMON_CMDS[@]} -gt 0 ]; then
	sysmon_msg "INFO" "Extra commands:"
	travers_commands make_command_dir
fi

[ -n "$SYSMON_PRE" ] && {
	sysmon_msg INFO "PRE_CMD: $SYSMON_PRE"
	eval "$SYSMON_PRE" | tee -a ${LOG_DIR}/run.log
	sysmon_msg INFO "PRE_CMD: Done"
}

on_terminate() {
	local exit_code=$?
	if [ $exit_code -ne 0 ] && [ $exit_code -ne 143 ] && [ $exit_code -ne 130 ]; then
		sysmon_msg "Error" "Command '${BASH_COMMAND}' failed on line ${BASH_LINENO[0]} with exit code ${exit_code}."
	fi

	if [ $exit_code -eq 143 ] || [ $exit_code -eq 130 ]; then
		exit_code=0
	fi

	[ -n "$SYSMON_POST" ] && {
		sysmon_msg INFO "POST_CMD: $SYSMON_POST"
		eval "$SYSMON_POST" | tee -a ${LOG_DIR}/run.log
		sysmon_msg INFO "POST_CMD: Done"
	}
	sysmon_msg INFO "DUMP LOGS: $LOG_DIR"
	exit $exit_code
}
trap 'on_terminate' SIGINT SIGTERM EXIT ERR

exec_extra_command() {
	local title=$1
	local cmd=$2
	LOG_FILE="${LOG_DIR}/${title}/sysmon_dump_${TIMESTAMP}.txt"
	eval "$cmd" > "$LOG_FILE" 2>&1 || {
		err_code=$?
		sysmon_msg "Error" "Command '$cmd' failed with exit code $err_code"
		sysmon_msg "Error" "$(cat $LOG_FILE)"
		exit $err_code
	}
}

sysmon_msg INFO "Starting sysmon_log.sh script"
while [ "$LOG_COUNT" -eq 0 ] || [ "$RUN_COUNTER" -lt "$LOG_COUNT" ]; do
	if [ ${#SYSMON_CMDS[@]} -gt 0 ]; then
		sysmon_msg INFO "Executing extra commands: "
		travers_commands exec_extra_command
	fi

	if [ -n "$COMMAND" ]; then
		TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
		LOG_FILE="${LOG_DIR}/sysmon_dump_${TIMESTAMP}.txt"
		sysmon_msg INFO "EXEC: $COMMAND"
		eval "$COMMAND" | tee -a "$LOG_FILE"
	fi
	[ -n "$SYSMON_ANALYZE" ] && {
		sysmon_msg INFO "SYSMON_LOG: Analyzing log file: cat $LOG_FILE | $SYSMON_ANALYZE"
		cat $LOG_FILE | eval "$SYSMON_ANALYZE"
	}
	wait

	sleep "$INTERVAL_TIME"
	RUN_COUNTER=$((RUN_COUNTER + 1))
done
