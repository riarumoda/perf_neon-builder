#!/bin/bash
echo "- Setting up kernel source pre-compilation..."

# Apply O3 flags
if [ "$DEVICE_IMPORT" != "a9y18qlte" ]; then
    echo "-- Applying O3 flags before compiling..."
    sed -i 's/KBUILD_CFLAGS\s\++= -O2/KBUILD_CFLAGS   += -O3/g' Makefile
    sed -i 's/LDFLAGS\s\++= -O2/LDFLAGS += -O3/g' Makefile
fi
# Make sure out folder exist
mkdir -p out &> /dev/null
# Common make command array for readability
MAKE_CMD=(make O=out "${MAKE_ARGS[@]}")
# Setup main defconfig
"${MAKE_CMD[@]}" $ACTUAL_MAIN_DEFCONFIG &> /dev/null
# Append additional configs
echo "-- Appending fragments to .config..."
for fragment in $COMMON_DEFCONFIG $DEVICE_DEFCONFIG $FEATURE_DEFCONFIG; do
    if [ -f "arch/arm64/configs/$fragment" ]; then
        echo "  Merging $fragment..."
        cat "arch/arm64/configs/$fragment" >> out/.config
    else
        echo "  Warning: Fragment arch/arm64/configs/$fragment not found!"
    fi
done
# Set kernel name
echo "CONFIG_LOCALVERSION=\"$KERNEL_NAME\"" >> out/.config
# Config generation
yes "" | "${MAKE_CMD[@]}" olddefconfig &> /dev/null
yes "" | "${MAKE_CMD[@]}" syncconfig &> /dev/null
# git cleanup
echo "-- Cleaning up git before compiling..."
git config user.email "$GIT_EMAIL" &> /dev/null
git config user.name "$GIT_NAME" &> /dev/null
git config set advice.addEmbeddedRepo true &> /dev/null
git add . &> /dev/null
git commit -m "cleanup: applied patches before build" &> /dev/null