#!/usr/bin/env bash
#
# kayra-language-settings.sh - Display the Kayra languages and apply the selection.
#
# The languages come from /usr/local/share/kayra/lang/languages.tsv. Entries
# without a lang/<code>.sh are shown as system-only languages: the interface
# stays in English while the system locale and gettext messages use the entry.
# The current interface language is the explicit lang setting; when lang is
# empty it is derived from locale/LANG (automatic mode). A language whose system
# locale is not generated is marked, but it can still be selected.
#
# Administrators also get an "Add Language..." entry. It lists the UTF-8
# locales from /etc/default/libc-locales that are not in the registry yet and
# appends a validated entry through kayra-locale-services.
#
# The selected code is handed over to kayra-set-language.sh, which writes the
# settings and generates the locale when the user is a kayra-admin member.
#
# Usage: kayra-language-settings.sh [fuzzel parameters...]
#
# Dependencies:
#   - fuzzel      (xbps-install -S fuzzel)
#   - libnotify   (for notify-send, xbps-install -S libnotify)
#
# Used commands: fuzzel, pkill, awk, grep, sed, tr, head, settings-conf.sh,
#                locale-client.sh, set-language.sh
#
set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_LANGUAGE_SETTINGS

source /usr/local/lib/kayra/admin.sh
source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/settings-conf.sh
source /usr/local/lib/kayra/locale-client.sh

LANG_DIR="/usr/local/share/kayra/lang"
REGISTRY="$LANG_DIR/languages.tsv"
SET_LANGUAGE="/usr/local/bin/kayra-set-language.sh"

ICON_CURRENT=$(printf '%b' '\U0000E837')   # radio_button_checked
ICON_OTHER=$(printf '%b' '\U0000E836')     # radio_button_unchecked
ICON_ADD=$(printf '%b' '\U0000E145')       # add

if [[ ! -r "$REGISTRY" ]]; then
    log ERROR "Language registry is missing: $REGISTRY"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_LANGUAGES]}"
    exit 1
fi

declare -a CODES=() LOCALES=() NAMES=() HAS_UI=()
while IFS=$'\t' read -r code locale language native name_en; do
    case "$code" in ''|'#'*) continue ;; esac
    CODES+=("$code")
    LOCALES+=("$locale")
    NAMES+=("$native")
    if [[ -f "$LANG_DIR/$code.sh" ]]; then
        HAS_UI+=("1")
    else
        HAS_UI+=("0")
    fi
done < "$REGISTRY"

if (( ${#CODES[@]} == 0 )) && ! is_kayra_admin; then
    log ERROR "No usable language entries found"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_LANGUAGES]}"
    exit 1
fi

# Current interface language: explicit lang, or derived from locale/LANG.
current_code=$(conf_get lang | head -n1)
if [[ -z "$current_code" ]]; then
    current_locale=$(conf_get locale | head -n1)
    if [[ -z "$current_locale" ]]; then
        current_locale=$(awk -F= '/^LANG=/{print $2; exit}' /etc/locale.conf 2>/dev/null |
            sed 's/^"//;s/"$//')
    fi
    [[ -n "$current_locale" ]] || current_locale=${LANG:-}
    derived=${current_locale%%_*}
    if [[ -n "$derived" && -f "$LANG_DIR/$derived.sh" ]]; then
        current_code=$derived
    else
        current_code=en
    fi
fi

missing_text="${MSG[MSG_SYSTEM_DATA_MISSING]:-system data not generated}"
missing_ui_text="${MSG[SYSTEM_ONLY]:-no Kayra translation}"

declare -a LINES=()
for i in "${!CODES[@]}"; do
    label=${NAMES[$i]}
    if [[ "${HAS_UI[$i]}" == "0" ]]; then
        label="$label ($missing_ui_text)"
    fi
    if ! locale_generated "${LOCALES[$i]}"; then
        label="$label ($missing_text)"
    fi
    if [[ "${CODES[$i]}" == "$current_code" ]]; then
        LINES+=("$ICON_CURRENT $label")
    else
        LINES+=("$ICON_OTHER $label")
    fi
done

# Admin-only entry to add a system locale that is not in the registry yet.
if is_kayra_admin; then
    LINES+=("$ICON_ADD ${MSG[ADD_LANGUAGE]:-Add Language...}")
    CODES+=("__add__")
fi

# Close any existing fuzzel processes
pkill -x fuzzel 2>/dev/null || true

# Window width of the longest menu entry (icon counted as 3 characters)
MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

SELECTED=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right --log-no-syslog \
    --minimal-lines --lines="${#LINES[@]}" --width="$MAX_WIDTH" --hide-prompt "$@") || true

[[ -z "$SELECTED" ]] && exit 0

SEL_INDEX=$(printf '%s\n' "${LINES[@]}" | awk -v sel="$SELECTED" '$0 == sel { print NR - 1; exit }')
[[ -z "$SEL_INDEX" ]] && exit 0

SELECTED_CODE="${CODES[$SEL_INDEX]}"
[[ -z "$SELECTED_CODE" ]] && exit 0

if [[ "$SELECTED_CODE" == "__add__" ]]; then
    if [[ -x /usr/local/bin/kayra-language-add.sh ]]; then
        /usr/local/bin/kayra-language-add.sh
    else
        log ERROR "Language add helper is missing"
        notify_error "${MSG[NOTIFY_TITLE]}" \
            "${MSG[MSG_ADD_UNAVAILABLE]:-The language add helper is missing.}"
    fi
    exit 0
fi

# An explicit choice that is already active does not need another write.
explicit_code=$(conf_get lang | head -n1)
if [[ -n "$explicit_code" && "$SELECTED_CODE" == "$explicit_code" ]]; then
    log INFO "Language $SELECTED_CODE is already active"
    exit 0
fi

if [[ ! -x "$SET_LANGUAGE" ]]; then
    log ERROR "Language script is missing: $SET_LANGUAGE"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_FAILED]}" LANG="$SELECTED_CODE")"
    exit 1
fi

log INFO "Changing the language to $SELECTED_CODE"

if ! "$SET_LANGUAGE" "$SELECTED_CODE"; then
    log ERROR "Failed to change the language to $SELECTED_CODE"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_FAILED]}" LANG="$SELECTED_CODE")"
    exit 1
fi

exit 0
