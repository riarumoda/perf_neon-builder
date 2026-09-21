#!/bin/bash

# Patcher helper - 1.7
apply_patches() {
    for patch_url in "$@"; do
        echo "-- Applying patch: $(basename "$patch_url")"
        if [[ "$GITHUB_TOKEN" == "" ]]; then
            curl -sL --fail --retry 3 "$patch_url" -o /tmp/temp_patch.patch
        else
            curl -sL --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$patch_url" -o /tmp/temp_patch.patch
        fi
        if [ -s /tmp/temp_patch.patch ]; then
            patch -s -p1 --fuzz=5 < /tmp/temp_patch.patch || { echo "Fatal: Failed to apply patch!"; exit 1; }
        else
            echo "Fatal: Failed to download patch from $patch_url"
            exit 1
        fi
    done
}

# Commit reverter - 1.7
revert_commit() {
    for patch_url in "$@"; do
        echo "-- Reverting commit: $(basename "$patch_url")"
        if [[ "$GITHUB_TOKEN" == "" ]]; then
            curl -sL --fail --retry 3 "$patch_url" -o /tmp/temp_revert.patch
        else
            curl -sL --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$patch_url" -o /tmp/temp_revert.patch
        fi
        if [ -s /tmp/temp_revert.patch ]; then
            patch -R -s -p1 < /tmp/temp_revert.patch || { echo "Fatal: Failed to revert commit!"; exit 1; }
        else
            echo "Fatal: Failed to download revert patch from $patch_url"
            exit 1
        fi
    done
}

# Shared patches for 4.14
LTO_PATCH="https://github.com/TheSillyOk/kernel_ls_patches/raw/refs/heads/master/fix_lto.patch"
KPATCH_PATCH="https://github.com/TheSillyOk/kernel_ls_patches/raw/refs/heads/master/kpatch_fix.patch"
DTBO_PATCHES=(
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/e517bc363a19951ead919025a560f843c2c03ad3.patch"
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/a62a3b05d0f29aab9c4bf8d15fe786a8c8a32c98.patch"
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/4b89948ec7d610f997dd1dab813897f11f403a06.patch"
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/fade7df36b01f2b170c78c63eb8fe0d11c613c4a.patch"
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/2628183db0d96be8dae38a21f2b09cb10978f423.patch"
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/31f4577af3f8255ae503a5b30d8f68906edde85f.patch"
)
DTC_PATCHES=(
    "https://github.com/LineageOS/android_kernel_xiaomi_sm6150/commit/e207247aa4553fff7190dde5dabb50aec400b513.patch"
    "https://github.com/LineageOS/android_kernel_xiaomi_sm6150/commit/ae58bbd8f7af4c3c290e63ddcd4112559c5fc240.patch"
)
LN8K_COMMON=(
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/ade11a168d80de8552752447edad545851490b35.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/eb4aef5a0b917537ca4cc5357068390a8d2d680b.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/ddedab15a165c5c68737e30e813e40e785b1f921.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/2cc9ab3c0d7f6cdb98b1ee72aca104980c1e4415.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/6d8c5b25168981cb8f7e3ef758872b21f3d8a361.patch"
)
SMB5LIB_COMMON=(
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/ee2627b0cf620f8f5fb59d31f164c2ca91a72523.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/18d91e84dfa2235a37f370b0007dc603f33585e7.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/b4ecd5825986daa2dff4b3783edf50ee15d17e4c.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/509115dbee1e4486481b38f28e2dd789a86bd6ea.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/1e8e5057a05e8d7bbfcdce0394ca8ac112c31905.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/b6fb4a7f3fdc6b868356d4865f4dfaa4d6dfc277.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/db4a6db01697b60ab9a2664cd2eb9e21b839963a.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/f5b7ddef27899943896d1a513c7b42348cf6e84b.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/b9a40caa95d713142064c7b52ab5634ba6d17ef8.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/f499c5d97d5444d8df8519869f4912ebc795a2d2.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/7f03348a4fd273e1623777b32558d6f83e02aa6d.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/521709b3fcd89b1c84b784390523951fdaf21ad9.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/2c6eaf6c957aeb3d11a85476fd0f01f28d85bbcf.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/55abe8f43549cb92d002b76f44c7f678adb28ce1.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/3318d76d02e61a1a7e03e3442a97540bc0056f0a.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/6257f9c3e7ffce612532aca4a98dbd6c8ef4ebf8.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/cf62977aeeee0aed13f4ebfa3771f7cd960703d7.patch"
    "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/a52850092fc5a2356ee5cadf4bd5d2b166c1c310.patch"
)

