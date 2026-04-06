#!/bin/bash
echo "- Starting kernel compilation..."

# Warning start banner
echo -e "\n================================\n   COMPILING PROCESS HAVE BEEN STARTED   \n================================\n"

# Compile the kernel
make -j$(nproc --all) O=out "${MAKE_ARGS[@]}"

# WWarning finish banner
echo -e "\n================================\n   COMPILING PROCESS HAVE BEEN STARTED   \n================================\n"
