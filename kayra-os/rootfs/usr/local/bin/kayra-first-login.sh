#!/bin/bash
#
# kayra-first-login.sh - one-time graphical login setup.
#
# Runs once per user, guarded by ~/.config/kayra/.firstlogin. It creates the
# standard user directories and seeds the locale key of settings.conf:
#
#   locale empty -> the LANG from /etc/locale.conf, unless the login manager
#                   provided a different non-C LANG (a greeter language
#                   selection), in which case that value is used
#   lang         -> left empty; kayra-session-env.sh and i18n.sh derive the
#                   interface language from locale/LANG automatically
#
# It never generates locales and never calls the locale service. The installer
# has already generated the locale it wrote to /etc/locale.conf.
#
# Used commands: awk, sed, head, mkdir, dirname, rm, printf
#                (settings-conf.sh provides conf_get/conf_set)
#

set -uo pipefail
export LC_ALL=C.UTF-8

. /usr/local/lib/kayra/settings-conf.sh

FLAG="$HOME/.config/kayra/.firstlogin"
REGISTRY="/usr/local/share/kayra/lang/languages.tsv"

is_c_locale() {
    case "${1:-}" in
        C|POSIX|C.UTF-8|C.utf8) return 0 ;;
    esac
    return 1
}

registry_locale() {  # registry_locale <code>
    local code=${1:-}
    [ -n "$code" ] && [ -r "$REGISTRY" ] || return 1
    awk -F'\t' -v code="$code" '
        $1 == code && $1 !~ /^#/ { print $2; exit }
    ' "$REGISTRY"
}

[ -f "$FLAG" ] || exit 0

# The settings file is shipped by skel; create it for users that predate it.
mkdir -p "$(dirname "$CONFIG_FILE")"
[ -f "$CONFIG_FILE" ] || : >"$CONFIG_FILE"

if [ -x /usr/local/bin/kayra-make-user-dirs.sh ]; then
    /usr/local/bin/kayra-make-user-dirs.sh || true
fi

system_lang=$(awk -F= '/^LANG=/{print $2; exit}' /etc/locale.conf 2>/dev/null)
system_lang=$(printf '%s' "$system_lang" | sed 's/^"//;s/"$//')
system_lang=${system_lang:-C.UTF-8}
case "$system_lang" in
    ''|*[!A-Za-z0-9._@-]*) system_lang=C.UTF-8 ;;
esac

current_locale=$(conf_get locale | head -n1)
current_lang=$(conf_get lang | head -n1)

if [ -z "$current_locale" ]; then
    seed="$system_lang"

    # A login manager may pass the language chosen in the greeter. Use it only
    # when it is a real non-C locale and differs from the system default.
    if [ -n "${LANG:-}" ] && ! is_c_locale "$LANG" && [ "$LANG" != "$system_lang" ]; then
        seed="$LANG"
    fi

    # A migrated settings file may already carry an explicit UI language.
    if [ -n "$current_lang" ]; then
        registry_value=$(registry_locale "$current_lang" 2>/dev/null || true)
        [ -n "$registry_value" ] && seed="$registry_value"
    fi

    case "$seed" in
        ''|*[!A-Za-z0-9._@-]*) seed=$system_lang ;;
    esac

    conf_set locale "$seed"
fi

# Keep the marker when the settings file could not be seeded, so the next
# login retries instead of silently leaving the user without a locale.
if [ -n "$(conf_get locale | head -n1)" ]; then
    rm -f "$FLAG"
fi
exit 0
