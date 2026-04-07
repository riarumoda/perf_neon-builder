#!/bin/bash

# Banner
echo " "
echo "==============================================="
echo "  ____            __   _   _                   "
echo " |  _ \ ___ _ __ / _| | \ | | ___  ___  _ __   "
echo " | |_) / _ \ '__| |_  |  \| |/ _ \/ _ \| '_ \  "
echo " |  __/  __/ |  |  _| | |\  |  __/ (_) | | | | "
echo " |_|   \___|_|  |_|   |_| \_|\___|\___/|_| |_| "
echo "==============================================="
echo " Build Script 1.1 - by Riaru Moda"
echo " https://t.me/trrflex"
echo " "

# Validate input arguments
echo "- Validating input arguments..."
if [ $# -ne 4 ]; then
    echo "Usage: $0 [device] [kernelsu_options] [bbg_options] [nomount_options]"
    echo "Example: $0 sweet zako bbg nomount"
    exit 1
fi

# Export arguments so sourced scripts can access them
echo "- Exporting input arguments..."
export DEVICE_IMPORT="$1"
export KERNELSU_SELECTOR="$2"
export BBG_SELECTOR="$3"
export NOMOUNT_SELECTOR="$4"

# Setup Environment
chmod +x scripts/setup-environment.sh
source scripts/setup-environment.sh

# Setup patches
chmod +x scripts/apply-device-patches.sh
source scripts/apply-device-patches.sh

# Setup goodies
chmod +x scripts/add-goodies.sh
source scripts/add-goodies.sh

# Build process
chmod +x scripts/before-compile.sh
chmod +x scripts/compile-it.sh
source scripts/before-compile.sh
source scripts/compile-it.sh

# Finalize
if [ -d "out/arch/arm64/boot" ]; then
    echo "- Build process finished, listed below are the build artifacts:"
    echo "==============================================="
    ls -alhZ out/arch/arm64/boot/
    echo "==============================================="
else
    echo "- Build process either failed during pre-compile or uring compile."
fi
