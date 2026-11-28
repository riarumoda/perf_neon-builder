#!/bin/bash

# Droidspaces kernel integration.
#   non-GKI (below 5.4): non-GKI fixes, full config set, systemd backports.
#   GKI (5.4 and newer): kABI patches, ABI-safe config set, 5.4 VFS backports.
#
# Knobs (device conf or environment):
#   DROIDSPACES_BACKPORTS=true|false
#   DROIDSPACES_GKI_KABI_VARIANT=1_2_3|3_4_5|6_7_8
#   DROIDSPACES_BACKPORTS_REF=main
#   DROIDSPACES_BACKPORTS_RAW=<url>
#   DROIDSPACES_OSS_REF=main
#   DROIDSPACES_OSS_PATCHES=<url>

DROIDSPACES_BACKPORTS="${DROIDSPACES_BACKPORTS:-true}"
DROIDSPACES_GKI_KABI_VARIANT="${DROIDSPACES_GKI_KABI_VARIANT:-6_7_8}"
DROIDSPACES_BACKPORTS_REF="${DROIDSPACES_BACKPORTS_REF:-main}"
DROIDSPACES_OSS_REF="${DROIDSPACES_OSS_REF:-main}"

DS_OSS_PATCHES="${DROIDSPACES_OSS_PATCHES:-https://raw.githubusercontent.com/ravindu644/Droidspaces-OSS/${DROIDSPACES_OSS_REF}/Documentation/resources/kernel-patches}"
DS_BACKPORTS_RAW="${DROIDSPACES_BACKPORTS_RAW:-https://raw.githubusercontent.com/Droidspaces/droidspaces-backports/${DROIDSPACES_BACKPORTS_REF}}"
export DROIDSPACES_XT_QTAGUID="${DROIDSPACES_XT_QTAGUID:-$DS_OSS_PATCHES/non-GKI/01.fix_kernel_panic_in_xt_qtaguid.patch}"
export DROIDSPACES_CGROUP="${DROIDSPACES_CGROUP:-$DS_OSS_PATCHES/non-GKI/02.fix_restore%20cgroup%20file%20prefix%20handling%20.patch}"
DS_START_DIR="$PWD"
DS_TMP="$(mktemp -d "${TMPDIR:-/tmp}/droidspaces.XXXXXX")" || { echo "-- Fatal: Droidspaces could not create a temporary directory"; exit 1; }
DS_BACKPORT_CACHE="$DS_TMP/backports"
DS_PATCH_APPLIED=0
DS_PATCH_SKIPPED=0
DS_PATCH_FAILED=0
DS_PATCH_SEQ=0
DS_GKI_KABI_OK="false"
DS_GKI_MQUEUE_OK="false"

ds_log() { echo "-- Droidspaces: $*"; }
ds_warn() { echo "-- Droidspaces: WARNING: $*"; }
ds_err() { echo "-- Droidspaces: ERROR: $*"; }

ds_cleanup() {
    cd "$DS_START_DIR" 2>/dev/null || true
    [ -n "$DS_TMP" ] && rm -rf "$DS_TMP"
}

ds_die() {
    ds_err "$*"
    ds_cleanup
    exit 1
}

ds_fetch() {
    local url="$1" out="$2"
    if command -v curl >/dev/null 2>&1; then
        if [ -n "$GITHUB_TOKEN" ]; then
            curl -fsSL --retry 3 --retry-all-errors -H "Authorization: Bearer $GITHUB_TOKEN" -o "$out" "$url"
        else
            curl -fsSL --retry 3 --retry-all-errors -o "$out" "$url"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [ -n "$GITHUB_TOKEN" ]; then
            wget -q --header="Authorization: Bearer $GITHUB_TOKEN" -O "$out" "$url"
        else
            wget -qO "$out" "$url"
        fi
    else
        return 1
    fi
}

ds_src_has() {
    grep -qE -- "$2" "$1" 2>/dev/null
}

ds_feature() {
    case "$1" in
        pidfd_open)              ds_src_has kernel/pid.c 'SYSCALL_DEFINE2\(pidfd_open' ;;
        waitid_P_PIDFD)          ds_src_has include/uapi/linux/wait.h 'P_PIDFD' ;;
        SO_BINDTOIFINDEX)        ds_src_has include/uapi/asm-generic/socket.h 'SO_BINDTOIFINDEX' ;;
        SO_PEERGROUPS)           ds_src_has include/uapi/asm-generic/socket.h 'SO_PEERGROUPS' ;;
        statx)                   ds_src_has fs/stat.c 'SYSCALL_DEFINE5\(statx' ;;
        STATX_MNT_ID)            ds_src_has include/uapi/linux/stat.h 'STATX_MNT_ID' ;;
        STATX_ATTR_MOUNT_ROOT)   ds_src_has include/uapi/linux/stat.h 'STATX_ATTR_MOUNT_ROOT' ;;
        utimensat_AT_EMPTY_PATH) ds_src_has fs/utimes.c 'AT_EMPTY_PATH' ;;
        faccessat2)              ds_src_has include/uapi/asm-generic/unistd.h '__NR_faccessat2' ;;
        close_range)             ds_src_has include/uapi/asm-generic/unistd.h '__NR_close_range' ;;
        nexthop_RTNLGRP)         ds_src_has include/uapi/linux/rtnetlink.h 'RTNLGRP_NEXTHOP' ;;
        NS_GET_NSTYPE)           ds_src_has include/uapi/linux/nsfs.h 'NS_GET_NSTYPE' ;;
        NS_GET_OWNER_UID)        ds_src_has include/uapi/linux/nsfs.h 'NS_GET_OWNER_UID' ;;
        TIOCGPTPEER)             ds_src_has include/uapi/asm-generic/ioctls.h 'TIOCGPTPEER' ;;
        cgroup_events_frozen)    ds_src_has kernel/cgroup/cgroup.c 'frozen (%d|0)' || ds_src_has kernel/cgroup.c 'frozen (%d|0)' ;;
        *) return 1 ;;
    esac
}

ds_patch_targets() {
    awk '
        /^--- a\// {
            p = substr($0, 7)
            sub(/\t.*/, "", p)
            print p
        }
        /^\+\+\+ b\// {
            p = substr($0, 7)
            sub(/\t.*/, "", p)
            print p
        }
    ' "$1" | sort -u
}

