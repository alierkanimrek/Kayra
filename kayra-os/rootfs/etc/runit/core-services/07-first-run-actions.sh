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
# Add any other one-time setup tasks below this line.

#Pipewire
mkdir -p /etc/pipewire/pipewire.conf.d
ln -s /usr/share/examples/wireplumber/10-wireplumber.conf /etc/pipewire/pipewire.conf.d/
ln -s /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/
mkdir -p /etc/alsa/conf.d
ln -s /usr/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d
ln -s /usr/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d

#Cups PDF Dir
sed -i 's|^#*Out .*|Out ${HOME}/Exports/documents/|' /etc/cups/cups-pdf.conf

#Services
ln -s /etc/sv/socklog-unix /etc/runit/runsvdir/current
ln -s /etc/sv/nanoklogd /etc/runit/runsvdir/current
ln -s /etc/sv/NetworkManager /etc/runit/runsvdir/current
ln -s /etc/sv/dbus /etc/runit/runsvdir/current
ln -s /etc/sv/greetd /etc/runit/runsvdir/current
ln -s /etc/sv/polkitd /etc/runit/runsvdir/current
ln -s /etc/sv/udevd /etc/runit/runsvdir/current
ln -s /etc/sv/uuidd /etc/runit/runsvdir/current
ln -s /etc/sv/chronyd /etc/runit/runsvdir/current
ln -s /etc/sv/cupsd /etc/runit/runsvdir/current
ln -s /etc/sv/avahi-daemon /etc/runit/runsvdir/current
ln -s /etc/sv/tlp /etc/runit/runsvdir/current
ln -s /etc/sv/tlp-pd /etc/runit/runsvdir/current
ln -s /etc/sv/bluetoothd /etc/runit/runsvdir/current

# Kayra service manager (user scripts talk to it through /run/kayra-system-services)
[ -e /etc/runit/runsvdir/current/kayra-system-services ] ||
  ln -s /etc/sv/kayra-system-services /etc/runit/runsvdir/current/kayra-system-services

# Kayra power profile service (user scripts talk to it through /run/kayra-power-services)
[ -e /etc/runit/runsvdir/current/kayra-power-services ] ||
  ln -s /etc/sv/kayra-power-services /etc/runit/runsvdir/current/kayra-power-services

# Kayra group management service (user scripts talk to it through /run/kayra-group-services)
[ -e /etc/runit/runsvdir/current/kayra-group-services ] ||
  ln -s /etc/sv/kayra-group-services /etc/runit/runsvdir/current/kayra-group-services

# Kayra locale service (the language menu talks to it through /run/kayra-locale-services)
[ -e /etc/runit/runsvdir/current/kayra-locale-services ] ||
  ln -s /etc/sv/kayra-locale-services /etc/runit/runsvdir/current/kayra-locale-services

# Kayra time service (the date/time menu talks to it through /run/kayra-time-services)
[ -e /etc/runit/runsvdir/current/kayra-time-services ] ||
  ln -s /etc/sv/kayra-time-services /etc/runit/runsvdir/current/kayra-time-services

# Kayra weekly SSD TRIM scheduler (snooze based, no user interface)
[ -e /etc/runit/runsvdir/current/kayra-trim ] ||
  ln -s /etc/sv/kayra-trim /etc/runit/runsvdir/current/kayra-trim

#void-packages
mkdir -p /var/spool/void-packages
chown root:users /var/spool/void-packages
chmod 770 /var/spool/void-packages
git config --global --add safe.directory /var/spool/void-packages

#PDF Printer
# cupsd is started later by stage 2, so lpadmin cannot reach a running
# scheduler here. Seed the queue files instead; cupsd reads them when it
# starts and completes the missing printer attributes itself.
install -d -m 0755 -o root -g lp /etc/cups/ppd
install -m 0644 -o root -g lp \
    /usr/share/cups/model/CUPS-PDF_opt.ppd /etc/cups/ppd/PDF.ppd
install -m 0600 -o root -g lp \
    /usr/local/share/kayra/cups/printers.conf /etc/cups/printers.conf

# One-time group setup for the installation user (wheel, kayra-admin and the
# required_groups list). The helper is idempotent and root-only.
if [ -x /usr/local/bin/kayra-first-run-groups.sh ]; then
    /usr/local/bin/kayra-first-run-groups.sh || true
fi

touch "$MARKER"
