#!/bin/bash
cd "$KERNEL_DIR"

# Export kernel patches
echo "-- Exporting device patches..."
LTO_PATCH="https://github.com/TheSillyOk/kernel_ls_patches/raw/refs/heads/master/fix_lto.patch"
DTBO_PATCH1="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/e517bc363a19951ead919025a560f843c2c03ad3.patch"
DTBO_PATCH2="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/a62a3b05d0f29aab9c4bf8d15fe786a8c8a32c98.patch"
DTBO_PATCH3="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/4b89948ec7d610f997dd1dab813897f11f403a06.patch"
DTBO_PATCH4="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/fade7df36b01f2b170c78c63eb8fe0d11c613c4a.patch"
DTBO_PATCH5="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/2628183db0d96be8dae38a21f2b09cb10978f423.patch"
DTBO_PATCH6="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit/31f4577af3f8255ae503a5b30d8f68906edde85f.patch"

# Apply device specific patches
echo "-- Applying patches..."
apply_patches "$LTO_PATCH"
apply_patches "$DTBO_PATCH1"
apply_patches "$DTBO_PATCH2"
apply_patches "$DTBO_PATCH3"
apply_patches "$DTBO_PATCH4"
apply_patches "$DTBO_PATCH5"
apply_patches "$DTBO_PATCH6"

# Specific tweaks
echo "-- Enabling EROFS support..."
echo "CONFIG_EROFS_FS=y" >> $FINAL_DEFCONFIG
echo "CONFIG_EROFS_FS_XATTR=y" >> $FINAL_DEFCONFIG
echo "CONFIG_EROFS_FS_POSIX_ACL=y" >> $FINAL_DEFCONFIG
echo "CONFIG_EROFS_FS_SECURITY=y" >> $FINAL_DEFCONFIG
echo "CONFIG_EROFS_FS_ZIP=y" >> $FINAL_DEFCONFIG
echo "-- Getting rid of the dirty flag..."
sed -i "s/printf '%s' -dirty/:/g" scripts/setlocalversion
echo "-- Disabling IKHeaders..."
sed -i 's/CONFIG_IKHEADERS=y/# CONFIG_IKHEADERS is not set/g' $FINAL_DEFCONFIG

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

# tune compiler flags
echo "-- Tuning compiler flags..."
sed -i 's/-Wno-format-security/-Wno-format-security -Wno-declaration-after-statement -Wno-implicit-int -Wno-enum-conversion -Wno-default-const-init-var-unsafe -Wno-default-const-init-field-unsafe -Wno-misleading-indentation -Wno-unsequenced -Wno-sizeof-pointer-memaccess -Wno-implicit-function-declaration -Wno-implicit-enum-enum-cast/g' Makefile
sed -i '/export KBUILD_CFLAGS/i KBUILD_CFLAGS += -mllvm -polly -mllvm -enable-gvn-hoist -Wno-unused-command-line-argument' Makefile
cd ..