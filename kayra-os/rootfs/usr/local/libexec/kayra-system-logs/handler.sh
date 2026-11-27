#!/bin/bash
#
# handler.sh - log stream handler of the Kayra service log streamer
#              (kayra-system-logs).
#
# socat starts one handler per log socket connection. The handler reads one
# service name from the client, validates it and streams the recent log lines:
#
#   * /var/log/<service>/current when it exists (svlogd file), with the last
#     20 lines, then "tail -F";
#   * otherwise the socklog everything stream, filtered by the service name,
#     with the last 20 matching lines, then a following filter.
#
# The TAI64N timestamp prefixes and ANSI escapes are removed for the console.
#
# The stream runs in its own process group and a watcher reads the remaining
# stdin: when the client disconnects, the watcher kills the whole group. A
# silent "tail -F" would otherwise stay alive after the client is gone.
#
# The socket permissions authorize the client (0660 root:kayra-admin); the
# handler only reads logs, it never changes system state.
#
# SIGPIPE is intentionally left at its default: a disconnected client closes
# the output pipe and ends the stream immediately. The watcher is the second
# safety net for a silent stream.
#
# Used commands: tail, grep, sed, ps, tr, kill, read, sleep, socat (via the
#                service run script)
#

set -uo pipefail

export LC_ALL=C.UTF-8
PATH=/usr/bin:/usr/sbin:/bin:/sbin
umask 027

SV_DIR=${SV_DIR:-/etc/sv}
LOG_DIR=${LOG_DIR:-/var/log}
SOCKLOG_FILE=${SOCKLOG_FILE:-/var/log/socklog/everything/current}

# The timestamp is TAI64N external format: "@" and 24 hex characters.
SED_EXPR='s/^@[0-9a-f]{24} //; s/\x1B\[[0-9;]*[A-Za-z]//g; s/\r$//'

STREAM_PID=""
STREAM_PGID=""
WATCH_PID=""

valid_service_name() {  # valid_service_name <service>
    local name=$1

    [[ $name =~ ^[A-Za-z0-9._@+-]+$ ]] || return 1
    [ "$name" != "." ] && [ "$name" != ".." ] || return 1
    (( ${#name} <= 64 )) || return 1
    return 0
}

kill_stream() {
    if [ -n "$STREAM_PGID" ]; then
        kill -TERM -- "-$STREAM_PGID" 2>/dev/null || true
    elif [ -n "$STREAM_PID" ]; then
        kill -TERM "$STREAM_PID" 2>/dev/null || true
    fi
}

cleanup() {
    trap - EXIT TERM INT HUP
    [ -n "$WATCH_PID" ] && kill "$WATCH_PID" 2>/dev/null || true
    kill_stream
    exit 0
}

trap cleanup EXIT TERM INT HUP

# Runs the given command in the background with the output filter, then waits.
# The pipeline gets its own process group so that EOF on the client connection
# can terminate all of its processes at once.
launch_stream() {
    local pgid

    set -m
    "$@" | sed -u -E "$SED_EXPR" &
    STREAM_PID=$!

    pgid=$(ps -o pgid= -p "$STREAM_PID" 2>/dev/null | tr -d ' ')
    [ -n "$pgid" ] || pgid=$STREAM_PID
    STREAM_PGID=$pgid

    (
        while IFS= read -r _; do :; done
        kill -TERM -- "-$STREAM_PGID" 2>/dev/null || true
    ) &
    WATCH_PID=$!

    wait "$STREAM_PID" 2>/dev/null || true
}

socklog_lines() {  # socklog_lines <file> <service>
    {
        # Last 20 matching lines of the current file, then follow.
        tail -c 1048576 -- "$1" 2>/dev/null |
            grep -a -F -- "$2" |
            tail -n 20

        tail -n 0 -F -- "$1" 2>/dev/null |
            grep -a --line-buffered -F -- "$2"
    }
}

# ------------------------------------------------------------------
# Read the service name and start the stream
# ------------------------------------------------------------------
IFS= read -r -t 5 service || exit 0

if ! valid_service_name "$service"; then
    printf 'Invalid service name: %s\n' "${service:-<empty>}"
    sleep 2
    exit 0
fi

if [ ! -d "$SV_DIR/$service" ]; then
    printf 'Service not found: %s\n' "$service"
    sleep 5
    exit 0
fi

log_file="$LOG_DIR/$service/current"

if [ -r "$log_file" ]; then
    launch_stream tail -n 20 -F -- "$log_file"
elif [ -r "$SOCKLOG_FILE" ]; then
    launch_stream socklog_lines "$SOCKLOG_FILE" "$service"
else
    printf 'No log source found for service: %s\n' "$service"
    sleep 5
fi

exit 0