ds_patch_snapshot() {
    local file="$1" dir="$2" target
    mkdir -p "$dir/files"
    : >"$dir/existing"
    while IFS= read -r target; do
        [ -f "$target" ] || continue
        mkdir -p "$dir/files/$(dirname "$target")"
        cp -a "$target" "$dir/files/$target"
        printf '%s\n' "$target" >>"$dir/existing"
    done < <(ds_patch_targets "$file")
}

ds_patch_rollback() {
    local file="$1" dir="$2" target
    while IFS= read -r target; do
        rm -f "$target.rej" "$target.orig"
        if [ -f "$dir/files/$target" ]; then
            cp -a "$dir/files/$target" "$target"
        else
            rm -f "$target"
        fi
    done < <(ds_patch_targets "$file")
}

ds_patch_clean_rejects() {
    local file="$1" target
    while IFS= read -r target; do
        rm -f "$target.rej" "$target.orig"
    done < <(ds_patch_targets "$file")
}

ds_patch() {
    local file="$1" label="$2" required="${3:-false}" fuzz="${4:-5}" quiet="${5:-false}"
    local snap

    if [ ! -f "$file" ]; then
        ds_warn "$label: patch file not found ($file)."
        DS_PATCH_FAILED=$((DS_PATCH_FAILED + 1))
        return 1
    fi

    if patch -p1 --fuzz="$fuzz" -s -f -R --dry-run <"$file" >/dev/null 2>&1; then
        ds_patch_clean_rejects "$file"
        ds_log "$label: already applied, skipping."
        DS_PATCH_SKIPPED=$((DS_PATCH_SKIPPED + 1))
        return 0
    fi

    if ! patch -p1 --fuzz="$fuzz" -s -f --dry-run <"$file" >/dev/null 2>&1; then
        ds_patch_clean_rejects "$file"
        if [ "$required" = "true" ]; then
            ds_err "$label: patch does not apply."
        elif [ "$quiet" != "true" ]; then
            ds_warn "$label: patch does not apply, skipping."
        fi
        DS_PATCH_FAILED=$((DS_PATCH_FAILED + 1))
        return 1
    fi

    snap="$DS_TMP/patch-snap/$DS_PATCH_SEQ"
    DS_PATCH_SEQ=$((DS_PATCH_SEQ + 1))
    ds_patch_snapshot "$file" "$snap"

    if patch -p1 --fuzz="$fuzz" -s -f <"$file" >/dev/null 2>&1; then
        ds_patch_clean_rejects "$file"
        rm -rf "$snap"
        ds_log "$label: applied."
        DS_PATCH_APPLIED=$((DS_PATCH_APPLIED + 1))
        return 0
    fi

    ds_patch_rollback "$file" "$snap"
    rm -rf "$snap"
    ds_warn "$label: patch failed, changes reverted and .rej files removed."
    DS_PATCH_FAILED=$((DS_PATCH_FAILED + 1))
    return 1
}

# Some kernel headers (fs/mount.h among them) have no include guard, so a file
# that includes one twice fails to compile. Keep only the first occurrence.
ds_dedupe_include() {
    local f="$1" hdr="$2" n

    [ -f "$f" ] || return 0
    n=$(grep -cxF "#include \"$hdr\"" "$f")
    [ "$n" -gt 1 ] || return 0
    awk -v line="#include \"$hdr\"" '
        $0 == line { if (seen++) next }
        { print }
    ' "$f" >"$f.ds-tmp" && mv "$f.ds-tmp" "$f"
    ds_log "removed duplicate #include \"$hdr\" from $f."
}

ds_config() {
    local opt="${1#CONFIG_}" val="${2:-y}"

    sed -i -E \
        -e "/^CONFIG_${opt}=/d" \
        -e "/^# CONFIG_${opt} is not set[[:space:]]*$/d" \
        "$FINAL_DEFCONFIG" || ds_die "could not update $FINAL_DEFCONFIG"

    if [ "$val" = "n" ]; then
        echo "# CONFIG_${opt} is not set" >>"$FINAL_DEFCONFIG"
    else
        echo "CONFIG_${opt}=${val}" >>"$FINAL_DEFCONFIG"
    fi
}

ds_config_group() {
    local title="$1"
    shift
    ds_log "  $title"
    local opt
    for opt in "$@"; do
        ds_config "$opt" "y"
    done
}

# --- GKI ------------------------------------------------------------------

ds_gki_sysvipc_safe() {
    if ((DS_KMAJ > 6 || (DS_KMAJ == 6 && DS_KMIN >= 12))); then
        ds_src_has include/linux/sched.h '__kabi_ignored'
    else
        ds_src_has include/linux/sched.h 'ANDROID_KABI_USE\([0-9]+, struct sysv_sem' ||
            ds_src_has include/linux/sched.h '_ANDROID_KABI_REPLACE\(.*sysv_shm'
    fi
}

ds_gki_mqueue_safe() {
    ds_src_has include/linux/sched/user.h 'ANDROID_KABI_USE\([0-9]+, unsigned long mq_bytes\)'
}

# Some 5.4 vendor trees (Samsung sm7325 among them) have the two KABI reserve
# slots but no ANDROID_OEM_DATA_ARRAY line, so the upstream patch cannot match.
ds_gki_mqueue_fallback() {
    local f="include/linux/sched/user.h" bak="$f.ds-bak"

    ds_gki_mqueue_safe && return 0
    grep -q 'unsigned long mq_bytes;' "$f" 2>/dev/null || return 1
    grep -q 'ANDROID_OEM_DATA_ARRAY' "$f" 2>/dev/null && return 1
    grep -q 'ANDROID_KABI_RESERVE(1);' "$f" 2>/dev/null || return 1
    grep -q 'ANDROID_KABI_RESERVE(2);' "$f" 2>/dev/null || return 1

    cp -a "$f" "$bak" || return 1
    sed -i 's|^\([[:space:]]*\)unsigned long mq_bytes;|\1//unsigned long mq_bytes;|' "$f"

    awk '
        /struct ratelimit_state ratelimit;/ { in_user = 1 }
        in_user && /ANDROID_KABI_RESERVE\(1\);/ {
            print "#if defined(CONFIG_POSIX_MQUEUE)"
            print "\tANDROID_KABI_USE(1, unsigned long mq_bytes);"
            print "\tANDROID_KABI_RESERVE(2);"
            print "#else"
            print
            next
        }
        in_user && /ANDROID_KABI_RESERVE\(2\);/ {
            print
            print "#endif"
            in_user = 0
            next
        }
        { print }
    ' "$f" >"$f.ds-tmp" && mv "$f.ds-tmp" "$f" || {
        rm -f "$f.ds-tmp"
        mv "$bak" "$f"
        return 1
    }

    if ds_gki_mqueue_safe; then
        rm -f "$bak"
        return 0
    fi
    mv "$bak" "$f"
    return 1
}

