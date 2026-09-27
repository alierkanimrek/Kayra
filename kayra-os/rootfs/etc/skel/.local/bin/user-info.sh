#!/usr/bin/env bash
#
# Kayra OS — Waybar "User Info" module
# ------------------------------------
# Generates data for a Waybar custom module expecting return-type=json.
# Output: {"text": "...", "tooltip": "...", "class": "...", "alt": "..."}
#
# Dependencies: jq, coreutils (getent, id)

set -euo pipefail

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_USER_INFO

# Module icon (user symbol)
# NOTE: LC_ALL=C.UTF-8 is required. The \U escape sequence, if the
# runtime locale is not UTF-8 (e.g., sway/waybar started in minimal env),
# silently fails to produce correct UTF-8 bytes and prints literal "\uXXXX".
# These lines eliminate that risk.
ICON_USER=$(LC_ALL=C.UTF-8 printf '%b' '\U000E853')
# Supervisor (wheel group member) badge
ICON_SUPERVISOR=$(LC_ALL=C.UTF-8 printf '%b' '\U000E8D3')

USERNAME="${USER:-$(whoami)}"

# Extract full name from GECOS field (comma-separated first field = full name)
FULLNAME=$(getent passwd "$USERNAME" | awk -F: '{print $5}' | cut -d, -f1)
if [ -z "$FULLNAME" ]; then
    FULLNAME="$USERNAME"
fi

# All groups user is member of (primary + secondary), alphabetically sorted
GROUPS_LIST=$(id -nG "$USERNAME" | tr ' ' '\n' | sort)

IS_SUPERVISOR=false
if printf '%s\n' "$GROUPS_LIST" | grep -qx "wheel"; then
    IS_SUPERVISOR=true
fi

# Tooltip (supports Pango markup)
TOOLTIP="<b>${FULLNAME}</b>  (${USERNAME})"
if $IS_SUPERVISOR; then
    TOOLTIP="${TOOLTIP}  ${ICON_SUPERVISOR}"
fi

GROUPS_FORMATTED=$(printf '%s\n' "$GROUPS_LIST" | sed 's/^/  • /')
TOOLTIP="${TOOLTIP}

<b>${MSG[LABEL_GROUPS]}</b>
${GROUPS_FORMATTED}"

CLASS="user-info"
if $IS_SUPERVISOR; then
    CLASS="user-info supervisor"
fi

# -c (compact) is required: waybar's return-type=json modules read output
# line by line. jq's default pretty-print produces multiline JSON (first line
# is just "{"), causing waybar to error "Missing '}' or object member name".
jq -nc \
  --arg text "$ICON_USER" \
  --arg tooltip "$TOOLTIP" \
  --arg class "$CLASS" \
  '{text: $text, tooltip: $tooltip, class: $class, alt: $class}'
