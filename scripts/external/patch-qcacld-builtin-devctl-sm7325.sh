#!/usr/bin/env bash
# Built-in qcacld does not come up by itself. Two layouts exist:
#  - the write handler loads the driver on "ON" (Lineage): only /dev/wlan must
#    be created for the built-in build;
#  - the write handler only waits (bonemachine): the driver must be loaded from
#    an initcall, after icnss2 has probed, as module_init() does for wlan.ko.
#
# Edits drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_main.c in place.
# Usage: ./patch-qcacld-builtin-devctl-sm7325.sh [kernel_root]
set -euo pipefail

KROOT="${1:-.}"
F="$KROOT/drivers/staging/qcacld-3.0/core/hdd/src/wlan_hdd_main.c"
[ -f "$F" ] || { echo "error: $F not found" >&2; exit 1; }

if grep -q 'BUILTIN_WLAN_DEVCTL' "$F"; then
	echo "wlan_hdd_main.c: already patched, skipping"
	exit 0
fi

# The built-in init is the only hdd_module_init() with __init
n=$(grep -cP '^static int __init hdd_module_init\(void\)$' "$F" || echo 0)
[ "$n" -eq 1 ] || { echo "error: built-in hdd_module_init anchor matched $n times (expected 1)" >&2; exit 1; }

# Its body must still be the plain wlan_init_sysfs() version
n=$(grep -c 'wlan_hdd_state_ctrl_param_create();' "$F" || echo 0)
[ "$n" -eq 1 ] || { echo "error: expected 1 devctl call before patching, found $n" >&2; exit 1; }

if awk '/^static ssize_t wlan_hdd_state_ctrl_param_write\(/,/^}$/' "$F" |
	grep -q 'hdd_driver_load()'; then
	mode=devctl
else
	mode=load
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if [ "$mode" = load ]; then
cat > "$TMP/repl.txt" <<'EOF'
static int __init hdd_module_init(void)
{
	int ret = -EINVAL;

	ret = wlan_init_sysfs();
	if (ret)
		hdd_err("Failed to create sysfs entry");

	return ret;
}

/*
 * BUILTIN_WLAN_DEVCTL: built-in builds only create boot_wlan and wait for a
 * userspace write. Load the driver here instead, after icnss2 has probed, so
 * /dev/wlan exists and the WiFi HAL's "ON" write finds a loaded driver.
 */
static int __init hdd_builtin_wlan_load(void)
{
	int ret;

	ret = hdd_driver_load();
	if (ret) {
		hdd_err("Failed to load WLAN driver; errno:%d", ret);
		return ret;
	}

	if (wlan_loader)
		wlan_loader->loaded_state = MODULE_INITIALIZED;

	return 0;
}
late_initcall(hdd_builtin_wlan_load);
EOF
else
cat > "$TMP/repl.txt" <<'EOF'
static int __init hdd_module_init(void)
{
	int ret;

	/* BUILTIN_WLAN_DEVCTL: the module_init path creates /dev/wlan, which the
	 * built-in branch never runs. Create it here; the write handler then
	 * loads the driver on the HAL's "ON".
	 */
	ret = wlan_hdd_state_ctrl_param_create();
	if (ret)
		hdd_err("Failed to create wlan state control param; errno:%d", ret);

	ret = wlan_init_sysfs();
	if (ret)
		hdd_err("Failed to create sysfs entry");

	return ret;
}
EOF
fi

# Replace the whole built-in function (its body has no nested brace at column 0)
awk 'NR==FNR { repl = repl $0 "\n"; next }
     /^static int __init hdd_module_init\(void\)$/ && !done {
	     printf "%s", repl; skip = 1; done = 1; next }
     skip && /^}$/ { skip = 0; next }
     !skip { print }' "$TMP/repl.txt" "$F" > "$TMP/out" && cat "$TMP/out" > "$F"

# sanity: marker landed once and the expected pieces are in place
[ "$(grep -c 'BUILTIN_WLAN_DEVCTL' "$F")" -eq 1 ] || { echo "error: built-in block not applied" >&2; exit 1; }
[ "$(grep -c 'wlan_init_sysfs();' "$F")" -eq 1 ] || { echo "error: wlan_init_sysfs call sites changed" >&2; exit 1; }
if [ "$mode" = load ]; then
	[ "$(grep -c 'late_initcall(hdd_builtin_wlan_load);' "$F")" -eq 1 ] || { echo "error: late_initcall hook missing" >&2; exit 1; }
	[ "$(grep -c 'ret = hdd_driver_load();' "$F")" -eq 1 ] || { echo "error: hdd_driver_load call missing" >&2; exit 1; }
	[ "$(grep -c 'wlan_hdd_state_ctrl_param_create();' "$F")" -eq 1 ] || { echo "error: devctl call sites changed" >&2; exit 1; }
	echo "wlan_hdd_main.c patched: built-in qcacld loads at late init"
else
	[ "$(grep -c 'wlan_hdd_state_ctrl_param_create();' "$F")" -eq 2 ] || { echo "error: expected 2 devctl call sites after patching" >&2; exit 1; }
	echo "wlan_hdd_main.c patched: /dev/wlan registered for built-in builds"
fi
