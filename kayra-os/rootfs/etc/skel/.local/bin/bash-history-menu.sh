#!/bin/bash
# Bash history fuzzel menu: last commands first, duplicates removed, copy with wl-copy

set -euo pipefail

HISTORY_FILE="${HOME}/.bash_history"

if [ ! -f "$HISTORY_FILE" ]; then
    echo "No .bash_history found." >&2
    exit 1
fi

# Read history, reverse (newest first), remove empty lines, deduplicate keeping latest
mapfile -t LINES < <(tac "$HISTORY_FILE" 2>/dev/null | awk 'NF && !seen[$0]++')

if [ ${#LINES[@]} -eq 0 ]; then
    echo "History is empty." >&2
    exit 1
fi

# Close any existing fuzzel
pkill -x fuzzel 2>/dev/null || true

SELECTED=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --log-no-syslog --anchor=center --width=50 --match-mode=exact --prompt="Bash History: ")

[ -z "$SELECTED" ] && exit 0

# Copy selected command to clipboard
echo -n "$SELECTED" | wl-copy