ds_apply_gki_patches() {
    local base="$DS_TMP/gki" url out v variants tried failed_before

    mkdir -p "$base"

    if ((DS_KMAJ > 6 || (DS_KMAJ == 6 && DS_KMIN >= 12))); then
        ds_log "applying the 6.12+ SYSVIPC kABI patch..."
        url="$DS_OSS_PATCHES/GKI/kernel-6.12/001.GKI-6.12-or-above-fix_sysvipc_kabi.patch"
        out="$base/001.gki-6.12-sysvipc.patch"
        if ds_fetch "$url" "$out" && [ -s "$out" ] &&
            ds_patch "$out" "GKI: SYSVIPC kABI (6.12+)" "false" 2; then
            DS_GKI_KABI_OK="true"
        elif ds_gki_sysvipc_safe; then
            ds_log "GKI: SYSVIPC kABI padding already present."
            DS_GKI_KABI_OK="true"
        fi
    else
        ds_log "applying the SYSVIPC kABI patch (below 6.12)..."
        variants=("$DROIDSPACES_GKI_KABI_VARIANT" "6_7_8" "3_4_5" "1_2_3")
        tried=" "
        for v in "${variants[@]}"; do
            case " $tried " in
                *" $v "*) continue ;;
            esac
            tried="$tried$v "
            case "$v" in
                1_2_3 | 3_4_5 | 6_7_8) ;;
                *)
                    ds_warn "unknown DROIDSPACES_GKI_KABI_VARIANT '$v'"
                    continue
                    ;;
            esac
            url="$DS_OSS_PATCHES/GKI/below-kernel-6.12/001.GKI-below-6.12-fix_sysvipc_kabi_${v}.patch"
            out="$base/001.sysvipc-${v}.patch"
            failed_before=$DS_PATCH_FAILED
            if ds_fetch "$url" "$out" && [ -s "$out" ] &&
                ds_patch "$out" "GKI: SYSVIPC kABI ($v)" "false" 2; then
                DS_GKI_KABI_OK="true"
                break
            fi
            DS_PATCH_FAILED=$failed_before
        done
        if [ "$DS_GKI_KABI_OK" != "true" ] && ds_gki_sysvipc_safe; then
            ds_log "GKI: SYSVIPC kABI padding already present."
            DS_GKI_KABI_OK="true"
        fi
    fi

    if [ "$DS_GKI_KABI_OK" != "true" ]; then
        if grep -qE '^CONFIG_SYSVIPC=y' "$FINAL_DEFCONFIG"; then
            ds_warn "CONFIG_SYSVIPC is enabled but its kABI patch is missing. This can bootloop the device; disable CONFIG_SYSVIPC or apply the patch by hand."
        fi
        ds_warn "leaving CONFIG_SYSVIPC and CONFIG_IPC_NS alone so the device stays bootable."
    fi

    if ((DS_KMAJ < 5 || (DS_KMAJ == 5 && DS_KMIN <= 10))); then
        ds_log "applying the POSIX_MQUEUE kABI patch (5.10 or lower)..."
        url="$DS_OSS_PATCHES/GKI/below-kernel-6.12/002.5.10_or_lower_use_android_abi_padding_for_posix_mqueue.patch"
        out="$base/002.posix-mqueue.patch"
        failed_before=$DS_PATCH_FAILED
        if ds_fetch "$url" "$out" && [ -s "$out" ] &&
            ds_patch "$out" "GKI: POSIX_MQUEUE kABI (5.10 or lower)" "false" 2 "true"; then
            DS_GKI_MQUEUE_OK="true"
        elif ds_gki_mqueue_safe; then
            ds_log "GKI: POSIX_MQUEUE kABI padding already present."
            DS_GKI_MQUEUE_OK="true"
        elif ds_gki_mqueue_fallback; then
            ds_log "GKI: POSIX_MQUEUE kABI padding adapted for this tree."
            DS_GKI_MQUEUE_OK="true"
        fi
        if [ "$DS_GKI_MQUEUE_OK" != "true" ]; then
            DS_PATCH_FAILED=$((failed_before + 1))
            ds_warn "leaving CONFIG_POSIX_MQUEUE alone; its kABI patch did not apply."
        else
            DS_PATCH_FAILED=$failed_before
        fi
    else
        DS_GKI_MQUEUE_OK="true"
    fi
}

ds_apply_gki_configs() {
    ds_log "applying GKI (ABI-safe) configs..."

    local opt
    for opt in \
        CONFIG_DEVTMPFS \
        CONFIG_PID_NS \
        CONFIG_NETFILTER_XT_MATCH_ADDRTYPE \
        CONFIG_USER_NS \
        CONFIG_IP6_NF_NAT \
        CONFIG_IP6_NF_TARGET_MASQUERADE \
        CONFIG_MACVLAN \
        CONFIG_IP_NF_TARGET_REJECT \
        CONFIG_IP6_NF_TARGET_REJECT \
        CONFIG_NETFILTER_XT_TARGET_LOG \
        CONFIG_NETFILTER_XT_MATCH_RECENT \
        CONFIG_IP_SET \
        CONFIG_IP_SET_HASH_IP \
        CONFIG_IP_SET_HASH_NET \
        CONFIG_NETFILTER_XT_SET \
        CONFIG_TMPFS_POSIX_ACL \
        CONFIG_TMPFS_XATTR; do
        ds_config "$opt" "y"
    done

    if [ "$DS_GKI_KABI_OK" = "true" ]; then
        ds_config CONFIG_SYSVIPC "y"
        ds_config CONFIG_IPC_NS "y"
    fi
    if [ "$DS_GKI_MQUEUE_OK" = "true" ]; then
        ds_config CONFIG_POSIX_MQUEUE "y"
    fi

    if grep -qE '^CONFIG_CFS_BANDWIDTH=y|^CONFIG_CGROUP_PIDS=y' "$FINAL_DEFCONFIG"; then
        ds_warn "CONFIG_CFS_BANDWIDTH/CONFIG_CGROUP_PIDS are enabled. They break the GKI kABI unless every vendor module is rebuilt and flashed together; --cpus and --pids-limit stay off otherwise."
    fi
}

