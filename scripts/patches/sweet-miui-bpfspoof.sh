#!/bin/bash
cd "$KERNEL_DIR"

# Specific tweaks
echo "-- Getting rid of the dirty flag..."
sed -i "s/printf '%s' -dirty/:/g" scripts/setlocalversion

echo "-- Applying BPF Spoofing..."
sed -i -e 's/^CONFIG_FAKE_UNAME_NONE=y/# CONFIG_FAKE_UNAME_NONE is not set/' \
       -e 's/^# CONFIG_FAKE_UNAME_5_10 is not set/CONFIG_FAKE_UNAME_5_10=y/' $FINAL_DEFCONFIG

echo "-- Disabling IKHeaders..."
sed -i 's/CONFIG_IKHEADERS=y/# CONFIG_IKHEADERS is not set/g' $FINAL_DEFCONFIG
cd ..
