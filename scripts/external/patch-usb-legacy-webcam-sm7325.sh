#!/usr/bin/env bash
# Keep the sm7325 USB device controller free for configfs (MTP + adb).
#
# The device patch scripts force every CONFIG_*=m to CONFIG_*=y.  On the stock
# sm7325 configs that turns CONFIG_USB_G_WEBCAM=m into =y, so webcam.c's
# module_init registers a composite gadget driver before dwc3 has probed:
#
#   udc-core: couldn't find an available UDC - added [g_webcam] to list of
#             pending drivers
#   ... dwc3 probes ...
#   g_webcam gadget: uvc: uvc_function_bind()
#   g_webcam gadget: g_webcam ready
#   usb: usb_mode_store : current usb mode : uvc
#
# udc-core binds that pending driver to a600000.dwc3 as soon as the UDC
# appears.  Configfs can then never claim the only UDC, so the gadget HAL
# cannot bring up MTP or adb (both are FunctionFS functions).  The HAL request
# times out with "monitorFfs signalled error" / "Gadget cannot be pulled down"
# and UsbDeviceManager reports status 1.  Host (OTG) mode does not use the UDC,
# which is why OTG keeps working.
#
# bonemachine's tree never builds g_webcam, which is why MTP+adb work there.
# This makes the legacy driver opt-in (g_webcam.legacy_webcam=1) and clears
# CONFIG_USB_G_WEBCAM from the final defconfig, so the UDC stays free for
# configfs.  The configfs UVC function is a separate symbol and unaffected.
#
# Idempotent. Usage: ./patch-usb-legacy-webcam-sm7325.sh [kernel_root] [defconfig]
set -euo pipefail

KROOT="${1:-.}"
DEFCONFIG="${2:-${FINAL_DEFCONFIG:-}}"

F="$KROOT/drivers/usb/gadget/legacy/webcam.c"
[ -f "$F" ] || { echo "error: $F not found" >&2; exit 1; }
command -v python3 > /dev/null || { echo "error: python3 is required" >&2; exit 1; }

echo "Freeing the USB gadget controller from legacy g_webcam in $KROOT..."
python3 - "$F" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
src = path.read_text()

anchor = "module_usb_composite_driver(webcam_driver);\n"
marker = "NEON_LEGACY_G_WEBCAM"

if marker in src:
    print("webcam.c: already patched, nothing to do")
    sys.exit(0)

if anchor not in src:
    sys.exit(f"error: webcam.c: anchor '{anchor.strip()}' not found")

replacement = """/*
 * NEON_LEGACY_G_WEBCAM: do not bind the legacy webcam gadget at module_init.
 *
 * udc-core queues this composite driver until the first UDC appears and then
 * binds it to that UDC (a600000.dwc3 here), which makes the controller
 * unavailable to configfs.  Since MTP and adb are FunctionFS functions behind
 * configfs, that leaves both of them dead while host/OTG mode still works.
 *
 * Keep the driver buildable, but only claim the UDC when explicitly asked for
 * with g_webcam.legacy_webcam=1 on the kernel command line (or modprobe).
 */
static bool legacy_webcam;
module_param(legacy_webcam, bool, 0444);
MODULE_PARM_DESC(legacy_webcam,
\t"bind the legacy webcam gadget to the first UDC (default: off)");

static int __init g_webcam_init(void)
{
\tif (!legacy_webcam) {
\t\tpr_info("g_webcam: legacy gadget disabled, configfs owns the UDC\\n");
\t\treturn 0;
\t}
\treturn usb_composite_probe(&webcam_driver);
}
module_init(g_webcam_init);

static void __exit g_webcam_exit(void)
{
\tif (legacy_webcam)
\t\tusb_composite_unregister(&webcam_driver);
}
module_exit(g_webcam_exit);
"""

path.write_text(src.replace(anchor, replacement, 1))
print("webcam.c: legacy g_webcam gadget made opt-in")
PY

# The final defconfig is the merged config after the =m -> =y pass, so the
# symbol shows up as =y there.  Scrub =y and =m alike so a later pass cannot
# turn the legacy gadget back into a built-in.
scrub() {
	local f="$1"
	[ -f "$f" ] || return 0
	if grep -qE '^CONFIG_USB_G_WEBCAM=(y|m)$' "$f"; then
		sed -i -E 's/^CONFIG_USB_G_WEBCAM=(y|m)$/# CONFIG_USB_G_WEBCAM is not set/' "$f"
		echo "cleared CONFIG_USB_G_WEBCAM in $f"
	fi
}

if [ -n "$DEFCONFIG" ]; then
	scrub "$KROOT/$DEFCONFIG"
	scrub "$DEFCONFIG"
fi
if [ -d "$KROOT/arch/arm64/configs" ]; then
	while IFS= read -r cfg; do
		scrub "$cfg"
	done < <(grep -rlE '^CONFIG_USB_G_WEBCAM=(y|m)$' "$KROOT/arch/arm64/configs" 2>/dev/null || true)
fi

# ---------------------------------------------------------------------------
# Post-conditions: never let a half-applied tree reach the compiler.
# ---------------------------------------------------------------------------
fails=0
check() {
	if eval "$2"; then
		echo "  ok: $1"
	else
		echo "  FAIL: $1" >&2
		fails=$((fails + 1))
	fi
}

check "legacy webcam init is opt-in" \
	"grep -q 'NEON_LEGACY_G_WEBCAM' '$F'"
check "module_usb_composite_driver() is gone" \
	"! grep -q 'module_usb_composite_driver(webcam_driver);' '$F'"
check "g_webcam_init() is registered" \
	"grep -q '^module_init(g_webcam_init);$' '$F'"
check "g_webcam_exit() is registered" \
	"grep -q '^module_exit(g_webcam_exit);$' '$F'"

if [ -n "$DEFCONFIG" ] && [ -f "$KROOT/$DEFCONFIG" ]; then
	check "CONFIG_USB_G_WEBCAM is not enabled in $DEFCONFIG" \
		"! grep -qE '^CONFIG_USB_G_WEBCAM=' '$KROOT/$DEFCONFIG'"
fi

[ "$fails" -eq 0 ] || { echo "error: $fails post-condition(s) failed" >&2; exit 1; }
echo "legacy g_webcam gadget disabled; a600000.dwc3 is free for configfs"
