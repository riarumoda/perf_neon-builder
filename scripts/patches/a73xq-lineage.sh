#!/bin/bash
# LineageOS SM7325 (a73xq) device patches
# Driver/firmware fixes live in scripts/external and are invoked from here.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$KERNEL_DIR" || exit 1

EXTERNAL="$REPO_ROOT/scripts/external"

# Kernel tree fixes
echo "-- Getting rid of the dirty flag..."
sed -i "s/printf '%s' -dirty/:/g" scripts/setlocalversion

echo "-- Disabling IKHeaders..."
sed -i 's/CONFIG_IKHEADERS=y/# CONFIG_IKHEADERS is not set/g' "$FINAL_DEFCONFIG"

# struct request keeps its completion csd as a plain struct __call_single_data
# (8-byte aligned), while call_single_data_t is 32-byte aligned, so clang 20+
# rejects &rq->csd with -Walign-mismatch. Declare the member with the proper
# type like the other csd users (netdevice.h's softnet_data, sched.h's rq).
echo "-- Aligning struct request csd..."
if grep -q '^[[:space:]]*struct __call_single_data csd;$' include/linux/blkdev.h; then
    sed -i 's/^\([[:space:]]*\)struct __call_single_data csd;$/\1call_single_data_t csd;/' include/linux/blkdev.h
fi
grep -q '^[[:space:]]*call_single_data_t csd;$' include/linux/blkdev.h || { echo "-- ERROR: could not align struct request csd"; exit 1; }

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
find techpack/audio -name "Makefile" -exec sed -i 's/\bobj-m\b/obj-y/g' {} +
find techpack/audio techpack/camera -name "*.conf" -exec sed -i 's/^\([[:space:]]*export[[:space:]]\+CONFIG_[^=]*\)=m$/\1=y/' {} +

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
