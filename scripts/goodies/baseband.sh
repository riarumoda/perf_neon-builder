#!/bin/bash

# Export Baseband Guard Variables
BBG_SETUP_URI="https://raw.githubusercontent.com/vc-teahouse/Baseband-guard/main/setup.sh"

# Setup BBG
cd $KERNEL_DIR
echo "-- Baseband Guard: Running setup script..."
curl -LSs --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" "$BBG_SETUP_URI" | bash &> /dev/null || { echo "-- Fatal: BBG setup failed!"; exit 1; }
echo "CONFIG_BBG=y" >> "$FINAL_DEFCONFIG"
sed -i 's|^REPO_LINK :=.*|REPO_LINK := https://github.com/vc-teahouse/Baseband-guard|' Baseband-guard/Makefile

# Hook LSM if available
if grep -q "#define DEFINE_LSM(lsm)" "include/linux/lsm_hooks.h" 2>/dev/null; then
    if grep -q "^CONFIG_LSM=" "$FINAL_DEFCONFIG"; then
        sed -i 's/^\(CONFIG_LSM=".*\)"/\1,baseband_guard"/' "$FINAL_DEFCONFIG"
        echo "-- Appended baseband_guard to existing CONFIG_LSM."
    else
        echo 'CONFIG_LSM="lockdown,yama,loadpin,safesetid,integrity,selinux,smack,tomoyo,apparmor,bpf,baseband_guard"' >> "$FINAL_DEFCONFIG"
        echo "-- Added default CONFIG_LSM with baseband_guard."
    fi
fi

# BBG Quirks
if grep -q "struct[[:space:]]\+task_security_struct[[:space:]]\+\*selinux_cred" "security/selinux/include/objsec.h" 2>/dev/null; then
    echo "-- Removing duplicate task_security_struct definition..."
    sed -i '/static inline struct task_security_struct \*selinux_cred/,/[[:space:]]*}/d' security/baseband-guard/tracing/tracing.c
fi
cd ..
