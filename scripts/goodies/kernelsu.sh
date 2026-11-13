#!/bin/bash

# Export KernelSU variables
SUSFS_PATCH="https://raw.githubusercontent.com/JackA1ltman/NonGKI_Kernel_Build_2nd/refs/heads/mainline/Patches/Patch/susfs_patch_to_${KERNEL_VERSION}.patch"
KSU_SETUP_URI="https://raw.githubusercontent.com/Baka-SU/BakaSU/refs/heads/main/kernel/setup.sh"
KSU_SETUP_BRANCH="sync-up"
KSU_HOOK="https://raw.githubusercontent.com/JackA1ltman/NonGKI_Kernel_Build_2nd/refs/heads/mainline/Patches/susfs_inline_hook_patches.sh"

# Run KernelSU setup script
cd $KERNEL_DIR
echo "-- KernelSU: Running setup script..."
curl -LSs --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$KSU_SETUP_URI" | bash -s "$KSU_SETUP_BRANCH" &> /dev/null || { echo "-- Fatal: KSU setup script failed to download/run!"; exit 1; }

# Enable KernelSU Configs
echo "-- KernelSU: Enabling configs..."
echo "CONFIG_KSU=y" >> $FINAL_DEFCONFIG
echo "CONFIG_KSU_MULTI_MANAGER_SUPPORT=y" >> $FINAL_DEFCONFIG
echo "CONFIG_KSU_MANUAL_HOOK=y" >> $FINAL_DEFCONFIG
echo "CONFIG_HAVE_SYSCALL_TRACEPOINTS=y" >> $FINAL_DEFCONFIG
echo "CONFIG_THREAD_INFO_IN_TASK=y" >> $FINAL_DEFCONFIG

# Apply SUSFS patches
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

# Duct tape SUSFS
if [[ "$KERNEL_VERSION" == "4.14" ]]; then
    if ! grep -q "susfs_is_uname_spoof_buffer_set" kernel/sys.c; then
        echo "-- KernelSU: Patching kernel/sys.c for susfs_spoof_uname..."
        git checkout kernel/sys.c
        rm -f kernel/sys.c.rej
        sed -i 's/^SYSCALL_DEFINE1(newuname/#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME\nextern struct static_key_false susfs_is_uname_spoof_buffer_set;\nextern void susfs_spoof_uname(struct new_utsname* tmp);\n#endif\n&/' kernel/sys.c
        sed -i '/^SYSCALL_DEFINE1(newuname/,/^}/ s/memcpy(&tmp, utsname(), sizeof(tmp));/memcpy(\&tmp, utsname(), sizeof(tmp));\n#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME\n\tif (static_branch_likely(\&susfs_is_uname_spoof_buffer_set))\n\t\tsusfs_spoof_uname(\&tmp);\n#endif/' kernel/sys.c
    fi
fi
if [[ "$KERNEL_VERSION" == "4.19" ]]; then
    echo "-- KernelSU: Patching fs/namespace.c for susfs_sus_mount..."
    sed -i 's|^[[:space:]]*mnt = alloc_vfsmnt(fc->source ?: "none");|#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n\t// - We will just stop checking for ksu process if /sdcard/Android is accessible,\n\t//   for the sake of performance\n\tif (static_branch_unlikely(\&susfs_is_sdcard_android_data_not_decrypted)) {\n\t\tif (susfs_is_current_ksu_domain()) {\n\t\t\tmnt = susfs_alloc_non_unshare_ksu_vfsmnt(fc->source ?:"none");\n\t\t\tgoto bypass_orig_flow;\n\t\t}\n\t}\n#endif\n\tmnt = alloc_vfsmnt(fc->source ?: "none");\n#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\nbypass_orig_flow:\n#endif|' fs/namespace.c
fi
if [[ "$KERNEL_VERSION" == "5.4" ]]; then
    # copy_mnt_ns() wraps copy_tree() in #ifdef CONFIG_KDP_NS on sm7325, which
    # breaks the SUSFS hunk's trailing context. With --fuzz=5 patch drops the
    # whole context and lands copy_flags |= CL_COPY_MNT_NS; in the wrong
    # function, where copy_flags does not exist. Move it back.
    if grep -q 'copy_flags |= CL_COPY_MNT_NS;' fs/namespace.c && \
       ! grep -A2 'copy_flags |= CL_SHARED_TO_SLAVE;' fs/namespace.c | grep -q 'CL_COPY_MNT_NS'; then
        echo "-- KernelSU: Moving misplaced copy_flags hook in fs/namespace.c..."
        python3 - <<'PY' || { echo "-- Fatal: could not fix copy_flags hook!"; exit 1; }
path = "fs/namespace.c"
src = open(path).read()
block = "#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n\tcopy_flags |= CL_COPY_MNT_NS;\n#endif\n"
if src.count(block) != 1:
    raise SystemExit("expected exactly one misplaced block, found %d" % src.count(block))
src = src.replace(block, "", 1)
anchor = "\tcopy_flags |= CL_SHARED_TO_SLAVE;\n"
if src.count(anchor) != 1:
    raise SystemExit("expected one CL_SHARED_TO_SLAVE anchor, found %d" % src.count(anchor))
src = src.replace(anchor, anchor + block, 1)
open(path, "w").write(src)
print("   -> moved into copy_mnt_ns()")
PY
    fi
    # susfs_patch_to_5.4.patch already patches fs/proc/fd.c; only fall back to
    # the legacy duct tape when it doesn't, or the labels get defined twice.
    if ! grep -q 'susfs_get_non_sus_mnt_id_from_mnt' fs/proc/fd.c; then
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
fi

# Then after allat, apply hooks
echo "-- KernelSU: Applying hooks..."
curl -LSs --fail --retry 3 "$KSU_HOOK" | bash &> /dev/null || { echo "Fatal: KSU setup script failed to download/run!"; exit 1; }

# Also ducttape hooks
if [[ "$KERNEL_VERSION" == "4.14" ]]; then
    echo "-- KernelSU: Fixing typos on fs/stat.c hooks..."
    sed -i 's/ksu_handle_stat(&dfd, &fname, &flag);/ksu_handle_stat(\&dfd, \&fname, \&flags);/g' fs/stat.c
    if grep -q 'ksu_handle_faccessat(&dfd, &fname, &mode, NULL);' fs/open.c && \
       ! grep -q 'extern int ksu_handle_faccessat' fs/open.c; then
        echo "-- KernelSU: Restoring fs/open.c declarations for faccessat2..."
        sed -i '/^long do_faccessat(/i\
            #ifdef CONFIG_KSU_SUSFS\
            extern struct static_key_true ksu_su_compat_enabled;\
            extern bool __ksu_is_allow_uid_for_current(uid_t uid);\
            extern int ksu_handle_faccessat(int *dfd, struct filename **filename, int *mode, int *flags);\
            extern int filename_lookup(int dfd, struct filename *name, unsigned flags, struct path *path, struct path *root);\
            #endif' fs/open.c
    fi
fi
if [[ "$KERNEL_VERSION" == "4.19" ]]; then
    echo "-- KernelSU: Fixing typos on fs/stat.c hooks..."
    sed -i 's/ksu_handle_stat(&dfd, &fname, &flag);/ksu_handle_stat(\&dfd, \&fname, \&flags);/g' fs/stat.c
fi

# Unstatic some symbols inside the kernel
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
cd ..
