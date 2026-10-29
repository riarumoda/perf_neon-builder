![banner](.github/assets/banner.png)
<div align="center" style="font-size: 1.25rem;">
    <strong>
        <em>
        This project is not affiliated with any Android-based OS.
        </em>
    </strong>
</div>

<br>

<div align="center">

[![Downloads](https://img.shields.io/github/downloads/riarumoda/perf_neon-builder/total?label=Downloads&logo=icloud&logoColor=white)](https://github.com/riarumoda/perf_neon-builder/releases)
[![Telegram](https://img.shields.io/badge/Follow-Telegram-blue?logo=telegram)](https://t.me/trrflexgroup)
[![CI Status](https://img.shields.io/github/actions/workflow/status/riarumoda/perf_neon-builder/release.yml?label=Status&logo=github-actions&logoColor=white)](https://github.com/riarumoda/perf_neon-builder/actions/workflows/normal.yml)

</div>

# Disclaimer
***Your warranty is now void. I am not responsible for bricked devices, dead SD cards, or you getting fired because an alarm failed to work. Please do some research if you have any concerns about features included before flashing it! YOU are choosing to make these modifications, and if you point the finger at me for messing up your device, I will laugh at you.***   
<p align="right">Your typical XDA Forum Disclaimer.<p>   

# Background
The naming, Perf Neon, is inspired by a Linux Distribution called KDE Neon, where KDE take latest Ubuntu LTS as a base system and then put Latest KDE on top of it. Same thing as Perf Neon, where i take whatever the world the LineageOS, CrDroid and PixelOS team put under their kernel source and then put minimal patches on top of it.   

# What is it for?
This kernel solely focuses on adding goodies on top of the stock kernel, which fulfill the dream of a purists, where they want everything stable and rock solid from their stock kernels but also wanted extra spices on top of it.   

# Release schedules
This kernel follows weekly builds of LineageOS, you will get a new kernel build every sunday. You might need to check out the GitHub repo for new releases. Emergency rebuilt might happen if services that this builder rely on being broken or kernel source code have massive changes.   

# Features
**Features list**   
| Kernel Name | KernelSU | Baseband Guard | NoMount | Droidspaces |
| :--- | :---: | :---: | :---: | :---: |
| LineageOS (SM6150) | ✅ w/ SUSFS | ✅ | ✅ | ✅ |
| CrDroid (SM6150) | ✅ w/ SUSFS | ✅ | ✅ | 🟡 |
| PixelOS (SM6150) | ✅ w/ SUSFS | ✅ | ✅ | ❌ |
| AwakenOS (SM6150) | ✅ w/ SUSFS | ✅ | ✅ | ❌ |
| LineageOS (SM6125) | ✅ w/ SUSFS | ✅ | ✅ | 🟡 |
| Mi-Thorium (MSM8937) | ✅ w/ SUSFS | ✅ | ✅ | ✅ |
| Mi-Thorium (SDM439) | ✅ w/ SUSFS | ✅ | ✅ | ✅ |
| Mi-Titanium (MSM8953) | ✅ w/ SUSFS | ✅ | ✅ | ✅ |
| SouthWest-NG (SDM660) | ✅ w/ SUSFS | ✅ | ✅ | ✅ |
| MIUI (SM6150) | ✅ w/ SUSFS | ✅ | ✅ | 🟡 |
| LineageOS (SM7325) | ✅ w/ SUSFS | ✅ | ✅ | ❌ |
   
**File Namings**   
`neon-<OS/KernelName>-<DeviceName>-<Platform>-<BuildDate>.zip`   
- **neon:** Label indicator telling the user this kernel is built on Perf Neon Builder.
- **OS/KernelName:** Operating System or Kernel names.
- **DeviceName:** Codename of the device.
- **Platform:** Chipset or platform identifier.
- **BuildDate:** When the kernel was compiled.

**Notes**
- During the usage of Droidspaces with systemd-based distros, mask the `NetworkManager` and `wpa_supplicant` systemd services to avoid overriding whos owning the wifi device, a.k.a NetworkManager will take control of the wifi device and android will not be able to connect to wifi until you masked the systemd services.   
- CrDroid (SM6150), LineageOS (SM6125), and MIUI (SM6150) Droidspaces support have been marked "Yellow" because of the new Resources Limiter features of Droidspaces 7.0.0, and this feature is incompatible with said kernels because said kernels have Qualcomm WALT feature enabled by default, and CFS_BANDWIDTH is NOT compatible with Qualcomm WALT enabled.   

# Compatibility
**Supported device list**   
| Kernel Name | Supported Devices | Supported Android version |
| :--- | :---: | :---: |
| LineageOS (SM6150) | Redmi Note 10 Pro/Pro Max (sweet), Redmi Note 7 Pro (violet), Xiaomi Mi Note 10 Lite (toco) | Android 13 ~ Android 17 |
| CrDroid (SM6150) | Redmi Note 10 Pro/Pro Max (sweet) | Android 13 ~ Android 17 |
| PixelOS (SM6150) | Redmi Note 10 Pro/Pro Max (sweet), Xiaomi Mi Note 10 Lite (toco) | Android 13 ~ Android 17 |
| AwakenOS (SM6150) | Redmi Note 10 Pro/Pro Max (sweet), Xiaomi Mi Note 10 Lite (toco) | Android 13 ~ Android 17 |
| LineageOS (SM6125) | Redmi Note 8/8T (ginkgo/willow), Xiaomi Mi A3 (laurel_sprout) | Android 13 ~ Android 17 |
| Mi-Thorium (MSM8937) | Redmi 3S (land), Redmi 4 (prada), Redmi 4X (santoni), Redmi Note 5A Prime/Y1 Prime (ugg), Redmi 4A (rolex), Redmi 5A (riva), Redmi Note 5A Lite/Y1 Lite (ugglite) | Android 11 ~ Android 17 |
| Mi-Thorium (SDM439) | Redmi 7A (pine), Redmi 8 (olive), Redmi 8A (olivelite), Redmi 8A Dual (olivewood) | Android 11 ~ Android 17 |
| Mi-Titanium (MSM8953) | Redmi S2/Y2 (ysl), Redmi Note 4/4X Snapdragon (mido), Redmi 5 (rosy), Redmi 5 Plus (vince), Redmi 4 Prime/Pro (markw) | Android 11 ~ Android 17 |
| SouthWest-NG (SDM660) | Xiaomi Mi Pad 4/4+ (clover), Redmi Note 7/7S (lavender) | Android 11 ~ Android 17 |
| MIUI (SM6150) | Redmi Note 10 Pro/Pro Max (sweet) | Android 11 ~ Android 17 |
| LineageOS (SM7325) | Samsung Galaxy A52s 5G (a52sxq) | Android 13 ~ Android 17 |

**Notes**   
- Looking for davinci? I moved davinci support from here to [Nebula Kernel Builder](https://github.com/Drsexo/davinci_kernel) instead.
- We recommend installing LineageOS, CrDroid and PixelOS kernels on their respective OS.   
- AwakenOS is upstreamed PixelOS kernels. This usually have newer commits before it got merged into the official PixelOS kernel sources.   
- LineageOS (SM6125) & LineageOS (SM7325) kernel might run on PixelOS for the respective device.
- Mi-Thorium, Mi-Titanium, and SouthWest-NG kernels doesn't have any OS constraints.   
- Akari & Mi8953 build for Mi-Titanium kernels contains 2 different way of handling USB, Media and Camera stack. If Mi8953 build feels broken to you pick the Akari build instead.   
- Legacy label on SouthWest-NG is used to boot A16 and older OS with kernel 4.19 inside of it, without dynamic partition. Main is used to boot Android 17 and newer whether it's partition being dynamic or not.
- Don't forget to flash appender after flashing the kernel if you're using bootloader bypass exploit on MSM8937 devices.
- Your device aren't yet supported? Go to the telegram channel to request your device for support.   

**Warning! ⚠️**
- Currently MIUI kernel for Redmi Note 10 Pro is in BETA stage. Currently it only targets and tested on Android 13 MIUI 14 / Android 13 HyperOS 1. If you want to, become a tester by joining the group support and send log captured by this KernelSU module called [Log Catcher](https://github.com/Howard20181/Log-Catcher).    

# Installation
**On Recovery**   
- Download both the flashable zip of the custom kernel and the original boot & dtbo image for your device as a backup.   
- Flash or Sideload the flashable zip with `adb sideload </path/to/flashable.zip>`  
- Allow to continue if you see Error 21 signature invalid.   
- Reboot to system.   
- Install lastest BakaSU Manager. [[Original](https://nightly.link/Baka-SU/BakaSU/workflows/build-manager/main/Manager-release.zip) / [Spoofed](https://nightly.link/Baka-SU/BakaSU/workflows/build-manager/main/Spoofed-Manager-release.zip)] (Optional)
- Profit.   

**Restore to default kernel**   
- You'll need to remove everything inside `/data/adb`. You can do this with `su -c rm -rf /data/adb/*`.   
- Then immediately reboot to bootloader/fastbootd.   
- Flash the stock boot image with `fastboot flash boot </path/to/original/boot/image.img>`   
- Also flash the stock dtbo image with `fastboot flash dtbo </path/to/original/dtbo/image.img>`
- Reboot with `fastboot reboot`.   
- Profit.   

**Notes**   
You can install different KernelSU Manager with BakaSU kernel drivers. This is currently supported other KernelSU Managers:   
- [Original KernelSU](https://github.com/tiann/KernelSU) (tiann)    
- [KOW's KernelSU](https://github.com/KOWX712/KernelSU) (KOWX712)   
   
# Credits
**Patches & buildscript**
- [TBYOOL](https://github.com/tbyool) for the buildscripts, kernel sources, kernel commits & kernel patches.   
- [xiaomi-sm6150](https://github.com/xiaomi-sm6150) for the DTB patches.   
- [JackA1ltMan](https://github.com/JackA1ltman) for BakaSU hook scripts & SUSFS patches.   
- [TheSillyOk](https://github.com/TheSillyOk) for LTO fixup for 4.14 devices.   
- [null07089](https://github.com/null07089) for SELinux Hide fixup script.

**Projects**   
- [Baka-SU](https://github.com/Baka-SU) for BakaSU.   
- [vc-teahouse](https://github.com/vc-teahouse) for Baseband Guard.   
- [maxsteeel](https://github.com/maxsteeel) for NoMount.   
- [ravindu644](https://github.com/ravindu644) for Droidspaces.   
- [LineageOS](https://github.com/LineageOS) for kernel sources.   
- [PixelOS-Devices](https://github.com/PixelOS-Devices) for kernel sources.   
- [Mi-Thorium](https://github.com/Mi-Thorium) for kernel sources.   
- [crdroidandroid](https://github.com/crdroidandroid) for kernel sources.   
- [imren0x](https://github.com/imren0x) for kernel sources.   
- [pix106](https://github.com/pix106) for kernel sources.   
