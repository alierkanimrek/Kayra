# single-instance.sh - Kayra OS single-instance guard (source it; do not execute it).
#
# Adds single_instance() to the caller's shell: it guarantees that only one
# instance of a program runs at a time.
#
# Usage in a script:
#   source "$HOME/.local/bin/single-instance.sh"
#   single_instance [name]      # name defaults to the script name ($0)
#
# * PID file: ${XDG_STATE_HOME:-$HOME/.local/state}/pids/<name>.pid
# * If that file holds a live process of the same program (PID reuse is
#   checked via /proc/<pid>/cmdline), it is killed together with its children,
#   then this instance takes over the PID file.
# * An EXIT trap is installed: on exit the script's own child processes are
#   killed and the PID file is removed (only if it still belongs to us).
# * TERM/INT/HUP are trapped so the cleanup runs before exiting (status 143).
#

_si_kill_tree() {   # önce çocukları, sonra süreci sonlandırır
    local c
    for c in $(pgrep -P "$1" 2>/dev/null); do _si_kill_tree "$c"; done
    kill "$1" 2>/dev/null
}

_si_cleanup() {
    local c
    trap - EXIT
    for c in $(pgrep -P $$ 2>/dev/null); do _si_kill_tree "$c"; done
    # pid dosyası hâlâ bize aitse sil
    [ "$(cat "$_si_pidfile" 2>/dev/null)" = "$$" ] && rm -f "$_si_pidfile"
}

single_instance() {
    local name=${1:-$(basename "$0")} dir old
    dir="${XDG_STATE_HOME:-$HOME/.local/state}/pids"
    mkdir -p "$dir"
    _si_pidfile="$dir/$name.pid"

    if [ -r "$_si_pidfile" ]; then
        old=$(<"$_si_pidfile")
        # PID yeniden kullanılmış olabilir: süreç gerçekten bu betik mi?
        if [ -n "$old" ] && [ "$old" != "$$" ] && [ -r "/proc/$old/cmdline" ] &&
           tr '\0' ' ' <"/proc/$old/cmdline" | grep -qF -- "$name"; then
            _si_kill_tree "$old"
            sleep 0.2
        fi
    fi

    echo $$ >"$_si_pidfile"
    trap '_si_cleanup' EXIT
    trap 'exit 143' TERM INT HUP
}
