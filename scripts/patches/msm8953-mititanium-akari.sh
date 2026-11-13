#!/bin/bash
cd "$KERNEL_DIR"

# Export kernel patches
echo "-- Exporting device patches..."
KSU_REVERT1="https://github.com/imren0x/msm-4.19/commit/599d78404136f1135dab59f8a4b07f375920d593.patch"
KSU_REVERT2="https://github.com/imren0x/msm-4.19/commit/ddaa99ca3d0d08729b832737aa8ead84cd9271bd.patch"
KSU_REVERT3="https://github.com/imren0x/msm-4.19/commit/13a81eb419c70b1ea0e6990852be3f1bba9766d8.patch"
KSU_REVERT4="https://github.com/imren0x/msm-4.19/commit/5426473d20be5c5b128b68d8a5d5fe838af3d7ad.patch"

# Apply device specific patches
# Revert newest first: v3.3.1+ update, 32567 update, import, ksu.config.
echo "-- Reverting KSU commits..."
revert_commit "$KSU_REVERT1"
revert_commit "$KSU_REVERT2"
revert_commit "$KSU_REVERT3"
revert_commit "$KSU_REVERT4"

echo "-- Fixing msm clk broken redifinition..."
sed -i 's/static inline void clk_debug_print_hw.*/void clk_debug_print_hw(struct clk *clk, struct seq_file *f);/' include/linux/clk/msm-clk-provider.h
sed -i '/static inline int clock_debug_register/,/}/c\int clock_debug_register(struct clk *clk);' drivers/clk/msm/clock.h
sed -i '/static inline void clock_debug_print_enabled.*/c\void clock_debug_print_enabled(bool print_parent);' drivers/clk/msm/clock.h

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