# Hengker Configs
# Based on: https://www.kali.org/docs/nethunter/nethunter-kernel-2-config-1/ and so on
nethunter_fouronefour_configs() {
    echo "-- Enabling general config for NetHunter..."
    echo "CONFIG_SYSVIPC=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MODULES=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MODULE_UNLOAD=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MODULE_FORCE_UNLOAD=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MODVERSIONS=y" >> $MAIN_DEFCONFIG
    echo "-- Enabling network config for NetHunter..."
    echo "CONFIG_BT_HCIBTUSB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_BT_HCIBTUSB_BCM=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_BT_HCIBTUSB_RTL=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_BT_HCIUART=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_BT_HCIUART_H4=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_BT_HCIBCM203X=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_BT_HCIBPA10X=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_BT_HCIBFUSB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_BT_HCIVHCI=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_ANDROID_BINDER_IPC=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CFG80211_WEXT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MAC80211=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MAC80211_MESH=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_RTL8150=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_RTL8152=y" >> $MAIN_DEFCONFIG
    echo "-- Enabling wifi config for NetHunter..."
    echo "CONFIG_WLAN_VENDOR_ATH=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_ATH9K_HTC=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CARL9170=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_ATH6KL=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_ATH6KL_USB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_WLAN_VENDOR_MEDIATEK=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MT7601U=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_WLAN_VENDOR_RALINK=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RT2X00=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RT2500USB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RT73USB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RT2800USB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RT2800USB_RT33XX=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RT2800USB_RT35XX=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RT2800USB_RT3573=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RT2800USB_RT53XX=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RT2800USB_RT55XX=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RT2800USB_UNKNOWN=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_WLAN_VENDOR_REALTEK=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RTL8187=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RTL_CARDS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RTL8192CU=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_RTL8XXXU_UNTESTED=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_WLAN_VENDOR_ZYDAS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_ZD1201=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_ZD1211RW=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_NET_RNDIS_WLAN=y" >> $MAIN_DEFCONFIG
    echo "-- Enabling SDR config for NetHunter..."
    echo "CONFIG_MEDIA_DIGITAL_TV_SUPPORT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MEDIA_SDR_SUPPORT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_AIRSPY=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_HACKRF=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_MSI2500=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MEDIA_SUBDRV_AUTOSELECT=n" >> $MAIN_DEFCONFIG
    echo "CONFIG_DVB_RTL2830=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DVB_RTL2832=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DVB_RTL2832_SDR=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DVB_SI2168=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DVB_ZD1301_DEMOD=y" >> $MAIN_DEFCONFIG
    echo "-- Enabling USB config for NetHunter..."
    echo "CONFIG_USB_ACM=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_CONFIGFS_SERIAL=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_CONFIGFS_ACM=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_CONFIGFS_OBEX=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_CONFIGFS_NCM=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_CONFIGFS_ECM=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_CONFIGFS_ECM_SUBSET=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_CONFIGFS_RNDIS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_CONFIGFS_EEM=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_CONFIGFS_MASS_STORAGE=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_CONFIGFS_F_HID=y" >> $MAIN_DEFCONFIG
    echo "-- Enabling NFS config for NetHunter..."
    echo "CONFIG_NETWORK_FILESYSTEMS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_NFS_V2=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_NFS_V3=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_NFS_V4=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_NFSD=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_NFSD_V3=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_NFSD_V4=y" >> $MAIN_DEFCONFIG
    echo "-- Enabling CAN config for NetHunter..."
    echo "CONFIG_CAN=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_NET_DEVLINK=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_RAW=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_BCM=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_GW=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_VCAN=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_SLCAN=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_DEV=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_CALC_BITTIMING=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_LEDS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_GRCAN=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_XILINXCAN=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_C_CAN=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_CC770=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_IFI_CANFD=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_M_CAN=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_SJA1000=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_SOFTING=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_HI311X=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_MCP251X=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_EMS_USB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_ESD_USB2=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_GS_USB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_KVASER_USB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_PEAK_USB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_8DEV_USB=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_VSOCKETS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_NETLINK_DIAG=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_NET_EMATCH_CANID=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_SERIAL_CONSOLE=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_SERIAL_GENERIC=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_SERIAL_CH341=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_USB_SERIAL_FTDI_SIO=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_HLCAN=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_CAN_ISOTP=y" >> $MAIN_DEFCONFIG
}
nethunter_fouronefour_patches() {
    # QCACLD_INJECT="https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder/-/raw/main/patches/4.14/add-qcacld-3.0-injection-4.14.patch"
    RTL88XXAU_DRIVER="https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder/-/raw/main/patches/4.14/add-rtl88xxau-5.6.4.2-drivers.patch"
    RTW88_DRIVER="https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder/-/raw/main/patches/4.14/add-rtw88-drivers-4.14.patch"
    UB500_PATCH="https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder/-/raw/main/patches/4.04/add-ub500-to-btusb.patch"
    # echo "-- Patching qcacld-3.0..."
    # apply_patches "$QCACLD_INJECT"
    echo "-- Patching rtl88xxau..."
    apply_patches "$RTL88XXAU_DRIVER"
    sed -i 's/__attribute__ ((fallthrough));/fallthrough;/g' drivers/net/wireless/realtek/rtl8812au/core/rtw_mlme_ext.c
    sed -i 's/sec->owe_ie && sec->owe_ie_len > 0/sec->owe_ie_len > 0/g' drivers/net/wireless/realtek/rtl8812au/core/rtw_mlme_ext.c
    echo "CONFIG_88XXAU=y" >> $MAIN_DEFCONFIG
    echo "-- Patching rtw88..."
    apply_patches "$RTW88_DRIVER"
    echo "CONFIG_RTW88=y" >> $MAIN_DEFCONFIG
    echo "-- Patching ub500..."
    apply_patches "$UB500_PATCH"
    echo "-- Patching ath9k..."
    find drivers/net/wireless/ath/ath9k -type f -name "*.[ch]" -exec sed -i 's/\bhtc_start\b/ath9k_htc_start/g' {} +
    find drivers/net/wireless/ath/ath9k -type f -name "*.[ch]" -exec sed -i 's/\bhtc_stop\b/ath9k_htc_stop/g' {} +
    find drivers/net/wireless/ath/ath9k -type f -name "*.[ch]" -exec sed -i 's/\bhtc_connect_service\b/ath9k_htc_connect_service/g' {} +
    sed -i -E 's/static int ath9k_htc_start\(struct ieee80211_hw/static int ath9k_mac80211_start(struct ieee80211_hw/g' drivers/net/wireless/ath/ath9k/htc_drv_main.c
    sed -i -E 's/static void ath9k_htc_stop\(struct ieee80211_hw/static void ath9k_mac80211_stop(struct ieee80211_hw/g' drivers/net/wireless/ath/ath9k/htc_drv_main.c
    sed -i -E 's/\.start[[:space:]]*=[[:space:]]*ath9k_htc_start,/.start = ath9k_mac80211_start,/g' drivers/net/wireless/ath/ath9k/htc_drv_main.c
    sed -i -E 's/\.stop[[:space:]]*=[[:space:]]*ath9k_htc_stop,/.stop = ath9k_mac80211_stop,/g' drivers/net/wireless/ath/ath9k/htc_drv_main.c
}
nethunter_fouronenine_patches() {
    RTW88_DRIVER="https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder/-/raw/main/patches/4.19/add-rtw88-drivers-4.19.patch"
    UB500_PATCH="https://gitlab.com/kalilinux/nethunter/build-scripts/kali-nethunter-kernel-builder/-/raw/main/patches/4.04/add-ub500-to-btusb.patch"
    echo "-- Patching rtw88..."
    apply_patches "$RTW88_DRIVER"
    echo "CONFIG_RTW88=y" >> $MAIN_DEFCONFIG
    echo "-- Patching ub500..."
    apply_patches "$UB500_PATCH"
}
# Shared configs
enable_erofs() {
    echo "-- Enabling EROFS support..."
    echo "CONFIG_EROFS_FS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_EROFS_FS_XATTR=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_EROFS_FS_POSIX_ACL=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_EROFS_FS_SECURITY=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_EROFS_FS_ZIP=y" >> $MAIN_DEFCONFIG
}
default_config_fouronefour() {
    echo "-- Tuning default configs..."
    echo "CONFIG_LTO_CLANG=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_THINLTO=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MODULE_REL_CRCS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_CRYPT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_DEFAULT_KEY=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_SNAPSHOT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_UEVENT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_VERITY=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_VERITY_FEC=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_BOW=y" >> $MAIN_DEFCONFIG
}
default_config_fouronenine() {
    echo "-- Tuning default configs..."
    echo "CONFIG_LTO_CLANG=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_THINLTO=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_MODULE_REL_CRCS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_SHADOW_CALL_STACK=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_CRYPT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_DEFAULT_KEY=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_SNAPSHOT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_UEVENT=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_VERITY=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_VERITY_FEC=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_DM_BOW=y" >> $MAIN_DEFCONFIG
}
disable_modversions() {
    echo "-- Disabling modversions..."
    sed -i 's/^CONFIG_MODVERSIONS=y/# CONFIG_MODVERSIONS is not set/' $MAIN_DEFCONFIG
}

