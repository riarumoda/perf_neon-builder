#!/bin/bash
echo "- Applying device specific patches for $DEVICE_IMPORT..."

# Patcher helper - 1.0
apply_patches() {
    for patch_url in "$@"; do
        wget -qO- "$patch_url" | patch -s -p1 --fuzz=5
    done
}

# Shared patches for 4.14
DTBO_PATCHES=(
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/e517bc363a19951ead919025a560f843c2c03ad3.patch"
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/a62a3b05d0f29aab9c4bf8d15fe786a8c8a32c98.patch"
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/4b89948ec7d610f997dd1dab813897f11f403a06.patch"
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/fade7df36b01f2b170c78c63eb8fe0d11c613c4a.patch"
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/2628183db0d96be8dae38a21f2b09cb10978f423.patch"
    "https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/31f4577af3f8255ae503a5b30d8f68906edde85f.patch"
)
LTO_PATCH="https://github.com/TheSillyOk/kernel_ls_patches/raw/refs/heads/master/fix_lto.patch"
KPATCH_PATCH="https://github.com/TheSillyOk/kernel_ls_patches/raw/refs/heads/master/kpatch_fix.patch"

# Patcher - 1.0
case "$DEVICE_IMPORT" in
    sweet|davinci|tucana|violet|ginkgo|laurel_sprout)
        # Device specific for 4.14
        if [[ "$DEVICE_IMPORT" == "sweet" ]]; then
            echo "-- Applying LN8K patches..."
            LN8K_PATCHES=(
                "https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/7b73f853977d2c016e30319dffb1f49957d30b40.patch"
                "https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/63dddc108d57dc43e1cd0da0f1445875f760cf97.patch"
                "https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/95816dff2ecc7ddd907a56537946b5cf1e864953.patch"
                "https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/330c60abc13530bd05287f9e5395d283ebfd6d0b.patch"
                "https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/0477c7006b41a1763b3314af9eb300491b91fc25.patch"
                "https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/aa5ddad5be03aa7436e7ce6e84d46b280849acae.patch"
                "https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/857638b0da6f80830122b8d1b45c7842970e76c3.patch"
                "https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/3a68adff14cbedd09ce2a735d575c3bf92dd696f.patch"
                "https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/30fcc15d5dcf2cfc3b83a5a7d4a77e2880639fa5.patch"
                "https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/1a17a6fbbf59d901c4b3aec66c06a1c96cd89c7e.patch"
            )
            apply_patches "${LN8K_PATCHES[@]}"
            echo "CONFIG_CHARGER_LN8000=y" >> $MAIN_DEFCONFIG
        elif [[ "$DEVICE_IMPORT" == "ginkgo" ]] || [[ "$DEVICE_IMPORT" == "laurel_sprout" ]]; then
            echo "-- Applying DTC patches..."
            apply_patches \
                "https://github.com/LineageOS/android_kernel_xiaomi_sm6150/commit/e207247aa4553fff7190dde5dabb50aec400b513.patch" \
                "https://github.com/LineageOS/android_kernel_xiaomi_sm6150/commit/ae58bbd8f7af4c3c290e63ddcd4112559c5fc240.patch"
        fi
        # Shared patches for 4.14
        echo "-- Applying shared patches (DTBO, LTO, KPATCH)..."
        apply_patches "${DTBO_PATCHES[@]}" "$LTO_PATCH" "$KPATCH_PATCH"
        # Common configs for 4.14
        echo "-- Tuning default configs..."
        echo "CONFIG_LTO_CLANG=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_EROFS_FS=y" >> $MAIN_DEFCONFIG
        echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $MAIN_DEFCONFIG
        ;;
    mi89x7)
        echo "-- STUB Entry for mi89x7. Nothing added yet."
        ;;
    a52s)
        echo "-- STUB Entry for a52s. Nothing added yet."
        ;;
    *)
        echo "No specific patches to apply for $DEVICE_IMPORT."
        ;;
esac