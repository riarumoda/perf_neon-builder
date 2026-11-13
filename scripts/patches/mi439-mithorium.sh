#!/bin/bash
cd "$KERNEL_DIR"

# Export kernel patches
echo "-- Exporting device patches..."
KSU_REVERT="https://github.com/Mi-Thorium/kernel_msm-4.19/commit/624875e8edc36ae280b1f8efc1d3c48a28da64ea.patch"

# Apply device specific patches
echo "-- Reverting KSU commit..."
revert_commit "$KSU_REVERT"

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
