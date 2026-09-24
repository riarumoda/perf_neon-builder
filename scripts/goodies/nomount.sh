#!/bin/bash

case "$NOMOUNT_SELECTOR" in
    nomount)
        # Download nomount
        nomount_download

        # Setup nomount
        nomount_setup
        ;;
    nomount-edge)
        # Setup nomount
        nomount_setup_bleeding_edge
        ;;
    none|"")
        echo "-- NoMount is not selected."
        ;;
    *)
        echo "- Invalid NOMOUNT_SELECTOR: $NOMOUNT_SELECTOR. Valid options: nomount, none."
        exit 1
        ;;
esac