# --- non-GKI --------------------------------------------------------------

ds_apply_nongki_patches() {
    local xt="$DS_TMP/01.xt_qtaguid.patch"
    local cg="$DS_TMP/02.cgroup.patch"

    if [ -f net/netfilter/xt_qtaguid.c ]; then
        ds_log "applying the xt_qtaguid panic fix..."
        ds_fetch "$DROIDSPACES_XT_QTAGUID" "$xt" || ds_die "could not download the xt_qtaguid patch"
        [ -s "$xt" ] || ds_die "the xt_qtaguid patch download is empty"
        ds_patch "$xt" "xt_qtaguid panic fix" "true" 5 ||
            ds_die "failed to apply the Droidspaces xt_qtaguid patch"
    else
        ds_log "xt_qtaguid not present in this tree, skipping its patch."
    fi

    if [ -f kernel/cgroup/cgroup.c ]; then
        ds_log "applying the cgroup file prefix fix..."
        ds_fetch "$DROIDSPACES_CGROUP" "$cg" || ds_die "could not download the cgroup patch"
        [ -s "$cg" ] || ds_die "the cgroup patch download is empty"
        ds_patch "$cg" "cgroup file prefix fix" "true" 5 ||
            ds_die "failed to apply the Droidspaces cgroup patch"
    else
        ds_warn "kernel/cgroup/cgroup.c not found, skipping the cgroup patch."
    fi
}

ds_apply_nongki_configs() {
    ds_log "applying non-GKI configs..."

    ds_config_group "IPC mechanisms" \
        CONFIG_SYSCTL CONFIG_SYSVIPC CONFIG_POSIX_MQUEUE
    ds_config_group "Core namespaces" \
        CONFIG_NAMESPACES CONFIG_PID_NS CONFIG_UTS_NS CONFIG_IPC_NS
    ds_config_group "Seccomp" \
        CONFIG_SECCOMP CONFIG_SECCOMP_FILTER
    ds_config_group "Control groups" \
        CONFIG_CGROUPS CONFIG_CGROUP_DEVICE CONFIG_CGROUP_SCHED \
        CONFIG_FAIR_GROUP_SCHED CONFIG_CGROUP_FREEZER CONFIG_CGROUP_NET_PRIO
    ds_config_group "Resource limits" \
        CONFIG_MEMCG CONFIG_MEMCG_SWAP CONFIG_MEMCG_SWAP_ENABLED \
        CONFIG_CFS_BANDWIDTH CONFIG_CGROUP_PIDS CONFIG_CGROUP_CPUACCT
    ds_config_group "Device filesystem" \
        CONFIG_DEVTMPFS
    ds_config_group "Overlay filesystem (volatile mode)" \
        CONFIG_OVERLAY_FS
    ds_config_group "tmpfs xattr and POSIX ACL (NixOS)" \
        CONFIG_TMPFS_POSIX_ACL CONFIG_TMPFS_XATTR
    ds_config_group "Firmware loading" \
        CONFIG_FW_LOADER CONFIG_FW_LOADER_USER_HELPER CONFIG_FW_LOADER_COMPRESS
    ds_config_group "Network isolation (NAT/none)" \
        CONFIG_NET_NS CONFIG_VETH CONFIG_BRIDGE CONFIG_NETFILTER \
        CONFIG_BRIDGE_NETFILTER CONFIG_NETFILTER_ADVANCED CONFIG_NF_CONNTRACK \
        CONFIG_IP_NF_IPTABLES CONFIG_IP_NF_FILTER CONFIG_NF_NAT CONFIG_NF_TABLES \
        CONFIG_IP_NF_TARGET_MASQUERADE CONFIG_NETFILTER_XT_TARGET_MASQUERADE \
        CONFIG_NETFILTER_XT_TARGET_TCPMSS CONFIG_NETFILTER_XT_MATCH_ADDRTYPE \
        CONFIG_NF_CONNTRACK_NETLINK CONFIG_NF_NAT_REDIRECT \
        CONFIG_IP_ADVANCED_ROUTER CONFIG_IP_MULTIPLE_TABLES
    ds_config_group "IPv4 legacy compat" \
        CONFIG_NF_CONNTRACK_IPV4 CONFIG_NF_NAT_IPV4 CONFIG_IP_NF_NAT
    ds_config_group "IPv6 NAT (NAT66)" \
        CONFIG_IPV6 CONFIG_IPV6_MULTIPLE_TABLES CONFIG_IPV6_SUBTREES \
        CONFIG_IP6_NF_IPTABLES CONFIG_IP6_NF_FILTER CONFIG_IP6_NF_MANGLE \
        CONFIG_IP6_NF_NAT CONFIG_IP6_NF_TARGET_MASQUERADE
    ds_config_group "IPv6 legacy compat" \
        CONFIG_NF_CONNTRACK_IPV6 CONFIG_NF_NAT_IPV6
    ds_config_group "Macvlan mode" \
        CONFIG_MACVLAN
    ds_config_group "Sparse image containers (loop + ext4)" \
        CONFIG_BLK_DEV_LOOP CONFIG_EXT4_FS
    ds_config_group "FUSE and TUN inside containers" \
        CONFIG_FUSE_FS CONFIG_TUN
    ds_config_group "Firewall (UFW/Fail2Ban)" \
        CONFIG_NETFILTER_XT_MATCH_COMMENT CONFIG_NETFILTER_XT_MATCH_STATE \
        CONFIG_NETFILTER_XT_MATCH_CONNTRACK CONFIG_NETFILTER_XT_MATCH_MULTIPORT \
        CONFIG_NETFILTER_XT_MATCH_HL CONFIG_NETFILTER_XT_TARGET_REJECT \
        CONFIG_IP_NF_TARGET_REJECT CONFIG_IP6_NF_TARGET_REJECT \
        CONFIG_NETFILTER_XT_TARGET_LOG CONFIG_IP_NF_TARGET_ULOG \
        CONFIG_NETFILTER_XT_MATCH_RECENT CONFIG_NETFILTER_XT_MATCH_LIMIT \
        CONFIG_NETFILTER_XT_MATCH_HASHLIMIT CONFIG_NETFILTER_XT_MATCH_OWNER \
        CONFIG_NETFILTER_XT_MATCH_PKTTYPE CONFIG_NETFILTER_XT_MATCH_MARK \
        CONFIG_NETFILTER_XT_TARGET_MARK CONFIG_IP_SET CONFIG_IP_SET_HASH_IP \
        CONFIG_IP_SET_HASH_NET CONFIG_NETFILTER_XT_SET \
        CONFIG_NETFILTER_NETLINK_QUEUE CONFIG_NETFILTER_NETLINK_LOG \
        CONFIG_NETFILTER_XT_TARGET_NFLOG
    ds_config_group "User namespaces (Docker, sandboxing)" \
        CONFIG_USER_NS

    ds_config CONFIG_ANDROID_PARANOID_NETWORK "n"
    ds_log "  disabled ANDROID_PARANOID_NETWORK (container internet)"
}