# Patcher - 1.5
echo "- Patching kernel source for $DEVICE_IMPORT..."
case "$DEVICE_IMPORT" in
    # LineageOS
    sweet-lineage|davinci-lineage|tucana-lineage|violet-lineage|toco-lineage)
        echo "-- Applying LTO patch..."
        apply_patches "$LTO_PATCH"
        echo "-- Applying DTB patches..."
        apply_patches "${DTBO_PATCHES[@]}"
        disable_modversions
        enable_erofs
        default_config_fouronefour
    ;;
    ginkgo-lineage|laurel_sprout-lineage)
        echo "-- Applying DTC patches..."
        apply_patches "${DTC_PATCHES[@]}"
        echo "-- Applying DTB patches..."
        apply_patches "${DTBO_PATCHES[@]}"
        disable_modversions
        enable_erofs
        default_config_fouronefour
    ;;
    gta4l-lineage)
        echo "-- Fixing scripts/dtc/livetree.c..."
        sed -i '/assert(generate_fixups);/d' scripts/dtc/livetree.c
        echo "-- Setting up extra drivers as built-in for gta4l..."
        sed -i 's/^CONFIG_QCA_CLD_WLAN=m$/CONFIG_QCA_CLD_WLAN=y/' arch/arm64/configs/$DEVICE_DEFCONFIG
        find techpack/data -name "Makefile" -exec sed -i 's/obj-m/obj-y/g' {} +
        find techpack/audio/config -name "*.conf" -exec sed -i 's/=m/=y/g' {} +
        find techpack/audio -name "Makefile*" -exec sed -i 's/obj-m/obj-y/g' {} +
        find techpack/audio -name "Kbuild*" -exec sed -i 's/obj-m/obj-y/g' {} +
        echo "CONFIG_SENSORS_SSC=y" >> $MAIN_DEFCONFIG
        enable_erofs
        default_config_fouronenine
    ;;
    sweet-lineage-nethunter|ginkgo-lineage-nethunter)
        if [[ $DEVICE_IMPORT == "sweet-lineage-nethunter" ]]; then
            echo "-- Applying LTO patch..."
            apply_patches "$LTO_PATCH"
        fi
        if [[ $DEVICE_IMPORT == "ginkgo-lineage-nethunter" ]]; then
            echo "-- Applying DTC patches..."
            apply_patches "${DTC_PATCHES[@]}"
        fi
        echo "-- Applying DTB patches..."
        apply_patches "${DTBO_PATCHES[@]}"
        nethunter_fouronefour_configs
        nethunter_fouronefour_patches
        enable_erofs
        default_config_fouronefour
    ;;
    # CrDroid
    sweet-crdroid|davinci-crdroid|tucana-crdroid)
        echo "-- Reverting hard to commits before KSU is being added..."
        git reset --hard 92255bf2fae58c5ca0c932ced8fe8c2e5443312a &> /dev/null
        if [[ "$DEVICE_IMPORT" == "tucana-crdroid" ]]; then
            echo "-- Fixing goodix driver..."
            sed -i 's/static void gtp_set_edge_filter_normal()/static void gtp_set_edge_filter_normal(void)/g' drivers/input/touchscreen/f4_goodix_driver_gt9886/goodix_ts_core.c
            sed -i 's/static int gtp_send_cur_cmd()/static int gtp_send_cur_cmd(void)/g' drivers/input/touchscreen/f4_goodix_driver_gt9886/goodix_ts_core.c
            echo "-- Fixing fts driver..."
            sed -i 's/"%100s %d %d"/"%99s %d %d"/g' drivers/input/touchscreen/fts_521/fts.c
            sed -i 's/"%100s"/"%99s"/g' drivers/input/touchscreen/fts_521/fts_proc.c
            sed -i 's/struct device \*getDev()/struct device \*getDev(void)/g' drivers/input/touchscreen/fts_521/fts_lib/ftsIO.c
            sed -i 's/struct i2c_client \*getClient()/struct i2c_client \*getClient(void)/g' drivers/input/touchscreen/fts_521/fts_lib/ftsIO.c
            echo "ccflags-y += -Wno-strict-prototypes" >> drivers/input/touchscreen/fts_521/Makefile
        fi
        disable_modversions
        enable_erofs
        default_config_fouronefour
    ;;
    # PixelOS
    sweet-pixelos|davinci-pixelos|toco-pixelos)
        disable_modversions
        default_config_fouronefour
    ;;
    # Mi-Thorium
    mi89x7-playground)
        echo "-- Reverting KSU commit..."
        revert_commit "https://github.com/Mi-Thorium/kernel_msm-4.19/commit/624875e8edc36ae280b1f8efc1d3c48a28da64ea.patch"
        if [[ $CLANG_STRAT == "1" ]]; then
            echo "-- Tuning CPU flags..."
            sed -i '/export KBUILD_CFLAGS/i \
            KBUILD_CFLAGS += -march=armv8-a+crypto+crc -mcpu=cortex-a53' Makefile
        fi
        echo "-- Fixing HW key for riva..."
        sed -i 's/#define FTS_POINT_REPORT_CHECK_EN[[:space:]]*0/#define FTS_POINT_REPORT_CHECK_EN               1/g' techpack/xiaomi-msm8937/touchscreen/focaltech_touch/focaltech_common.h
        sed -i '/input_report_key(input_dev, BTN_TOUCH, 0);/a \
            if (ts_data->key_state) {\
                struct fts_ts_platform_data *pdata = ts_data->pdata;\
                int key_idx;\
                int num_keys = 0;\
                u32 *keycodes = NULL;\
        \
            if (pdata->key_is_vkeys && pdata->vkeys_pdata) {\
                    num_keys = pdata->vkeys_pdata->num_keys;\
                    keycodes = pdata->vkeys_pdata->keycodes;\
            } else if (!pdata->key_is_vkeys) {\
                    num_keys = pdata->key_number;\
                    keycodes = pdata->keys;\
            }\
        \
            if (keycodes) {\
                    for (key_idx = 0; key_idx < num_keys; key_idx++) {\
                            if (ts_data->key_state & (1 << key_idx))\
                                    input_report_key(input_dev, keycodes[key_idx], 0);\
                    }\
            }\
            ts_data->key_state = 0;\
        }' techpack/xiaomi-msm8937/touchscreen/focaltech_touch/focaltech_point_report_check.c
        enable_erofs
        default_config_fouronenine
    ;;
    # SouthWest-NG
    lavender-southwest-ng)
        echo "-- Fixing audio..."
        sed -i '1i #include <linux/i2c.h>\n#include <linux/module.h>' techpack/audio/asoc/codecs/tas2557_clover/tas2557-regmap.c
        sed -i '1i #include <linux/i2c.h>\n#include <linux/module.h>' techpack/audio/asoc/codecs/max98937.c
        sed -i 's/module_i2c_driver(max98927_i2c_driver)/module_i2c_driver(max98927_i2c_driver);/' techpack/audio/asoc/codecs/max98937.c
        sed -i 's/module_i2c_driver(max98927_i2c_driver);/builtin_i2c_driver(max98927_i2c_driver);/' techpack/audio/asoc/codecs/max98937.c
        enable_erofs
        default_config_fouronenine
    ;;
    lavender-southwest-ng-nethunter)
        echo "-- Fixing audio..."
        sed -i '1i #include <linux/i2c.h>\n#include <linux/module.h>' techpack/audio/asoc/codecs/tas2557_clover/tas2557-regmap.c
        sed -i '1i #include <linux/i2c.h>\n#include <linux/module.h>' techpack/audio/asoc/codecs/max98937.c
        sed -i 's/module_i2c_driver(max98927_i2c_driver)/module_i2c_driver(max98927_i2c_driver);/' techpack/audio/asoc/codecs/max98937.c
        sed -i 's/module_i2c_driver(max98927_i2c_driver);/builtin_i2c_driver(max98927_i2c_driver);/' techpack/audio/asoc/codecs/max98937.c
        nethunter_fouronefour_configs
        nethunter_fouronenine_patches
        enable_erofs
        default_config_fouronenine
    ;;
    # Spiteful MIUI Buildout
    spiteful-sweet-miui-buildout)
        echo "-- Reverting hard to commits before KSU is being added..."
        git reset --hard 1c950660849776c0105ae268270acb590d1df308 &> /dev/null
        disable_modversions
        enable_erofs
        default_config_fouronefour
    ;;
    # Spiteful AOSP Buildout
    spiteful-sweet-aosp-buildout)
        echo "-- Reverting hard to commits before KSU is being added..."
        git reset --hard 1b133f3054948bee6c59332c83699ff2b95d7978 &> /dev/null
        disable_modversions
        enable_erofs
        default_config_fouronefour
    ;;
    # Titan Kernel
    a9y18qlte-titan-aosp)
        echo "-- Nuking pre-built KSU..."
        sed -i '/kernelsu/d' drivers/Kconfig
        sed -i '/kernelsu/d' drivers/Makefile
        rm -rf drivers/kernelsu
        rm -rf KernelSU
        OPENSSL_DIR="$(pwd)/.openssl1.1"
        echo "-- Installing openssl 1.1 at: '$OPENSSL_DIR'"
        if [[ "$OPENSSL_DIR" != /* ]]; then
            echo "--  OPENSSL_DIR is empty or not absolute! Check your shell environment."
            ls -alhZ $OPENSSL_DIR
            ls -alhZ $OPENSSL_DIR/../
            exit 1
        fi
        if [ ! -d "$OPENSSL_DIR" ]; then
            wget https://www.openssl.org/source/openssl-1.1.1w.tar.gz -O openssl-1.1.1w.tar.gz &> /dev/null || { echo "Fatal: openssl source code failed to download!"; exit 1; }
            tar -xf openssl-1.1.1w.tar.gz &> /dev/null
            cd openssl-1.1.1w
            ./config --prefix="$OPENSSL_DIR" --openssldir="$OPENSSL_DIR" &> /dev/null
            make -s -j$(nproc) &> /dev/null
            make -s install &> /dev/null
            cd ..
            rm -rf openssl-1.1.1w*
        fi
        export HOSTCFLAGS="-I$OPENSSL_DIR/include"
        export HOSTLDFLAGS="-L$OPENSSL_DIR/lib -Wl,-rpath,$OPENSSL_DIR/lib"
        export LD_LIBRARY_PATH="$OPENSSL_DIR/lib:$LD_LIBRARY_PATH"
        export MY_OPENSSL_DIR="$OPENSSL_DIR"
        echo "-- Overriding MAKE_ARGS..."
        export MAKE_ARGS=(
            ARCH=arm64 CC=aarch64-linux-android-gcc LD=aarch64-linux-android-ld.bfd
            AR=aarch64-linux-android-ar AS=aarch64-linux-android-as NM=aarch64-linux-android-nm
            OBJCOPY=aarch64-linux-android-objcopy OBJDUMP=aarch64-linux-android-objdump
            STRIP=aarch64-linux-android-strip CROSS_COMPILE=aarch64-linux-android- 
            HOSTCFLAGS="$HOSTCFLAGS" HOSTLDFLAGS="$HOSTLDFLAGS" OPENSSL="$MY_OPENSSL_DIR/bin/openssl"
        )
        echo "-- Tuning default configs..."
        echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $MAIN_DEFCONFIG
        sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' $MAIN_DEFCONFIG
        sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' $MAIN_DEFCONFIG
        sed -i 's/CONFIG_MODULE_SIG=y/# CONFIG_MODULE_SIG is not set/g' $MAIN_DEFCONFIG
        sed -i 's/CONFIG_MODULE_SIG_ALL=y/# CONFIG_MODULE_SIG_ALL is not set/g' $MAIN_DEFCONFIG
        sed -i 's/CONFIG_MODULE_SIG_FORCE=y/# CONFIG_MODULE_SIG_FORCE is not set/g' $MAIN_DEFCONFIG
        sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYRING=y/# CONFIG_SYSTEM_TRUSTED_KEYRING is not set/g' $MAIN_DEFCONFIG
    ;;
    *)
        echo "No specific patches to apply for $DEVICE_IMPORT."
    ;;
esac

if [[ "$CLANG_STRAT" == "1" ]]; then
    echo "- Variable clang_strat is set to 1! applying extra patches..."
    echo "-- Allowing to compile on new AOSP clang..."
    sed -i 's/-Wno-format-security/-Wno-format-security -Wno-enum-conversion -Wno-default-const-init-var-unsafe -Wno-default-const-init-field-unsafe -Wno-misleading-indentation -Wno-unsequenced -Wno-sizeof-pointer-memaccess -Wno-implicit-function-declaration -Wno-implicit-enum-enum-cast/g' Makefile
    echo "-- Setting up -O3 flags..."
    sed -i 's/KBUILD_CFLAGS.*+= -O2/KBUILD_CFLAGS   += -O3/g' Makefile
    if [[ $DEVICE_IMPORT == "spiteful-sweet-aosp-buildout" || $DEVICE_IMPORT == "spiteful-sweet-miui-buildout" ]]; then
        echo "-- Default clang tweaks skipped."
    else
        echo "-- Adding default clang tweaks..."
        sed -i '/export KBUILD_CFLAGS/i \
        KBUILD_CFLAGS += -mllvm -polly -mllvm -enable-gvn-hoist -Wno-unused-command-line-argument' Makefile
    fi
fi

if [[ "$CLANG_STRAT" == "2" ]]; then
    echo "- Variable clang_strat is set to 2! applying extra patches..."
    echo "-- Setting up -O3 flags..."
    sed -i 's/KBUILD_CFLAGS.*+= -O2/KBUILD_CFLAGS   += -O3/g' Makefile
fi

if [[ "$CLANG_STRAT" == "3" ]]; then
    echo "- Variable clang_strat is set to 3! applying extra patches..."
    echo "-- Setting up -O3 flags..."
    sed -i 's/KBUILD_CFLAGS.*+= -O2/KBUILD_CFLAGS   += -O3/g' Makefile
fi

if [[ "$CLANG_STRAT" == "0" ]]; then
    if [[ $DEVICE_IMPORT != "a9y18qlte-titan-aosp" ]]; then
        echo "- Variable clang_strat is set to 0! applying extra patches..."
        echo "-- Setting up -O3 flags..."
        sed -i 's/KBUILD_CFLAGS.*+= -O2/KBUILD_CFLAGS   += -O3/g' Makefile
    fi
fi