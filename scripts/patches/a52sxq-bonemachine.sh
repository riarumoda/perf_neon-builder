#!/bin/bash
# bone-machine SM7325 (a52sxq) device patches
# Driver/firmware fixes live in scripts/external and are invoked from here.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$KERNEL_DIR" || exit 1

EXTERNAL="$REPO_ROOT/scripts/external"

# Drop ReSukiSU from resukisu-aosp (only its BPF/XDP backport is wanted), newest
# first so each revert still has its context.
RESUKISU_REPO="https://github.com/bone-machine/android_kernel_samsung_sm7325_a52s_5g"
echo "-- Removing ReSukiSU integration..."
revert_commit \
    "$RESUKISU_REPO/commit/398b1633f6dafdf2c891fab1d32c4526754e3fb1.patch" \
    "$RESUKISU_REPO/commit/299560a16e66ce82a84b54a8cc624f45ab7a31bd.patch" \
    "$RESUKISU_REPO/commit/af72a44a3ac6c0b1a57103da6f93d693bfe7a0c5.patch" \
    "$RESUKISU_REPO/commit/2054bf82fb43e04d53412876db20e0ae518d3c10.patch" \
    "$RESUKISU_REPO/commit/aecde9f054d581df7114e9f952996e54fe012498.patch" \
    "$RESUKISU_REPO/commit/4e6198ac1aa13e0519b8819dbdbc985b06ee26f8.patch"

# The ReSukiSU Kconfig block cannot be reverted as a patch any more: conf
# rewrote it as a "# KernelSU" menu in the generated config, while the vendor
# defconfig keeps the hand-written "# ReSukiSU" block.
echo "-- Removing ReSukiSU defconfig flags..."
RESUKISU_CFGS=("$FINAL_DEFCONFIG" "arch/arm64/configs/$MAIN_DEFCONFIG")
for cfg in "${RESUKISU_CFGS[@]}"; do
    [ -f "$cfg" ] || continue
    if grep -qx '# KernelSU' "$cfg" && grep -qx '# end of KernelSU' "$cfg"; then
        sed -i '/^# KernelSU$/,/^# end of KernelSU$/d' "$cfg"
    fi
    if grep -qx '# ReSukiSU' "$cfg" &&
       grep -qx '# CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK is not set' "$cfg"; then
        sed -i '/^# ReSukiSU$/,/^# CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK is not set$/d' "$cfg"
    fi
    # catch symbols the ranges above did not cover
    sed -i -E \
        -e '/^CONFIG_KSU([=_A-Z0-9]|$)/d' \
        -e '/^# CONFIG_KSU([ _A-Z0-9]|$)/d' \
        -e '/^# (end of )?(KernelSU|ReSukiSU)( |$)/d' "$cfg"
    grep -q 'CONFIG_KSU' "$cfg" && { echo "-- ERROR: ReSukiSU defconfig flags remain in $cfg"; exit 1; }
done

# 711b146 wires in the KernelSU submodule; the goodies ship their own, so drop
# the gitlink, the symlink and both in-tree references.
echo "-- Removing ReSukiSU driver glue..."
rm -rf KernelSU
rm -f drivers/kernelsu
sed -i '\|^source "drivers/kernelsu/Kconfig"$|d' drivers/Kconfig
sed -i '\|^obj-$(CONFIG_KSU) += kernelsu/$|d' drivers/Makefile
grep -qE 'drivers/kernelsu|kernelsu/' drivers/Kconfig drivers/Makefile && { echo "-- ERROR: ReSukiSU driver glue remains"; exit 1; }
grep -q 'ReSukiSU\|KernelSU' .gitmodules && { echo "-- ERROR: ReSukiSU submodule entry remains"; exit 1; }

# Unlike Lineage's Makefile, this tree never adds -fintegrated-as for
# LLVM_IAS=1, so as-version.sh probes the wrapped CC and Kconfig aborts with
# "unknown assembler invoked".
echo "-- Fixing integrated assembler detection for wrapped CC..."
if ! grep -q -- '-fintegrated-as' Makefile; then
    sed -i 's/^ifneq (\$(LLVM_IAS),1)$/ifeq ($(LLVM_IAS),1)\nCLANG_FLAGS\t+= -fintegrated-as\nelse/' Makefile
fi
grep -q -- '-fintegrated-as' Makefile || { echo "-- ERROR: could not add -fintegrated-as to CLANG_FLAGS"; exit 1; }

# Kernel tree fixes
echo "-- Getting rid of the dirty flag..."
sed -i "s/printf '%s' -dirty/:/g" scripts/setlocalversion

echo "-- Disabling IKHeaders..."
sed -i 's/CONFIG_IKHEADERS=y/# CONFIG_IKHEADERS is not set/g' "$FINAL_DEFCONFIG"

# seccomp.c, fs/proc/array.c and KernelSU use seccomp.filter_count, but this
# tree still ships the 5.4 struct seccomp.
echo "-- Restoring struct seccomp filter_count..."
if ! grep -q 'atomic_t filter_count;' include/linux/seccomp.h; then
    sed -i '/^struct seccomp {$/,/^};$/ s/^\([[:space:]]*\)int mode;$/\1int mode;\n\1atomic_t filter_count;/' include/linux/seccomp.h
