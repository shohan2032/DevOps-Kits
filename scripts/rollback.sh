#!/bin/bash

BASE_PATH=/home/ubuntu/frontend
RELEASES_PATH=${BASE_PATH}/releases
ACTIVE_RELEASE_PATH=${BASE_PATH}/current

# List the directories by modification time (most recently modified first)
folder_list=$(ls -t -1 "${RELEASES_PATH}")

# Count the number of lines (folders) in folder_list
num_folders=$(echo "${folder_list}" | wc -l)

# Prompt the user for the number of steps to rollback (default to 1 if no input)
read -p "Enter the number of steps to rollback (default is 1, 0 for the latest release): " steps
steps=${steps:-1}  # Default to 1 if no input provided

# Calculate the index of the target folder in the list
target_index=$((steps + 1))  # Add 1 to account for 0-based indexing
# Debugging output to check the value of target_index
echo "Target Index: $target_index"
echo "Total Folders: $num_folders"

# Check if the user entered 0 (latest release) or a positive number of steps
if [ "$steps" -ge 0 ]; then
    # Check if the target index is within bounds
    if [ "$target_index" -le "$num_folders" ]; then
      # Get the folder name to rollback to
      rollback_folder=$(echo "${folder_list}" | awk "NR==${target_index}")
      # Debugging output to check the value of rollback_folder
      echo "Rollback Folder: $rollback_folder"

      # Update RELEASES_PATH to the selected folder
      RELEASE_PATH=${RELEASES_PATH}/${rollback_folder}

      # Create the symbolic link to activate the selected release
      ln -s -n -f "$RELEASE_PATH" "$ACTIVE_RELEASE_PATH"
      pm2 reload frontend
      echo "Rolled back to: $rollback_folder"
    else
      echo "Invalid input. No such rollback step available."
    fi
else
    if [ "$steps" -eq 0 ]; then
      # Rolling back to the latest release
      latest_release=$(echo "${folder_list}" | awk 'NR==1')
      RELEASE_PATH=${RELEASES_PATH}/${latest_release}
      # Create the symbolic link to activate the selected release
      ln -s -n -f "$RELEASE_PATH" "$ACTIVE_RELEASE_PATH"
      pm2 reload frontend
      echo "Rolled back to the latest release: $latest_release"
    else
      echo "Invalid input. Enter a non-negative number of steps or 0 for the latest release."
    fi
fi