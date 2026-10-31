#!/usr/bin/env bash
# Defer the Samsung sec_input Synaptics firmware check/update out of probe, so
# request_firmware() does not stall the initcall thread for the 60 s sysfs
# fallback timeout (and, because this driver treats a failed request as a probe
# error, does not leave the touchscreen dead afterwards).
# Edits drivers/input/sec_input/synaptics/synaptics_core.c in place (sed/awk).
# Usage: ./apply-synaptics-fw-defer.sh [kernel_root]
set -euo pipefail

KROOT="${1:-.}"
F="$KROOT/drivers/input/sec_input/synaptics/synaptics_core.c"
[ -f "$F" ] || { echo "error: $F not found" >&2; exit 1; }

if grep -q 'synaptics_ts_fw_update_work' "$F"; then
	echo "synaptics_core.c: already patched, skipping"
	exit 0
fi

# every anchor must match exactly once, otherwise the source changed: stop
expect_one() {
	local n
	n=$(grep -cP -- "$1" "$F" || true)
	if [ "$n" -ne 1 ]; then
		echo "error: anchor '$1' matched $n times (expected 1)" >&2
		exit 1
	fi
}
expect_one '^static int synaptics_ts_hw_init\(struct i2c_client \*client\)$'
expect_one '^\tret = synaptics_ts_fw_update_on_probe\(ts\);$'
expect_one 'schedule_delayed_work\(&ts->work_read_info, msecs_to_jiffies\(50\)\);'
expect_one '^void synaptics_ts_release\(struct i2c_client \*client\)$'

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---- block 1: deferred work (inserted before synaptics_ts_hw_init) ----
cat > "$TMP/work.txt" <<'EOF'
/*
 * request_firmware() called from probe runs before userspace (ueventd) exists
 * and before /vendor/firmware_mnt is mounted, so it can only be satisfied by
 * the sysfs fallback. That blocks the initcall thread for the full 60 s
 * firmware timeout, and a failed request made probe fail. When the IC already
 * runs a valid application firmware, do the FW check/update from a work item
 * instead: the wait then happens in a kworker, and ueventd serves the request
 * as soon as it is running.
 */
#define SYNAPTICS_TS_FW_WORK_RETRY_MAX 10

static void synaptics_ts_fw_update_work(struct work_struct *work);
static DECLARE_DELAYED_WORK(synaptics_ts_fw_work, synaptics_ts_fw_update_work);
static struct synaptics_ts_data *synaptics_ts_fw_ts;
static bool synaptics_ts_fw_deferred;
static int synaptics_ts_fw_work_retry;

static void synaptics_ts_fw_update_work(struct work_struct *work)
{
        struct synaptics_ts_data *ts = synaptics_ts_fw_ts;
        int ret;

        if (!ts || !ts->probe_done || ts->plat_data->shutdown_called)
                return;

        mutex_lock(&ts->modechange);

        if (ts->plat_data->power_state != SEC_INPUT_STATE_POWER_ON) {
                mutex_unlock(&ts->modechange);
                if (synaptics_ts_fw_work_retry++ < SYNAPTICS_TS_FW_WORK_RETRY_MAX) {
                        queue_delayed_work(system_unbound_wq, &synaptics_ts_fw_work,
                                        msecs_to_jiffies(1000));
                } else {
                        input_err(true, &ts->client->dev,
                                        "%s: not powered, skip deferred fw update\n", __func__);
                }
                return;
        }

        /* the irq is already requested here, unlike in the original probe path */
        disable_irq(ts->irq);
        ret = synaptics_ts_fw_update_on_probe(ts);
        enable_irq(ts->irq);

        if (ret < 0)
                input_err(true, &ts->client->dev,
                                "%s: deferred fw update failed(%d)\n", __func__, ret);
        else
                input_info(true, &ts->client->dev, "%s: deferred fw check done\n", __func__);

        mutex_unlock(&ts->modechange);
}

EOF

# ---- block 2: replacement for the synchronous call in hw_init ----
cat > "$TMP/hw.txt" <<'EOF'
        /*
         * IC already in application mode with the app fw set up: touch works
         * without the image, so defer the check/update to a work item.
         * Otherwise (bootloader mode) the image is required: flash now.
         */
        synaptics_ts_fw_deferred = false;
        if (ret >= 0 && ts->dev_mode == SYNAPTICS_TS_MODE_APPLICATION_FIRMWARE) {
                ret = 0;
                synaptics_ts_fw_ts = ts;
                synaptics_ts_fw_deferred = true;
        } else {
                ret = synaptics_ts_fw_update_on_probe(ts);
        }
EOF

# ---- block 3: queue the work at the end of probe ----
cat > "$TMP/queue.txt" <<'EOF'

        if (synaptics_ts_fw_deferred && !ts->plat_data->shutdown_called) {
                synaptics_ts_fw_work_retry = 0;
                queue_delayed_work(system_unbound_wq, &synaptics_ts_fw_work, 0);
        }
EOF

# leading 8 spaces -> tabs (kernel style); no-op if tabs survived copy/paste
for f in work hw queue; do
	unexpand -t 8 --first-only "$TMP/$f.txt" > "$TMP/$f.tab" && mv "$TMP/$f.tab" "$TMP/$f.txt"
done

# 1) hw_init: replace the synchronous call (must run BEFORE block 1 is
#    inserted: that block contains the same call and must stay untouched)
awk 'NR==FNR { b = b $0 "\n"; next }
     /^\tret = synaptics_ts_fw_update_on_probe\(ts\);$/ { printf "%s", b; next }
     { print }' "$TMP/hw.txt" "$F" > "$TMP/1" && cat "$TMP/1" > "$F"

# 2) insert the work block right before synaptics_ts_hw_init()
awk 'NR==FNR { b = b $0 "\n"; next }
     /^static int synaptics_ts_hw_init\(struct i2c_client \*client\)$/ { printf "%s", b }
     { print }' "$TMP/work.txt" "$F" > "$TMP/2" && cat "$TMP/2" > "$F"

# 3) probe: queue the deferred work right after work_read_info is scheduled
awk 'NR==FNR { b = b $0 "\n"; next }
     { print }
     /schedule_delayed_work\(&ts->work_read_info, msecs_to_jiffies\(50\)\);/ { printf "%s", b }' \
	"$TMP/queue.txt" "$F" > "$TMP/3" && cat "$TMP/3" > "$F"

# 4) synaptics_ts_release(): cancel the work before the other cancels
awk '/^void synaptics_ts_release\(struct i2c_client \*client\)$/ { inrel = 1 }
     inrel && /^\tcancel_delayed_work_sync\(&ts->work_read_info\);$/ {
             print "\tcancel_delayed_work_sync(&synaptics_ts_fw_work);"; inrel = 0 }
     { print }' "$F" > "$TMP/4" && cat "$TMP/4" > "$F"

# sanity: all four edits landed, and the work function kept its own call
for p in 'static DECLARE_DELAYED_WORK\(synaptics_ts_fw_work' \
         'synaptics_ts_fw_deferred = true;' \
         'queue_delayed_work\(system_unbound_wq, &synaptics_ts_fw_work, 0\)' \
         'cancel_delayed_work_sync\(&synaptics_ts_fw_work\)'; do
	grep -qP "$p" "$F" || { echo "error: edit not applied: $p" >&2; exit 1; }
done
n=$(grep -c 'ret = synaptics_ts_fw_update_on_probe(ts);' "$F")
[ "$n" -eq 2 ] || { echo "error: expected 2 fw_update_on_probe calls, found $n" >&2; exit 1; }
echo "synaptics_core.c patched"