# --- systemd 258-262 backports --------------------------------------------

# ds_backport_file <repo path>
# Prints the cached patch path, downloading it on first use.
ds_backport_file() {
    local rel="$1" file="$DS_BACKPORT_CACHE/${rel//\//_}"

    if [ ! -s "$file" ]; then
        if ! ds_fetch "$DS_BACKPORTS_RAW/$rel" "$file" || [ ! -s "$file" ]; then
            return 1
        fi
    fi
    printf '%s\n' "$file"
}

ds_backport_patch() {
    local rel="$1" label="$2" feature="${3:-}" file

    if [ -n "$feature" ] && ds_feature "$feature"; then
        ds_log "$label: $feature already present, skipping."
        DS_PATCH_SKIPPED=$((DS_PATCH_SKIPPED + 1))
        return 0
    fi

    file=$(ds_backport_file "$rel") || {
        ds_warn "$label: could not download $rel."
        DS_PATCH_FAILED=$((DS_PATCH_FAILED + 1))
        return 1
    }
    ds_patch "$file" "$label" "false" 2
}

# Each entry is "repo path|label|feature probe".
ds_backport_list() {
    local entry rel label feature
    for entry in "$@"; do
        IFS='|' read -r rel label feature <<<"$entry"
        ds_backport_patch "$rel" "$label" "$feature"
    done
}

# ds_backport_try <label> <repo path>...
# Applies the first variant that works and counts it once.
ds_backport_try() {
    local label="$1" rel
    shift
    for rel in "$@"; do
        if ds_backport_patch "$rel" "$label"; then
            return 0
        fi
        DS_PATCH_FAILED=$((DS_PATCH_FAILED - 1))
    done
    DS_PATCH_FAILED=$((DS_PATCH_FAILED + 1))
    ds_warn "$label: no variant applied."
    return 0
}

