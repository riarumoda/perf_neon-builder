#!/bin/bash
cd "$KERNEL_DIR"

# Revert KSU
echo "-- Reverting KSU Specific commits..."
revert_commit "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/4740c36778c805159d81c5fc07b8f87741a2d790.patch"
revert_commit "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/d6857cbfff3345158783bd6fc61bf1a6c34801ab.patch"
revert_commit "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/6203929885ae6c67832aae96967f777a7200d48d.patch"
revert_commit "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/44bb4823d220dabae44df799f0068374a796729f.patch"
revert_commit "https://github.com/awaken-sweet/android_kernel_xiaomi_sm6150/commit/4b07bf36aabfd0a15ed156ee3be3d3233cde79be.patch"

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
