#!/bin/bash
echo "- Setting up additional goodies..."

# Default Exports
export BACKPORT_GENERAL_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/backport_patches.sh"
export BBG_SETUP_URI="https://github.com/vc-teahouse/Baseband-guard/raw/main/setup.sh"
export SUSFS_PATCH="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/Patch/susfs_patch_to_${KERNEL_VERSION}.patch"

# Helper function for safe download and execution
download_and_execute() {
    local url="$1"
    local description="$2"
    local temp_file="/tmp/temp_script_$$.sh"
    
    echo "-- Downloading ${description}..."
    if ! curl -fSL --retry 3 --retry-delay 2 -o "$temp_file" "$url"; then
        echo "Fatal: Failed to download ${description} from $url"
        rm -f "$temp_file"
        exit 1
    fi
    
    if [ ! -s "$temp_file" ]; then
        echo "Fatal: Downloaded ${description} is empty"
        rm -f "$temp_file"
        exit 1
    fi
    
    echo "-- Executing ${description}..."
    if ! bash "$temp_file"; then
        echo "Fatal: Failed to execute ${description}"
        rm -f "$temp_file"
        exit 1
    fi
    
    rm -f "$temp_file"
    echo "-- ${description} completed successfully"
}

# Helper function for safe download and pipe to bash with arguments
download_and_execute_with_args() {
    local url="$1"
    local description="$2"
    local args="$3"
    local temp_file="/tmp/temp_script_$$.sh"
    
    echo "-- Downloading ${description}..."
    if ! curl -fSL --retry 3 --retry-delay 2 -o "$temp_file" "$url"; then
        echo "Fatal: Failed to download ${description} from $url"
        rm -f "$temp_file"
        exit 1
    fi
    
    if [ ! -s "$temp_file" ]; then
        echo "Fatal: Downloaded ${description} is empty"
        rm -f "$temp_file"
        exit 1
    fi
    
    echo "-- Executing ${description} with arguments: $args..."
    if ! bash "$temp_file" $args; then
        echo "Fatal: Failed to execute ${description}"
        rm -f "$temp_file"
        exit 1
    fi
    
    rm -f "$temp_file"
    echo "-- ${description} completed successfully"
}

