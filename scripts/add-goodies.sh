#!/bin/bash
echo "- Setting up additional goodies..."

# Defualt Exports
export BACKPORT_GENERAL_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/backport_patches.sh"
export KSU_SETUP_URI="https://github.com/ReSukiSU/ReSukiSU/raw/refs/heads/main/kernel/setup.sh"
export BBG_SETUP_URI="https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh"
export SUSFS_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/Patch/susfs_patch_to_${KERNEL_VERSION}.patch"

# KernelSU setup
echo "-- Setting up KernelSU..."
case "$KERNELSU_SELECTOR" in
    zako|zako-susfs)
        # Setup KernelSU
        curl -LSs "$KSU_SETUP_URI" | bash -s main &> /dev/null
        # Enable the necessary KernelSU configs
        echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MULTI_MANAGER_SUPPORT=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KPM=n" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MANUAL_HOOK=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_THREAD_INFO_IN_TASK=y" >> $MAIN_DEFCONFIG
        # SUSFS Settings
        if [[ "$KERNELSU_SELECTOR" == "zako-susfs" ]]; then
            wget -qO- $SUSFS_PATCH | patch -s -p1 --fuzz=5
            echo "CONFIG_KSU_SUSFS=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> $MAIN_DEFCONFIG
            echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> $MAIN_DEFCONFIG
            KSU_HOOK="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/susfs_inline_hook_patches.sh"
        else
            KSU_HOOK="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/syscall_hook_patches.sh"
        fi
        # Apply backport and hooks
        curl -LSs "$BACKPORT_GENERAL_PATCH" | bash &> /dev/null
        curl -LSs "$KSU_HOOK" | bash &> /dev/null
        ;;
    none|"")
        echo "No KernelSU to set up."
        ;;
    *)
        echo "- Invalid KERNELSU_SELECTOR: $KERNELSU_SELECTOR. Valid options: zako, zako-susfs, none."
        exit 1
        ;;
esac

# Baseband Guard setup
case "$BBG_SELECTOR" in
    bbg)
        # Setup Baseband Guard
        echo "-- Setting up Baseband Guard..."
        curl -LSs "$BBG_SETUP_URI" | bash &> /dev/null
        # Enable the necessary Baseband Guard configs
        echo "CONFIG_BBG=y" >> $MAIN_DEFCONFIG
        # Kernel Settings for Baseband Guard
        if [[ "$KERNEL_VERSION" == "4.19" ] || [ "$KERNEL_VERSION" == "5.4" ]]; then
            sed -i '/CONFIG_LSM=/s/"$/ ,baseband_guard"/' $MAIN_DEFCONFIG
        fi
        ;;
    none|"")
        echo "No Baseband Guard to set up."
        ;;
    *)
        echo "- Invalid BBG_SELECTOR: $BBG_SELECTOR. Valid options: bbg, none."
        exit 1
        ;;
esac
