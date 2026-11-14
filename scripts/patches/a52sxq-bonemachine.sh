#!/bin/bash
# bone-machine SM7325 (a52sxq) device patches
# Driver/firmware fixes live in scripts/external and are invoked from here.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$KERNEL_DIR" || exit 1

EXTERNAL="$REPO_ROOT/scripts/external"

# Strip the ReSukiSU integration from the resukisu-aosp branch. We want the
# branch for its Android 17 BPF/XDP backport, but the builder already ships
# BakaSU, so the in-tree root solution must go. Revert newest first so each
# patch still has the context it was written against.
RESUKISU_REPO="https://github.com/bone-machine/android_kernel_samsung_sm7325_a52s_5g"
echo "-- Removing ReSukiSU integration..."
revert_commit \
    "$RESUKISU_REPO/commit/398b1633f6dafdf2c891fab1d32c4526754e3fb1.patch" \
    "$RESUKISU_REPO/commit/299560a16e66ce82a84b54a8cc624f45ab7a31bd.patch" \
    "$RESUKISU_REPO/commit/af72a44a3ac6c0b1a57103da6f93d693bfe7a0c5.patch" \
    "$RESUKISU_REPO/commit/2054bf82fb43e04d53412876db20e0ae518d3c10.patch" \
    "$RESUKISU_REPO/commit/aecde9f054d581df7114e9f952996e54fe012498.patch" \
    "$RESUKISU_REPO/commit/4e6198ac1aa13e0519b8819dbdbc985b06ee26f8.patch"

# 7654d12 adds the ReSukiSU Kconfig block, but later defconfig regenerations
# moved its surrounding context, so it cannot be reversed as a patch. Remove
# the block from the generated final config (and the vendor defconfig it came
# from) instead. The generated config has been rewritten by conf, so its menu
# comments ("# KernelSU", "# end of KernelSU", the ReSukiSU warning text) no
# longer match the hand-written "# ReSukiSU" block in the vendor defconfig.
# Drop the symbols first, then the leftover menu/comment headers.
echo "-- Removing ReSukiSU defconfig flags..."
RESUKISU_CFGS=("$FINAL_DEFCONFIG" "arch/arm64/configs/$MAIN_DEFCONFIG")
for cfg in "${RESUKISU_CFGS[@]}"; do
    [ -f "$cfg" ] || continue
    # conf turns the block into a menu ("# KernelSU" ... "# end of KernelSU")
    if grep -qx '# KernelSU' "$cfg" && grep -qx '# end of KernelSU' "$cfg"; then
        sed -i '/^# KernelSU$/,/^# end of KernelSU$/d' "$cfg"
    fi
    # the vendor defconfig still carries the hand-written variant
    if grep -qx '# ReSukiSU' "$cfg" &&
       grep -qx '# CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK is not set' "$cfg"; then
        sed -i '/^# ReSukiSU$/,/^# CONFIG_KSU_MANUAL_HOOK_AUTO_INITRC_HOOK is not set$/d' "$cfg"
    fi
    # catch any symbol the ranges above did not cover
    sed -i -E \
        -e '/^CONFIG_KSU([=_A-Z0-9]|$)/d' \
        -e '/^# CONFIG_KSU([ _A-Z0-9]|$)/d' \
        -e '/^# (end of )?(KernelSU|ReSukiSU)( |$)/d' "$cfg"
    grep -q 'CONFIG_KSU' "$cfg" && { echo "-- ERROR: ReSukiSU defconfig flags remain in $cfg"; exit 1; }
done

# 711b146 wires a KernelSU submodule into the driver tree. A depth-1 clone
# never checks that submodule out and the goodies provide their own KernelSU,
# so drop the gitlink, the symlink and the two in-tree references by hand.
echo "-- Removing ReSukiSU driver glue..."
rm -rf KernelSU
rm -f drivers/kernelsu
sed -i '\|^source "drivers/kernelsu/Kconfig"$|d' drivers/Kconfig
sed -i '\|^obj-$(CONFIG_KSU) += kernelsu/$|d' drivers/Makefile
grep -qE 'drivers/kernelsu|kernelsu/' drivers/Kconfig drivers/Makefile && { echo "-- ERROR: ReSukiSU driver glue remains"; exit 1; }
grep -q 'ReSukiSU\|KernelSU' .gitmodules && { echo "-- ERROR: ReSukiSU submodule entry remains"; exit 1; }

# scripts/as-version.sh only shortcuts to "LLVM 0" when -fintegrated-as shows up
# in CLANG_FLAGS; otherwise it probes $(CC) itself. This tree (unlike Lineage's)
# never adds that flag when LLVM_IAS=1, so the builder's wrapped CC
# ("ccache .../gcc-wrapper.py clang") gets probed instead of clang and Kconfig
# aborts with "unknown assembler invoked" on every defconfig/syncconfig. Add the
# flag the same way Lineage's Makefile does, so the integrated assembler is used
# (and advertised) whenever LLVM_IAS=1.
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

# seccomp.c, fs/proc/array.c and KernelSU all use seccomp.filter_count, but
# this tree still ships the 5.4 struct seccomp, so init_task.c does not build.
echo "-- Restoring struct seccomp filter_count..."
if ! grep -q 'atomic_t filter_count;' include/linux/seccomp.h; then
    sed -i '/^struct seccomp {$/,/^};$/ s/^\([[:space:]]*\)int mode;$/\1int mode;\n\1atomic_t filter_count;/' include/linux/seccomp.h
fi
grep -q 'atomic_t filter_count;' include/linux/seccomp.h || { echo "-- ERROR: could not add filter_count to struct seccomp"; exit 1; }

# struct request keeps its completion csd as a plain struct __call_single_data
# (8-byte aligned), while call_single_data_t is 32-byte aligned, so clang 20+
# rejects &rq->csd with -Walign-mismatch. Declare the member with the proper
# type like the other csd users (netdevice.h's softnet_data, sched.h's rq).
echo "-- Aligning struct request csd..."
if grep -q '^[[:space:]]*struct __call_single_data csd;$' include/linux/blkdev.h; then
    sed -i 's/^\([[:space:]]*\)struct __call_single_data csd;$/\1call_single_data_t csd;/' include/linux/blkdev.h
fi
grep -q '^[[:space:]]*call_single_data_t csd;$' include/linux/blkdev.h || { echo "-- ERROR: could not align struct request csd"; exit 1; }

# scripts/gcc-wrapper.py turns every warning into a hard error, and clang 24
# reports diagnostics this 5.4 tree predates. Keep suppressing the warnings
# only (no -mllvm/polly flags, those stay out).
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
sed -i 's/static int[[:space:]]\+wlan_hdd_state_ctrl_param_create/static int __maybe_unused wlan_hdd_state_ctrl_param_create/' drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_main.c
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
