#!/bin/bash

echo "-- KernelSU: loading functions..."
chmod +x scripts/functions/kernelsu.sh
source scripts/functions/kernelsu.sh

case "$KERNELSU_SELECTOR" in
    baka)
        # Import hook script
        ksu_import_hook_script

        # Run KernelSU setup script
        ksu_run_setup

        # Enable the necessary KernelSU configs
        ksu_common_configs

        # Apply KSU Hooks
        ksu_apply_hooks

        # Duct tape fixes for Hooks
        ksu_fix_hooks_fouronefour
        ksu_fix_hooks_fouronenine

        # Export SELinux Symbols
        ksu_export_selinux_symbols

        # Hide custom rom
        # ksu_hide_customrom

        # Fix exposed SELinux
        # ksu_fix_exposed_selinux_linag

        # Nuke dirtyflag
        ksu_nuke_dirtyflag
        ;;
    baka-susfs)
        # Import hook script
        ksu_import_hook_script

        # Run KernelSU setup script
        ksu_run_setup

        # Enable the necessary KernelSU configs
        ksu_common_configs

        # Setup SUSFS
        ksu_setup_susfs
        
        # Duct tape fixes for SUSFS
        ksu_fix_susfs_fouronefour
        ksu_fix_susfs_fouronenine
        ksu_fix_susfs_fivepointfour

        # Apply KSU Hooks
        ksu_apply_hooks

        # Duct tape fixes for Hooks
        ksu_fix_hooks_fouronefour
        ksu_fix_hooks_fouronenine

        # Export SELinux Symbols
        ksu_export_selinux_symbols

        # Hide custom rom
        # ksu_hide_customrom

        # Fix exposed SELinux
        # ksu_fix_exposed_selinux_linag

        # Nuke dirtyflag
        ksu_nuke_dirtyflag
        ;;
    none|"")
        echo "-- KernelSU is not selected."
        ;;
    *)
        echo "- Invalid KERNELSU_SELECTOR: $KERNELSU_SELECTOR. Valid options: baka, baka-susfs, none."
        exit 1
        ;;
esac