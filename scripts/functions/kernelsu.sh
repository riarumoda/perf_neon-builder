#!/bin/bash 

# Export KernelSU variables
export SUSFS_PATCH="https://raw.githubusercontent.com/JackA1ltman/NonGKI_Kernel_Build_2nd/refs/heads/mainline/Patches/Patch/susfs_patch_to_${KERNEL_VERSION}.patch"
export KSU_SETUP_URI="https://raw.githubusercontent.com/Baka-SU/BakaSU/refs/heads/main/kernel/setup.sh"
export KSU_SELINUX_HIDE_LINEAGE="https://raw.githubusercontent.com/null07089/Lineage_Hide/refs/heads/main/scripts/selinux_hide_patch.sh"
export KSU_CUSTOMROM_HIDE_LINEAGE="https://raw.githubusercontent.com/null07089/Lineage_Hide/refs/heads/main/scripts/patch-kernel.sh"

# Temporary measurements before they add stuff again
export KSU_SETUP_BRANCH="main"
# export KSU_SETUP_BRANCH="5b76b884c75f729a220bb317aa4a4fc78f0e0e9c"
# export KSU_SETUP_BRANCH="sync-susfs"

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
    curl -LSs --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$KSU_SETUP_URI" | bash -s "$KSU_SETUP_BRANCH" &> /dev/null || { echo "-- Fatal: KSU setup script failed to download/run!"; exit 1; }
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
        if ! grep -q "susfs_is_uname_spoof_buffer_set" kernel/sys.c; then
            echo "-- KernelSU: Patching kernel/sys.c for susfs_spoof_uname..."
            git checkout kernel/sys.c
            rm -f kernel/sys.c.rej
            sed -i 's/^SYSCALL_DEFINE1(newuname/#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME\nextern struct static_key_false susfs_is_uname_spoof_buffer_set;\nextern void susfs_spoof_uname(struct new_utsname* tmp);\n#endif\n&/' kernel/sys.c
            sed -i '/^SYSCALL_DEFINE1(newuname/,/^}/ s/memcpy(&tmp, utsname(), sizeof(tmp));/memcpy(\&tmp, utsname(), sizeof(tmp));\n#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME\n\tif (static_branch_likely(\&susfs_is_uname_spoof_buffer_set))\n\t\tsusfs_spoof_uname(\&tmp);\n#endif/' kernel/sys.c
        fi
    fi
}
ksu_fix_susfs_fouronenine() {
    if [[ "$KERNEL_VERSION" == "4.19" ]]; then
        echo "-- KernelSU: Patching fs/namespace.c for susfs_sus_mount..."
        sed -i 's|^[[:space:]]*mnt = alloc_vfsmnt(fc->source ?: "none");|#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n\t// - We will just stop checking for ksu process if /sdcard/Android is accessible,\n\t//   for the sake of performance\n\tif (static_branch_unlikely(\&susfs_is_sdcard_android_data_not_decrypted)) {\n\t\tif (susfs_is_current_ksu_domain()) {\n\t\t\tmnt = susfs_alloc_non_unshare_ksu_vfsmnt(fc->source ?:"none");\n\t\t\tgoto bypass_orig_flow;\n\t\t}\n\t}\n#endif\n\tmnt = alloc_vfsmnt(fc->source ?: "none");\n#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\nbypass_orig_flow:\n#endif|' fs/namespace.c
    fi
}
ksu_fix_susfs_fivepointfour() {
    if [[ "$KERNEL_VERSION" == "5.4" ]]; then
        echo "-- KernelSU: Patching fs/proc/fd.c for susfs_sus_mount..."
        if grep -Fq 'ino:\t%lu\n' fs/proc/fd.c; then
            sed -i '/^[[:space:]]*seq_printf(m, "pos:\\t%lli\\nflags:\\t0%o\\nmnt_id:\\t%i\\nino:\\t%lu\\n",/i \
            #ifdef CONFIG_KSU_SUSFS_SUS_KSTAT\
            	if (susfs_is_current_app_uid()) {\
            		struct inode *inode = file_inode(file);\
            		bool is_fuse = false;\
            		if (susfs_is_inode_sus_kstat(inode, &is_fuse)) {\
            			int mnt_id = real_mount(file->f_path.mnt)->mnt_id;\
            			unsigned long ino = inode->i_ino;\
            			susfs_sus_kstat_spoof_proc_fd_seq_show(&mnt_id, &ino, inode->i_sb->s_dev);\
            			seq_printf(m, "pos:\\t%lli\\nflags:\\t0%o\\nmnt_id:\\t%i\\nino:\\t%lu\\n",\
            					(long long)file->f_pos, f_flags,\
            					mnt_id,\
            					ino);\
            			goto bypass_orig_flow;\
            		}\
            	}\
            #endif // #ifdef CONFIG_KSU_SUSFS_SUS_KSTAT\
            \
            #ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\
            	if (likely(susfs_is_current_proc_umounted())) {\
            		struct mount *mnt = real_mount(file->f_path.mnt);\
            		if (mnt->mnt_id >= DEFAULT_KSU_MNT_ID) {\
            			struct path path;\
            			char *pathname = kmalloc(PAGE_SIZE, GFP_KERNEL);\
            			char *dpath;\
            \
            			if (!pathname) {\
            				goto orig_flow;\
            			}\
            			dpath = d_path(&file->f_path, pathname, PAGE_SIZE);\
            			if (!dpath) {\
            				goto out_kfree;\
            			}\
            			if (kern_path(dpath, 0, &path)) {\
            				goto out_kfree;\
            			}\
            			if (!d_backing_inode(path.dentry)) {\
            				goto out_path_put;\
            			}\
            \
            			seq_printf(m, "pos:\\t%lli\\nflags:\\t0%o\\nmnt_id:\\t%i\\nino:\\t%lu\\n",\
            					(long long)file->f_pos, f_flags,\
            					susfs_get_non_sus_mnt_id_from_mnt(mnt),\
            					d_backing_inode(path.dentry)->i_ino);\
            			path_put(&path);\
            			kfree(pathname);\
            			goto bypass_orig_flow;\
            out_path_put:\
            			path_put(&path);\
            out_kfree:\
            			kfree(pathname);\
            			goto orig_flow;\
            		}\
            	}\
            orig_flow:\
            #endif // #ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\
            ' fs/proc/fd.c
            sed -i '/^[[:space:]]*show_fd_locks(m, file, files);/i \
            #if defined(CONFIG_KSU_SUSFS_SUS_MOUNT) || defined(CONFIG_KSU_SUSFS_SUS_KSTAT)\
            bypass_orig_flow:\
            #endif // #if defined(CONFIG_KSU_SUSFS_SUS_MOUNT) || defined(CONFIG_KSU_SUSFS_SUS_KSTAT)\
            ' fs/proc/fd.c
        fi
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
    unstatic "security/selinux/ss/status.c" "struct page \*selinux_status_page;"
    unstatic "security/selinux/ss/status.c" "DEFINE_MUTEX(selinux_status_lock);"
    unstatic "security/selinux/ss/services.c" "DEFINE_RWLOCK(policy_rwlock);"
    unstatic "security/selinux/hooks.c" "struct security_operations selinux_ops"
    unstatic "security/selinux/ss/services.c" "void security_dump_masked_av"
    unstatic "security/selinux/ss/services.c" "void context_struct_compute_av"
}

# Fix exposed SELinux on LineageOS and their forks
ksu_fix_exposed_selinux_linag() {
    echo "-- KernelSU: Fixing exposed adbd SELinux..."
    curl -LSs --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$KSU_SELINUX_HIDE_LINEAGE" | bash -s KernelSU/ &> /dev/null || { echo "-- Fatal: SELinux Hide fixup script failed to download/run!"; exit 1; }
}

# Nuke dirty flag
ksu_nuke_dirtyflag() {
    echo "-- KernelSU: Removing dirty flag label..."
    sed -i 's/\$(KSU_COMMIT_SHA)-dirty/$(KSU_COMMIT_SHA)/' KernelSU/kernel/Kbuild
}

# Hide custom rom details
ksu_hide_customrom() {
    echo "-- KernelSU: Hiding Custom ROM details..."
    curl -LSs --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$KSU_CUSTOMROM_HIDE_LINEAGE" | bash -s ./ &> /dev/null || { echo "-- Fatal: Hide Custom ROM script failed to download/run!"; exit 1; }
}