#!/bin/bash
echo "- Applying device specific patches for $DEVICE_IMPORT..."

if [[ "$DEVICE_IMPORT" == "sweet" ]]; then
    # Main LN8K Exports
    export LN8K_PATCH1="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/7b73f853977d2c016e30319dffb1f49957d30b40.patch"
    export LN8K_PATCH2="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/63dddc108d57dc43e1cd0da0f1445875f760cf97.patch"
    export LN8K_PATCH3="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/95816dff2ecc7ddd907a56537946b5cf1e864953.patch"
    export LN8K_PATCH4="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/330c60abc13530bd05287f9e5395d283ebfd6d0b.patch"
    export LN8K_PATCH5="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit/0477c7006b41a1763b3314af9eb300491b91fc25.patch"
    # Sub LN8K Exports
    export LN8K_PATCH6="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/aa5ddad5be03aa7436e7ce6e84d46b280849acae.patch"
    export LN8K_PATCH7="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/857638b0da6f80830122b8d1b45c7842970e76c3.patch"
    export LN8K_PATCH8="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/3a68adff14cbedd09ce2a735d575c3bf92dd696f.patch"
    export LN8K_PATCH9="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/30fcc15d5dcf2cfc3b83a5a7d4a77e2880639fa5.patch"
    export LN8K_PATCH10="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit/1a17a6fbbf59d901c4b3aec66c06a1c96cd89c7e.patch"
    # Apply LN8K patches
    echo "-- Applying LN8K patches..."
    wget -qO- $LN8K_PATCH1 | patch -s -p1
    wget -qO- $LN8K_PATCH2 | patch -s -p1
    wget -qO- $LN8K_PATCH3 | patch -s -p1
    wget -qO- $LN8K_PATCH4 | patch -s -p1
    wget -qO- $LN8K_PATCH5 | patch -s -p1
    wget -qO- $LN8K_PATCH6 | patch -s -p1
    wget -qO- $LN8K_PATCH7 | patch -s -p1
    wget -qO- $LN8K_PATCH8 | patch -s -p1
    wget -qO- $LN8K_PATCH9 | patch -s -p1
    wget -qO- $LN8K_PATCH10 | patch -s -p1
    echo "CONFIG_CHARGER_LN8000=y" >> $MAIN_DEFCONFIG
    # DTBO Exports
    export DTBO_PATCH1="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/e517bc363a19951ead919025a560f843c2c03ad3.patch"
    export DTBO_PATCH2="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/a62a3b05d0f29aab9c4bf8d15fe786a8c8a32c98.patch"
    export DTBO_PATCH3="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/4b89948ec7d610f997dd1dab813897f11f403a06.patch"
    export DTBO_PATCH4="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/fade7df36b01f2b170c78c63eb8fe0d11c613c4a.patch"
    export DTBO_PATCH5="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/2628183db0d96be8dae38a21f2b09cb10978f423.patch"
    export DTBO_PATCH6="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/31f4577af3f8255ae503a5b30d8f68906edde85f.patch"
    echo "-- Applying DTBO patches..."
    wget -qO- $DTBO_PATCH1 | patch -s -p1
    wget -qO- $DTBO_PATCH2 | patch -s -p1
    wget -qO- $DTBO_PATCH3 | patch -s -p1
    wget -qO- $DTBO_PATCH4 | patch -s -p1
    wget -qO- $DTBO_PATCH5 | patch -s -p1
    wget -qO- $DTBO_PATCH6 | patch -s -p1
    # LTO Exports
    export LTO_PATCH="https://github.com/TheSillyOk/kernel_ls_patches/raw/refs/heads/master/fix_lto.patch"
    echo "-- Applying LTO patches..."
    wget -qO- $LTO_PATCH | patch -s -p1
    echo "CONFIG_LTO_CLANG=y" >> $MAIN_DEFCONFIG
    # Apply general config patches
    echo "-- Tuning the rest of default configs..."
    echo "CONFIG_EROFS_FS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $MAIN_DEFCONFIG
    # BORE Scheduler Export
    export REWEIGHT_TASK_BACKPORT="https://github.com/ximi-mojito-test/android_kernel_xiaomi_mojito/commit/eff756aaf5d666a15d8ac19743b582c2ce0fe3aa.patch"
    export BORE_PATCH="https://github.com/ximi-mojito-test/android_kernel_xiaomi_mojito/commit/2220322065591df5ff7ae27cc1fff386d3631bd0.patch"
    echo "-- Applying BORE Scheduler patch..."
    wget -qO- $REWEIGHT_TASK_BACKPORT | patch -s -p1 --fuzz=5
    wget -qO- $BORE_PATCH | patch -s -p1 --fuzz=5
    echo "CONFIG_SCHED_BORE=y" >> $MAIN_DEFCONFIG
