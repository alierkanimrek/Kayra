#!/usr/bin/env bash
#
# waybar-config-builder.sh - Build the Waybar configuration file.
#
# The Waybar configuration is not written by hand. It is generated from the
# template file ~/.config/waybar/config.template, where every translatable
# text is marked with a {{PLACEHOLDER}} marker. This script replaces each
# marker with the matching text of the active language file
# (lang/current.sh, loaded through i18n.sh) and writes the result to
# ~/.config/waybar/config.jsonc.
#
# Important instructions:
#   * The script has one single job, it takes no arguments and shows no
#     menu. It is called by the scripts that change the language or the
#     theme.
#   * The template is the source of truth. A marker without a translation in
#     the language file is kept unchanged in the output and is reported in
#     the log file, so a missing translation is visible but the config stays
#     usable.
#   * The config is written to a temporary file first and moved into place
#     afterwards, so a failed run never leaves a half written config behind.
#   * Only the config file is written. The template, style.css and theme.css
#     of Waybar are never modified or removed by this script.
#   * The log messages of this script are in English, the texts of the
#     config come from the language file (i18n_WAYBAR_CONFIG).
#
# Usage: waybar-config-builder.sh
#
# Used commands: grep, sed, sort, mktemp, mv, rm, mkdir
#

set -uo pipefail

export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

source "$SCRIPT_DIR/klog.sh"
source "$SCRIPT_DIR/i18n.sh"
declare -n MSG=i18n_WAYBAR_CONFIG

CONFIG_DIR="$HOME/.config/waybar"
TEMPLATE="$CONFIG_DIR/config.template"
OUT="$CONFIG_DIR/config.jsonc"

# --- Template check ------------------------------------------------------
if [[ ! -f "$TEMPLATE" ]]; then
    log ERROR "Template not found: $TEMPLATE"
    exit 1
fi

if [[ ! -s "$TEMPLATE" ]]; then
    log ERROR "Template is empty: $TEMPLATE"
    exit 1
fi

mkdir -p "$CONFIG_DIR" || {
    log ERROR "Config directory not created: $CONFIG_DIR"
    exit 1
}

# --- Collect the markers of the template ---------------------------------
# grep prints every {{NAME}} marker of the template, sed removes the braces
# and sort removes the duplicates.
PLACEHOLDERS=$(grep -o '{{[A-Za-z0-9_]*}}' "$TEMPLATE" | sed 's/[{}]//g' | sort -u)

if [[ -z "$PLACEHOLDERS" ]]; then
    log WARN "The template has no placeholders: $TEMPLATE"
fi

# --- Map the markers to the language texts -------------------------------
# The sed script holds one "s|{{NAME}}|text|g" line per marker. It is
# applied to the template in one pass.
SED_FILE=$(mktemp "${TMPDIR:-/tmp}/waybar-i18n.sed.XXXXXX") || {
    log ERROR "Temporary file not created"
    exit 1
}

TMP_OUT=$(mktemp "${TMPDIR:-/tmp}/waybar-config.XXXXXX") || {
    log ERROR "Temporary file not created"
    rm -f "$SED_FILE"
    exit 1
}

trap 'rm -f "$SED_FILE" "$TMP_OUT"' EXIT

for ph in $PLACEHOLDERS; do
    value="${MSG[$ph]:-}"
    if [[ -z "$value" ]]; then
        # Without a translation the marker stays in the config, this is only
        # a warning so that the config is still usable.
        log WARN "No translation found for placeholder: $ph"
        continue
    fi
    # The sed script holds one line per marker, so line breaks of the text
    # are replaced by a space.
    value="${value//$'\n'/ }"
    # Escape the characters that are special in the replacement of a sed
    # command: the backslash, the ampersand and the delimiter.
    value="${value//\\/\\\\}"
    value="${value//&/\\&}"
    value="${value//|/\\|}"
    printf 's|{{%s}}|%s|g\n' "$ph" "$value" >> "$SED_FILE"
done

# --- Build the config ----------------------------------------------------
# The sed script replaces every known marker with its text. Markers without
# a translation are kept as they are.
{
    printf '// Waybar config - built by waybar-config-builder.sh\n'
    printf '// Generated file, do not edit. Edit the template instead.\n'
    printf '\n'
} > "$TMP_OUT"

sed -f "$SED_FILE" "$TEMPLATE" >> "$TMP_OUT"

# --- Check the result ----------------------------------------------------
if [[ ! -s "$TMP_OUT" ]]; then
    log ERROR "The generated config is empty"
    exit 1
fi

# Markers that are still in the output have no translation.
LEFT_OVER=$(grep -o '{{[A-Za-z0-9_]*}}' "$TMP_OUT" | sort -u | tr '\n' ' ')
if [[ -n "$LEFT_OVER" ]]; then
    log WARN "Untranslated markers in the config: $LEFT_OVER"
fi

mv "$TMP_OUT" "$OUT" || {
    log ERROR "Config not created: $OUT"
    exit 1
}

log INFO "Waybar config created: $OUT"

exit 0
