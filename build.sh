#!/bin/bash

# Environment setup
setup_environment() {
    echo "Setting up build environment..."
    # Imports
    local DEVICE_IMPORT="$1"
    local KERNELSU_SELECTOR="$2"
    # Maintainer info
    export KBUILD_BUILD_USER=flexes-compile
    export KBUILD_BUILD_HOST=riaru.com
    export GIT_NAME="$KBUILD_BUILD_USER"
    export GIT_EMAIL="$KBUILD_BUILD_USER@$KBUILD_BUILD_HOST"
    # GCC and Clang settings
    export CLANG_REPO_URI="https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b.git"
    export GCC_64_REPO_URI="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git"
    export GCC_32_REPO_URI="https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git"
    export CLANG_DIR=$PWD/clang
    export GCC64_DIR=$PWD/gcc64
    export GCC32_DIR=$PWD/gcc32
    export PATH="$CLANG_DIR/bin/:$GCC64_DIR/bin/:$GCC32_DIR/bin/:/usr/bin:$PATH"
    # Device Settings - v2.2
    export SELECTED_DEVICE="$DEVICE_IMPORT"
    if [[ "$DEVICE_IMPORT" == "sweet" ]]; then
        # Editable defconfig
        export MAIN_DEFCONFIG="arch/arm64/configs/vendor/sdmsteppe-perf_defconfig"
        # Do not use for edit
        export ACTUAL_MAIN_DEFCONFIG="vendor/sdmsteppe-perf_defconfig"
        export COMMON_DEFCONFIG="vendor/debugfs.config"
        export DEVICE_DEFCONFIG="vendor/sweet.config"
        # Kernel name
        export KERNEL_NAME="-perf-neon"
    else
        echo "Invalid DEVICE_IMPORT. Use a valid device name."
        exit 1
    fi
    # KernelSU Settings
    if [[ "$KERNELSU_SELECTOR" == "--ksu=KSU_BLXX" ]]; then
        export KSU_SETUP_URI="https://github.com/backslashxx/KernelSU/raw/refs/heads/master/kernel/setup.sh"
        export KSU_BRANCH="master"
        export KSU_GENERAL_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/susfs_inline_hook_patches.sh"
    elif [[ "$KERNELSU_SELECTOR" == "--ksu=KSU_NEXT" ]]; then
        export KSU_SETUP_URI="https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh"
        export KSU_BRANCH="legacy_susfs"
        export KSU_GENERAL_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/susfs_inline_hook_patches.sh"
    elif [[ "$KERNELSU_SELECTOR" == "--ksu=NONE" ]]; then
        export KSU_SETUP_URI=""
        export KSU_BRANCH=""
        export KSU_GENERAL_PATCH=""
    else
        echo "Invalid KernelSU selector. Use --ksu=KSU_BLXX, --ksu=KSU_NEXT, or --ksu=NONE."
        exit 1
    fi
    # Baseband Guard exports
    export BBG_SETUP_URI="https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh"
}

# Setup toolchain function
setup_toolchain() {
    echo "Setting up toolchain..."
    if [ ! -d "$PWD/clang" ]; then
        git clone $CLANG_REPO_URI --depth=1 clang &> /dev/null
    else
        echo "Local clang dir found, using it."
    fi
    if [ ! -d "$PWD/gcc64" ]; then
        git clone $GCC_64_REPO_URI --depth=1 gcc64 &> /dev/null
    else
        echo "Local gcc64 dir found, using it."
    fi
    if [ ! -d "$PWD/gcc32" ]; then
        git clone $GCC_32_REPO_URI --depth=1 gcc32 &> /dev/null
    else
        echo "Local gcc32 dir found, using it."
    fi
}

