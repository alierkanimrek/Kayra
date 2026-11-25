#!/usr/bin/env bash
#
# kayra-theme-monitor.sh - Re-apply the Kayra theme when the GTK theme changes.
#
# Watches the GTK settings (gsettings, the gtk-3.0/gtk-4.0 settings files,
# xsettingsd and ~/.config/kayra) and re-applies the palette when the active
# theme or color scheme changes. Only active when auto_theme is true in
# settings.conf.
#
# The palette is read by kayra-theme-probe.gjs and applied by
# kayra-change-theme.sh. The monitor does not run at startup: the first
# palette update is triggered by the first settings change.
#
# Started by the sway session, guarded by single_instance.
#
# Used libraries: single-instance.sh, settings-conf.sh, klog.sh.
# Used commands: gsettings, inotifywait, mktemp, kayra-theme-probe.gjs,
#                kayra-change-theme.sh
#

set -uo pipefail
export LC_ALL=C.UTF-8

source /usr/local/lib/kayra/single-instance.sh
single_instance

source /usr/local/lib/kayra/klog.sh
source /usr/local/lib/kayra/settings-conf.sh

PROBE=/usr/local/bin/kayra-theme-probe.gjs
APPLY=/usr/local/bin/kayra-change-theme.sh

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
WATCH_DIRS=(
    "$CONFIG_HOME/gtk-3.0"
    "$CONFIG_HOME/gtk-4.0"
    "$CONFIG_HOME/xsettingsd"
    "$CONFIG_HOME/kayra"
)

# Reads the active palette and hands it to the apply script.
# Returns non-zero when the probe or the apply script fails.
on_change() {
    local auto_theme probe_out probe_err rc

    auto_theme=$(conf_get auto_theme)
    if [ "$auto_theme" != "true" ]; then
        log DEBUG "auto_theme is not true; theme not updated"
        return 0
    fi

    probe_err=$(mktemp "${TMPDIR:-/tmp}/kayra-theme-probe.XXXXXX") || {
        log ERROR "cannot create a temporary file for the probe output"
        return 1
    }

    probe_out=$("$PROBE" 2>"$probe_err")
    rc=$?

    if [ "$rc" -ne 0 ]; then
        log ERROR "theme probe failed: $(<"$probe_err")"
        rm -f "$probe_err"
        return 1
    fi
    rm -f "$probe_err"

    if [ -z "$probe_out" ]; then
        log ERROR "theme probe returned no output"
        return 1
    fi

    if ! "$APPLY" "$probe_out"; then
        log ERROR "failed to apply the theme colors"
        return 1
    fi

    log INFO "theme colors updated"
    return 0
}

# Feeds gsettings and inotify events into the same stream. The loop below
# reads one line per event.
event_stream() {
    local dir

    if command -v gsettings >/dev/null 2>&1; then
        gsettings monitor org.gnome.desktop.interface 2>/dev/null \
            | grep --line-buffered -E 'gtk-theme|color-scheme' &
    fi

    if command -v inotifywait >/dev/null 2>&1; then
        for dir in "${WATCH_DIRS[@]}"; do
            [ -d "$dir" ] || continue
            inotifywait -m -q \
                -e close_write,moved_to,create,delete,attrib "$dir" &
        done
    fi

    wait
}

while read -r _; do
    while read -r -t 0.3 _; do :; done   # coalesce rapid successive events
    on_change
done < <(event_stream)
