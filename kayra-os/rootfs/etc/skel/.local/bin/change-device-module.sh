#!/usr/bin/env bash
#
# change-device-module.sh - Changes the kernel module of a device.
#
# Called from show-device-mods.sh when an unused module is selected:
#   change-device-module.sh <device-key> <module>
#   e.g. change-device-module.sh pci:0000:00:02.0 vboxvideo
#
# NOTE: This script does not perform any operation yet. It only validates
# its arguments and logs the request. The actual module change (unbind the
# current driver, bind the new one) will be implemented later.
#
export LC_ALL=C.UTF-8
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"

# shellcheck source=/dev/null
[ -f "$SCRIPT_DIR/klog.sh" ] && . "$SCRIPT_DIR/klog.sh"
if ! command -v log >/dev/null 2>&1; then
    log() { printf '%s\n' "$*"; }
fi

DEVICE_KEY="${1:-}"
MODULE="${2:-}"

if [ -z "$DEVICE_KEY" ] || [ -z "$MODULE" ]; then
    echo "Usage: change-device-module.sh <device-key> <module>" >&2
    exit 1
fi

# TODO: implement the module change here
#   - unbind the current driver from the device
#   - load the requested module (modprobe)
#   - bind the new driver to the device

log INFO "Change module requested: device=$DEVICE_KEY module=$MODULE (not implemented yet)"

exit 0