# Setup specific device patches
setup_specific() {
    echo "Applying device specific patches for $SELECTED_DEVICE..."
    if [[ "$SELECTED_DEVICE" == "sweet" ]]; then
        # Main LN8K Exports
        export LN8K_PATCH1="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/7b73f853977d2c016e30319dffb1f49957d30b40.patch"
        export LN8K_PATCH2="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/63dddc108d57dc43e1cd0da0f1445875f760cf97.patch"
        export LN8K_PATCH3="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/95816dff2ecc7ddd907a56537946b5cf1e864953.patch"
        export LN8K_PATCH4="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/330c60abc13530bd05287f9e5395d283ebfd6d0b.patch"
        export LN8K_PATCH5="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/0477c7006b41a1763b3314af9eb300491b91fc25.patch"
        # Sub LN8K Exports
        export LN8K_PATCH6="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/aa5ddad5be03aa7436e7ce6e84d46b280849acae.patch"
        export LN8K_PATCH7="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/857638b0da6f80830122b8d1b45c7842970e76c3.patch"
        export LN8K_PATCH8="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/3a68adff14cbedd09ce2a735d575c3bf92dd696f.patch"
        export LN8K_PATCH9="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/30fcc15d5dcf2cfc3b83a5a7d4a77e2880639fa5.patch"
        export LN8K_PATCH10="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/1a17a6fbbf59d901c4b3aec66c06a1c96cd89c7e.patch"
        # Apply LN8K patches
        echo "Applying LN8K patches..."
        wget -qO- $LN8K_PATCH1 | patch -s -p1
        wget -qO- $LN8K_PATCH2 | patch -s -p1
        wget -qO- $LN8K_PATCH3 | patch -s -p1
        wget -qO- $LN8K_PATCH4 | patch -s -p1
        wget -qO- $LN8K_PATCH5 | patch -s -p1
        wget -qO- $LN8K_PATCH6 | patch -s -p1
        wget -qO- $LN8K_PATCH7 | patch -s -p1
        wget -qO- $LN8K_PATCH8 | patch -s -p1
        wget -qO- $LN8K_PATCH9 | patch -s -p1
        wget -qO- $LN8K_PATCH10 | patch -s -p1
        echo "CONFIG_CHARGER_LN8000=y" >> $MAIN_DEFCONFIG
        # DTBO Exports
        export DTBO_PATCH1="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/e517bc363a19951ead919025a560f843c2c03ad3.patch"
        export DTBO_PATCH2="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/a62a3b05d0f29aab9c4bf8d15fe786a8c8a32c98.patch"
        export DTBO_PATCH3="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/4b89948ec7d610f997dd1dab813897f11f403a06.patch"
        export DTBO_PATCH4="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/fade7df36b01f2b170c78c63eb8fe0d11c613c4a.patch"
        export DTBO_PATCH5="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/2628183db0d96be8dae38a21f2b09cb10978f423.patch"
        export DTBO_PATCH6="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/31f4577af3f8255ae503a5b30d8f68906edde85f.patch"
        # Apply DTBO patches
        echo "Applying DTBO patches..."
        wget -qO- $DTBO_PATCH1 | patch -s -p1
        wget -qO- $DTBO_PATCH2 | patch -s -p1
        wget -qO- $DTBO_PATCH3 | patch -s -p1
        wget -qO- $DTBO_PATCH4 | patch -s -p1
        wget -qO- $DTBO_PATCH5 | patch -s -p1
        wget -qO- $DTBO_PATCH6 | patch -s -p1
        # LTO Exports
        export LTO_PATCH="https://github.com/TheSillyOk/kernel_ls_patches/raw/refs/heads/master/fix_lto.patch"
        # Apply LTO patches
        echo "Applying LTO patches..."
        wget -qO- $LTO_PATCH | patch -s -p1
        echo "CONFIG_LTO_CLANG=y" >> $MAIN_DEFCONFIG
        # Setup Baseband Guard
        echo "Setting up Baseband Guard..."
        curl -LSs $BBG_SETUP_URI | bash
        echo "CONFIG_BBG=y" >> $MAIN_DEFCONFIG
        # Apply general config patches
        echo "Tuning the rest of default configs..."
        echo "CONFIG_EROFS_FS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $MAIN_DEFCONFIG
        # SUSFS Patch
        export SUSFS_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/Patch/susfs_patch_to_4.14.patch"
        # KernelSU umount patch
        export KSU_UMOUNT_PATCH="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/64db0dfa2f8aa6c519dbf21eb65c9b89643cda3d.patch"
        # Apply umount backport and susfs
        wget -qO- $KSU_UMOUNT_PATCH | patch -s -p1
        wget -qO- $SUSFS_PATCH | patch -s -p1 --fuzz=5
        # Apply susfs configs
        echo "CONFIG_KSU_SUSFS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SUS_PATH=n" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SUS_MOUNT=n" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=n" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=n" >> $MAIN_DEFCONFIG
    else
        echo "No specific patches to apply for $SELECTED_DEVICE."
    fi
}

