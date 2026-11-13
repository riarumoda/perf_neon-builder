#!/bin/bash
# bone-machine SM7325 (a52sxq) device patches
# Driver/firmware fixes live in scripts/external and are invoked from here.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$KERNEL_DIR" || exit 1

EXTERNAL="$REPO_ROOT/scripts/external"

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