elif [[ "$DEVICE_IMPORT" == "davinci" ]]; then
    # DTBO Exports
    export DTBO_PATCH1="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/e517bc363a19951ead919025a560f843c2c03ad3.patch"
    export DTBO_PATCH2="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/a62a3b05d0f29aab9c4bf8d15fe786a8c8a32c98.patch"
    export DTBO_PATCH3="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/4b89948ec7d610f997dd1dab813897f11f403a06.patch"
    export DTBO_PATCH4="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/fade7df36b01f2b170c78c63eb8fe0d11c613c4a.patch"
    export DTBO_PATCH5="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/2628183db0d96be8dae38a21f2b09cb10978f423.patch"
    export DTBO_PATCH6="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/31f4577af3f8255ae503a5b30d8f68906edde85f.patch"
    echo "-- Applying DTBO patches..."
    wget -qO- $DTBO_PATCH1 | patch -s -p1
    wget -qO- $DTBO_PATCH2 | patch -s -p1
    wget -qO- $DTBO_PATCH3 | patch -s -p1
    wget -qO- $DTBO_PATCH4 | patch -s -p1
    wget -qO- $DTBO_PATCH5 | patch -s -p1
    wget -qO- $DTBO_PATCH6 | patch -s -p1
    # LTO Exports
    export LTO_PATCH="https://github.com/TheSillyOk/kernel_ls_patches/raw/refs/heads/master/fix_lto.patch"
    echo "-- Applying LTO patches..."
    wget -qO- $LTO_PATCH | patch -s -p1
    echo "CONFIG_LTO_CLANG=y" >> $MAIN_DEFCONFIG
    # Apply general config patches
    echo "-- Tuning the rest of default configs..."
    echo "CONFIG_EROFS_FS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $MAIN_DEFCONFIG
    # BORE Scheduler Export
    export REWEIGHT_TASK_BACKPORT="https://github.com/ximi-mojito-test/android_kernel_xiaomi_mojito/commit/eff756aaf5d666a15d8ac19743b582c2ce0fe3aa.patch"
    export BORE_PATCH="https://github.com/ximi-mojito-test/android_kernel_xiaomi_mojito/commit/2220322065591df5ff7ae27cc1fff386d3631bd0.patch"
    echo "-- Applying BORE Scheduler patch..."
    wget -qO- $REWEIGHT_TASK_BACKPORT | patch -s -p1 --fuzz=5
    wget -qO- $BORE_PATCH | patch -s -p1 --fuzz=5
    echo "CONFIG_SCHED_BORE=y" >> $MAIN_DEFCONFIG
elif [[ "$DEVICE_IMPORT" == "ginkgo" ]]; then
    # DTC Upgrade Exports
    export DTC_PATCH1="https://github.com/LineageOS/android_kernel_xiaomi_sm6150/commit/e207247aa4553fff7190dde5dabb50aec400b513.patch"
    export DTC_PATCH2="https://github.com/LineageOS/android_kernel_xiaomi_sm6150/commit/ae58bbd8f7af4c3c290e63ddcd4112559c5fc240.patch"
    echo "-- Applying DTC patches..."
    wget -qO- $DTC_PATCH1 | patch -s -p1
    wget -qO- $DTC_PATCH2 | patch -s -p1
    # DTBO Exports
    export DTBO_PATCH1="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/e517bc363a19951ead919025a560f843c2c03ad3.patch"
    export DTBO_PATCH2="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/a62a3b05d0f29aab9c4bf8d15fe786a8c8a32c98.patch"
    export DTBO_PATCH3="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/4b89948ec7d610f997dd1dab813897f11f403a06.patch"
    export DTBO_PATCH4="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/fade7df36b01f2b170c78c63eb8fe0d11c613c4a.patch"
    export DTBO_PATCH5="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/2628183db0d96be8dae38a21f2b09cb10978f423.patch"
    export DTBO_PATCH6="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/31f4577af3f8255ae503a5b30d8f68906edde85f.patch"
    echo "-- Applying DTBO patches..."
    wget -qO- $DTBO_PATCH1 | patch -s -p1
    wget -qO- $DTBO_PATCH2 | patch -s -p1
    wget -qO- $DTBO_PATCH3 | patch -s -p1
    wget -qO- $DTBO_PATCH4 | patch -s -p1
    wget -qO- $DTBO_PATCH5 | patch -s -p1
    wget -qO- $DTBO_PATCH6 | patch -s -p1
    # LTO Exports
    export LTO_PATCH="https://github.com/TheSillyOk/kernel_ls_patches/raw/refs/heads/master/fix_lto.patch"
    echo "-- Applying LTO patches..."
    wget -qO- $LTO_PATCH | patch -s -p1
    echo "CONFIG_LTO_CLANG=y" >> $MAIN_DEFCONFIG
    # Apply general config patches
    echo "-- Tuning the rest of default configs..."
    echo "CONFIG_EROFS_FS=y" >> $MAIN_DEFCONFIG
    echo "CONFIG_SECURITY_SELINUX_DEVELOP=y" >> $MAIN_DEFCONFIG
    # BORE Scheduler Export
    export REWEIGHT_TASK_BACKPORT="https://github.com/ximi-mojito-test/android_kernel_xiaomi_mojito/commit/eff756aaf5d666a15d8ac19743b582c2ce0fe3aa.patch"
    export BORE_PATCH="https://github.com/ximi-mojito-test/android_kernel_xiaomi_mojito/commit/2220322065591df5ff7ae27cc1fff386d3631bd0.patch"
    echo "-- Applying BORE Scheduler patch..."
    wget -qO- $REWEIGHT_TASK_BACKPORT | patch -s -p1 --fuzz=5
    wget -qO- $BORE_PATCH | patch -s -p1 --fuzz=5
    echo "CONFIG_SCHED_BORE=y" >> $MAIN_DEFCONFIG
elif [[ "$DEVICE_IMPORT" == "mi89x7" ]]; then
    # BORE Scheduler Export
    export BORE_PATCH="https://github.com/rystX-OpenSource/rystx-kernel_asus_sdm660/commit/dfdf4d2fd3c1d0a9ad4dfbeaf2878e65dc87022b.patch"
    echo "-- Applying BORE Scheduler patch..."
    wget -qO- $BORE_PATCH | filterdiff -x "arch/arm64/configs/asus/*" | patch -s -p1 --fuzz=5 &> /dev/null
    echo "CONFIG_SCHED_BORE=y" >> $MAIN_DEFCONFIG
else
    echo "No specific patches to apply for $DEVICE_IMPORT."
fi