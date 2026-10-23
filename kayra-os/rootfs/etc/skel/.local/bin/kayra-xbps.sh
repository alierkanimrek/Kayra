#!/usr/bin/env bash

export LC_ALL=C

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"
check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        lock_content=$(cat "$LOCK_FILE" 2>/dev/null || true)
        notify-send -i applications-engineering "${MSG[LOCK_MSG]}\n $lock_content"
        exit 0
    fi
}


PACKAGES_DIR="/var/spool/void-packages"
LOCK_FILE="/tmp/xbps.lock"

pkg="${1:-}"
[[ -z "$pkg" ]] && exit 1

REMOVE_CHECK="xbps-query -S "$pkg""
if eval "$REMOVE_CHECK" >/dev/null 2>&1; then
    action=$(notify-send -i applications-engineering -t 0 \
        -A remove="${MSG[ACTION_REMOVE]}" \
        "${MSG[REMOVE_CONFIRM]//%s/$pkg}" "")
    if [[ "$action" == "remove" ]]; then
        check_lock
        echo "${MSG[ACTION_REMOVE]}: $pkg" > "$LOCK_FILE"
        output=$(pkexec xbps-remove -y "$pkg" 2>&1) || ret=$?
        rm -f "$LOCK_FILE"
        if [[ $ret -eq 0 ]]; then
			notify-send -i applications-engineering "${MSG[REMOVE_OK]}"
		else
			notify-send -i applications-engineering "${MSG[REMOVE_FAIL]}"
			log "DEBUG" "${MSG[REMOVE_FAIL]}: $pkg  msg:$output"
		fi
    fi
    exit 0
fi

INSTALL_CHECK="xbps-query -R $pkg"
if eval "$INSTALL_CHECK" >/dev/null 2>&1; then
    action=$(notify-send -i applications-engineering -t 0 \
        -A install="${MSG[ACTION_INSTALL]}" \
        "${MSG[INSTALL_CONFIRM]//%s/$pkg}" "")
    if [[ "$action" == "install" ]]; then
        check_lock
        echo "${MSG[ACTION_INSTALL]}: $pkg" > "$LOCK_FILE"
        ret=0
        output=$(pkexec xbps-install -Sy "$pkg" 2>&1) || ret=$?
        rm -f "$LOCK_FILE"
        if [[ $ret -eq 0 ]]; then
            notify-send -i applications-engineering "${MSG[INSTALL_OK]}"
        else
            notify-send -i applications-engineering "${MSG[INSTALL_FAIL]}"
            log "DEBUG" "${MSG[INSTALL_FAIL]}: $pkg msg:$output"
        fi
    fi
    exit 0
fi

action=$(notify-send -i applications-engineering -t 0 -A install="${MSG[ACTION_INSTALL]}" "${MSG[INSTALL_CONFIRM]//%s/$pkg}" "")
if [[ "$action" = "install" ]]; then
	if ! cd "$PACKAGES_DIR"; then
		notify-send -i applications-engineering "${MSG[CD_ERR]}"
		log DEBUG "cd $PACKAGES_DIR failed"
		exit 0
	fi
	if ! fetch_out=$(git fetch origin 2>&1); then
		notify-send -i applications-engineering "${MSG[GIT_FETCH_ERR]}"
		log DEBUG "git fetch failed: $fetch_out"
		exit 0
	fi
	if ! status_out=$(git status -uno 2>&1); then
		notify-send -i applications-engineering "${MSG[GIT_STATUS_ERR]}"
		log DEBUG "git status failed: $status_out"
		exit 0
	fi
	if echo "$status_out" | grep -q "behind"; then
		echo "git pull"
	fi
fi
