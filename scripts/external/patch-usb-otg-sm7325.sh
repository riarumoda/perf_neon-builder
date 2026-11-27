#!/usr/bin/env bash
# Restore USB host / OTG on the bonemachine sm7325 tree.
#
# bonemachine ships CONFIG_DISABLE_LOCKSCREEN_USB_RESTRICTION unset, so Samsung's
# lock-screen USB restriction stays compiled in.  With that config off,
# reserve_state_check() in drivers/usb/notify/usb_notify.c runs this at boot:
#
#   #ifndef CONFIG_DISABLE_LOCKSCREEN_USB_RESTRICTION
#       if (u_noti->lock_state == USB_NOTIFY_INIT_STATE) {
#               u_noti->udev.first_restrict = true;
#               set_notify_disable(&u_noti->udev, NOTIFY_BLOCK_TYPE_HOST);
#               u_noti->skip_possible_usb = 1;
#       }
#   ...
#
# set_notify_disable(HOST) emits NOTIFY_EVENT_HOST_DISABLE, whose handler sets
# NOTIFY_BLOCK_TYPE_HOST in udev.disable_state.  check_block_event() then treats
# every host/OTG cable event as blocked, so dwc3 never switches to host mode:
# no VBUS boost, no xhci probe, no enumeration.
#
# lock_state only leaves USB_NOTIFY_INIT_STATE when userspace writes the Samsung
# usb_notify sysfs node (usb_sl / secure_lock).  AOSP and Lineage's UsbService
# never write it, so the block is permanent on this ROM.  Client mode (MTP, adb)
# is a separate block bit and keeps working, which is exactly the observed
# "MTP+adb work, OTG dead" behaviour.
#
# Lineage's tree sets CONFIG_DISABLE_LOCKSCREEN_USB_RESTRICTION=y, which compiles
# the boot-time host block (and the rest of the lock-screen restriction) out,
# and that is why OTG works there.  Enable the same option here.
#
# Idempotent. Usage: ./patch-usb-otg-sm7325.sh [kernel_root] [defconfig]
set -euo pipefail

KROOT="${1:-.}"
DEFCONFIG="${2:-${FINAL_DEFCONFIG:-}}"
SYM="CONFIG_DISABLE_LOCKSCREEN_USB_RESTRICTION"

KCONFIG="$KROOT/drivers/usb/notify/Kconfig"
NOTIFY="$KROOT/drivers/usb/notify/usb_notify.c"

[ -f "$KCONFIG" ] || { echo "error: $KCONFIG not found (not an sm7325 usb_notify tree?)" >&2; exit 1; }
grep -qx "config DISABLE_LOCKSCREEN_USB_RESTRICTION" "$KCONFIG" ||
	{ echo "error: $KCONFIG has no DISABLE_LOCKSCREEN_USB_RESTRICTION symbol" >&2; exit 1; }
[ -f "$NOTIFY" ] || { echo "error: $NOTIFY not found" >&2; exit 1; }

echo "Enabling USB host/OTG in $KROOT (disabling the lock-screen USB restriction)..."

# Rewrite "# CONFIG_X is not set" / "CONFIG_X=n|m" to "CONFIG_X=y".  Files that
# never mention the symbol are left alone.
enable_sym() {
	local f="$1" changed=0

	[ -f "$f" ] || return 0

	if grep -qx "# $SYM is not set" "$f"; then
		sed -i "s/^# $SYM is not set$/$SYM=y/" "$f"
		changed=1
	fi
	if grep -qE "^$SYM=" "$f"; then
		if ! grep -qx "$SYM=y" "$f"; then
			changed=1
		fi
		sed -i -E "s/^$SYM=.*$/$SYM=y/" "$f"
	fi

	[ "$changed" -eq 1 ] && echo "  enabled $SYM in $f"
	return 0
}

# 1) The finalized defconfig that the build actually parses.
if [ -n "$DEFCONFIG" ]; then
	if [ -f "$KROOT/$DEFCONFIG" ]; then
		enable_sym "$KROOT/$DEFCONFIG"
	elif [ -f "$DEFCONFIG" ]; then
		enable_sym "$DEFCONFIG"
	fi
fi

# 2) Every source fragment/defconfig (including the embedded *_stock_defconfig
#    used for the spoofed /proc/config.gz), so a rebuild keeps the setting.
if [ -d "$KROOT/arch/arm64/configs" ]; then
	while IFS= read -r cfg; do
		enable_sym "$cfg"
	done < <(grep -rlE "^# $SYM is not set$|^$SYM=" "$KROOT/arch/arm64/configs" 2>/dev/null || true)
fi

# 3) The merged config normally carries the line, but make sure it ends up =y
#    even in a tree that only sets it through an unusual fragment layout.
if [ -n "$DEFCONFIG" ] && [ -f "$KROOT/$DEFCONFIG" ] && ! grep -qE "^$SYM=" "$KROOT/$DEFCONFIG"; then
	echo "$SYM=y" >> "$KROOT/$DEFCONFIG"
	echo "  appended $SYM=y to $KROOT/$DEFCONFIG"
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

if [ -n "$DEFCONFIG" ] && [ -f "$KROOT/$DEFCONFIG" ]; then
	check "$SYM=y in $DEFCONFIG" \
		"grep -qx '$SYM=y' '$KROOT/$DEFCONFIG'"
	check "no disabled $SYM left in $DEFCONFIG" \
		"! grep -qE '^# $SYM is not set$|^$SYM=[nm]$' '$KROOT/$DEFCONFIG'"
fi

if [ -d "$KROOT/arch/arm64/configs" ]; then
	check "no config under arch/arm64/configs still disables $SYM" \
		"! grep -rqE '^# $SYM is not set$|^$SYM=[nm]$' '$KROOT/arch/arm64/configs'"
fi

# The fix relies on this config gating the boot-time host block, so make sure
# the tree really is the one this script was written for.
check "usb_notify.c carries the guarded boot-time host block" \
	"grep -q 'set_notify_disable(&u_noti->udev, NOTIFY_BLOCK_TYPE_HOST);' '$NOTIFY'"

[ "$fails" -eq 0 ] || { echo "error: $fails post-condition(s) failed" >&2; exit 1; }
echo "USB host/OTG unblocked; lock-screen USB restriction is compiled out"