# ds_ksu_cut_block <file> <literal text> <block file> <strip blanks 0|1|2>
# Cuts the #if CONFIG_KSU ... #endif block above the line holding the text.
ds_ksu_cut_block() {
    local f="$1" text="$2" blk="$3" strip="$4"

    awk -v blk="$blk" -v text="$text" -v strip="$strip" '
        { line[NR] = $0 }
        END {
            target = 0
            for (i = 1; i <= NR; i++)
                if (index(line[i], text)) { target = i; break }
            if (target == 0) exit 1
            j = target - 1
            while (j > 0 && line[j] ~ /^[[:space:]]*$/) j--
            if (j == 0 || line[j] !~ /^#endif/) exit 1
            depth = 0
            start = 0
            for (k = j; k >= 1; k--) {
                if (line[k] ~ /^#endif/) depth++
                else if (line[k] ~ /^#if/) depth--
                if (depth == 0) { start = k; break }
            }
            if (start == 0) exit 1
            ksu = 0
            for (k = start; k <= j; k++)
                if (line[k] ~ /CONFIG_KSU/) ksu = 1
            if (!ksu) exit 1
            if (strip >= 1) {
                if (start > 1 && line[start - 1] ~ /^[[:space:]]*$/) start--
                else if (j < NR && line[j + 1] ~ /^[[:space:]]*$/) j++
            }
            if (strip >= 2) {
                while (start > 1 && line[start - 1] ~ /^[[:space:]]*$/) start--
                while (j < NR && line[j + 1] ~ /^[[:space:]]*$/) j++
            }
            for (k = start; k <= j; k++) print line[k] > blk
            close(blk)
            for (i = 1; i <= NR; i++)
                if (i < start || i > j) print line[i]
        }
    ' "$f" >"$f.ds-tmp" && mv "$f.ds-tmp" "$f"
}

ds_ksu_insert_block() {
    local f="$1" text="$2" blk="$3"

    [ -s "$blk" ] || return 0
    awk -v blk="$blk" -v text="$text" '
        !done && index($0, text) {
            while ((getline l < blk) > 0) print l
            close(blk)
            done = 1
        }
        { print }
    ' "$f" >"$f.ds-tmp" && mv "$f.ds-tmp" "$f"
}

# KernelSU's manual hook block sits between out: and SYSCALL_DEFINE3(faccessat),
# inside the 5.4 faccessat2 hunk, so the patch cannot cross it. Move the block
# aside, apply, and put it back.
ds_patch_around_ksu_block() {
    local file="$1" label="$2"
    local f="fs/open.c" bak="$DS_TMP/ksu-open.c.bak"
    local blk_a="$DS_TMP/ksu-decl.blk" blk_b="$DS_TMP/ksu-call.blk"
    local before=$DS_PATCH_FAILED

    if ds_patch "$file" "$label" "false" 2 "true"; then
        return 0
    fi
    DS_PATCH_FAILED=$before

    if ! grep -q 'CONFIG_KSU' "$f" 2>/dev/null; then
        DS_PATCH_FAILED=$((before + 1))
        ds_warn "$label: patch does not apply, skipping."
        return 1
    fi

    cp -a "$f" "$bak" || {
        DS_PATCH_FAILED=$((before + 1))
        ds_warn "$label: could not back up $f."
        return 1
    }

    if ! ds_ksu_cut_block "$f" 'SYSCALL_DEFINE3(faccessat,' "$blk_a" 1 ||
        ! ds_ksu_cut_block "$f" 'return do_faccessat(dfd, filename, mode);' "$blk_b" 2; then
        cp -a "$bak" "$f"
        rm -f "$f.ds-tmp" "$blk_a" "$blk_b"
        DS_PATCH_FAILED=$((before + 1))
        ds_warn "$label: patch does not apply, skipping."
        return 1
    fi

    if ! ds_patch "$file" "$label" "false" 2 "true"; then
        cp -a "$bak" "$f"
        rm -f "$blk_a" "$blk_b"
        DS_PATCH_FAILED=$((before + 1))
        ds_warn "$label: patch does not apply, skipping."
        return 1
    fi

    ds_ksu_insert_block "$f" 'SYSCALL_DEFINE3(faccessat,' "$blk_a"
    ds_ksu_insert_block "$f" 'return do_faccessat(dfd, filename, mode, 0);' "$blk_b"

    if [ "$(grep -c 'ksu_handle_faccessat' "$f")" -ge 2 ] &&
        grep -q 'SYSCALL_DEFINE4(faccessat2' "$f"; then
        rm -f "$bak" "$blk_a" "$blk_b"
        ds_log "$label: applied around the KernelSU hook block."
        return 0
    fi

    cp -a "$bak" "$f"
    rm -f "$blk_a" "$blk_b"
    ds_warn "$label: could not restore the KernelSU block; fs/open.c rolled back."
    DS_PATCH_FAILED=$((before + 1))
    return 1
}

ds_backport_faccessat2() {
    local rel="$1" label="$2" file

    if ds_feature faccessat2; then
        ds_log "$label: faccessat2 already present, skipping."
        DS_PATCH_SKIPPED=$((DS_PATCH_SKIPPED + 1))
        return 0
    fi

    file=$(ds_backport_file "$rel") || {
        ds_warn "$label: could not download $rel."
        DS_PATCH_FAILED=$((DS_PATCH_FAILED + 1))
        return 1
    }
    ds_patch_around_ksu_block "$file" "$label"
}

# 4.14 and 4.19 have no frozen 0 patch upstream; add the seven lines in place
# when the tree lacks the cgroup v2 freezer. Without them systemd never sees a
# scope unit become empty and every stop waits for its timeout.
ds_cgroup_frozen_fix() {
    local f bak

    ds_feature cgroup_events_frozen && return 0

    for f in kernel/cgroup/cgroup.c kernel/cgroup.c; do
        [ -f "$f" ] || continue
        grep -q 'static int cgroup_events_show' "$f" || continue
        bak="$f.ds-bak"
        cp -a "$f" "$bak" || return 1
        awk '
            /static int cgroup_events_show\(/ { infn = 1 }
            infn && !done && /^[[:space:]]*return 0;/ {
                print "\tseq_puts(seq, \"frozen 0\\n\");"
                done = 1
            }
            { print }
            infn && done { infn = 0 }
        ' "$f" >"$f.ds-tmp" && mv "$f.ds-tmp" "$f" || {
            rm -f "$f.ds-tmp"
            mv "$bak" "$f"
            return 1
        }
        if ds_feature cgroup_events_frozen; then
            rm -f "$bak"
            ds_log "cgroup: added the frozen key to cgroup.events."
            return 0
        fi
        mv "$bak" "$f"
        return 1
    done
    return 1
}

ds_pidfd_backport_414() {
    local rel
    ds_log "applying the 4.14 pidfd backport..."
    for rel in \
        "pidfd-backport-4.14/0001-BACKPORT-signal-add-pidfd_send_signal-syscall.patch" \
        "pidfd-backport-4.14/0002-UPSTREAM-signal-don-t-silently-convert-SI_USER-signa.patch" \
        "pidfd-backport-4.14/0003-UPSTREAM-signal-use-fdget-since-we-don-t-allow-O_PAT.patch" \
        "pidfd-backport-4.14/0004-BACKPORT-clone-add-CLONE_PIDFD.patch" \
        "pidfd-backport-4.14/0005-BACKPORT-signal-support-CLONE_PIDFD-with-pidfd_send_.patch" \
        "pidfd-backport-4.14/0006-UPSTREAM-fork-do-not-release-lock-that-wasn-t-taken.patch" \
        "pidfd-backport-4.14/0007-UPSTREAM-signal-improve-comments.patch" \
        "pidfd-backport-4.14/0008-UPSTREAM-pidfd-add-polling-support.patch" \
        "pidfd-backport-4.14/0009-BACKPORT-pid-add-pidfd_open.patch" \
        "pidfd-backport-4.14/0010-BACKPORT-arch-wire-up-pidfd_open.patch" \
        "pidfd-backport-4.14/0011-UPSTREAM-pidfd-fix-a-poll-race-when-setting-exit_sta.patch" \
        "pidfd-backport-4.14/0012-BACKPORT-arch-add-pidfd-and-io_uring-syscalls-everyw.patch"; do
        ds_backport_patch "$rel" "pidfd 4.14: ${rel##*/}"
    done
}

ds_pidfd_backport_49() {
    local b="pidfd-backport-4.9"
    local rel

    ds_log "applying the 4.9 pidfd backport..."
    for rel in \
        "$b/0001-BACKPORT-signal-add-pidfd_send_signal-syscall.patch" \
        "$b/0002-UPSTREAM-signal-don-t-silently-convert-SI_USER-signa.patch" \
        "$b/0003-UPSTREAM-signal-use-fdget-since-we-don-t-allow-O_PAT.patch"; do
        ds_backport_patch "$rel" "pidfd 4.9: ${rel##*/}"
    done

    ds_backport_try "pidfd 4.9: 0004" \
        "$b/0004-BACKPORT-clone-add-CLONE_PIDFD.patch" \
        "$b/alt-4.9.1xx/0004-BACKPORT-clone-add-CLONE_PIDFD.patch"

    ds_backport_patch "$b/0005-BACKPORT-signal-support-CLONE_PIDFD-with-pidfd_send_.patch" "pidfd 4.9: 0005"

    ds_backport_try "pidfd 4.9: 0006" \
        "$b/0006-BACKPORT-fork-do-not-release-lock-that-wasn-t-taken.patch" \
        "$b/alt-4.9.1xx/0006-BACKPORT-fork-do-not-release-lock-that-wasn-t-taken.patch"

    for rel in \
        "$b/0007-UPSTREAM-signal-improve-comments.patch" \
        "$b/0008-UPSTREAM-pidfd-add-polling-support.patch" \
        "$b/0009-BACKPORT-pid-add-pidfd_open.patch" \
        "$b/0010-BACKPORT-arch-wire-up-pidfd_open.patch" \
        "$b/0011-UPSTREAM-pidfd-fix-a-poll-race-when-setting-exit_sta.patch" \
        "$b/0012-BACKPORT-arch-add-pidfd-and-io_uring-syscalls-everyw.patch"; do
        ds_backport_patch "$rel" "pidfd 4.9: ${rel##*/}"
    done

    ds_log "pidfd 4.9: skipping the 32-bit ARM calls.S fix (arm64 build)."
}

ds_backports_49() {
    if ! ds_feature pidfd_open; then
        ds_pidfd_backport_49
    else
        ds_log "pidfd already present, skipping the 4.9 pidfd backport."
    fi

    ds_log "applying the 4.9 systemd backport series..."
    ds_backport_list \
        "kernel-4.9-series/0001-pidfd-add-P_PIDFD-to-waitid.patch|4.9: waitid(P_PIDFD)|waitid_P_PIDFD" \
        "kernel-4.9-series/0002-fork-don-t-check-parent_tidptr-with-CLONE_PIDFD.patch|4.9: parent_tidptr fix|" \
        "kernel-4.9-series/0003-net-introduce-SO_BINDTOIFINDEX-sockopt.patch|4.9: SO_BINDTOIFINDEX|SO_BINDTOIFINDEX"

    # 4.9 never had statx; if it is present only the v5.8 mount fields are missing.
    if ds_feature statx; then
        ds_backport_list \
            "kernel-4.14-series/0004-statx-add-mount-ID.patch|4.9: statx mount ID|STATX_MNT_ID" \
            "kernel-4.14-series/0005-statx-add-mount_root.patch|4.9: statx mount root|STATX_ATTR_MOUNT_ROOT"
    else
        ds_backport_patch "kernel-4.9-series/0004-statx-add-a-reduced-statx-syscall-with-mount-ID-and-.patch" "4.9: statx with mount ID"
    fi

    ds_backport_list \
        "kernel-4.9-series/0005-utimensat-AT_EMPTY_PATH-support.patch|4.9: utimensat AT_EMPTY_PATH|utimensat_AT_EMPTY_PATH"

    ds_backport_faccessat2 \
        "kernel-4.9-series/0006-vfs-add-faccessat2-syscall.patch" "4.9: faccessat2"

    ds_backport_list \
        "kernel-4.9-series/0007-open-add-close_range.patch|4.9: close_range|close_range" \
        "kernel-4.9-series/0008-arch-wire-up-close_range.patch|4.9: close_range wiring|close_range" \
        "kernel-4.9-series/0009-rtnetlink-accept-nexthop-message-types-and-multicast.patch|4.9: nexthop rtnetlink|nexthop_RTNLGRP" \
        "kernel-4.9-series/0015-cgroup-report-frozen-0-in-cgroup.events-on-kernels-w.patch|4.9: cgroup frozen events|cgroup_events_frozen" \
        "kernel-4.9-series/0011-net-introduce-SO_PEERGROUPS-getsockopt.patch|4.9: SO_PEERGROUPS|SO_PEERGROUPS" \
        "kernel-4.9-series/0012-nsfs-Add-an-ioctl-to-return-the-namespace-type.patch|4.9: nsfs namespace type ioctl|NS_GET_NSTYPE" \
        "kernel-4.9-series/0013-nsfs-Add-an-ioctl-to-return-owner-UID-of-a-userns.patch|4.9: nsfs owner UID ioctl|NS_GET_OWNER_UID" \
        "kernel-4.9-series/0014-tty-add-TIOCGPTPEER-ioctl.patch|4.9: TIOCGPTPEER|TIOCGPTPEER"

    ds_cgroup_frozen_fix || ds_log "4.9: cgroup.events has no frozen key; login session stops may hang."

    ds_log "4.9: skipping the x86/32-bit ARM syscall table patch (arm64 build)."
}

ds_backports_414() {
    if ! ds_feature pidfd_open; then
        ds_pidfd_backport_414
    else
        ds_log "pidfd already present, skipping the 4.14 pidfd backport."
    fi

    ds_log "applying the 4.14 systemd backport series..."
    ds_backport_list \
        "kernel-4.14-series/0001-pidfd-add-P_PIDFD-to-waitid.patch|4.14: waitid(P_PIDFD)|waitid_P_PIDFD" \
        "kernel-4.14-series/0002-fork-don-t-check-parent_tidptr-with-CLONE_PIDFD.patch|4.14: parent_tidptr fix|" \
        "kernel-4.14-series/0003-net-introduce-SO_BINDTOIFINDEX-sockopt.patch|4.14: SO_BINDTOIFINDEX|SO_BINDTOIFINDEX" \
        "kernel-4.14-series/0004-statx-add-mount-ID.patch|4.14: statx mount ID|STATX_MNT_ID" \
        "kernel-4.14-series/0005-statx-add-mount_root.patch|4.14: statx mount root|STATX_ATTR_MOUNT_ROOT" \
        "kernel-4.14-series/0006-utimensat-AT_EMPTY_PATH-support.patch|4.14: utimensat AT_EMPTY_PATH|utimensat_AT_EMPTY_PATH"

    ds_backport_faccessat2 \
        "kernel-4.14-series/0007-vfs-add-faccessat2-syscall.patch" "4.14: faccessat2"

    ds_backport_list \
        "kernel-4.14-series/0008-open-add-close_range.patch|4.14: close_range|close_range" \
        "kernel-4.14-series/0009-arch-wire-up-close_range.patch|4.14: close_range wiring|close_range" \
        "kernel-4.14-series/0010-rtnetlink-accept-nexthop-message-types-and-multicast.patch|4.14: nexthop rtnetlink|nexthop_RTNLGRP"

    ds_cgroup_frozen_fix || ds_log "4.14: cgroup.events has no frozen key; login session stops may hang."
}

ds_backports_419() {
    ds_log "applying the 4.19 systemd backport series..."
    ds_backport_list \
        "kernel-4.19-series/0001-pidfd-add-P_PIDFD-to-waitid.patch|4.19: waitid(P_PIDFD)|waitid_P_PIDFD" \
        "kernel-4.19-series/0002-net-introduce-SO_BINDTOIFINDEX-sockopt.patch|4.19: SO_BINDTOIFINDEX|SO_BINDTOIFINDEX" \
        "kernel-4.19-series/0003-statx-add-mount-ID.patch|4.19: statx mount ID|STATX_MNT_ID" \
        "kernel-4.19-series/0004-statx-add-mount_root.patch|4.19: statx mount root|STATX_ATTR_MOUNT_ROOT" \
        "kernel-4.19-series/0005-utimensat-AT_EMPTY_PATH-support.patch|4.19: utimensat AT_EMPTY_PATH|utimensat_AT_EMPTY_PATH"

    ds_backport_faccessat2 \
        "kernel-4.19-series/0006-vfs-add-faccessat2-syscall.patch" "4.19: faccessat2"

    ds_backport_list \
        "kernel-4.19-series/0007-open-add-close_range.patch|4.19: close_range|close_range" \
        "kernel-4.19-series/0008-arch-wire-up-close_range.patch|4.19: close_range wiring|close_range" \
        "kernel-4.19-series/0009-rtnetlink-accept-nexthop-message-types-and-multicast.patch|4.19: nexthop rtnetlink|nexthop_RTNLGRP"

    ds_cgroup_frozen_fix || ds_log "4.19: cgroup.events has no frozen key; login session stops may hang."

    ds_log "4.19: skipping the x86 syscall table patch (arm64 build)."
}

ds_backports_54() {
    ds_log "applying the 5.4 systemd 260+ backport series..."
    ds_backport_list \
        "kernel-5.4-series/0001-statx-add-mount-ID.patch|5.4: statx mount ID|STATX_MNT_ID" \
        "kernel-5.4-series/0002-statx-add-mount_root.patch|5.4: statx mount root|STATX_ATTR_MOUNT_ROOT" \
        "kernel-5.4-series/0003-utimensat-AT_EMPTY_PATH-support.patch|5.4: utimensat AT_EMPTY_PATH|utimensat_AT_EMPTY_PATH"

    ds_backport_faccessat2 \
        "kernel-5.4-series/0004-vfs-add-faccessat2-syscall.patch" "5.4: faccessat2"

    ds_backport_list \
        "kernel-5.4-series/0005-open-add-close_range.patch|5.4: close_range|close_range" \
        "kernel-5.4-series/0006-arch-wire-up-close_range.patch|5.4: close_range wiring|close_range"

    ds_log "5.4: skipping the x86 syscall table patch (arm64 build)."
}

ds_apply_backports() {
    if [ "$DROIDSPACES_BACKPORTS" != "true" ]; then
        ds_log "systemd backports disabled by DROIDSPACES_BACKPORTS."
        return 0
    fi

    if ((DS_KMAJ > 5 || (DS_KMAJ == 5 && DS_KMIN > 4))); then
        ds_log "kernel $DS_KVER needs no systemd backports."
        return 0
    fi

    if ((DS_KMAJ < 4 || (DS_KMAJ == 4 && DS_KMIN < 9))); then
        ds_warn "kernel $DS_KVER is older than 4.9; the systemd 258+ backports do not cover it."
        return 0
    fi

    mkdir -p "$DS_BACKPORT_CACHE"
    ds_log "fetching systemd backports from $DS_BACKPORTS_RAW..."

    case "$DS_KMAJ.$DS_KMIN" in
        4.9) ds_backports_49 ;;
        4.14) ds_backports_414 ;;
        4.19) ds_backports_419 ;;
        5.4) ds_backports_54 ;;
        *) ds_log "no backport series for $DS_KVER." ;;
    esac
}

