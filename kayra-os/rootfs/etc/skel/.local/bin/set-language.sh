#!/usr/bin/env bash
#
# set-language.sh - Switch the system language.
#
# The argument is the locale code of the language, taken from the "locale -av"
# output (e.g. "tr_TR.utf8"). A short language code (e.g. "tr") is accepted
# as well.
#
# The locale code is mapped here:
#   - the first two characters select the language data file (lang/<code>.sh),
#     which is linked as lang/current.sh and is used by i18n.sh
#   - the locale string (e.g. "tr_TR.UTF-8") is written to ~/.profile
#
# When there is no language data file in lang/ for the locale, lang/en.sh is
# used for the interface. The locale in ~/.profile is still changed to the
# selected locale and the user is informed about it.
#
# Usage: set-language.sh <locale-code>
#   e.g. set-language.sh tr_TR.utf8
#        set-language.sh tr
#
# Dependencies:
#   - libnotify   (for notify-send, xbps-install -S libnotify)
#
# Used commands: ln, sed, grep, awk, tr, swaymsg, bash, notify-send
#
set -uo pipefail
export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_SET_LANGUAGE

source "$SCRIPT_DIR/klog.sh"
source "$SCRIPT_DIR/notify.sh"

# Icon shown on the notification (Material Symbols codepoint).
ICON_LANGUAGE=$(printf '%b' '\U000F799')   # language
NOTIFY_ICON="$ICON_LANGUAGE"

LANG_DATA_DIR="$SCRIPT_DIR/lang"
LANG_LINK="$LANG_DATA_DIR/current.sh"
LANG_FALLBACK="$LANG_DATA_DIR/en.sh"
PROFILE_FILE="$HOME/.profile"
WAYBAR_BUILDER="$SCRIPT_DIR/waybar-config-builder.sh"

# Locale strings of the short language codes.
declare -A LOCALE_MAP=(
    ["en"]="en_US.UTF-8"
    ["tr"]="tr_TR.UTF-8"
)

ARG="${1:-}"
if [[ -z "$ARG" ]]; then
    log ERROR "No locale code given"
    echo "Usage: $(basename "$0") <locale-code>" >&2
    exit 1
fi

# --- Map the argument to a language code and a locale string -------------
LANG_CODE=""
LOCALE_STRING=""

if [[ "$ARG" == *_* || "$ARG" == *.* ]]; then
    # Locale code form, e.g. "tr_TR.utf8"
    LOCALE_BASE="${ARG%%.*}"
    LANG_CODE="${LOCALE_BASE%%_*}"
    REGION_PART="${LOCALE_BASE#*_}"
    if [[ "$REGION_PART" == "$LOCALE_BASE" ]]; then
        LOCALE_STRING="${LANG_CODE,,}.UTF-8"
    else
        LOCALE_STRING="${LANG_CODE,,}_${REGION_PART^^}.UTF-8"
    fi
else
    # Short language code form, e.g. "tr"
    LANG_CODE="$ARG"
    LOCALE_STRING="${LOCALE_MAP[$LANG_CODE]:-${LANG_CODE,,}_${LANG_CODE^^}.UTF-8}"
fi

[[ -z "$LANG_CODE" ]] && LANG_CODE="en"

log INFO "Language requested: code=$LANG_CODE locale=$LOCALE_STRING"

# --- Language data file -------------------------------------------------
# The language data is missing when there is no file for the language code.
# In that case lang/en.sh is used for the interface.
LANG_DATA_FILE="$LANG_DATA_DIR/$LANG_CODE.sh"
LANG_DATA_FALLBACK=0

if [[ ! -f "$LANG_DATA_FILE" ]]; then
    LANG_DATA_FALLBACK=1
    LANG_DATA_FILE="$LANG_FALLBACK"
    log WARN "No language data file for $LANG_CODE, using en.sh for the interface"
fi

if [[ ! -f "$LANG_DATA_FILE" ]]; then
    log ERROR "Language data file is missing: $LANG_DATA_FILE"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_FAILED]}" LANG="$LANG_CODE")"
    exit 1
fi

# --- Apply the language data --------------------------------------------
ln -sf "$(basename "$LANG_DATA_FILE")" "$LANG_LINK"
log INFO "Language data set to $(basename "$LANG_DATA_FILE")"

# --- Update ~/.profile --------------------------------------------------
if [[ -f "$PROFILE_FILE" ]]; then
    if grep -q "^export LANG=" "$PROFILE_FILE"; then
        sed -i "s|^export LANG=.*|export LANG=$LOCALE_STRING|" "$PROFILE_FILE"
    else
        printf 'export LANG=%s\n' "$LOCALE_STRING" >> "$PROFILE_FILE"
    fi

    if grep -q "^export LC_ALL=" "$PROFILE_FILE"; then
        sed -i "s|^export LC_ALL=.*|export LC_ALL=$LOCALE_STRING|" "$PROFILE_FILE"
    else
        printf 'export LC_ALL=%s\n' "$LOCALE_STRING" >> "$PROFILE_FILE"
    fi
    log INFO "Updated $PROFILE_FILE with $LOCALE_STRING"
else
    {
        printf '# User profile - language and locale settings\n'
        printf 'export LANG=%s\n' "$LOCALE_STRING"
        printf 'export LC_ALL=%s\n' "$LOCALE_STRING"
    } > "$PROFILE_FILE"
    log INFO "Created $PROFILE_FILE with $LOCALE_STRING"
fi

# --- Update the waybar config -------------------------------------------
if [[ -f "$WAYBAR_BUILDER" ]]; then
    bash "$WAYBAR_BUILDER" >/dev/null 2>&1
    log INFO "Waybar config rebuilt"
fi

# Signal waybar to reload the configuration (do not fail outside sway)
swaymsg reload >/dev/null 2>&1 || true

# --- Notification --------------------------------------------------------
# The messages are loaded again, so they are in the new language.
source "$SCRIPT_DIR/i18n.sh"

if (( LANG_DATA_FALLBACK )); then
    log INFO "Language set to $LANG_CODE, the interface uses the English data"
    notify_warn "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_NO_LANG_DATA]}" LANG="$LANG_CODE" LOCALE="$LOCALE_STRING")"
else
    log INFO "Language set to $LANG_CODE"
    notify_ok "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_CHANGED]}" LANG="$LANG_CODE" LOCALE="$LOCALE_STRING")"
fi

exit 0