# Helper function for safe patch download and apply
download_and_apply_patch() {
    local url="$1"
    local description="$2"
    local temp_file="/tmp/temp_patch_$$.patch"
    
    echo "-- Downloading ${description}..."
    if ! curl -fSL --retry 3 --retry-delay 2 -o "$temp_file" "$url"; then
        echo "Fatal: Failed to download ${description} from $url"
        rm -f "$temp_file"
        exit 1
    fi
    
    if [ ! -s "$temp_file" ]; then
        echo "Fatal: Downloaded ${description} is empty"
        rm -f "$temp_file"
        exit 1
    fi
    
    echo "-- Applying ${description}..."
    if ! patch -s -p1 --fuzz=5 < "$temp_file"; then
        echo "Fatal: Failed to apply ${description}"
        rm -f "$temp_file"
        exit 1
    fi
    
    rm -f "$temp_file"
    echo "-- ${description} applied successfully"
}

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
            KSU_HOOK="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/susfs_inline_hook_patches.sh"
        else
            KSU_HOOK="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/syscall_hook_patches.sh"
        fi
        
        # Setup KernelSU
        download_and_execute_with_args "$KSU_SETUP_URI" "KernelSU setup script" "$KSU_SETUP_BRANCH"
        
        # Enable the necessary KernelSU configs
        echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MULTI_MANAGER_SUPPORT=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KPM=n" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MANUAL_HOOK=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_THREAD_INFO_IN_TASK=y" >> $MAIN_DEFCONFIG
        
        # Apply backport and hooks
        echo "-- Applying KernelSU hooks..."
        download_and_execute "$BACKPORT_GENERAL_PATCH" "backport patch"
        download_and_execute "$KSU_HOOK" "KSU hook script"
        
        if [[ "$KERNELSU_SELECTOR" == "zako-susfs" ]]; then
            download_and_apply_patch "$SUSFS_PATCH" "SUSFS patch"
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
        fi
        
        # Export policy_rwlock if exist
        POLICY_RWLOCK_CHECK=$(grep -q "static DEFINE_RWLOCK(policy_rwlock);" "${PWD}/security/selinux/ss/services.c" && echo "true")
        if [[ "$POLICY_RWLOCK_CHECK" == "true" ]]; then
            echo "-- Exporting policy_rwlock..."
            sed -i 's/^static \(DEFINE_RWLOCK(policy_rwlock);\)/\1/' security/selinux/ss/services.c
        fi
        
        # Kernel 4.4 specific patches
        if [[ "$KERNEL_VERSION" == "4.4" ]]; then
            echo "-- Re-tuning ksu_handle_devpts under 4.4..."
            sed -i '/static struct tty_struct \*pts_unix98_lookup/,/}/ s/ksu_handle_devpts((struct inode \*)file->f_path.dentry->d_inode);/ksu_handle_devpts(pts_inode);/' drivers/tty/pty.c
        fi
        ;;
        
    ksunext|ksunext-susfs)
        # KernelSU Settings
        export KSU_SETUP_URI="https://github.com/KernelSU-Next/KernelSU-Next/raw/refs/heads/dev/kernel/setup.sh"
        export KSU_SETUP_BRANCH="legacy"
        # SUSFS Settings
        if [[ "$KERNELSU_SELECTOR" == "ksunext-susfs" ]]; then
            export KSU_SETUP_BRANCH="legacy_susfs"
            KSU_HOOK="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/susfs_inline_hook_patches.sh"
        else
            KSU_HOOK="https://github.com/JackA1ltman/NonGKI_Kernel_Build_2nd/raw/refs/heads/mainline/Patches/syscall_hook_patches.sh"
        fi
        
        # Setup KernelSU
        download_and_execute_with_args "$KSU_SETUP_URI" "KernelSU-Next setup script" "$KSU_SETUP_BRANCH"
        
        # Enable the necessary KernelSU configs
        echo "CONFIG_KSU=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_KSU_MANUAL_HOOK=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_THREAD_INFO_IN_TASK=y" >> $MAIN_DEFCONFIG
        
        # Apply backport and hooks
        echo "-- Applying KernelSU hooks..."
        download_and_execute "$BACKPORT_GENERAL_PATCH" "backport patch"
        download_and_execute "$KSU_HOOK" "KSU hook script"
        
        if [[ "$KERNELSU_SELECTOR" == "ksunext-susfs" ]]; then
            download_and_apply_patch "$SUSFS_PATCH" "SUSFS patch"
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
        fi
        
        # Export policy_rwlock if exist
        POLICY_RWLOCK_CHECK=$(grep -q "static DEFINE_RWLOCK(policy_rwlock);" "${PWD}/security/selinux/ss/services.c" && echo "true")
        if [[ "$POLICY_RWLOCK_CHECK" == "true" ]]; then
            echo "-- Exporting policy_rwlock..."
            sed -i 's/^static \(DEFINE_RWLOCK(policy_rwlock);\)/\1/' security/selinux/ss/services.c
        fi
        
        # Kernel 4.4 specific patches
        if [[ "$KERNEL_VERSION" == "4.4" ]]; then
            echo "-- Re-tuning ksu_handle_devpts under 4.4..."
            sed -i '/static struct tty_struct \*pts_unix98_lookup/,/}/ s/ksu_handle_devpts((struct inode \*)file->f_path.dentry->d_inode);/ksu_handle_devpts(pts_inode);/' drivers/tty/pty.c
        fi
        ;;
        
    none|"")
        echo "-- KernelSU is not selected."
        ;;
        
    *)
        echo "- Invalid KERNELSU_SELECTOR: $KERNELSU_SELECTOR. Valid options: zako, zako-susfs, ksunext, ksunext-susfs, none."
        exit 1
        ;;
esac

# Baseband Guard setup
case "$BBG_SELECTOR" in
    bbg)
        # Setup Baseband Guard
        echo "-- Setting up Baseband Guard..."
        download_and_execute "$BBG_SETUP_URI" "Baseband Guard setup script"
        
        # Enable the necessary Baseband Guard configs
        echo "CONFIG_BBG=y" >> $MAIN_DEFCONFIG
        
        # Check if kernel have DEFINE_LSM
        DEFINE_LSM_CHECK=$(grep -q "#define DEFINE_LSM(lsm)" "${PWD}/include/linux/lsm_hooks.h" && echo "true")
        
        # Kernel Settings for Baseband Guard
        if [[ "$DEFINE_LSM_CHECK" == "true" ]]; then
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
        echo "-- Baseband Guard is not selected."
        ;;
        
    *)
        echo "- Invalid BBG_SELECTOR: $BBG_SELECTOR. Valid options: bbg, none."
        exit 1
        ;;
esac

echo "- Additional goodies setup completed successfully"
