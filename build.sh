#!/bin/bash

# Validate input arguments
echo "- Validating input arguments..."
if [ $# -lt 2 ]; then
    echo ""
    echo "Usage: $0 [device] [os]"
    echo "examples: $0 sweet lineage"
    echo ""
    exit 1
fi

# Load device and OS from input arguments
DEVICE="$1"
OS="$2"

# Load CI environment
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
BUILD_DATE="${BUILD_DATE:-$(date +%Y%m%d)}"
BUILD_TYPE="${BUILD_TYPE:-Testing}"
export GITHUB_TOKEN BUILD_DATE BUILD_TYPE

# Load CI github secrets silently
if [ -n "$GITHUB_TOKEN" ]; then
    git config --global url."https://x-access-token:$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"
fi

# Banner
echo " "
echo "==============================================="
echo "  ____            __   _   _                   "
echo " |  _ \ ___ _ __ / _| | \ | | ___  ___  _ __   "
echo " | |_) / _ \ '__| |_  |  \| |/ _ \/ _ \| '_ \  "
echo " |  __/  __/ |  |  _| | |\  |  __/ (_) | | | | "
echo " |_|   \___|_|  |_|   |_| \_|\___|\___/|_| |_| "
echo "==============================================="
echo " Build Script 3.0 - by Riaru Moda"
echo " https://t.me/trrflex"
echo " "

# Load device metadata
echo "-- Loading device settings..."
source "devices/$DEVICE/$OS.conf" || { echo "-- ERROR: could not load device settings"; exit 1; }

# Export build metadata for make and helper scripts
DEVICE_NAME="$DEVICE"
export DEVICE_NAME KBUILD_BUILD_USER KBUILD_BUILD_HOST

# Clone device source code
echo "-- Cloning kernel repository..."
if [ "$IS_DEPTH_CLONE" = "true" ]; then
    git clone --depth=1 --branch "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_DIR" &> /dev/null || { echo "-- ERROR: failed to clone $KERNEL_REPO"; exit 1; }
else
    git clone --branch "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_DIR" &> /dev/null || { echo "-- ERROR: failed to clone $KERNEL_REPO"; exit 1; }
fi

# Clone extra repositories: <repo>|<branch>|<target directory>
if [ "${#KERNEL_EXTRA_REPOS[@]}" -gt 0 ]; then
    echo "-- Cloning extra repositories..."
    for entry in "${KERNEL_EXTRA_REPOS[@]}"; do
        IFS='|' read -r repo branch target_dir <<< "$entry"
        if [ -z "$repo" ] || [ -z "$branch" ] || [ -z "$target_dir" ]; then
            echo "-- ERROR: invalid KERNEL_EXTRA_REPOS entry: $entry"
            exit 1
        fi
        echo "   -> $target_dir"
        mkdir -p "$(dirname "$KERNEL_DIR/$target_dir")"
        if [ "$IS_DEPTH_CLONE" = "true" ]; then
            git clone --depth=1 --branch "$branch" "$repo" "$KERNEL_DIR/$target_dir" &> /dev/null || { echo "-- ERROR: failed to clone $repo"; exit 1; }
        else
            git clone --branch "$branch" "$repo" "$KERNEL_DIR/$target_dir" &> /dev/null || { echo "-- ERROR: failed to clone $repo"; exit 1; }
        fi
    done
fi

# Determine kernel version from Makefile
cd $KERNEL_DIR
KERNEL_VERSION=$(awk -F'[[:space:]]*=[[:space:]]*' '/^VERSION/{v=$2} /^PATCHLEVEL/{print v"."$2; exit}' Makefile)
export KERNEL_VERSION
cd ..

# Set up clang compiler
cd $KERNEL_DIR
echo "-- Setting up compiler..."
if [ -n "$GITHUB_TOKEN" ]; then
    AUTH_HEADER=(-H "Authorization: Bearer $GITHUB_TOKEN")
else
    AUTH_HEADER=()
fi
TC_URLS="$(curl -fsSL --retry 5 --retry-all-errors "${AUTH_HEADER[@]}" https://api.github.com/repos/Neutron-Toolchains/clang-build-catalogue/releases/latest | grep -o '"browser_download_url": *"[^"]*"' | head -n 1 | cut -d '"' -f 4)"
[ -n "$TC_URLS" ] || { echo "-- ERROR: could not resolve toolchain URL"; exit 1; }
CLANG_ROOT="$PWD/clang"
mkdir -p "$CLANG_ROOT"
PATH="$PWD/clang/bin/:$PATH"
MAKE_ARGS=(
	ARCH=arm64 LLVM=1 LLVM_IAS=1 LD=ld.lld
	CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- CROSS_COMPILE_ARM32=arm-linux-gnueabi-
)

# Apply a kconfig target and abort with the relevant output if it fails
config_step() {
	local target="$1"
	{ yes "" 2>/dev/null || true; } | make O=out "${MAKE_ARGS[@]}" "$target" >> config.log 2>&1 || {
		echo "-- ERROR: '$target' failed"
		tail -n 40 config.log
		cp config.log ../config.log 2>/dev/null || true
		exit 1
	}
}
curl -fL --retry 5 --retry-all-errors --retry-delay 5 "${AUTH_HEADER[@]}" -o "neutron-clang.tar.zst" "$TC_URLS" || { echo "-- ERROR: failed to download toolchain: $TC_URLS"; exit 1; }
tar --zstd -C "$CLANG_ROOT" -xf "neutron-clang.tar.zst" || { echo "-- ERROR: failed to extract toolchain"; exit 1; }
rm -f "neutron-clang.tar.zst"

# Never let a broken toolchain silently fall back to the host gcc
if ! "$CLANG_ROOT/bin/clang" --version &> /dev/null; then
    echo "-- ERROR: clang is not usable at $CLANG_ROOT/bin/clang"
    exit 1
fi
if ! "$CLANG_ROOT/bin/ld.lld" --version &> /dev/null; then
    echo "-- ERROR: ld.lld is not usable at $CLANG_ROOT/bin/ld.lld"
    exit 1
fi
export PATH
echo "-- Compiler: $("$CLANG_ROOT/bin/clang" --version | head -n 1)"

# Wrap the compiler with ccache when available (CI restores ~/.ccache).
# The compiler identity includes the resolved clang version and the wrapper
# hash, so a toolchain or wrapper change can never hit stale objects.
if command -v ccache &> /dev/null; then
    CLANG_ID="$("$CLANG_ROOT/bin/clang" --version | head -n 1)"
    export CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
    export CCACHE_COMPILERCHECK="string:${CLANG_ID}:$(sha256sum scripts/gcc-wrapper.py | cut -d' ' -f1)"
    mkdir -p "$CCACHE_DIR"
    echo "-- Enabling ccache ($(ccache --version | head -n 1))..."
    ccache -z &> /dev/null || true
    MAKE_ARGS+=(
        CC="ccache $PWD/scripts/gcc-wrapper.py clang"
        HOSTCC="ccache clang"
        HOSTCXX="ccache clang++"
    )
fi
cd ..

# Generate single main defconfig
echo "-- Generating generic kernel config..."
cd $KERNEL_DIR
mkdir -p out &> /dev/null
: > config.log
config_step "$MAIN_DEFCONFIG"
echo "-- Appending fragments to .config..."
for fragment in $COMMON_DEFCONFIG $DEVICE_DEFCONFIG $FEATURE_DEFCONFIG; do
    if [ -f "arch/arm64/configs/$fragment" ]; then
        echo "   -> Merging $fragment..."
        cat "arch/arm64/configs/$fragment" >> out/.config
    else
        echo "   -> Warning: Fragment arch/arm64/configs/$fragment not found!"
    fi
done
if [[ "$IS_SYNCCONFIG" == "true" ]]; then
    echo "-- Executing olddefconfig and syncconfig..."
    config_step olddefconfig
    config_step syncconfig
else
    echo "-- Executing olddefconfig and silentoldconfig..."
    config_step olddefconfig
    config_step silentoldconfig
fi
echo "-- Copying merged config to defconfig directory..."
cp out/.config arch/arm64/configs/"$DEVICE"_stock_defconfig || exit 1
cp out/.config arch/arm64/configs/"$DEVICE"_defconfig || exit 1
if [[ "$IS_SPOOF_DEFCONFIG" == "true" ]]; then
    echo "-- Hard code config.gz into kernel..."
    sed -i 's|\$(KCONFIG_CONFIG)|arch/arm64/configs/'"$DEVICE"'_stock_defconfig|g' kernel/Makefile
fi
echo "-- Cleaning up..."
rm -rf out &> /dev/null
echo "-- Exporting finalized kernel config..."
export FINAL_DEFCONFIG="arch/arm64/configs/"$DEVICE"_defconfig"
export COMPILE_DEFCONFIG="${DEVICE}_defconfig"
cd ..

# Load device specific patches
echo "-- Loading device specific patches..."
source scripts/patches.sh

# Load goodies
echo "-- Loading goodies..."
source scripts/goodies.sh

# Compile kernel
echo "-- Prepping build environment..."
cd "$KERNEL_DIR"
mkdir -p out &> /dev/null
echo "-- Parsing final defconfig..."
config_step "$COMPILE_DEFCONFIG"
if [[ "$IS_SYNCCONFIG" == "true" ]]; then
    echo "-- Executing olddefconfig and syncconfig..."
    config_step olddefconfig
    config_step syncconfig
else
    echo "-- Executing olddefconfig and silentoldconfig..."
    config_step olddefconfig
    config_step silentoldconfig
fi
echo "-- Compiling the kernel..."
set -o pipefail
make -j$(nproc --all) O=out "${MAKE_ARGS[@]}" 2>&1 | tee build.log
BUILD_STATUS=$?
set +o pipefail
if [ "$BUILD_STATUS" -ne 0 ]; then
    echo "-- ERROR: kernel compilation failed"
    cp build.log ../build.log 2>/dev/null || true
    cp config.log ../config.log 2>/dev/null || true
    cp out/.config ../final.config 2>/dev/null || true
    cd ..
    exit 1
fi
echo "-- Exporting build versions..."
export KSU_NAME=$(grep -m 1 -e "-- BakaSU version name:" build.log | awk -F': ' '{print $2}' | tr -d '[:space:]')
export KSU_CODE=$(grep -m 1 -e "-- BakaSU version code:" build.log | awk -F': ' '{print $2}' | tr -d '[:space:]')
export SUSFS_VER=$(grep -m 1 -e "-- SUSFS_VERSION:" build.log | awk -F': ' '{print $2}' | tr -d '[:space:]')
export BBG_VER=$(grep -m 1 -e "-- BBG version:" build.log | awk -F': ' '{print $2}' | tr -d '[:space:]')
export NOMOUNT_VER=$(grep -m 1 "NOMOUNT_BASE_VERSION" fs/nomount/nomount.h 2>/dev/null | awk -F'"' '{print $2}' | tr -d '[:space:]')
cp build.log ../build.log
cp config.log ../config.log 2>/dev/null || true
cp out/.config ../final.config
cd ..
echo "-- Writing release info.txt..."
echo "KSU_NAME=${KSU_NAME:-N/A}" >> release_info.txt
echo "KSU_CODE=${KSU_CODE:-N/A}" >> release_info.txt
echo "SUSFS_VER=${SUSFS_VER:-N/A}" >> release_info.txt
echo "BBG_VER=${BBG_VER:-N/A}" >> release_info.txt
echo "NOMOUNT_VER=${NOMOUNT_VER:-N/A}" >> release_info.txt

# AnyKernel3 / UNICA Flasher prep-up
if [[ "$IS_ANYKERNEL3" == "true" ]]; then
    echo "-- Cloning AnyKernel3 repository..."
    rm -rf AnyKernel3
    git clone https://github.com/riarumoda/AnyKernel3 AnyKernel3 --depth=1
    echo "-- Copying kernel image and dtb/dtbo to AnyKernel3..."
    cp "$KERNEL_DIR/out/arch/arm64/boot/$IMAGE" AnyKernel3/
    if [ -n "$DTB" ] && [ -f "$KERNEL_DIR/out/arch/arm64/boot/$DTB" ]; then cp "$KERNEL_DIR/out/arch/arm64/boot/$DTB" AnyKernel3/; fi
    if [ -n "$DTBO" ] && [ -f "$KERNEL_DIR/out/arch/arm64/boot/$DTBO" ]; then cp "$KERNEL_DIR/out/arch/arm64/boot/$DTBO" AnyKernel3/; fi
    echo "-- Updating AnyKernel3 settings..."
    sed -i "s/supported.versions=11-16/supported.versions=$VERSIONS/" AnyKernel3/anykernel.sh
    sed -i "s/sweet (sm6150)/$BANNER/g" AnyKernel3/banner
    echo "-- Updating AnyKernel3 device name..."
    if [[ "$IS_EXTENSIVE_DEVICE" == "true" ]]; then
        # Complex devices: replace both names and inject the remaining variants.
        sed -i "s/device.name1=sweet/device.name1=$DEVICE_1/" AnyKernel3/anykernel.sh
        sed -i "s/device.name2=sweetin/device.name2=$DEVICE_2/" AnyKernel3/anykernel.sh
        if [ -n "$DEVICE_EXTRA" ]; then
            DEVICE_INDEX=3
            DEVICE_LINES=""
            for device_name in $DEVICE_EXTRA; do
                DEVICE_LINES="${DEVICE_LINES:+$DEVICE_LINES\\n}device.name${DEVICE_INDEX}=${device_name}"
                DEVICE_INDEX=$((DEVICE_INDEX + 1))
            done
            sed -i "/device.name2=$DEVICE_2/a ${DEVICE_LINES}" AnyKernel3/anykernel.sh
        fi
    else
        # Simple devices: just replace the two default names.
        sed -i "s/device.name1=sweet/device.name1=$DEVICE_1/" AnyKernel3/anykernel.sh
        sed -i "s/device.name2=sweetin/device.name2=$DEVICE_2/" AnyKernel3/anykernel.sh
    fi
    echo "-- Updating kernel build type..."
    sed -i "s/KERNEL_BUILD_TYPE=\"Weekly\"/KERNEL_BUILD_TYPE=\"$BUILD_TYPE\"/" AnyKernel3/anykernel.sh
    echo "-- Zipping AnyKernel3 package..."
    [ -n "$ZIP_PREFIX" ] || { echo "-- ERROR: ZIP_PREFIX is not set in devices/$DEVICE/$OS.conf"; exit 1; }
    ZIPNAME="$ZIP_PREFIX-$BUILD_DATE.zip"
    cd AnyKernel3
    zip -rq9 "../$ZIPNAME" ./*
    cd ..
else
    echo "-- Prepping UNICA flasher..."
    source scripts/external/unica-sm7325.sh
fi
