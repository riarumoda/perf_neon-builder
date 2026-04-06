#!/bin/bash
echo "- Starting kernel compilation..."

# Warning start banner
echo " "
echo "====================================="
echo " COMPILING PROCESS HAVE BEEN STARTED "
echo "====================================="
echo " "

# Compile the kernel
make -j$(nproc --all) O=out "${MAKE_ARGS[@]}"

# WWarning finish banner
echo " "
echo "======================================"
echo " COMPILING PROCESS HAVE BEEN FINISHED "
echo "======================================"
echo " "