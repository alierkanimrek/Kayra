# ~/.local/lib/single-instance.sh
# Kullanım: source ~/.local/lib/single-instance.sh; single_instance [ad]
# Aynı adlı eski örneği (alt süreçleriyle birlikte) sonlandırır, çıkışta kendi alt süreçlerini temizler.

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
