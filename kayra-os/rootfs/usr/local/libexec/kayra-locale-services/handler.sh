#!/bin/bash
#
# handler.sh - job handler of the Kayra locale service
#              (kayra-locale-services).
#
# socat-link.sh starts one handler per job socket connection, with the job lock
# already held. The handler reads one NDJSON request, validates the requested
# locale against /etc/default/libc-locales, enables it and rebuilds the glibc
# locale archive with xbps-reconfigure.
#
# Supported commands:
#   ensure <locale>     generate one locale listed in /etc/default/libc-locales
#   add <code> <locale> <language> <native> <name_en>
#                       append one entry to languages.tsv (admin only)
#
# The socket is only reachable for members of the fixed kayra-admin group, so
# the service does not distinguish callers. Input is never passed to a shell:
# the locale must match an exact entry of /etc/default/libc-locales and the
# registry fields are validated and written with printf.
#
# Events:
#   unchanged      level 1  locale already present in the archive
#   generating     level 1  xbps-reconfigure is about to run
#   generated      level 1  locale was generated and verified
#   language_added level 1  registry entry appended
#   unsupported    level 3  locale is not a UTF-8 entry in the database
#   duplicate      level 3  language code or locale already in the registry
#   busy           level 3  the xbps package database is locked
#   invalid        level 3  invalid registry field
#   failed         level 4  generation or registry write failed
#
# Response codes:
#   0 success, 3 operation failed, 4 invalid request
#
# Used commands: jq, logger, locale, awk, mktemp, timeout, xbps-reconfigure,
#                tail, wc, printf, flock (via kayra-xbps-lock.sh)
#

set -uo pipefail
trap '' PIPE

export LC_ALL=C.UTF-8
PATH=/usr/bin:/usr/sbin:/bin:/sbin
umask 027

RUN_DIR=${RUN_DIR:-/run/kayra-locale-services}
EVENTS_FILE=${EVENTS_FILE:-$RUN_DIR/events.ndjson}
LOCALE_DB=${LOCALE_DB:-/etc/default/libc-locales}
LANG_REGISTRY=${LANG_REGISTRY:-/usr/local/share/kayra/lang/languages.tsv}

. /usr/local/lib/kayra/socat-link.sh
. /usr/local/lib/kayra/kayra-xbps-lock.sh

if ! command -v jq >/dev/null 2>&1; then
    logger -t kayra-locale-services -p user.err \
        "jq is not installed" 2>/dev/null || true
    exit 1
fi

log_svc() {  # log_svc <level> <message>
    logger -t kayra-locale-services -p "user.$1" -- "$2" 2>/dev/null || true
}

locale_key() {  # locale_key <locale>
    printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/g'
}

is_generated() {  # is_generated <locale>
    local want
    want=$(locale_key "$1")
    [ -n "$want" ] || return 1
    locale -a 2>/dev/null |
        tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/g' |
        grep -qxF -- "$want"
}

