#!/usr/bin/env bash
#
# sv-lib.sh - Kayra OS runit service library (source it; do not execute it).
#
# Provides the functions that read the state of a runit service without
# root privileges:
#   sv_run_programs <service>     prints the programs of the run script
#   sv_service_is_running <service>
#                                 returns 0 when the service is running
#   sv_guess_state <service>      prints running, stopped or disabled
#
# Usage in a script:
#   source "$HOME/.local/bin/sv-lib.sh"
#   state=$(sv_guess_state sshd)
#
# * The state is guessed from the process table: the program that the run
#   script of the service starts is searched in the process list.
# * The service directories are taken from SV_DIR and SERVICE_DIR, the
#   defaults are /etc/sv and /var/service.
# * The functions need no root privileges, the runit control files are only
#   readable by root.
#
# Used commands: awk, pgrep
#

export LC_ALL=C.UTF-8

: "${SV_DIR:=/etc/sv}"
: "${SERVICE_DIR:=/var/service}"

# Prints the programs that the run script of the service starts. The
# options, the redirections and the wrapper programs are skipped.
sv_run_programs() {
    local run_file="$SV_DIR/$1/run"

    [ -r "$run_file" ] || return 1

    awk '
        /^[[:space:]]*exec[[:space:]]+/ { last = $0 }
        END {
            if (last == "") exit 1
            line = last
            sub(/^[[:space:]]*exec[[:space:]]+/, "", line)
            n = split(line, parts, /[[:space:]]+/)
            for (i = 1; i <= n; i++) {
                t = parts[i]
                if (t == "") continue
                if (t ~ /[<>]/ || t ~ /^-/ || t ~ /:/) continue
                gsub(/^.*\//, "", t)
                if (t == "exec" || t == "chpst" || t == "env" ||
                    t == "set" || t == "su" || t == "sh" || t == "bash") continue
                print t
            }
        }
    ' "$run_file"
}

# Returns 0 when the service is running.
sv_service_is_running() {
    local program

    for program in $(sv_run_programs "$1"); do
        pgrep -x "$program" >/dev/null 2>&1 && return 0
    done

    return 1
}

# Prints the state of the service: running, stopped or disabled.
sv_guess_state() {
    local name="$1"

    if [ ! -e "$SERVICE_DIR/$name" ]; then
        printf 'disabled\n'
        return 0
    fi

    if sv_service_is_running "$name"; then
        printf 'running\n'
    else
        printf 'stopped\n'
    fi

    return 0
}
