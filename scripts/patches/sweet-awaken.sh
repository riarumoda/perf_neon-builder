#!/bin/bash
cd "$KERNEL_DIR"

# Revert the in-tree KernelSU-Next so BakaSU can own drivers/kernelsu.
echo "-- Reverting KSU specific commits..."
rm -rf drivers/kernelsu

awk '
  skip_blank {
    if ($0 ~ /^[[:space:]]*$/) { skip_blank = 0; next }
    skip_blank = 0
  }
  /^source "drivers\/kernelsu\/Kconfig"$/ { skip_blank = 1; next }
  { print }
' drivers/Kconfig > drivers/Kconfig.tmp &&
    mv drivers/Kconfig.tmp drivers/Kconfig ||
    { echo "-- Fatal: failed to revert drivers/Kconfig!"; exit 1; }

awk '
  /^obj-\$\(CONFIG_KSU\)[[:space:]]*\+=[[:space:]]*kernelsu\/$/ {
    if (have_prev && prev ~ /^[[:space:]]*$/) have_prev = 0
    next
  }
  {
    if (have_prev) print prev
    prev = $0
    have_prev = 1
  }
  END { if (have_prev) print prev }
' drivers/Makefile > drivers/Makefile.tmp &&
    mv drivers/Makefile.tmp drivers/Makefile ||
    { echo "-- Fatal: failed to revert drivers/Makefile!"; exit 1; }

for defconfig in arch/arm64/configs/*_defconfig; do
    awk '
      /^# KernelSU$/ {
        if (n > 0 && buf[n - 1] == "#") n--
        if (n > 0 && buf[n - 1] ~ /^[[:space:]]*$/) n--
        in_ksu = 1
        next
      }
      in_ksu {
        if ($0 == "CONFIG_KSU_MANUAL_HOOK=y") in_ksu = 0
        next
      }
      { buf[n++] = $0 }
      END { for (i = 0; i < n; i++) print buf[i] }
    ' "$defconfig" > "$defconfig.tmp" &&
        mv "$defconfig.tmp" "$defconfig" ||
        { echo "-- Fatal: failed to revert $defconfig!"; exit 1; }
done

remove_ksu_hooks() {
    awk '
      /^[[:space:]]*#ifdef CONFIG_KSU_MANUAL_HOOK[[:space:]]*$/ { inblock = 1; next }
      inblock {
        if ($0 ~ /^[[:space:]]*#endif[[:space:]]*$/) { inblock = 0; skip_blank = 1 }
        next
      }
      skip_blank {
        if ($0 ~ /^[[:space:]]*$/) { skip_blank = 0; next }
        skip_blank = 0
      }
      { print }
    ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}
for hook in drivers/input/input.c fs/exec.c fs/open.c fs/read_write.c \
            fs/stat.c kernel/reboot.c security/selinux/avc.c; do
    if [ -f "$hook" ]; then
        remove_ksu_hooks "$hook" ||
            { echo "-- Fatal: failed to revert hooks in $hook!"; exit 1; }
    fi
done

sed -i '/^SYSCALL_DEFINE3(read,/,/^}/ {
  s/^\tstruct fd f;$/\tstruct fd f = fdget_pos(fd);/
  /^\tf = fdget_pos(fd);$/d
}' fs/read_write.c || { echo "-- Fatal: failed to revert fs/read_write.c!"; exit 1; }

sed -i '/^int path_umount(struct path \*path, int flags);$/{N;d;}' fs/internal.h ||
    { echo "-- Fatal: failed to revert fs/internal.h!"; exit 1; }
sed -i '/^static int can_umount(/,/^#ifdef __ARCH_WANT_SYS_OLDUMOUNT$/{
  /^#ifdef __ARCH_WANT_SYS_OLDUMOUNT$/!d
}' fs/namespace.c || { echo "-- Fatal: failed to revert fs/namespace.c!"; exit 1; }

leftovers=""
if [ -d drivers/kernelsu ]; then
    leftovers="$leftovers drivers/kernelsu"
fi
if grep -q 'CONFIG_KSU' arch/arm64/configs/*_defconfig; then
    leftovers="$leftovers defconfig"
fi
if grep -q 'CONFIG_KSU_MANUAL_HOOK' drivers/input/input.c fs/exec.c fs/open.c \
       fs/read_write.c fs/stat.c kernel/reboot.c security/selinux/avc.c; then
    leftovers="$leftovers hooks"
fi
if grep -q 'path_umount' fs/internal.h fs/namespace.c; then
    leftovers="$leftovers path_umount"
fi
if grep -q 'kernelsu' drivers/Kconfig drivers/Makefile; then
    leftovers="$leftovers drivers"
fi
if [ -n "$leftovers" ]; then
    echo "-- Fatal: KSU revert left:$leftovers"
    exit 1
fi
echo "   -> removed drivers/kernelsu, its configs and manual hooks"

# Specific tweaks
echo "-- Fixing fair scheduler..."
sed -i -e 's/update_load_avg(qcfs_rq, se, 0);/update_load_avg(se, 0);/g' \
       -e 's/update_load_avg(cfs_rq, se, 0);/update_load_avg(se, 0);/g' \
       kernel/sched/fair.c
sed -i '/se_update_runnable/d' kernel/sched/fair.c
sed -i '/assert_list_leaf_cfs_rq/d' kernel/sched/fair.c

echo "-- Disabling modversions..."
sed -i 's/^CONFIG_MODVERSIONS=y/# CONFIG_MODVERSIONS is not set/' $FINAL_DEFCONFIG

# tune default configs
echo "-- Tuning default configs..."
echo "CONFIG_LTO_CLANG=y" >> $FINAL_DEFCONFIG
echo "CONFIG_THINLTO=y" >> $FINAL_DEFCONFIG
echo "CONFIG_MODULE_REL_CRCS=y" >> $FINAL_DEFCONFIG
echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $FINAL_DEFCONFIG
echo "CONFIG_DM_CRYPT=y" >> $FINAL_DEFCONFIG
echo "CONFIG_DM_DEFAULT_KEY=y" >> $FINAL_DEFCONFIG
echo "CONFIG_DM_SNAPSHOT=y" >> $FINAL_DEFCONFIG
echo "CONFIG_DM_UEVENT=y" >> $FINAL_DEFCONFIG
echo "CONFIG_DM_VERITY=y" >> $FINAL_DEFCONFIG
echo "CONFIG_DM_VERITY_FEC=y" >> $FINAL_DEFCONFIG
echo "CONFIG_DM_BOW=y" >> $FINAL_DEFCONFIG

cd ..
