#!/bin/sh
# One-time first-boot fixups for the installed system.
# Skipped entirely inside the live/installer session, and only ever
# runs once on a real installation thanks to the marker file below.

MARKER="/var/lib/kayra-firstboot-done"

# We are still in the live/installer session — do nothing.
if [ -d /run/initramfs/live ]; then
    return 0
fi

# Already ran on this installed system — do nothing.
if [ -e "$MARKER" ]; then
    return 0
fi

mkdir -p "$(dirname "$MARKER")"

# Regreet 
chown -R _greeter:_greeter /var/log/regreet
chown -R _greeter:_greeter /var/lib/regreet
chmod +x /etc/greetd/wayland-sessions/sway.wrapper
# Add any other one-time setup tasks below this line.

#Pipewire
mkdir -p /etc/pipewire/pipewire.conf.d
ln -s /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
ln -s /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
mkdir -p /etc/alsa/conf.d
ln -s /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d
ln -s /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d

touch "$MARKER"
