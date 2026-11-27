#!/usr/bin/env bash
#
# kayra-language-add.sh - Add a system locale to the Kayra language registry.
#
# Admin only. Lists the UTF-8 locales from /etc/default/libc-locales that are
# not yet represented in languages.tsv. Entries are searchable by locale code
# and by the English language name from /usr/share/i18n/locales (for example
# "de_DE.UTF-8 - German"). If there is no lang/<code>.sh, it warns that the
# Kayra interface will stay in English and asks for confirmation before writing
# the registry entry. It does not generate the locale; selecting the new entry
# in the language menu generates it when needed.
#
# The list is long, so the fuzzel height is left at its default and the search
# prompt stays visible.
#
# The language code is the part before the first "_" of the locale
# (de_DE.UTF-8 -> de). Locales whose code is already in the registry are not
# listed, so every language code has exactly one locale.
#
# Usage: kayra-language-add.sh [fuzzel parameters...]
#
# Dependencies:
#   - fuzzel      (xbps-install -S fuzzel)
#   - libnotify   (for notify-send, xbps-install -S libnotify)
#   - jq, socat   (via locale-client.sh)
#   - glibc-locales (provides /usr/share/i18n/locales for the English names)
#
# Used commands: fuzzel, pkill, awk, sort, jq, locale-client.sh
#
set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/admin.sh
require_kayra_admin

source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_LANGUAGE_ADD

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/locale-client.sh

LANG_DIR="/usr/local/share/kayra/lang"
REGISTRY="$LANG_DIR/languages.tsv"
LOCALE_DB="/etc/default/libc-locales"

if [[ ! -r "$REGISTRY" ]]; then
    log ERROR "Language registry is missing: $REGISTRY"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_REGISTRY_MISSING]}"
    exit 1
fi

if [[ ! -r "$LOCALE_DB" ]]; then
    log ERROR "Locale database is missing: $LOCALE_DB"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_LOCALE_DB_MISSING]}"
    exit 1
fi

# locale_language_name <locale> -> English language name from glibc
# Falls back to the locale code when the source file or language field is
# missing. The source files are installed by glibc-locales.
locale_language_name() {
    local locale=${1:-}
    local base file name

    base=${locale%%.*}
    file="/usr/share/i18n/locales/$base"

    if [[ -r "$file" ]]; then
        name=$(awk -F'"' '/^language[ \t]+"/ { print $2; exit }' "$file" 2>/dev/null)
    fi

    printf '%s' "${name:-$locale}"
}

# Existing codes and locales from the registry.
declare -A EXISTING_CODES=() EXISTING_LOCALES=()
while IFS=$'\t' read -r code locale rest; do
    case "$code" in ''|'#'*) continue ;; esac
    EXISTING_CODES[$code]=1
    EXISTING_LOCALES[$locale]=1
done < "$REGISTRY"