# Add KernelSU function
setup_ksu() {
    if [ -n "$KSU_SETUP_URI" ]; then
        echo "Setting up KernelSU..."
        if [[ "$KSU_SETUP_URI" == *"backslashxx/KernelSU"* ]]; then
            # Apply manual hook
            # curl -LSs $KSU_GENERAL_PATCH | bash
            # Run Setup Script
            curl -LSs $KSU_SETUP_URI | bash -s $KSU_BRANCH
            # Manual Config Enablement
            echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_TAMPER_SYSCALL_TABLE=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KPROBES=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_HAVE_KPROBES=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KPROBE_EVENTS=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KRETPROBES=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $MAIN_DEFCONFIG
        elif [[ "$KSU_SETUP_URI" == *"KernelSU-Next/KernelSU-Next"* ]]; then
            # Apply manual hook
            # curl -LSs $KSU_GENERAL_PATCH | bash
            # Run Setup Script
            curl -LSs $KSU_SETUP_URI | bash -s $KSU_BRANCH
            # Manual Config Enablement
            echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_KPROBES_HOOK=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KPROBES=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_HAVE_KPROBES=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KPROBE_EVENTS=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KRETPROBES=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $MAIN_DEFCONFIG
        fi
    else
        echo "No KernelSU to set up."
    fi
}

setup_precompile() {
    # Apply O3 flags into Kernel Makefile
    echo "Applying O3 flags before compiling..."
    sed -i 's/KBUILD_CFLAGS\s\++= -O2/KBUILD_CFLAGS   += -O3/g' Makefile
    sed -i 's/LDFLAGS\s\++= -O2/LDFLAGS += -O3/g' Makefile
    # Make a output directory
    mkdir -p out
    # Setup main defconfig for compilation
    make O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        $ACTUAL_MAIN_DEFCONFIG &> /dev/null
    # Merge additional configs
    echo "Appending fragments to .config..."
    for fragment in $COMMON_DEFCONFIG $DEVICE_DEFCONFIG; do
        if [ -f "arch/arm64/configs/$fragment" ]; then
            echo "Merging $fragment..."
            cat "arch/arm64/configs/$fragment" >> out/.config
        else
            echo "Warning: Fragment arch/arm64/configs/$fragment not found!"
        fi
    done
    # Set kernel name
    echo "CONFIG_LOCALVERSION=\"$KERNEL_NAME\"" >> out/.config
    # Run olddefconfig to finalize .config
    yes "" | make O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu- \
        olddefconfig &> /dev/null
    # Do a git cleanup before compiling
    echo "Cleaning up git before compiling..."
    git config user.email $GIT_EMAIL
    git config user.name $GIT_NAME
    git config set advice.addEmbeddedRepo true
    git add .
    git commit -m "cleanup: applied patches before build" &> /dev/null
}

# Compile kernel function
compile_kernel() {
    # Start compilation
    echo "Starting kernel compilation..."
    make -j$(nproc --all) \
        O=out \
        ARCH=arm64 \
        LLVM=1 \
        LLVM_IAS=1 \
        CC=clang \
        LD=ld.lld \
        AR=llvm-ar \
        AS=llvm-as \
        NM=llvm-nm \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip \
        CROSS_COMPILE=aarch64-linux-android- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CLANG_TRIPLE=aarch64-linux-gnu- 
}

# Main function
main() {
    # Check if all four arguments are valid
    echo "Validating input arguments..."
    if [ $# -ne 2 ]; then
        echo "Usage: $0 <DEVICE_IMPORT> <KERNELSU_SELECTOR>"
        echo "Example: $0 sweet --ksu=KSU_BLXX"
        exit 1
    fi
    setup_environment "$1" "$2"
    setup_toolchain
    setup_specific
    setup_ksu
    setup_precompile
    compile_kernel
}

# Run the main function
main "$1" "$2"