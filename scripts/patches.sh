#!/bin/bash

# Patcher helper - 1.8
_patch_api_url() {
    sed -E 's#^https://github\.com/([^/]+)/([^/]+)/commit/([0-9a-fA-F]+)\.patch$#https://api.github.com/repos/\1/\2/commits/\3#' <<< "$1"
}

# Patch applier - 1.8
apply_patches() {
    for patch_url in "$@"; do
        echo "-- Applying patch: $(basename "$patch_url")"
        patch_url="$(_patch_api_url "$patch_url")"
        rm -f /tmp/temp_patch.patch
        if [[ -z "${GITHUB_TOKEN:-}" ]]; then
            curl -sL --fail --retry 3 -H "Accept: application/vnd.github.patch" "$patch_url" -o /tmp/temp_patch.patch || true
        else
            curl -sL --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github.patch" "$patch_url" -o /tmp/temp_patch.patch || true
        fi
        if [ -s /tmp/temp_patch.patch ]; then
            patch -s -p1 --fuzz=5 < /tmp/temp_patch.patch || { echo "Fatal: Failed to apply patch!"; exit 1; }
        else
            echo "Fatal: Failed to download patch from $patch_url"
            exit 1
        fi
    done
}

# Commit reverter - 1.8
revert_commit() {
    for patch_url in "$@"; do
        echo "-- Reverting commit: $(basename "$patch_url")"
        patch_url="$(_patch_api_url "$patch_url")"
        rm -f /tmp/temp_revert.patch
        if [[ -z "${GITHUB_TOKEN:-}" ]]; then
            curl -sL --fail --retry 3 -H "Accept: application/vnd.github.patch" "$patch_url" -o /tmp/temp_revert.patch || true
        else
            curl -sL --fail --retry 3 -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github.patch" "$patch_url" -o /tmp/temp_revert.patch || true
        fi
        if [ -s /tmp/temp_revert.patch ]; then
            patch -R -s -p1 < /tmp/temp_revert.patch || { echo "Fatal: Failed to revert commit!"; exit 1; }
        else
            echo "Fatal: Failed to download revert patch from $patch_url"
            exit 1
        fi
    done
}

# Patcher - 2.0
echo " -- Applying device specific patches..."
source "scripts/patches/$DEVICE-$OS.sh" || { echo "-- ERROR: could not load device patches"; exit 1; }
