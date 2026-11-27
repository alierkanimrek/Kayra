#!/usr/bin/env bash
#
# kayra-session-env.sh - print the per-user session locale environment.
#
# The output is shell code (export/unset lines); eval it in the session
# launcher. No other output is written to stdout.
#
# Resolution:
#   lang     = settings.conf lang (empty = automatic)
#   locale   = settings.conf locale, or registry[lang].locale, or
#              /etc/locale.conf LANG
#
#   LANG     = locale when generated, otherwise the system LANG when it is a
#              non-C locale, otherwise en_US.UTF-8, otherwise C.UTF-8
#   LANGUAGE = registry[lang].LANGUAGE for an explicit lang, otherwise the
#              registry list of the locale language when it exists (for
#              example tr:en), otherwise the language part of the locale
#   LC_ALL   = unset
#
# GNU gettext ignores LANGUAGE when LANG is C, POSIX or C.UTF-8; that is why
# C.UTF-8 is the last fallback.
#
# Usage:
#   eval "$(/usr/local/bin/kayra-session-env.sh)"
#
# Used commands: locale, awk, tr, sed, grep, head, printf (via settings-conf.sh)
#
set -uo pipefail
export LC_ALL=C.UTF-8

. /usr/local/lib/kayra/settings-conf.sh

LANG_DIR=/usr/local/share/kayra/lang
REGISTRY=$LANG_DIR/languages.tsv

declare -A REG_LOCALE=() REG_LANGUAGE=()
if [ -r "$REGISTRY" ]; then
    while IFS=$'\t' read -r code locale language native name_en; do
        case "$code" in ''|'#'*) continue ;; esac
        REG_LOCALE[$code]=$locale
        REG_LANGUAGE[$code]=$language
    done < "$REGISTRY"
fi

is_c_locale() {
    case "${1:-}" in
        C|POSIX|C.UTF-8|C.utf8) return 0 ;;
    esac
    return 1
}

locale_key() {
    printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/g'
}

generated=$(locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/g')

is_generated() {
    local want
    want=$(locale_key "${1:-}")
    [ -n "$want" ] && grep -qxF -- "$want" <<<"$generated"
}

system_lang=$(awk -F= '/^LANG=/{print $2; exit}' /etc/locale.conf 2>/dev/null)
system_lang=$(printf '%s' "$system_lang" | sed 's/^"//;s/"$//')
system_lang=${system_lang:-C.UTF-8}

lang=$(conf_get lang | head -n1)
desired_locale=$(conf_get locale | head -n1)

[ -n "$desired_locale" ] || desired_locale=${REG_LOCALE[$lang]:-}
[ -n "$desired_locale" ] || desired_locale=$system_lang

if is_generated "$desired_locale"; then
    chosen=$desired_locale
elif ! is_c_locale "$system_lang" && is_generated "$system_lang"; then
    chosen=$system_lang
elif is_generated en_US.UTF-8; then
    chosen=en_US.UTF-8
else
    chosen=C.UTF-8
fi

if [ -n "$lang" ] && [ -n "${REG_LANGUAGE[$lang]:-}" ]; then
    language=${REG_LANGUAGE[$lang]}
else
    derived_language=${desired_locale%%_*}
    if [ -n "${REG_LANGUAGE[$derived_language]:-}" ]; then
        language=${REG_LANGUAGE[$derived_language]}
    elif is_c_locale "$desired_locale"; then
        language=en
    else
        language=$derived_language
    fi
fi

# Defense in depth: settings.conf is user owned. Never eval arbitrary values.
case "$chosen" in *[!A-Za-z0-9._@-]*) chosen=C.UTF-8 ;; esac
case "$language" in *[!A-Za-z0-9_@:-]*) language=en ;; esac

printf 'export LANG=%s\n' "$chosen"
printf 'export LANGUAGE=%s\n' "$language"
printf 'unset LC_ALL\n'
