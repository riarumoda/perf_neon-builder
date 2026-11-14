#!/usr/bin/env bash
# Built-in qcacld only registers /dev/wlan in the module build, and Samsung's
# WiFi HAL never writes the boot_wlan sysfs hook, so nothing loads the driver.
# Load it from a late initcall, after icnss2 has probed, as module_init() does
# for wlan.ko.
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

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

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

# Replace the whole built-in function (its body has no nested brace at column 0)
awk 'NR==FNR { repl = repl $0 "\n"; next }
     /^static int __init hdd_module_init\(void\)$/ && !done {
	     printf "%s", repl; skip = 1; done = 1; next }
     skip && /^}$/ { skip = 0; next }
     !skip { print }' "$TMP/repl.txt" "$F" > "$TMP/out" && cat "$TMP/out" > "$F"

# sanity: marker landed once, load hooked once, stock body and devctl untouched
[ "$(grep -c 'BUILTIN_WLAN_DEVCTL' "$F")" -eq 1 ] || { echo "error: built-in load block not applied" >&2; exit 1; }
[ "$(grep -c 'late_initcall(hdd_builtin_wlan_load);' "$F")" -eq 1 ] || { echo "error: late_initcall hook missing" >&2; exit 1; }
[ "$(grep -c 'ret = hdd_driver_load();' "$F")" -eq 1 ] || { echo "error: hdd_driver_load call missing" >&2; exit 1; }
[ "$(grep -c 'wlan_hdd_state_ctrl_param_create();' "$F")" -eq 1 ] || { echo "error: devctl call sites changed" >&2; exit 1; }
[ "$(grep -c 'wlan_init_sysfs();' "$F")" -eq 1 ] || { echo "error: wlan_init_sysfs call sites changed" >&2; exit 1; }
echo "wlan_hdd_main.c patched: built-in qcacld loads at late init"
