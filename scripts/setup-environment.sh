#!/bin/bash
echo "- Setting up build environment..."

# GCC and Clang settings
export CLANG_REPO_URI="https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b.git"
export GCC_64_REPO_URI="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git"
export GCC_32_REPO_URI="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git"
export CLANG_DIR=$PWD/clang
export GCC64_DIR=$PWD/gcc64
export GCC32_DIR=$PWD/gcc32
export PATH="$CLANG_DIR/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH"

# Clang setup
if [ ! -d "$PWD/clang" ]; then
    git clone $CLANG_REPO_URI --depth=1 clang &> /dev/null
else
    echo "Local clang dir found, using it."
fi

# GCC64 setup
if [ ! -d "$PWD/gcc64" ]; then
    git clone $GCC_64_REPO_URI --depth=1 gcc64 &> /dev/null
else
    echo "Local gcc64 dir found, using it."
fi

# GCC32 setup
if [ ! -d "$PWD/gcc32" ]; then
    git clone $GCC_32_REPO_URI --depth=1 gcc32 &> /dev/null
else
    echo "Local gcc32 dir found, using it."
fi

# Device Settings - v2.3
if [[ "$DEVICE_IMPORT" == "sweet" ]]; then
    # Defconfigs
    export MAIN_DEFCONFIG="arch/arm64/configs/vendor/sdmsteppe-perf_defconfig"
    export ACTUAL_MAIN_DEFCONFIG="vendor/sdmsteppe-perf_defconfig"
    export COMMON_DEFCONFIG="vendor/debugfs.config"
    export DEVICE_DEFCONFIG="vendor/sweet.config"
    export FEATURE_DEFCONFIG=""
    # Maintainer
    export KBUILD_BUILD_USER=riarumoda-compile
    export KBUILD_BUILD_HOST=riaru.com
    # Kernel Version
    export KERNEL_VERSION="4.14"
elif [[ "$DEVICE_IMPORT" == "davinci" ]]; then
    # Defconfigs
    export MAIN_DEFCONFIG="arch/arm64/configs/vendor/sdmsteppe-perf_defconfig"
    export ACTUAL_MAIN_DEFCONFIG="vendor/sdmsteppe-perf_defconfig"
    export COMMON_DEFCONFIG="vendor/debugfs.config"
    export DEVICE_DEFCONFIG="vendor/davinci.config"
    export FEATURE_DEFCONFIG=""
    # Maintainer
    export KBUILD_BUILD_USER=riarumoda-compile
    export KBUILD_BUILD_HOST=riaru.com
    # Kernel Version
    export KERNEL_VERSION="4.14"
elif [[ "$DEVICE_IMPORT" == "ginkgo" ]]; then
    # Defconfigs
    export MAIN_DEFCONFIG="arch/arm64/configs/vendor/trinket-perf_defconfig"
    export ACTUAL_MAIN_DEFCONFIG="vendor/trinket-perf_defconfig"
    export COMMON_DEFCONFIG="vendor/debugfs.config vendor/xiaomi-trinket.config"
    export DEVICE_DEFCONFIG="vendor/ginkgo.config"
    export FEATURE_DEFCONFIG=""
    # Maintainer
    export KBUILD_BUILD_USER=hiyorun-compile
    export KBUILD_BUILD_HOST=riaru.com
    # Kernel Version
    export KERNEL_VERSION="4.14"
elif [[ "$DEVICE_IMPORT" == "mi89x7" ]]; then
    # Defconfigs
    export MAIN_DEFCONFIG="arch/arm64/configs/vendor/msm8937-perf_defconfig"
    export ACTUAL_MAIN_DEFCONFIG="vendor/msm8937-perf_defconfig"
    export COMMON_DEFCONFIG="vendor/msm8937-legacy.config vendor/common.config"
    export DEVICE_DEFCONFIG="vendor/xiaomi/msm8937/common.config vendor/xiaomi/msm8937/mi8937.config"
    export FEATURE_DEFCONFIG="vendor/feature/lineageos.config vendor/feature/android-12.config vendor/feature/erofs.config vendor/feature/exfat.config vendor/feature/lmkd.config vendor/feature/lto.config vendor/feature/ntfs.config vendor/feature/wireguard.config"
    # Maintainer
    export KBUILD_BUILD_USER=riarumoda-compile
    export KBUILD_BUILD_HOST=riaru.com
    # Kernel Version
    export KERNEL_VERSION="4.19"
else
    echo "- Invalid DEVICE_IMPORT. Use a valid device name."
    echo "  Valid options: sweet, ginkgo, mi89x7."
    echo "  Yours is $DEVICE_IMPORT."
    exit 1
fi

# Maintainer info
export GIT_NAME="$KBUILD_BUILD_USER"
export GIT_EMAIL="$KBUILD_BUILD_USER@$KBUILD_BUILD_HOST"

# Kernel name
export KERNEL_NAME="-perf-neon"
