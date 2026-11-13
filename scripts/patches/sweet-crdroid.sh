#!/bin/bash
cd "$KERNEL_DIR"

# Specific tweaks
echo "-- Enabling EROFS support..."
echo "CONFIG_EROFS_FS=y" >> $FINAL_DEFCONFIG
echo "CONFIG_EROFS_FS_XATTR=y" >> $FINAL_DEFCONFIG
echo "CONFIG_EROFS_FS_POSIX_ACL=y" >> $FINAL_DEFCONFIG
echo "CONFIG_EROFS_FS_SECURITY=y" >> $FINAL_DEFCONFIG
echo "CONFIG_EROFS_FS_ZIP=y" >> $FINAL_DEFCONFIG

echo "-- Disabling Werror enforcement..."
echo "CONFIG_CC_WERROR=n" >> $FINAL_DEFCONFIG

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

cd ..
