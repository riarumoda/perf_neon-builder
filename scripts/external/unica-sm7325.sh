#!/bin/bash
# UNICA flasher packaging for SM7325 devices
# Sourced from build.sh after the kernel has been compiled.

# Resolve the LineageOS codename and DTBO path for this device
if [ -n "$UNICA_CODENAME" ]; then
    CODENAME="$UNICA_CODENAME"
elif [[ "$DEVICE" == "a52" ]]; then
    CODENAME="a52sxq"
else
    CODENAME="${DEVICE}xq"
fi
DTBO_DIR="${UNICA_DTBO_DIR:-arch/arm64/boot/dts/samsung/$DEVICE/$CODENAME}"

# Out-of-tree builds (make O=out) write the .dtbo files under out/, while older
# in-tree builds leave them next to the sources. Resolve whichever exists.
if [ -z "${UNICA_DTBO_IMAGE:-}" ]; then
    if compgen -G "$PWD/$KERNEL_DIR/out/$DTBO_DIR/*.dtbo" > /dev/null; then
        DTBO_DIR="out/$DTBO_DIR"
    elif ! compgen -G "$PWD/$KERNEL_DIR/$DTBO_DIR/*.dtbo" > /dev/null; then
        echo "-- ERROR: no .dtbo files found for $CODENAME"
        exit 1
    fi
fi

# Prepare boot image tools
BIN_DIR="$PWD/$KERNEL_DIR/clang/bin"
mkdir -p "$BIN_DIR"
if [ ! -x "$BIN_DIR/magiskboot" ]; then
    echo "-- Downloading magiskboot..."
    APK_URL="$(curl -s "https://api.github.com/repos/topjohnwu/Magisk/releases" | grep -oE 'https://[^\"]+\.apk' | grep 'Magisk[-.]v' | head -n 1)"
    [ -n "$APK_URL" ] || { echo "-- ERROR: could not resolve Magisk APK URL"; exit 1; }
    curl -L --retry 5 --retry-all-errors --retry-delay 5 -o magisk.apk "$APK_URL"
    unzip -p "magisk.apk" "lib/x86_64/libmagiskboot.so" > "$BIN_DIR/magiskboot"
    chmod +x "$BIN_DIR/magiskboot"
    rm -f magisk.apk
fi
if [ ! -x "$BIN_DIR/avbtool" ]; then
    echo "-- Downloading avbtool..."
    AVBTOOL_URL="https://android.googlesource.com/platform/external/avb/+/refs/heads/master/avbtool.py?format=TEXT"
    curl -sL "$AVBTOOL_URL" | base64 --decode -i > "$BIN_DIR/avbtool"
    chmod +x "$BIN_DIR/avbtool"
fi

# Download the stock boot image used as the repack base
echo "-- Downloading stock boot image..."
mkdir -p "$BIN_DIR/images"
STOCK_BOOT="$BIN_DIR/images/boot.img"
if [ -n "$UNICA_BOOT_URL" ]; then
    BOOT_URL="$UNICA_BOOT_URL"
else
    BOOT_URL="$(curl -s "https://download.lineageos.org/api/v2/devices/$CODENAME/builds" | grep -oE 'https://[^\"]+/boot\.img' | head -n 1)"
fi
[ -n "$BOOT_URL" ] || { echo "-- ERROR: could not find boot.img download link for $CODENAME"; exit 1; }
curl -sSL --retry 5 --retry-all-errors --retry-delay 5 -o "$STOCK_BOOT" "$BOOT_URL"
ls -alhZ "$STOCK_BOOT"

# Generate the DTBO image from the compiled device trees, or reuse the one the
# kernel build produced itself (UNICA_DTBO_IMAGE points at it).
DTBO_IMG="$PWD/$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
if [ -n "${UNICA_DTBO_IMAGE:-}" ]; then
    echo "-- Using dtbo image produced by the build..."
    DTBO_SRC="$PWD/$KERNEL_DIR/$UNICA_DTBO_IMAGE"
    [ -f "$DTBO_SRC" ] || { echo "-- ERROR: dtbo image not found at $DTBO_SRC"; exit 1; }
    if [ "$(readlink -f "$DTBO_SRC")" != "$(readlink -f "$DTBO_IMG")" ]; then
        cp "$DTBO_SRC" "$DTBO_IMG"
    fi
else
    echo "-- Generating dtbo image..."
    MKDTBOIMG="$PWD/$KERNEL_DIR/out/mkdtboimg.py"
    curl -sSL "https://android.googlesource.com/platform/system/libufdt/+/refs/heads/main/utils/src/mkdtboimg.py?format=TEXT" | base64 -d > "$MKDTBOIMG"
    chmod +x "$MKDTBOIMG"
    ( cd "$KERNEL_DIR" && python3 "$MKDTBOIMG" create out/arch/arm64/boot/dtbo.img "$DTBO_DIR"/*.dtbo ) \
        || { echo "-- ERROR: failed to generate dtbo image from $DTBO_DIR"; exit 1; }
fi
[ -s "$DTBO_IMG" ] || { echo "-- ERROR: dtbo image is missing or empty at $DTBO_IMG"; exit 1; }

# Unpack the stock boot image, replace its kernel and repack it
echo "-- Rebuilding boot image..."
TMP_DIR="$PWD/$KERNEL_DIR/out/arch/arm64/boot/tmp"
IMAGE_FILE="$PWD/$KERNEL_DIR/out/arch/arm64/boot/Image"
REPACKED_BOOT="$PWD/$KERNEL_DIR/out/arch/arm64/boot/boot.img"
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cp "$STOCK_BOOT" "$TMP_DIR/boot.img"
(
    cd "$TMP_DIR"
    "$BIN_DIR/avbtool" erase_footer --image "boot.img"
    "$BIN_DIR/magiskboot" unpack boot.img
    rm -f kernel
    cp "$IMAGE_FILE" kernel
    "$BIN_DIR/magiskboot" repack boot.img boot-repacked.img
    cp boot-repacked.img "$REPACKED_BOOT"
)

# Stage the UNICA flasher package
echo "-- Staging UNICA package..."
rm -rf output
mkdir -p output/images output/META-INF/com/google/android
cp "$REPACKED_BOOT" output/images/boot.img
cp "$KERNEL_DIR/out/arch/arm64/boot/dtbo.img" output/images/dtbo.img
echo "# Dummy file; update-binary is a shell script." > output/META-INF/com/google/android/updater-script
touch output/META-INF/com/google/android/update-binary
chmod +x scripts/external/update-binary-sm7325.sh
bash scripts/external/update-binary-sm7325.sh

# Zip the final flasher
echo "-- Zipping UNICA package..."
[ -n "$ZIP_PREFIX" ] || { echo "-- ERROR: ZIP_PREFIX is not set in devices/$DEVICE/$OS.conf"; exit 1; }
ZIPNAME="$ZIP_PREFIX-$BUILD_DATE.zip"
cd output
zip -rq9 "../$ZIPNAME" ./*
cd ..
