#!/bin/bash
echo "- Setting up additional goodies..."

# Default Exports
export BACKPORT_GENERAL_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/backport_patches.sh"
export BBG_SETUP_URI="https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh"
export SUSFS_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/Patch/susfs_patch_to_${KERNEL_VERSION}.patch"

# KernelSU setup
echo "-- Setting up KernelSU..."
case "$KERNELSU_SELECTOR" in
    zako|zako-susfs)
        # KernelSU Settings
        export KSU_SETUP_URI="https://github.com/ReSukiSU/ReSukiSU/raw/refs/heads/main/kernel/setup.sh"
        export KSU_SETUP_BRANCH="main"
        # SUSFS Settings
        if [[ "$KERNELSU_SELECTOR" == "zako-susfs" ]]; then
            export KSU_SETUP_BRANCH="main"
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
        # Setup KernelSU
        curl -LSs --fail --retry 3 "$KSU_SETUP_URI" | bash -s $KSU_SETUP_BRANCH &> /dev/null || { echo "Fatal: KSU setup script failed to download/run!"; exit 1; }
        # Enable the necessary KernelSU configs
        echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MULTI_MANAGER_SUPPORT=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KPM=n" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MANUAL_HOOK=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_THREAD_INFO_IN_TASK=y" >> $MAIN_DEFCONFIG
        # Apply backport and hooks
        curl -LSs "$BACKPORT_GENERAL_PATCH" | bash
        curl -LSs "$KSU_HOOK" | bash
        if [[ "$KERNELSU_SELECTOR" == "zako-susfs" ]]; then
            wget -qO- $SUSFS_PATCH | patch -s -p1 --fuzz=5
        fi
        ;;
    ksunext|ksunext-susfs)
        # KernelSU Settings
        export KSU_SETUP_URI="https://github.com/KernelSU-Next/KernelSU-Next/raw/refs/heads/dev/kernel/setup.sh"
        export KSU_SETUP_BRANCH="legacy"
        # SUSFS Settings
        if [[ "$KERNELSU_SELECTOR" == "ksunext-susfs" ]]; then
            export KSU_SETUP_BRANCH="legacy_susfs"
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
        # Setup KernelSU
        curl -LSs --fail --retry 3 "$KSU_SETUP_URI" | bash -s $KSU_SETUP_BRANCH &> /dev/null || { echo "Fatal: KSU setup script failed to download/run!"; exit 1; }
        # Enable the necessary KernelSU configs
        echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MANUAL_HOOK=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_THREAD_INFO_IN_TASK=y" >> $MAIN_DEFCONFIG
        # Apply backport and hooks
        curl -LSs "$BACKPORT_GENERAL_PATCH" | bash
        curl -LSs "$KSU_HOOK" | bash
        if [[ "$KERNELSU_SELECTOR" == "ksunext-susfs" ]]; then
            wget -qO- $SUSFS_PATCH | patch -s -p1 --fuzz=5
        fi
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
        curl -LSs --fail --retry 3 "$BBG_SETUP_URI" | bash &> /dev/null || { echo "Fatal: BBG setup script failed to download/run!"; exit 1; }
        # Enable the necessary Baseband Guard configs
        echo "CONFIG_BBG=y" >> $MAIN_DEFCONFIG
        # Kernel Settings for Baseband Guard
        if [[ "$KERNEL_VERSION" == "4.19" ]] || [[ "$KERNEL_VERSION" == "5.4" ]]; then
            LSM_FALLBACK='CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,bpf,baseband_guard"'
            if grep -q "CONFIG_LSM=" "$MAIN_DEFCONFIG"; then
                sed -i '/CONFIG_LSM=/s/"$/ ,baseband_guard"/' "$MAIN_DEFCONFIG"
                echo "-- Appended baseband_guard to existing CONFIG_LSM."
            else
                echo "$LSM_FALLBACK" >> "$MAIN_DEFCONFIG"
                echo "-- Added default CONFIG_LSM with baseband_guard."
            fi
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

