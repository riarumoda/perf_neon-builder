#!/usr/bin/env bash
# Defer the stm_ts firmware check/update out of probe, so request_firmware()
# does not stall the initcall thread for the 60 s sysfs-fallback timeout.
# Edits drivers/input/sec_input/stm/stm_core.c in place using only sed/awk.
# Usage: ./apply-stm-fw-defer.sh [kernel_root]
set -euo pipefail

KROOT="${1:-.}"
F="$KROOT/drivers/input/sec_input/stm/stm_core.c"
[ -f "$F" ] || { echo "error: $F not found" >&2; exit 1; }

# already applied? do nothing
if grep -q 'stm_ts_fw_update_work' "$F"; then
	echo "stm_core.c: already patched, skipping"
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
expect_one '^static int stm_ts_hw_init\(struct stm_ts_data \*ts\)$'
expect_one '^\tret = stm_ts_fw_update_on_probe\(ts\);$'
expect_one 'schedule_delayed_work\(&ts->work_read_info, msecs_to_jiffies\(50\)\);'
expect_one '^void stm_ts_release\(struct stm_ts_data \*ts\)$'

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---- block 1: deferred work (inserted before stm_ts_hw_init) ----
cat > "$TMP/work.txt" <<'EOF'
/*
 * request_firmware() called from probe runs before userspace (ueventd) exists
 * and before /vendor/firmware_mnt is mounted, so it can only be satisfied by
 * the sysfs fallback. That blocks the initcall thread for the full 60 s
 * firmware timeout and delays "Run /init". Do the FW check/update from a work
 * item instead: the wait then happens in a kworker, and ueventd serves the
 * request as soon as it is running.
 */
#define STM_TS_FW_WORK_RETRY_MAX 10

static void stm_ts_fw_update_work(struct work_struct *work);
static DECLARE_DELAYED_WORK(stm_ts_fw_work, stm_ts_fw_update_work);
static int stm_ts_fw_work_retry;

static void stm_ts_fw_update_work(struct work_struct *work)
{
        struct stm_ts_data *ts = g_ts;
        int ret;

        if (!ts || !ts->probe_done || ts->plat_data->shutdown_called)
                return;

        mutex_lock(&ts->modechange);

        if (ts->plat_data->power_state != SEC_INPUT_STATE_POWER_ON) {
                mutex_unlock(&ts->modechange);
                if (stm_ts_fw_work_retry++ < STM_TS_FW_WORK_RETRY_MAX) {
                        queue_delayed_work(system_unbound_wq, &stm_ts_fw_work,
                                        msecs_to_jiffies(1000));
                } else {
                        input_err(true, &ts->client->dev,
                                        "%s: not powered, skip deferred fw update\n", __func__);
                }
                return;
        }

        ret = stm_ts_fw_update_on_probe(ts);
        if (ret < 0)
                input_err(true, &ts->client->dev,
                                "%s: deferred fw update failed(%d)\n", __func__, ret);
        else
                input_info(true, &ts->client->dev, "%s: deferred fw check done\n", __func__);

        mutex_unlock(&ts->modechange);
}

EOF

# ---- block 2: queue the work at the end of probe ----
cat > "$TMP/queue.txt" <<'EOF'

        if (!ts->plat_data->shutdown_called && !ts->plat_data->hw_param.checksum_result) {
                stm_ts_fw_work_retry = 0;
                queue_delayed_work(system_unbound_wq, &stm_ts_fw_work, 0);
        }
EOF

# leading 8 spaces -> tabs (kernel style); no-op if tabs survived copy/paste
for f in work queue; do
	unexpand -t 8 --first-only "$TMP/$f.txt" > "$TMP/$f.tab" && mv "$TMP/$f.tab" "$TMP/$f.txt"
done

# 1) hw_init: only flash synchronously when the IC firmware is corrupted
#    (a corrupted IC cannot report channel info); otherwise it is deferred.
#    This must run BEFORE the work block is inserted: that block contains the
#    same call and must stay untouched.
sed -i 's|^\tret = stm_ts_fw_update_on_probe(ts);$|\t/* corrupted IC: flash now, otherwise deferred to stm_ts_fw_update_work() */\n\tret = 0;\n\tif (ts->plat_data->hw_param.checksum_result)\n\t\tret = stm_ts_fw_update_on_probe(ts);|' "$F"

# 2) insert the work block right before stm_ts_hw_init()
awk 'NR==FNR { b = b $0 "\n"; next }
     /^static int stm_ts_hw_init\(struct stm_ts_data \*ts\)$/ { printf "%s", b }
     { print }' "$TMP/work.txt" "$F" > "$TMP/1" && cat "$TMP/1" > "$F"

# 3) probe: queue the deferred work right after work_read_info is scheduled
awk 'NR==FNR { b = b $0 "\n"; next }
     { print }
     /schedule_delayed_work\(&ts->work_read_info, msecs_to_jiffies\(50\)\);/ { printf "%s", b }' \
	"$TMP/queue.txt" "$F" > "$TMP/3" && cat "$TMP/3" > "$F"

# 4) stm_ts_release(): cancel the work (first work_read_info cancel after its header)
awk '/^void stm_ts_release\(struct stm_ts_data \*ts\)$/ { inrel = 1 }
     inrel && /^\tcancel_delayed_work_sync\(&ts->work_read_info\);$/ {
             print "\tcancel_delayed_work_sync(&stm_ts_fw_work);"; inrel = 0 }
     { print }' "$F" > "$TMP/4" && cat "$TMP/4" > "$F"

# sanity: all four edits landed
for p in 'static DECLARE_DELAYED_WORK\(stm_ts_fw_work' \
         'ret = 0;' \
         'queue_delayed_work\(system_unbound_wq, &stm_ts_fw_work, 0\)' \
         'cancel_delayed_work_sync\(&stm_ts_fw_work\)'; do
	grep -qP "$p" "$F" || { echo "error: edit not applied: $p" >&2; exit 1; }
done
echo "stm_core.c patched"