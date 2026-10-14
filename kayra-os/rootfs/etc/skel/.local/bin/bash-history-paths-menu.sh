#!/bin/bash
# Bash history paths menu: extract file/path arguments from commands

set -euo pipefail

HISTORY_FILE="${HOME}/.bash_history"

if [ ! -f "$HISTORY_FILE" ]; then
    echo "No .bash_history found." >&2
    exit 1
fi

# Reverse history (newest first), skip empty lines, deduplicate paths globally
mapfile -t PATHS < <(tac "$HISTORY_FILE" 2>/dev/null | awk '
NF {
    for (i = 2; i <= NF; i++) {
        token = $i
        gsub(/^["'\''"]+|["'\''"]+$/, "", token)
        if (token ~ /\// && token !~ /^-/ && !(token in seen)) {
            seen[token] = 1
            print token
        }
    }
}')

if [ ${#PATHS[@]} -eq 0 ]; then
    echo "No file/path arguments found in history." >&2
    exit 1
fi

pkill -x fuzzel 2>/dev/null || true

SELECTED=$(printf '%s\n' "${PATHS[@]}" | fuzzel --dmenu --log-no-syslog --anchor=center --width=50 --match-mode=exact --prompt="History Paths: ")

[ -z "$SELECTED" ] && exit 0

echo -n "$SELECTED" | wl-copy
