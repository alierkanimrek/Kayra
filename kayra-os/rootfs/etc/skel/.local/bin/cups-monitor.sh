#!/usr/bin/env bash
#
# cups-monitor.sh - Waybar custom module for the CUPS print queue.
#
# Prints Waybar JSON ({text, tooltip, class}) on stdout. The module shows only
# the print glyph (Material Symbols "print", U+E8AD) and only while there is at
# least one active print job. When the queue is empty the text is empty and the
# module stays hidden (Waybar "hide-empty-text"). The tooltip carries the job
# list (id / owner / size) and the state of every printer.
#
# Error handling:
#   * Only a real print job failure turns the glyph into the warning colour and
#     raises a single notification. The failure is read from the "Alerts:" line
#     of "lpstat -l -o", which is the IPP job-state-reasons keyword list.
#     Failure keywords: job-stopped, job-stopped-partially, job-aborted-by-system,
#     job-completed-with-errors, job-completed-with-warnings, job-data-insufficient,
#     job-held. Benign keywords (none, job-printing, job-queued, job-incoming,
#     job-hold-until-specified) are ignored.
#   * An unreachable/offline printer or a printer paused with cupsdisable is NOT
#     an error: it is only reported in the tooltip, it never notifies. This
#     avoids notification spam from a printer that is simply not connected.
#   * The notification fires once per error episode: the error must stay for
#     ERROR_HOLD seconds in a row and is re-armed only after the error is gone.
#   * There is no notification for a job starting or finishing.
#
# Polling state machine (keeps the queue responsive without busy polling):
#   * A job exists              -> poll every 1 second.
#   * The queue just emptied    -> keep polling every 1 second for COOLDOWN
#                                  (10 minutes), so a follow-up job is caught fast.
#   * COOLDOWN passed, still no job -> poll every 3 seconds until the next job.
#   * A new job appears in 3 s mode -> immediately back to 1 second.
#
# Used libraries: single-instance.sh, klog.sh, i18n.sh, notify.sh.
# Commands used: lpstat, date, jq, awk, sed, printf, sleep, numfmt.
#
# Usage: cups-monitor.sh   (invoked by Waybar's custom/cups-monitor module)

export LC_ALL=C.UTF-8
set -uo pipefail

source "$HOME/.local/bin/single-instance.sh"
single_instance

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_CUPS_MONITOR

# Material Symbols codepoint shown as the module glyph (print).
ICON=$(printf '%b' '\U0000E8AD')

# Notifications reuse the same Material glyph (notify.sh renders it).
export NOTIFY_ICON="$ICON"
source "$(dirname "$0")/notify.sh"

for required_command in lpstat jq awk; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        log ERROR "Required command not found: $required_command" >&2
        exit 1
    fi
done

POLL_ACTIVE=1       # seconds between samples while jobs are active or in cooldown
POLL_IDLE=3         # seconds between samples when the queue has been idle
COOLDOWN=600        # seconds the queue stays on POLL_ACTIVE after getting empty
ERROR_HOLD=30       # seconds a job error must persist before notifying

# IPP job-state-reasons keywords that mean a real job failure.
FAILURE_RE='job-stopped|job-stopped-partially|job-aborted-by-system|job-completed-with-errors|job-completed-with-warnings|job-data-insufficient|job-held'

last_job_seen=0     # epoch of the last sample that had at least one job (0 = none yet)
error_since=0       # start of the current error streak (0 = no error)
notified=0          # notification sent for the current error streak
last_json=""        # last emitted Waybar JSON line

# Prints the active jobs, one "job|owner|size|alerts|printer" line per job.
# The "Alerts:" and "queued for" lines are indented continuations of the job
# they belong to, so the parser buffers the current job until the next one.
read_jobs() {
    lpstat -W not-completed -l -o 2>/dev/null | awk '
        function flush() {
            if (id != "") printf "%s|%s|%s|%s|%s\n", id, owner, size, alerts, printer
        }
        /^[^ \t]/ && NF {
            flush()
            id = $1; owner = $2; size = $3; alerts = ""; printer = ""
            next
        }
        /^[ \t]+Alerts:/ {
            alerts = $0
            sub(/^[ \t]*Alerts:[ \t]*/, "", alerts)
            next
        }
        /^[ \t]+queued for / {
            printer = $0
            sub(/^[ \t]*queued for[ \t]*/, "", printer)
            next
        }
        END { flush() }
    '
}

