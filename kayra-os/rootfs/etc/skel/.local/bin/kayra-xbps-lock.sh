#!/usr/bin/env bash
#
# kayra-xbps-lock.sh - Shared XBPS lock helpers for Kayra OS (source it; do not execute it).
#
# This library gives every Kayra software script a single coordination point
# with the xbps commands the user may run by hand (xbps-install, xbps-remove,
# xbps-reconfigure, xbps-pkgdb, xbps-alternatives).
#
# Locking model:
#   * XBPS_NATIVE_LOCK (/var/db/xbps/lock) is the exact file libxbps flocks with
#     LOCK_EX before it touches the package database (see lib/pkgdb.c,
#     xbps_pkgdb_lock). When two xbps transactions overlap, the second one
#     blocks and prints "package database locked, waiting...".
#   * The file is world readable and flock works on read-only file descriptors,
#     so this library can take the very same lock as an unprivileged user,
#     without root. While the lock is held, any xbps command the user starts
#     waits for it, and vice versa.
#   * flock is released automatically by the kernel when the process exits, so
#     a crashed or killed script never leaves a stale lock behind.
#
# DEADLOCK RULE (important):
#   Never call a native xbps command while holding the lock. The child opens
#   the same file again and requests LOCK_EX, which waits for the lock we hold,
#   while we wait for the child: a deadlock. Always run such commands through
#   xbps_run_native, which releases the lock first and re-acquires it after.
#   Also never call xbps_run_native inside a command substitution $(...): the
#   function must run in the current shell or the lock is released in a subshell
#   and left inconsistent.
#
# Functions:
#   xbps_lock_acquire        Acquire the lock (non-blocking). Non-zero when the
#                            lock is already held by another operation.
#   xbps_lock_release        Release the lock held by this shell.
#   xbps_run_native CMD...   Release, run CMD, re-acquire. Output is stored in
#                            XBPS_NATIVE_OUTPUT and the CMD exit code returned.
#   xbps_busy                Return 0 when any process holds the lock.
#   xbps_status_set TEXT     Publish TEXT to XBPS_MSG_FILE (shown by waybar).
#   xbps_status_clear        Remove XBPS_MSG_FILE.
#
# Used commands: flock, printf, rm, sleep, basename.
#
# Usage:
#   source "$(dirname "$0")/kayra-xbps-lock.sh"
#   if ! xbps_lock_acquire; then ... handle busy ...; exit 0; fi
#   xbps_status_set "Installing package..."
#   xbps_run_native pkexec xbps-install -Sy foo || ret=$?
#   echo "$XBPS_NATIVE_OUTPUT"
#   xbps_lock_release

export LC_ALL=C.UTF-8

# The lock file every xbps transaction uses (libxbps pkgdb lock).
XBPS_NATIVE_LOCK="/var/db/xbps/lock"
# Human readable status text consumed by the waybar monitor and power-menu.
XBPS_MSG_FILE="/tmp/kayra-xbps.msg"

# File descriptor of the lock held by this shell (empty when not held).
_XBPS_LOCK_FD=""
# Output of the last command executed through xbps_run_native.
XBPS_NATIVE_OUTPUT=""

# Acquire the shared lock without blocking.
# Returns 0 on success, non-zero when another operation already holds it (or
# when the lock file is not usable, in which case we run unlocked).
xbps_lock_acquire() {
    # Not readable: cannot coordinate at kernel level, run without a lock.
    [[ -r "$XBPS_NATIVE_LOCK" ]] || return 0

    exec {_XBPS_LOCK_FD}<"$XBPS_NATIVE_LOCK" || {
        _XBPS_LOCK_FD=""
        return 0
    }

    if ! flock -n "$_XBPS_LOCK_FD"; then
        exec {_XBPS_LOCK_FD}<&-
        _XBPS_LOCK_FD=""
        return 1
    fi

    return 0
}

# Release the lock held by this shell (no-op when it is not held).
xbps_lock_release() {
    if [[ -n "${_XBPS_LOCK_FD:-}" ]]; then
        flock -u "$_XBPS_LOCK_FD" 2>/dev/null || true
        exec {_XBPS_LOCK_FD}<&-
        _XBPS_LOCK_FD=""
    fi
}

# Run a native xbps command without deadlocking against our own lock: release
# it, run the command (its combined output goes to XBPS_NATIVE_OUTPUT), then
# re-acquire the lock, waiting if a user command took it in the meantime.
xbps_run_native() {
    local rc=0

    xbps_lock_release
    XBPS_NATIVE_OUTPUT=$("$@" 2>&1) || rc=$?
    while ! xbps_lock_acquire; do
        sleep 0.3
    done

    return "$rc"
}

# Return 0 (true) when any process holds the lock, non-zero when it is free.
xbps_busy() {
    local fd

    [[ -r "$XBPS_NATIVE_LOCK" ]] || return 1

    exec {fd}<"$XBPS_NATIVE_LOCK" || return 1
    if flock -n "$fd"; then
        flock -u "$fd" 2>/dev/null || true
        exec {fd}<&-
        return 1
    fi
    exec {fd}<&-
    return 0
}

# Publish a human readable status text for the monitor / power menu.
xbps_status_set() {
    printf '%s\n' "$1" > "$XBPS_MSG_FILE"
}

# Clear the published status text.
xbps_status_clear() {
    rm -f "$XBPS_MSG_FILE"
}
