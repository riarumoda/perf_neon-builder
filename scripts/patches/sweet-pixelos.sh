#!/bin/bash
cd "$KERNEL_DIR"

# Specific tweaks
echo "-- Fixing fair scheduler..."
sed -i -e 's/update_load_avg(qcfs_rq, se, 0);/update_load_avg(se, 0);/g' \
       -e 's/update_load_avg(cfs_rq, se, 0);/update_load_avg(se, 0);/g' \
       kernel/sched/fair.c
sed -i '/se_update_runnable/d' kernel/sched/fair.c
sed -i '/assert_list_leaf_cfs_rq/d' kernel/sched/fair.c

echo "-- Disabling modversions..."
sed -i 's/^CONFIG_MODVERSIONS=y/# CONFIG_MODVERSIONS is not set/' $FINAL_DEFCONFIG

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
