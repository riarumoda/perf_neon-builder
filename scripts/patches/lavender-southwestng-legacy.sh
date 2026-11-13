#!/bin/bash
cd "$KERNEL_DIR"

# Specific tweaks
echo "-- Fixing fingerprint..."
sed -i '1s/^/#ifndef CONFIG_MACH_XIAOMI_SDM660\n#define CONFIG_MACH_XIAOMI_SDM660 1\n#endif\n\n/' drivers/input/fingerprint/fpc/fpc1020_platform_tee.c
sed -i '/#ifdef CONFIG_MACH_XIAOMI_SDM660/{
  N
  /int irqf;/{
    N
    c\	int irqf;
  }
}' drivers/input/fingerprint/fpc/fpc1020_platform_tee.c
sed -i '/#ifdef CONFIG_MACH_XIAOMI_SDM660/{
  N
  /size_t i;/{
    N
    c\	size_t i;
  }
}' drivers/input/fingerprint/fpc/fpc1020_platform_tee.c
sed -i 's/goto irq_gpio_exit;/{ devm_gpio_free(dev, fpc1020->irq_gpio); goto exit; }/g' drivers/input/fingerprint/fpc/fpc1020_platform_tee.c
sed -i 's/goto rst_gpio_exit;/{ devm_gpio_free(dev, fpc1020->rst_gpio); devm_gpio_free(dev, fpc1020->irq_gpio); goto exit; }/g' drivers/input/fingerprint/fpc/fpc1020_platform_tee.c
sed -i -e '/rst_gpio_exit:/d' -e '/irq_gpio_exit:/d' drivers/input/fingerprint/fpc/fpc1020_platform_tee.c

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
