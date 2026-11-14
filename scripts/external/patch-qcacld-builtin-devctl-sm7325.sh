#!/usr/bin/env bash
# Built-in qcacld only registers /dev/wlan in the module build, so the WiFi HAL
# fails with "Failed to access driver state control param". Register it from the
# built-in initcall too; the HAL's "ON" write then triggers hdd_driver_load().
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
	int ret;

	/* BUILTIN_WLAN_DEVCTL: the module build registers /dev/wlan from
	 * module_init(), which built-in builds never run. Without it the WiFi
	 * HAL cannot issue "ON", so hdd_driver_load() is never called.
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

# Replace the whole built-in function (its body has no nested brace at column 0)
awk 'NR==FNR { repl = repl $0 "\n"; next }
     /^static int __init hdd_module_init\(void\)$/ && !done {
	     printf "%s", repl; skip = 1; done = 1; next }
     skip && /^}$/ { skip = 0; next }
     !skip { print }' "$TMP/repl.txt" "$F" > "$TMP/out" && cat "$TMP/out" > "$F"

# sanity: the marker landed once, both call sites exist, sysfs init kept
[ "$(grep -c 'BUILTIN_WLAN_DEVCTL' "$F")" -eq 1 ] || { echo "error: built-in devctl block not applied" >&2; exit 1; }
[ "$(grep -c 'wlan_hdd_state_ctrl_param_create();' "$F")" -eq 2 ] || { echo "error: expected 2 devctl call sites after patching" >&2; exit 1; }
[ "$(grep -c 'wlan_init_sysfs();' "$F")" -eq 1 ] || { echo "error: wlan_init_sysfs call sites changed" >&2; exit 1; }
echo "wlan_hdd_main.c patched: /dev/wlan registered for built-in builds"