fi
grep -q 'atomic_t filter_count;' include/linux/seccomp.h || { echo "-- ERROR: could not add filter_count to struct seccomp"; exit 1; }

# rq->csd is a plain __call_single_data (8-byte aligned) while
# call_single_data_t is 32-byte aligned, which trips -Walign-mismatch on clang 20+.
echo "-- Aligning struct request csd..."
if grep -q '^[[:space:]]*struct __call_single_data csd;$' include/linux/blkdev.h; then
    sed -i 's/^\([[:space:]]*\)struct __call_single_data csd;$/\1call_single_data_t csd;/' include/linux/blkdev.h
fi
grep -q '^[[:space:]]*call_single_data_t csd;$' include/linux/blkdev.h || { echo "-- ERROR: could not align struct request csd"; exit 1; }

# gcc-wrapper.py makes warnings fatal; silence the ones clang 24 added that
# this 5.4 tree predates.
echo "-- Silencing clang 24-only warnings..."
if ! grep -q 'cc-disable-warning, default-const-init-var-unsafe' Makefile; then
    warn_flags=""
    for warn in declaration-after-statement implicit-int enum-conversion \
                default-const-init-var-unsafe default-const-init-field-unsafe \
                misleading-indentation unsequenced sizeof-pointer-memaccess \
                implicit-function-declaration implicit-enum-enum-cast \
                unused-command-line-argument; do
        warn_flags="${warn_flags} \$(call cc-disable-warning, ${warn})"
    done
    sed -i "/^export KBUILD_CFLAGS CFLAGS_KERNEL CFLAGS_MODULE/i KBUILD_CFLAGS +=${warn_flags}" Makefile
fi
grep -q 'cc-disable-warning, default-const-init-var-unsafe' Makefile || { echo "-- ERROR: could not add clang warning suppressions"; exit 1; }

# Deferred firmware loading (custom external patches)
echo "-- Fixing firmware load delay..."
bash "$EXTERNAL/patch-drivers-fts-sm7325.sh" ./ || { echo "-- ERROR: failed to patch stm firmware loading"; exit 1; }
bash "$EXTERNAL/patch-drivers-synaptics-sm7325.sh" ./ || { echo "-- ERROR: failed to patch synaptics firmware loading"; exit 1; }
bash "$EXTERNAL/patch-skip-modules-sm7325.sh" || { echo "-- ERROR: failed to patch module skipping"; exit 1; }
F=drivers/base/firmware_loader/fallback_table.c
grep -q '\.loading_timeout = 60,' "$F" && sed -i 's/\.loading_timeout = 60,/.loading_timeout = 10,/' "$F"

# Force every driver to be built-in
echo "-- Forcing every drivers to be built-in..."
sed -i '/^CONFIG_/s/=m$/=y/' "$FINAL_DEFCONFIG"
find techpack/ \( -name "Makefile" -o -name "Kbuild" \) -exec sed -i 's/\bobj-m\b/obj-y/g' {} +
find techpack/audio techpack/camera techpack/video -name "*.conf" -exec sed -i 's/^\([[:space:]]*export[[:space:]]\+CONFIG_[^=]*\)=m$/\1=y/' {} +

# Fix qcacld-3.0
echo "-- Fixing qcacld-3.0..."
# Built-in qcacld never registers /dev/wlan (only the module_init path does),
# so the WiFi HAL cannot load the driver. Register the chardev at init too.
bash "$EXTERNAL/patch-qcacld-builtin-devctl-sm7325.sh" ./ || { echo "-- ERROR: failed to register /dev/wlan for built-in qcacld"; exit 1; }
find drivers/staging/qca-wifi-host-cmn drivers/staging/qcacld-3.0 -type f \( -name "*.c" -o -name "*.h" \) \
  -exec sed -i 's/\bnl80211hdr_put\b/qca_nl80211hdr_put/g' {} +
sed -i 's/bool ipa_is_ready(/bool __weak ipa_is_ready(/g' drivers/staging/qcacld-3.0/components/ipa/dispatcher/src/wlan_ipa_obj_mgmt_api.c

# Tune default configs
echo "-- Tuning default configs..."
echo "CONFIG_LTO_CLANG=y" >> "$FINAL_DEFCONFIG"
echo "CONFIG_THINLTO=y" >> "$FINAL_DEFCONFIG"
echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> "$FINAL_DEFCONFIG"
echo "CONFIG_DM_CRYPT=y" >> "$FINAL_DEFCONFIG"
echo "CONFIG_DM_DEFAULT_KEY=y" >> "$FINAL_DEFCONFIG"
echo "CONFIG_DM_SNAPSHOT=y" >> "$FINAL_DEFCONFIG"
echo "CONFIG_DM_UEVENT=y" >> "$FINAL_DEFCONFIG"
echo "CONFIG_DM_VERITY=y" >> "$FINAL_DEFCONFIG"
echo "CONFIG_DM_VERITY_FEC=y" >> "$FINAL_DEFCONFIG"
echo "CONFIG_DM_BOW=y" >> "$FINAL_DEFCONFIG"


cd "$REPO_ROOT" || exit 1
