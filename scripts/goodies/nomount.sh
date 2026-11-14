#!/bin/bash

# Export nomount variables
NOMOUNT_SETUP_URI="https://raw.githubusercontent.com/maxsteeel/nomount/refs/heads/master/kernel/setup.sh"
NOMOUNT_SETUP_BRANCH="v2.3.0-720"

# Setup nomount
cd $KERNEL_DIR
echo "-- NoMount: Running setup script..."
curl -LSs --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$NOMOUNT_SETUP_URI" | bash -s "$NOMOUNT_SETUP_BRANCH" &> /dev/null || { echo "-- Fatal: NoMount setup script failed to download/run!"; exit 1; }
echo "CONFIG_NOMOUNT=y" >> "$FINAL_DEFCONFIG"
cd ..