# All UTF-8 locales listed by the package, without C/POSIX.
declare -a RAW=() LINES=() LOCALES=() DISPLAY_NAMES=()
mapfile -t RAW < <(
    awk '
        {
            line = $0
            sub(/^[ \t]*#?[ \t]*/, "", line)
            split(line, f, /[ \t]+/)
            if (f[1] == "" || f[2] == "") next
            if (toupper(f[2]) != "UTF-8") next
            if (f[1] == "C" || f[1] == "POSIX" || f[1] == "C.UTF-8") next
            print f[1]
        }
    ' "$LOCALE_DB" | sort -u
)

for locale in "${RAW[@]}"; do
    code=${locale%%_*}
    [[ $code =~ ^[a-z]{2,3}$ ]] || continue
    [[ -n ${EXISTING_LOCALES[$locale]:-} ]] && continue
    [[ -n ${EXISTING_CODES[$code]:-} ]] && continue

    name=$(locale_language_name "$locale")
    if [[ -z "$name" || "$name" == "$locale" ]]; then
        name="$locale"
        line="$locale"
    else
        line="$locale - $name"
    fi

    LINES+=("$line")
    LOCALES+=("$locale")
    DISPLAY_NAMES+=("$name")
done

if (( ${#LINES[@]} == 0 )); then
    log INFO "No new UTF-8 locales found"
    notify_info "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_NO_LOCALES]}"
    exit 0
fi

pkill -x fuzzel 2>/dev/null || true

MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

# Long list: leave the height to fuzzel and keep the search prompt visible.
SELECTED=$(printf '%s\n' "${LINES[@]}" | fuzzel --dmenu --anchor=top-right \
    --log-no-syslog --width="$MAX_WIDTH" \
    --prompt="${MSG[PROMPT_SEARCH]:-Search: }" "$@") || true

[[ -z "$SELECTED" ]] && exit 0

SEL_INDEX=$(printf '%s\n' "${LINES[@]}" |
    awk -v sel="$SELECTED" '$0 == sel { print NR - 1; exit }')
[[ -z "$SEL_INDEX" ]] && exit 0

LOCALE="${LOCALES[$SEL_INDEX]}"
NAME="${DISPLAY_NAMES[$SEL_INDEX]}"
[[ -z "$LOCALE" ]] && exit 0

CODE="${LOCALE%%_*}"

if [[ ! "$CODE" =~ ^[a-z]{2,3}$ ]]; then
    log ERROR "Cannot derive a language code from $LOCALE"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_INVALID_LOCALE]}" LOCALE="$LOCALE")"
    exit 1
fi

# No interface translation: warn and confirm before writing the registry.
if [[ ! -f "$LANG_DIR/$CODE.sh" ]]; then
    BODY=$(i18n_template "${MSG[MSG_MISSING_TRANSLATION]}" \
        CODE="$CODE" LOCALE="$LOCALE")
    ACTION=$(notify_action "${MSG[NOTIFY_TITLE]}" "$BODY" \
        "add=${MSG[BUTTON_ADD]}" "cancel=${MSG[BUTTON_CANCEL]}")
    if [[ "$ACTION" != "add" ]]; then
        log INFO "Adding $LOCALE cancelled by the user"
        exit 0
    fi
fi

LANGUAGE_LIST="${CODE}:en"
NATIVE_NAME="${NAME:-$LOCALE}"
NAME_EN="$NATIVE_NAME"

log INFO "Adding language: code=$CODE locale=$LOCALE name=$NATIVE_NAME"

if ! locale_add "$CODE" "$LOCALE" "$LANGUAGE_LIST" "$NATIVE_NAME" "$NAME_EN"; then
    log ERROR "Language service is not reachable"
    notify_error "${MSG[NOTIFY_TITLE]}" "${MSG[MSG_SERVICE_UNAVAILABLE]}"
    exit 1
fi

if locale_result_ok; then
    log INFO "Language added: $LOCALE"
    notify_ok "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_ADDED]}" LOCALE="$LOCALE")"
    exit 0
fi

# Find the terminal event to distinguish a duplicate from a real failure.
EVENT=""
for line in "${LOCALE_EVENTS[@]}"; do
    event=$("${LOCALE_JQ:-jq}" -r '.event // empty' <<<"$line" 2>/dev/null)
    case "$event" in
        duplicate|unsupported|invalid|failed) EVENT=$event ;;
    esac
done

case "$EVENT" in
    duplicate)
        log INFO "Language already present: $LOCALE"
        notify_info "${MSG[NOTIFY_TITLE]}" \
            "$(i18n_template "${MSG[MSG_EXISTS]}" LOCALE="$LOCALE")"
        ;;
    *)
        log ERROR "Could not add language: $LOCALE (${EVENT:-no event})"
        notify_error "${MSG[NOTIFY_TITLE]}" \
            "$(i18n_template "${MSG[MSG_FAILED]}" LOCALE="$LOCALE")"
        exit 1
        ;;
esac

exit 0
