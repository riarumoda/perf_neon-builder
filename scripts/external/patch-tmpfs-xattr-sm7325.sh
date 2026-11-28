#!/usr/bin/env bash
# Let /dev (tmpfs) store SELinux labels on the Lineage sm7325 trees.
#
# Android mounts /dev as a tmpfs and ueventd labels every node it creates via
# the security.selinux xattr (setfscreatecon() -> security_inode_init_security).
# tmpfs only registers those xattr handlers when CONFIG_TMPFS_XATTR is enabled
# (mm/shmem.c: sb->s_xattr = shmem_xattr_handlers is inside
# #ifdef CONFIG_TMPFS_XATTR, and shmem_initxattrs is #defined to NULL
# otherwise).  With the option off, security_inode_init_security() sees
# initxattrs == NULL and silently drops the label, so every /dev inode falls
# back to the mount's def_sid (u:object_r:file:s0).
#
# LineageOS' generated vendor/lineage-{a52sxq,a73xq,m52xq}_defconfig ships with
# CONFIG_TMPFS_XATTR disabled, which is why the lineage-sm7325 build bootloops
# while bone-machine's Samsung defconfig (CONFIG_TMPFS_XATTR=y) does not:
#
#   apexd-bootstrap: Failed to create a new loop device. Retrying...:
#                    Failed to open loop-control: Permission denied
#   Could not create loop device for /system/apex/...
#   init: reboot,bootloader,bootstrap-apexd-failed
#
# apexd runs in a confined domain, so a mislabelled /dev/loop-control is
# rejected with EACCES before userspace ever gets to system_server.
#
# Idempotent. Usage: ./patch-tmpfs-xattr-sm7325.sh [kernel_root] [defconfig]
set -euo pipefail

KROOT="${1:-.}"
DEFCONFIG="${2:-${FINAL_DEFCONFIG:-}}"

[ -n "$DEFCONFIG" ] || {
	echo "error: no defconfig given (pass it as \$2 or set FINAL_DEFCONFIG)" >&2
	exit 1
}

enable_tmpfs_xattr() {
	local f="$1"

	[ -f "$f" ] || return 0

	# Drop any existing setting first so the file cannot end up with both
	# "is not set" and "=y" (the last one wins, but keep it unambiguous).
	sed -i -E \
		-e '/^CONFIG_TMPFS_XATTR=/d' \
		-e '/^# CONFIG_TMPFS_XATTR is not set[[:space:]]*$/d' \
		"$f"

	echo 'CONFIG_TMPFS_XATTR=y' >>"$f"
	echo "enabled CONFIG_TMPFS_XATTR in $f"
}

# The merged config the build actually feeds to Kconfig.
enable_tmpfs_xattr "$KROOT/$DEFCONFIG"
# Also handle an absolute DEFCONFIG / a caller that already cd'ed in.
if [ "$DEFCONFIG" != "$KROOT/$DEFCONFIG" ] && [ -f "$DEFCONFIG" ]; then
	enable_tmpfs_xattr "$DEFCONFIG"
fi

# ---------------------------------------------------------------------------
# Post-conditions: never let a half-applied config reach the compiler.
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

F="$KROOT/$DEFCONFIG"

check "CONFIG_TMPFS_XATTR=y in $DEFCONFIG" \
	"grep -qx 'CONFIG_TMPFS_XATTR=y' '$F'"
check "no conflicting CONFIG_TMPFS_XATTR entry in $DEFCONFIG" \
	"[ \"\$(grep -cE '^(# )?CONFIG_TMPFS_XATTR([= ]|$)' '$F')\" -eq 1 ]"
check "CONFIG_TMPFS is still enabled in $DEFCONFIG" \
	"grep -qx 'CONFIG_TMPFS=y' '$F'"

# The rationale only holds while tmpfs gates xattr handlers on the symbol.
if [ -f "$KROOT/mm/shmem.c" ]; then
	check "tmpfs xattr handlers are gated on CONFIG_TMPFS_XATTR" \
		"awk '/#ifdef CONFIG_TMPFS_XATTR/{f=1} f&&/sb->s_xattr = shmem_xattr_handlers;/{found=1} END{exit !found}' '$KROOT/mm/shmem.c'"
fi

[ "$fails" -eq 0 ] || { echo "error: $fails post-condition(s) failed" >&2; exit 1; }
echo "tmpfs xattrs enabled; /dev nodes can carry their SELinux labels again"