# Prints every printer as "name|state|offline". State is idle, printing or
# disabled; offline is 1 when a state message mentions an unreachable printer.
read_printers() {
    lpstat -p 2>/dev/null | awk '
        function flush() {
            if (name != "") printf "%s|%s|%s\n", name, state, offline
        }
        /^printer / {
            flush()
            name = $2
            state = "idle"
            if ($0 ~ /now printing/) state = "printing"
            else if ($0 ~ /disabled/) state = "disabled"
            offline = 0
            next
        }
        /^[ \t]+/ {
            if ($0 ~ /unavailable|not exist|offline|connecting-to-device/) offline = 1
        }
        END { flush() }
    '
}

# Prints the size in a short human readable form, or the raw value on failure.
human_size() {
    if [[ "$1" =~ ^[0-9]+$ ]] && command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec "$1" 2>/dev/null || printf '%s' "$1"
    else
        printf '%s' "$1"
    fi
}

# Maps a printer state keyword to its localized label.
state_label() {
    case "$1" in
        printing) printf '%s' "${MSG[STATE_PRINTING]}" ;;
        disabled) printf '%s' "${MSG[STATE_DISABLED]}" ;;
        *)        printf '%s' "${MSG[STATE_IDLE]}" ;;
    esac
}

while true; do
    now=$(date +%s)

    mapfile -t JOBS < <(read_jobs)
    count=${#JOBS[@]}

    # A job whose Alerts keyword matches the failure set is an error.
    error_line=""
    if (( count > 0 )); then
        error_line=$(printf '%s\n' "${JOBS[@]}" | awk -F'|' -v re="$FAILURE_RE" '$4 ~ re { print; exit }')
    fi

    if (( count > 0 )); then
        last_job_seen=$now
    fi

    # --- error notification (debounced, once per episode) -----------------
    if [[ -n "$error_line" ]]; then
        if (( error_since == 0 )); then
            error_since=$now
        fi
        if (( notified == 0 )) && (( now - error_since >= ERROR_HOLD )); then
            IFS='|' read -r e_id e_owner e_size e_alerts e_printer <<< "$error_line"
            log WARN "Print job error: $e_id (printer=$e_printer alerts=$e_alerts)" >&2
            notify_error "${MSG[NOTIFY_TITLE]}" \
                "$(i18n_template "${MSG[NOTIFY_ERROR]}" JOB="$e_id" PRINTER="$e_printer" STATE="$e_alerts")"
            notified=1
        fi
    else
        error_since=0
        notified=0
    fi

    # --- build the tooltip (only needed while the module is visible) ------
    TIP=""
    if (( count > 0 )); then
        TIP="${MSG[JOBS_HEADER]}"
        while IFS='|' read -r j_id j_owner j_size j_alerts j_printer; do
            [[ -n "$j_id" ]] || continue
            TIP+=$'\n'"$(i18n_template "${MSG[JOB_LINE]}" JOB="$j_id" OWNER="$j_owner" SIZE="$(human_size "$j_size")")"
        done <<< "$(printf '%s\n' "${JOBS[@]}")"

        mapfile -t PRINTERS < <(read_printers)
        if (( ${#PRINTERS[@]} > 0 )); then
            TIP+=$'\n'"${MSG[PRINTERS_HEADER]}"
            while IFS='|' read -r p_name p_state p_offline; do
                [[ -n "$p_name" ]] || continue
                label="$(state_label "$p_state")"
                (( p_offline == 1 )) && label="$label (${MSG[STATE_UNAVAILABLE]})"
                TIP+=$'\n'"$(i18n_template "${MSG[PRINTER_LINE]}" PRINTER="$p_name" STATE="$label")"
            done <<< "$(printf '%s\n' "${PRINTERS[@]}")"
        fi

        default_printer=$(lpstat -d 2>/dev/null | sed -n 's/^system default destination: //p')
        if [[ -n "$default_printer" ]]; then
            TIP+=$'\n'"$(i18n_template "${MSG[DEFAULT_PRINTER]}" PRINTER="$default_printer")"
        else
            TIP+=$'\n'"${MSG[DEFAULT_NONE]}"
        fi
    fi

    # --- text and class ---------------------------------------------------
    if (( count > 0 )); then
        TEXT="$ICON"
        if [[ -n "$error_line" ]]; then
            CLASS="error"
        else
            CLASS=""
        fi
    else
        TEXT=""
        CLASS=""
    fi

    json=$(jq -nc --arg text "$TEXT" --arg tooltip "$TIP" --arg class "$CLASS" \
        '{text: $text, tooltip: $tooltip, class: $class}')

    if [[ "$json" != "$last_json" ]]; then
        printf '%s\n' "$json"
        last_json="$json"
    fi

    # --- next poll interval ----------------------------------------------
    if (( count > 0 )); then
        sleep "$POLL_ACTIVE"
    elif (( last_job_seen > 0 && now - last_job_seen < COOLDOWN )); then
        sleep "$POLL_ACTIVE"
    else
        sleep "$POLL_IDLE"
    fi
done
