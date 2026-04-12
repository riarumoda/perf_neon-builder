#!/bin/bash
echo "- Setting up build environment..."

# GCC and Clang settings
export CLANG_ROOT="$PWD/clang"
export GCC64_ROOT="$PWD/gcc64"
export GCC32_ROOT="$PWD/gcc32"
export PATH="$CLANG_ROOT/bin:$GCC64_ROOT/bin:$GCC32_ROOT/bin:/usr/bin:$PATH"
TC_URLS=(
    "clang|https://gitlab.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-r547379.git"
    "gcc64|https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git"
    "gcc32|https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git"
)
for tc in "${TC_URLS[@]}"; do
    dir="${tc%%|*}"; url="${tc##*|}"
    [ ! -d "$dir" ] && git clone "$url" --depth=1 "$dir" &> /dev/null || echo "-- Using local $dir"
done

# Device Default Exports
export KBUILD_BUILD_USER=riarumoda-compile
export KBUILD_BUILD_HOST=riaru.com
export KERNEL_VERSION="4.14"
export MAIN_DEFCONFIG="arch/arm64/configs/vendor/sdmsteppe-perf_defconfig"
export ACTUAL_MAIN_DEFCONFIG="vendor/sdmsteppe-perf_defconfig"
export COMMON_DEFCONFIG="vendor/debugfs.config"
export FEATURE_DEFCONFIG=""

# Device Settings - v3.0
case "$DEVICE_IMPORT" in
    sweet|davinci|tucana|violet)
        export DEVICE_DEFCONFIG="vendor/${DEVICE_IMPORT}.config"
        ;;
    ginkgo|laurel_sprout)
        export MAIN_DEFCONFIG="arch/arm64/configs/vendor/trinket-perf_defconfig"
        export ACTUAL_MAIN_DEFCONFIG="vendor/trinket-perf_defconfig"
        export COMMON_DEFCONFIG="vendor/debugfs.config vendor/xiaomi-trinket.config"
        export DEVICE_DEFCONFIG="vendor/${DEVICE_IMPORT}.config"
        export KBUILD_BUILD_USER=hiyorun-compile
        ;;
    alioth|lmi|munch)
        export MAIN_DEFCONFIG="arch/arm64/configs/vendor/kona-perf_defconfig"
        export ACTUAL_MAIN_DEFCONFIG="vendor/kona-perf_defconfig"
        export DEVICE_DEFCONFIG="vendor/xiaomi/sm8250-common.config vendor/xiaomi/${DEVICE_IMPORT}.config"
        export KERNEL_VERSION="4.19"
        export KBUILD_BUILD_USER=kebeletxd-compile
        ;;
    mi89x7)
        export MAIN_DEFCONFIG="arch/arm64/configs/vendor/msm8937-perf_defconfig"
        export ACTUAL_MAIN_DEFCONFIG="vendor/msm8937-perf_defconfig"
        export COMMON_DEFCONFIG="vendor/msm8937-legacy.config vendor/common.config"
        export DEVICE_DEFCONFIG="vendor/xiaomi/msm8937/common.config vendor/xiaomi/msm8937/mi8937.config"
        export FEATURE_DEFCONFIG="vendor/feature/lineageos.config vendor/feature/android-12.config vendor/feature/erofs.config vendor/feature/exfat.config vendor/feature/lmkd.config vendor/feature/lto.config vendor/feature/ntfs.config vendor/feature/wireguard.config"
        export KERNEL_VERSION="4.19"
        ;;
    a52s)
        export MAIN_DEFCONFIG="arch/arm64/configs/vendor/lineage-a52sxq_defconfig"
        export ACTUAL_MAIN_DEFCONFIG="vendor/lineage-a52sxq_defconfig"
        export COMMON_DEFCONFIG=""
        export DEVICE_DEFCONFIG=""
        export FEATURE_DEFCONFIG=""
        export KERNEL_VERSION="5.4"
        ;;
    *)
        echo "- Invalid DEVICE_IMPORT. Valid options: sweet, davinci, ginkgo, laurel_sprout, mi89x7, a52s. Yours: $DEVICE_IMPORT."
        exit 1
        ;;
esac

# Maintainer info
export GIT_NAME="$KBUILD_BUILD_USER"
export GIT_EMAIL="$KBUILD_BUILD_USER@$KBUILD_BUILD_HOST"

# Kernel name
export KERNEL_NAME="-perf-neon"

# Global Make Arguments
export MAKE_ARGS=(
    ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as
    NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip
    CROSS_COMPILE=aarch64-linux-android- CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
    CLANG_TRIPLE=aarch64-linux-gnu-
)
