#!/bin/bash
#
# Fuzzel menu helper script for launching user menu commands.
# Thin wrapper around user-menu.sh (icons and commands live in that script).

set -euo pipefail

exec "$HOME/.local/bin/user-menu.sh" "$@"
