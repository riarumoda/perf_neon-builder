#!/bin/bash
# Thx to YUPIK/utkusthr/Frax3r/salvo from unica/osm0sis
# Lil bit modded by riarumoda
cat <<'EOF' > "output/META-INF/com/google/android/update-binary"
#!/sbin/sh
# Shell Script EDIFY Replacement: Recovery Flashable Zip
# osm0sis @ XDAdevelopers
# salvogiangri @ XDAdevelopers
# Frax3r @ XDAdevelopers
OUTFD=/proc/self/fd/$2;
ZIPFILE="$3";
TMPDIR="/tmp/kernelimages";
package_extract_dir() {
  local entry outfile;
  for entry in $(unzip -l "$ZIPFILE" 2>/dev/null | tail -n+4 | grep -v '/$' | grep -o " $1.*$" | cut -c2-); do
    outfile="$(echo "$entry" | sed "s|${1}|${2}|")";
    mkdir -p "$(dirname "$outfile")";
    unzip -o "$ZIPFILE" "$entry" -p > "$outfile";
  done;
}
ui_print() {
  while [ "$1" ]; do
    echo -e "ui_print $1
      ui_print" >> $OUTFD;
    shift;
  done;
}
write_raw_image() { dd if="$1" of="$2"; }
set_progress() { echo "set_progress $1" >> $OUTFD; }
ui_print " ";
ui_print "********************************************";
ui_print "          Generic Kernel Installer          ";
ui_print "                          by Frax3r         ";
ui_print "********************************************";
ui_print "Borrowed for Perf Neon Builder by Riaru Moda";
ui_print " ";
set_progress 0
if ! getprop ro.boot.bootloader | grep -qE "A736|A528|M526"; then
  ui_print "- Device is not supported, aborting...";
  exit 1;
fi
ui_print "- Extracting images";
mkdir -p $TMPDIR;
package_extract_dir "images" "$TMPDIR/";
set_progress 20;
ui_print "- Flashing boot.img...";
write_raw_image "$TMPDIR/boot.img" "/dev/block/bootdevice/by-name/boot";
set_progress 40;
ui_print "- Flashing dtbo.img...";
write_raw_image "$TMPDIR/dtbo.img" "/dev/block/bootdevice/by-name/dtbo";
set_progress 60;
ui_print "- Cleaning up...";
rm -rf "$TMPDIR";
set_progress 100;
ui_print " ";
ui_print "********************************************";
ui_print " Flashing completed.                        ";
ui_print "     Make sure to check the UN1CA project.  ";
ui_print "********************************************";
ui_print "Also check out Perf Neon Builder too!";
ui_print " ";
EOF