#!/bin/bash
# LineageOS SM7325 (m52xq) device patches
# Driver/firmware fixes live in scripts/external and are invoked from here.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$KERNEL_DIR" || exit 1

EXTERNAL="$REPO_ROOT/scripts/external"

# Kernel tree fixes
echo "-- Getting rid of the dirty flag..."
sed -i "s/printf '%s' -dirty/:/g" scripts/setlocalversion

echo "-- Disabling IKHeaders..."
sed -i 's/CONFIG_IKHEADERS=y/# CONFIG_IKHEADERS is not set/g' "$FINAL_DEFCONFIG"

# SELinux: keep /sys/fs/selinux/enforce writable so the end user can switch the
# policy. Port of bone-machine's 0e28b10, which does not apply to this tree.
# echo "-- Patching SELinux policy switching..."
# bash "$EXTERNAL/patch-selinux-switch-sm7325.sh" ./ || { echo "-- ERROR: failed to patch SELinux policy switching"; exit 1; }

# rq->csd is a plain __call_single_data (8-byte aligned) while
# call_single_data_t is 32-byte aligned, which trips -Walign-mismatch on clang 20+.
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

# USB: the =m -> =y pass above turns CONFIG_USB_G_WEBCAM into a built-in.  Its
# module_init then parks a composite driver in udc-core's pending list and
# claims a600000.dwc3 before configfs can, so MTP and adb (both FunctionFS)
# never enumerate while OTG keeps working.  Keep the UDC free for configfs.
echo "-- Disabling the legacy g_webcam gadget..."
bash "$EXTERNAL/patch-usb-legacy-webcam-sm7325.sh" ./ "$FINAL_DEFCONFIG" || { echo "-- ERROR: failed to free the USB gadget controller"; exit 1; }

# Fix qcacld-3.0
echo "-- Fixing qcacld-3.0..."
# Built-in qcacld must load itself; the ROM only loads wlan.ko
bash "$EXTERNAL/patch-qcacld-builtin-devctl-sm7325.sh" ./ || { echo "-- ERROR: failed to patch built-in qcacld"; exit 1; }
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