is_supported() {  # is_supported <locale>
    local want=${1:-}
    [ -n "$want" ] || return 1
    [ -r "$LOCALE_DB" ] || return 1
    awk -v want="$want" '
        {
            line = $0
            sub(/^[ \t]*#?[ \t]*/, "", line)
            split(line, f, /[ \t]+/)
            if (f[1] == want) { found = 1; exit }
        }
        END { exit !found }
    ' "$LOCALE_DB"
}

is_supported_utf8() {  # is_supported_utf8 <locale>
    local want=${1:-}
    [ -n "$want" ] || return 1
    [ -r "$LOCALE_DB" ] || return 1
    awk -v want="$want" '
        {
            line = $0
            sub(/^[ \t]*#?[ \t]*/, "", line)
            split(line, f, /[ \t]+/)
            if (f[1] == want && toupper(f[2]) == "UTF-8") { found = 1; exit }
        }
        END { exit !found }
    ' "$LOCALE_DB"
}

uncomment_locale() {  # uncomment_locale <locale>
    local want=${1:?locale required}
    local tmp

    tmp=$(mktemp "$RUN_DIR/locale.XXXXXX") || return 1
    if ! awk -v want="$want" '
        {
            original = $0
            line = original
            sub(/^[ \t]*#?[ \t]*/, "", line)
            split(line, f, /[ \t]+/)
            if (f[1] == want) {
                sub(/^[ \t]*#?[ \t]*/, "", original)
                print original
                next
            }
            print
        }
    ' "$LOCALE_DB" >"$tmp"; then
        rm -f "$tmp"
        return 1
    fi

    if ! cat "$tmp" >"$LOCALE_DB"; then
        rm -f "$tmp"
        return 1
    fi
    rm -f "$tmp"
    return 0
}

locale_data() {  # locale_data <locale> <generated 0|1>
    jq -cn --arg locale "$1" --argjson generated "$2" \
        '{locale: $locale, generated: ($generated == 1)}'
}

emit_event() {  # emit_event <level> <event> <message> <data-json>
    local level=$1 event=$2 message=$3 data=${4:-'{}'} line

    line=$(sl_msg evt id="$id" owner="$owner" cmd="$cmd" parm="$parm" \
        level="$level" event="$event" msg="$message" data="$data") || return 1

    # Write the event stream before the client socket; ignore socket errors.
    printf '%s\n' "$line" >>"$EVENTS_FILE" 2>/dev/null || true
    printf '%s\n' "$line" 2>/dev/null || true
}

respond() {  # respond <ok> <code> <message> [data-json]
    local ok=$1 code=$2 message=$3 data=${4:-'{}'} line

    line=$(sl_msg res id="$id" owner="$owner" cmd="$cmd" parm="$parm" \
        ok="$ok" code="$code" msg="$message" data="$data") || return 1
    printf '%s\n' "$line" 2>/dev/null || true
}

invalid_request() {  # invalid_request <message>
    log_svc warn "$1"
    respond false 4 "$1" '{}'
    exit 0
}

valid_language_code() {  # valid_language_code <code>
    [[ ${1:-} =~ ^[a-z]{2,3}$ ]]
}

valid_locale_name() {  # valid_locale_name <locale>
    local value=${1:-}
    [[ $value =~ ^[A-Za-z0-9][A-Za-z0-9._@-]*$ ]] && (( ${#value} <= 64 ))
}

valid_language_list() {  # valid_language_list <list>
    local value=${1:-}
    [[ $value =~ ^[A-Za-z0-9_@:.-]+$ ]] && (( ${#value} <= 64 ))
}

valid_text() {  # valid_text <text>
    local value=${1:-}
    [ -n "$value" ] && (( ${#value} <= 64 )) || return 1
    case "$value" in
        *$'\t'*|*$'\n'*|*$'\r'*) return 1 ;;
    esac
    return 0
}

registry_has_code() {  # registry_has_code <code>
    local code=${1:-}
    [ -r "$LANG_REGISTRY" ] || return 1
    awk -F'\t' -v code="$code" '$1 == code { found = 1; exit }
        END { exit !found }' "$LANG_REGISTRY"
}

registry_has_locale() {  # registry_has_locale <locale>
    local locale=${1:-}
    [ -r "$LANG_REGISTRY" ] || return 1
    awk -F'\t' -v locale="$locale" '$2 == locale { found = 1; exit }
        END { exit !found }' "$LANG_REGISTRY"
}

language_data() {  # language_data <code> <locale>
    jq -cn --arg code "$1" --arg locale "$2" '{code: $code, locale: $locale}'
}

handle_add() {  # handle_add <code> <locale> <language> <native> <name_en>
    local code=$1 locale=$2 language=$3 native=$4 name_en=$5 data

    data=$(language_data "$code" "$locale")

    if ! valid_language_code "$code"; then
        log_svc warn "Invalid language code: ${code:-<empty>}"
        emit_event "$SL_LVL_WARN" invalid "Invalid language code" "$data"
        respond false 4 "Invalid language code" "$data"
        return 0
    fi

    if ! valid_locale_name "$locale"; then
        log_svc warn "Invalid locale name: ${locale:-<empty>}"
        emit_event "$SL_LVL_WARN" invalid "Invalid locale name" "$data"
        respond false 4 "Invalid locale name" "$data"
        return 0
    fi

    if ! is_supported_utf8 "$locale"; then
        log_svc warn "Locale is not a UTF-8 entry in the database: $locale"
        emit_event "$SL_LVL_WARN" unsupported \
            "Locale is not a UTF-8 entry in the locale database" "$data"
        respond false 4 "Locale is not a UTF-8 entry in the locale database" "$data"
        return 0
    fi

    if [ "$code" != "${locale%%_*}" ]; then
        log_svc warn "Language code does not match locale: $code / $locale"
        emit_event "$SL_LVL_WARN" invalid \
            "Language code does not match the locale" "$data"
        respond false 4 "Language code does not match the locale" "$data"
        return 0
    fi

    if ! valid_language_list "$language"; then
        log_svc warn "Invalid LANGUAGE list: ${language:-<empty>}"
        emit_event "$SL_LVL_WARN" invalid "Invalid LANGUAGE list" "$data"
        respond false 4 "Invalid LANGUAGE list" "$data"
        return 0
    fi

    if ! valid_text "$native" || ! valid_text "$name_en"; then
        log_svc warn "Invalid language display name"
        emit_event "$SL_LVL_WARN" invalid "Invalid language display name" "$data"
        respond false 4 "Invalid language display name" "$data"
        return 0
    fi

    if registry_has_code "$code"; then
        log_svc info "Language code already exists: $code"
        emit_event "$SL_LVL_WARN" duplicate \
            "Language code already exists: $code" "$data"
        respond false 3 "Language code already exists" "$data"
        return 0
    fi

    if registry_has_locale "$locale"; then
        log_svc info "Locale already exists in the registry: $locale"
        emit_event "$SL_LVL_WARN" duplicate \
            "Locale already exists in the registry: $locale" "$data"
        respond false 3 "Locale already exists in the registry" "$data"
        return 0
    fi

    if [ ! -f "$LANG_REGISTRY" ]; then
        log_svc err "Language registry is missing: $LANG_REGISTRY"
        emit_event "$SL_LVL_ERR" failed "Language registry is missing" "$data"
        respond false 3 "Language registry is missing" "$data"
        return 0
    fi

    # Keep one entry per line even if the file was edited without a final EOL.
    if [ -s "$LANG_REGISTRY" ] &&
        [ "$(tail -c 1 "$LANG_REGISTRY" | wc -l)" -eq 0 ]; then
        printf '\n' >>"$LANG_REGISTRY"
    fi

    if ! printf '%s\t%s\t%s\t%s\t%s\n' \
        "$code" "$locale" "$language" "$native" "$name_en" \
        >>"$LANG_REGISTRY"; then
        log_svc err "Could not write the language registry"
        emit_event "$SL_LVL_ERR" failed \
            "Could not write the language registry" "$data"
        respond false 3 "Could not write the language registry" "$data"
        return 0
    fi

    log_svc info "Language added: $code ($locale)"
    emit_event "$SL_LVL_INFO" language_added \
        "Language added: $code" "$data"
    respond true 0 "Language added" "$data"
}

handle_ensure() {  # handle_ensure <locale>
    local locale=$1 rc

    if ! is_supported "$locale"; then
        log_svc warn "Unsupported locale: $locale"
        emit_event "$SL_LVL_WARN" unsupported \
            "Locale is not listed in the locale database" \
            "$(locale_data "$locale" 0)"
        respond false 4 "Locale is not supported" "$(locale_data "$locale" 0)"
        return 0
    fi

    if is_generated "$locale"; then
        log_svc info "Locale already generated: $locale"
        emit_event "$SL_LVL_INFO" unchanged \
            "Locale already generated: $locale" "$(locale_data "$locale" 1)"
        respond true 0 "Locale already generated" "$(locale_data "$locale" 1)"
        return 0
    fi

    if xbps_busy; then
        log_svc warn "Package database is busy; not generating $locale"
        emit_event "$SL_LVL_WARN" busy \
            "Package database is busy" "$(locale_data "$locale" 0)"
        respond false 3 "Package database is busy" "$(locale_data "$locale" 0)"
        return 0
    fi

    if ! command -v xbps-reconfigure >/dev/null 2>&1; then
        log_svc err "xbps-reconfigure is not installed"
        emit_event "$SL_LVL_ERR" failed \
            "xbps-reconfigure is not installed" "$(locale_data "$locale" 0)"
        respond false 3 "xbps-reconfigure is not installed" \
            "$(locale_data "$locale" 0)"
        return 0
    fi

    if ! uncomment_locale "$locale"; then
        log_svc err "Could not enable locale: $locale"
        emit_event "$SL_LVL_ERR" failed \
            "Could not update the locale database" "$(locale_data "$locale" 0)"
        respond false 3 "Could not update the locale database" \
            "$(locale_data "$locale" 0)"
        return 0
    fi

    log_svc info "Generating locale: $locale"
    emit_event "$SL_LVL_INFO" generating \
        "Generating locale: $locale" "$(locale_data "$locale" 0)"

    timeout 300 xbps-reconfigure -f glibc-locales >/dev/null 2>&1
    rc=$?

    if [ "$rc" -ne 0 ]; then
        if xbps_busy; then
            log_svc warn "Package database is busy while generating $locale"
            emit_event "$SL_LVL_WARN" busy \
                "Package database is busy" "$(locale_data "$locale" 0)"
            respond false 3 "Package database is busy" \
                "$(locale_data "$locale" 0)"
        else
            log_svc err "xbps-reconfigure failed for $locale (exit $rc)"
            emit_event "$SL_LVL_ERR" failed \
                "xbps-reconfigure failed" "$(locale_data "$locale" 0)"
            respond false 3 "xbps-reconfigure failed" \
                "$(locale_data "$locale" 0)"
        fi
        return 0
    fi

    if ! is_generated "$locale"; then
        log_svc err "Locale is still missing after generation: $locale"
        emit_event "$SL_LVL_ERR" failed \
            "Locale is still missing after generation" \
            "$(locale_data "$locale" 0)"
        respond false 3 "Locale is still missing after generation" \
            "$(locale_data "$locale" 0)"
        return 0
    fi

    log_svc info "Locale generated: $locale"
    emit_event "$SL_LVL_INFO" generated \
        "Locale generated: $locale" "$(locale_data "$locale" 1)"
    respond true 0 "Locale generated" "$(locale_data "$locale" 1)"
}

# ------------------------------------------------------------------
# Read and validate one request
# ------------------------------------------------------------------
IFS= read -r -t 10 -n 4097 req || exit 0
(( ${#req} <= 4096 )) || {
    log_svc warn "Request is too large"
    exit 0
}

req_type=$(jq -r '.type // empty' <<<"$req" 2>/dev/null)
[ "$req_type" = "req" ] || exit 0

id=$(jq -r '.id // empty' <<<"$req" 2>/dev/null)
owner=$(jq -r '.owner // "unknown"' <<<"$req" 2>/dev/null)
cmd=$(jq -r '.cmd // empty' <<<"$req" 2>/dev/null)
parm=$(jq -c 'if ((.parm | type) == "array") or ((.parm | type) == "object")
              then .parm else [] end' <<<"$req" 2>/dev/null)
[ -n "$parm" ] || parm='[]'

case "$cmd" in
    ensure) need=1 ;;
    add) need=5 ;;
    *) invalid_request "Invalid command" ;;
esac

parm_len=$(jq -r 'if (.parm | type) == "array" then (.parm | length) else -1 end' \
    <<<"$req" 2>/dev/null)
[ "$parm_len" = "$need" ] || invalid_request "Invalid request parameters"

parm_str() {  # parm_str <index>
    jq -r --argjson i "$1" \
        '.parm[$i] | if type == "string" then . else "" end' \
        <<<"$req" 2>/dev/null
}

if [ "$cmd" = "ensure" ]; then
    locale=$(parm_str 0)
    if [[ ! $locale =~ ^[A-Za-z0-9][A-Za-z0-9._@-]*$ ]] || (( ${#locale} > 64 )); then
        log_svc warn "Invalid locale name: ${locale:-<empty>}"
        respond false 4 "Invalid locale name" '{}'
        exit 0
    fi
    handle_ensure "$locale"
else
    code=$(parm_str 0)
    locale=$(parm_str 1)
    language=$(parm_str 2)
    native=$(parm_str 3)
    name_en=$(parm_str 4)
    handle_add "$code" "$locale" "$language" "$native" "$name_en"
fi

exit 0