# --- main -----------------------------------------------------------------

cd "$KERNEL_DIR" || ds_die "could not enter $KERNEL_DIR"

if [ -z "$FINAL_DEFCONFIG" ] || [ ! -f "$FINAL_DEFCONFIG" ]; then
    ds_die "final defconfig not found (FINAL_DEFCONFIG='$FINAL_DEFCONFIG')"
fi

DS_KVER="${KERNEL_VERSION:-}"
if [ -z "$DS_KVER" ]; then
    DS_KVER=$(awk -F'[[:space:]]*=[[:space:]]*' \
        '/^VERSION/{v=$2} /^PATCHLEVEL/{print v"."$2; exit}' Makefile)
fi
DS_KMAJ="${DS_KVER%%.*}"
DS_KMIN="${DS_KVER#*.}"
DS_KMIN="${DS_KMIN%%.*}"
case "${DS_KMAJ}${DS_KMIN}" in
    '' | *[!0-9]*)
        ds_warn "could not parse the kernel version (got '$DS_KVER'); assuming 4.14."
        DS_KVER="4.14"
        DS_KMAJ=4
        DS_KMIN=14
        ;;
esac

if ((DS_KMAJ > 5 || (DS_KMAJ == 5 && DS_KMIN >= 4))); then
    DS_GKI="true"
else
    DS_GKI="false"
fi

ds_log "kernel $DS_KVER ($([ "$DS_GKI" = "true" ] && echo "GKI/5.x" || echo "non-GKI"))"

if [ "$DS_GKI" = "true" ]; then
    ds_apply_gki_patches
    ds_apply_gki_configs
else
    ds_apply_nongki_patches
    ds_apply_nongki_configs
fi

ds_apply_backports

# The statx mount-ID backport adds fs/mount.h to fs/stat.c, but the KernelSU
# inline hook already did. fs/mount.h has no include guard, so the second copy
# redefines its structs.
ds_dedupe_include fs/stat.c mount.h

ds_log "patches: $DS_PATCH_APPLIED applied, $DS_PATCH_SKIPPED skipped, $DS_PATCH_FAILED not applied."
if [ "$DS_PATCH_FAILED" -gt 0 ]; then
    ds_warn "some optional patches did not apply; see the lines above."
fi

ds_cleanup
