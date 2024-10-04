#!/usr/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
# author: saeedm@nvidia.com
# date: 2024-10-03
# dump system information for debugging, Networking centric

set +x
# Check if OUTPUT_DIR is provided as an argument, otherwise use mktemp to create a temporary directory
if [ -z "$1" ]; then
    OUTPUT_DIR=$(mktemp -d)
    echo "No output directory provided. Using temporary directory: $OUTPUT_DIR"
else
    OUTPUT_DIR="$1"
    mkdir -p "$OUTPUT_DIR"  # Create the directory if it doesn't exist
    echo "Using provided output directory: $OUTPUT_DIR"
fi

# Wrapper function to execute devlink commands and generate output files
devlink_health_report() {
    local device=$1
    local reporter=$2
    local cmd=$3

    # Remove leading colon from the device name (if any)
    device=${device%:}

    # Generate file name based on device and reporter
    local base_filename="${OUTPUT_DIR}/${device//\//_}_${reporter}"
    local cmd_file=${cmd// /_}
    # Run devlink health show command
    local out_file="${base_filename}_${cmd_file}.txt"
    echo "Running 'devlink health show' for $device (reporter: $reporter)..."
    local cmd_exec="devlink health $cmd $device reporter $reporter"
    echo "commandline: $cmd_exec" > "$out_file"
    (set -x; $cmd_exec &>> "$out_file"; set +x)
    echo "Output saved to $out_file"
}

# Run the devlink command and parse the output
# Run the devlink command and parse the output
devlink health show | awk '
    BEGIN { device="" }
    /^pci\// {
        device=$1;
        sub(/:$/, "", device);  # Remove the trailing colon
        printf "\n%s\n", device;
    }
    /reporter/ {
        reporter=$2;
        printf "  reporter %s\n", reporter
    }
' | while read -r line; do
	echo $line
    # Check if the line contains a device or a reporter
    if [[ "$line" == pci/* ]]; then
        device="$line"
    elif [[ "$line" == *"reporter"* ]]; then
        reporter=$(echo "$line" | awk '{print $2}')  # Extract reporter name
        echo DEVICE=$device reporter=$reporter

        # Run the devlink health show command and save the output
        devlink_health_report $device $reporter show
        devlink_health_report $device $reporter diagnose
        devlink_health_report $device $reporter "dump show"
        (set -x; devlink health dump clear $device reporter $reporter; set +x)
   fi
done

# Print the output directory and the list of files
echo -e "\nAll devlink commands executed and outputs saved in the following directory:"
echo "Files created:"
find "$OUTPUT_DIR" -type f
echo "$OUTPUT_DIR"