#!/bin/sh
# One-time first-boot fixups for the installed system.
# Skipped entirely inside the live/installer session, and only ever
# runs once on a real installation thanks to the marker file below.

MARKER="/var/lib/kayra-firstboot-done"

# We are still in the live/installer session — do nothing.
if [ -d /run/initramfs/live ]; then
    exit 0
fi

# Already ran on this installed system — do nothing.
if [ -e "$MARKER" ]; then
    exit 0
fi

mkdir -p "$(dirname "$MARKER")"

# Fix 
chown -R _greeter:_greeter /var/log/regreet
# Add any other one-time setup tasks below this line.


touch "$MARKER"
