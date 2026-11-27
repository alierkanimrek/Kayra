#!/usr/bin/env bash
#
# kayra-set-language.sh - Set the Kayra interface language for the user.
#
# The argument is a language code from languages.tsv (e.g. "tr", "en"). The
# registry maps it to the locale and the GNU gettext LANGUAGE fallback list.
#
# The script writes settings.conf:
#   lang=<code>            Kayra interface language
#   locale=<locale>        desired system locale for the session
#
# When the locale is not generated and the user is a member of kayra-admin,
# kayra-locale-services is asked to generate it. A regular user can still
# select the language: the interface and gettext messages work through
# LANGUAGE, while formatting and some applications stay in the system locale.
#
# LC_ALL is never written to ~/.profile. The session environment is built by
# kayra-session-env.sh and applied by kayra-session at the next login.
#
# Usage: kayra-set-language.sh <code>
#   e.g. kayra-set-language.sh tr
#
# Dependencies:
#   - libnotify   (for notify-send, xbps-install -S libnotify)
#   - jq, socat   (via locale-client.sh, only when locale.ensure is needed)
#
# Used commands: awk, sed, basename, dirname, mkdir, printf, bash, swaymsg,
#                dbus-update-activation-environment, settings-conf.sh,
#                locale-client.sh
#
set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/admin.sh
source /usr/local/lib/kayra/i18n.sh
declare -n MSG=i18n_SET_LANGUAGE

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/notify.sh
source /usr/local/lib/kayra/settings-conf.sh
source /usr/local/lib/kayra/locale-client.sh

ICON_LANGUAGE=$(printf '%b' '\U000F799')   # language
NOTIFY_ICON="$ICON_LANGUAGE"

LANG_DIR="/usr/local/share/kayra/lang"
REGISTRY="$LANG_DIR/languages.tsv"
WAYBAR_BUILDER="/usr/local/bin/kayra-waybar-config-builder.sh"
SESSION_ENV="/usr/local/bin/kayra-session-env.sh"

ARG="${1:-}"
if [[ -z "$ARG" ]]; then
    log ERROR "No language code given"
    echo "Usage: $(basename "$0") <code>" >&2
    exit 1
fi

# --- Read the language registry -----------------------------------------
if [[ ! -r "$REGISTRY" ]]; then
    log ERROR "Language registry is missing: $REGISTRY"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_FAILED]}" LANG="$ARG")"
    exit 1
fi

declare -A REG_LOCALE=() REG_LANGUAGE=() REG_NATIVE=()
while IFS=$'\t' read -r code locale language native name_en; do
    case "$code" in ''|'#'*) continue ;; esac
    REG_LOCALE[$code]=$locale
    REG_LANGUAGE[$code]=$language
    REG_NATIVE[$code]=$native
done < "$REGISTRY"

LANG_CODE="$ARG"
if [[ -z "${REG_LOCALE[$LANG_CODE]:-}" ]]; then
    log ERROR "Unknown language code: $ARG"
    notify_error "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_FAILED]}" LANG="$ARG")"
    exit 1
fi

LOCALE_STRING="${REG_LOCALE[$LANG_CODE]}"
LANGUAGE_LIST="${REG_LANGUAGE[$LANG_CODE]}"
NATIVE_NAME="${REG_NATIVE[$LANG_CODE]:-$LANG_CODE}"

UI_DATA=1
if [[ ! -f "$LANG_DIR/$LANG_CODE.sh" ]]; then
    UI_DATA=0
    log WARN "No Kayra interface translation for $LANG_CODE; English fallback"
fi

log INFO "Language requested: code=$LANG_CODE locale=$LOCALE_STRING language=$LANGUAGE_LIST"

# --- Generate the locale when possible ----------------------------------
ensure_ok=0
if locale_generated "$LOCALE_STRING"; then
    ensure_ok=1
elif is_kayra_admin; then
    notify_info "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_PREPARING]}" LANG="$NATIVE_NAME" LOCALE="$LOCALE_STRING")"

    if locale_ensure "$LOCALE_STRING"; then
        if locale_result_ok; then
            ensure_ok=1
            log INFO "Locale generated: $LOCALE_STRING"
        else
            log WARN "Locale generation failed: $LOCALE_STRING"
        fi
    else
        log WARN "Locale service is not reachable"
    fi
else
    log INFO "Locale is not generated and the user is not kayra-admin: $LOCALE_STRING"
fi

# --- Store the user settings --------------------------------------------
mkdir -p "$(dirname "$CONFIG_FILE")"
[[ -f "$CONFIG_FILE" ]] || : >"$CONFIG_FILE"
conf_set lang "$LANG_CODE"
conf_set locale "$LOCALE_STRING"

# --- Apply the new environment to new D-Bus activations -----------------
# The subshell keeps this script's LC_ALL=C.UTF-8 out of the session bus.
if [[ -x "$SESSION_ENV" ]]; then
    if env_out=$("$SESSION_ENV" 2>/dev/null); then
        (
            eval "$env_out"
            dbus-update-activation-environment LANG LANGUAGE
        ) >/dev/null 2>&1 || true
    fi
fi

# --- Rebuild the waybar configuration -----------------------------------
if [[ -f "$WAYBAR_BUILDER" ]]; then
    bash "$WAYBAR_BUILDER" >/dev/null 2>&1
    log INFO "Waybar config rebuilt"
fi

# Signal waybar to reload the configuration (do not fail outside sway)
swaymsg reload >/dev/null 2>&1 || true

# --- Notification in the new language -----------------------------------
# Reload the language data so the message uses the new interface language.
source /usr/local/lib/kayra/i18n.sh

if (( UI_DATA && ensure_ok )); then
    log INFO "Language set to $LANG_CODE ($LOCALE_STRING)"
    notify_ok "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_CHANGED]}" \
            LANG="$NATIVE_NAME" LOCALE="$LOCALE_STRING")"
elif (( ! UI_DATA && ! ensure_ok )); then
    log INFO "Language set to $LANG_CODE; no UI data, locale not generated: $LOCALE_STRING"
    notify_warn "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_NO_UI_AND_LOCALE]}" \
            LANG="$NATIVE_NAME" LOCALE="$LOCALE_STRING")"
elif (( ! UI_DATA )); then
    log INFO "Language set to $LANG_CODE; no UI data: $LOCALE_STRING"
    notify_warn "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_NO_UI_DATA]}" \
            LANG="$NATIVE_NAME" LOCALE="$LOCALE_STRING")"
else
    log INFO "Language set to $LANG_CODE; locale not generated: $LOCALE_STRING"
    notify_warn "${MSG[NOTIFY_TITLE]}" \
        "$(i18n_template "${MSG[MSG_NO_LOCALE_DATA]}" \
            LANG="$NATIVE_NAME" LOCALE="$LOCALE_STRING")"
fi

exit 0
