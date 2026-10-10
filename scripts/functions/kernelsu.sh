#!/bin/bash 

# Export KernelSU variables
export SUSFS_PATCH="https://raw.githubusercontent.com/JackA1ltman/NonGKI_Kernel_Build_2nd/refs/heads/mainline/Patches/Patch/susfs_patch_to_${KERNEL_VERSION}.patch"
export KSU_SETUP_URI="https://raw.githubusercontent.com/Baka-SU/BakaSU/refs/heads/main/kernel/setup.sh"

# Temporary measurements before they add stuff again
# export KSU_SETUP_BRANCH="main"
export KSU_SETUP_BRANCH="5b76b884c75f729a220bb317aa4a4fc78f0e0e9c"

# Import hook script
ksu_import_hook_script() {
    if [[ "$KERNELSU_SELECTOR" =~ "-susfs" ]]; then
        KSU_HOOK="https://raw.githubusercontent.com/JackA1ltman/NonGKI_Kernel_Build_2nd/refs/heads/mainline/Patches/susfs_inline_hook_patches.sh"
    else
        KSU_HOOK="https://raw.githubusercontent.com/JackA1ltman/NonGKI_Kernel_Build_2nd/refs/heads/mainline/Patches/syscall_hook_patches.sh"
    fi
}

# Run setup script
ksu_run_setup() {
    echo "-- KernelSU: Running setup script..."
    curl -LSs --fail --retry 3 "$KSU_SETUP_URI" | bash -s "$KSU_SETUP_BRANCH" &> /dev/null || { echo "-- Fatal: KSU setup script failed to download/run!"; exit 1; }
}

# Configure basic KernelSu configs
ksu_common_configs() {
    echo "-- KernelSU: Enabling configs..."
    echo "CONFIG_KSU=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_MULTI_MANAGER_SUPPORT=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_MANUAL_HOOK=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_THREAD_INFO_IN_TASK=y" >> $FINAL_DEFCONFIG
}

# Apply SUSFS patches
ksu_setup_susfs() {
    echo "-- KernelSU: Applying SUSFS patch..."
    wget -qO- $SUSFS_PATCH | patch -p1 -s --fuzz=5
    echo "-- KernelSU: Enabling SUSFS configs..."
    echo "CONFIG_KSU_SUSFS=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> $FINAL_DEFCONFIG
    echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> $FINAL_DEFCONFIG
}

# Ducttape SUSFS if there's patch failures
ksu_fix_susfs_fouronefour() {
    if [[ "$KERNEL_VERSION" == "4.14" ]]; then
        echo "-- KernelSU: No ducttapes for SUSFS in 4.14 yet."
    fi
}
ksu_fix_susfs_fouronenine() {
    if [[ "$KERNEL_VERSION" == "4.19" ]]; then
        echo "-- KernelSU: Patching fs/namespace.c for susfs_sus_mount..."
        sed -i 's|^[[:space:]]*mnt = alloc_vfsmnt(fc->source ?: "none");|#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n\t// - We will just stop checking for ksu process if /sdcard/Android is accessible,\n\t//   for the sake of performance\n\tif (static_branch_unlikely(\&susfs_is_sdcard_android_data_not_decrypted)) {\n\t\tif (susfs_is_current_ksu_domain()) {\n\t\t\tmnt = susfs_alloc_non_unshare_ksu_vfsmnt(fc->source ?:"none");\n\t\t\tgoto bypass_orig_flow;\n\t\t}\n\t}\n#endif\n\tmnt = alloc_vfsmnt(fc->source ?: "none");\n#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\nbypass_orig_flow:\n#endif|' fs/namespace.c
    fi
}

# Apply KernelSU hooks
ksu_apply_hooks() {
    echo "-- KernelSU: Applying hooks..."
    curl -LSs --fail --retry 3 "$KSU_HOOK" | bash &> /dev/null || { echo "Fatal: KSU setup script failed to download/run!"; exit 1; }
}

# Ducttape hooks if there's patch failures
ksu_fix_hooks_fouronefour() {
    if [[ "$KERNEL_VERSION" == "4.14" ]]; then
        echo "-- KernelSU: Fixing typos on fs/stat.c hooks..."
        sed -i 's/ksu_handle_stat(&dfd, &fname, &flag);/ksu_handle_stat(\&dfd, \&fname, \&flags);/g' fs/stat.c
    fi
}
ksu_fix_hooks_fouronenine() {
    if [[ "$KERNEL_VERSION" == "4.19" ]]; then
        echo "-- KernelSU: Fixing typos on fs/stat.c hooks..."
        sed -i 's/ksu_handle_stat(&dfd, &fname, &flag);/ksu_handle_stat(\&dfd, \&fname, \&flags);/g' fs/stat.c
    fi
}

# Export selinux symbols
ksu_export_selinux_symbols() {
    echo "-- KernelSU: Checking and exporting static SELinux symbols..."
    unstatic() {
        local file="$1" regex="$2"
        if [ -f "$file" ] && grep -q "static $regex" "$file" 2>/dev/null; then
            sed -i "s/static $regex/$regex/" "$file"
            echo "   -> Exported: $regex"
        fi
    }
    unstatic "security/selinux/selinuxfs.c" "ssize_t (\*write_op\[\])"
    unstatic "security/selinux/selinuxfs.c" "ssize_t (\*const write_op\[\])"
    unstatic "security/selinux/selinuxfs.c" "const struct file_operations sel_handle_status_ops"
    unstatic "security/selinux/selinuxfs.c" "DEFINE_MUTEX(sel_mutex);"
    unstatic "security/selinux/ss/services.c" "struct page \*selinux_status_page;"
    unstatic "security/selinux/ss/services.c" "DEFINE_MUTEX(selinux_status_lock);"
    unstatic "security/selinux/ss/services.c" "DEFINE_RWLOCK(policy_rwlock);"
    unstatic "security/selinux/hooks.c" "struct security_operations selinux_ops"
}