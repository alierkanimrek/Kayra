#!/usr/bin/env bash

export LC_ALL=C

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"
check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        lock_content=$(cat "$LOCK_FILE" 2>/dev/null || true)
        notify-send "${MSG[APP_NAME]}" "${MSG[LOCK_MSG]}\n $lock_content"
        exit 0
    fi
}

exit_(){
	rm $LOCK_FILE 2>/dev/null
	exit 0
}


PACKAGES_DIR="/var/spool/void-packages"
LOCK_FILE="/tmp/xbps.lock"

pkg="${1:-}"
[[ -z "$pkg" ]] && exit 1

REMOVE_CHECK="xbps-query -S "$pkg""
if eval "$REMOVE_CHECK" >/dev/null 2>&1; then
    action=$(notify-send "${MSG[APP_NAME]}" -t 0 \
        -A remove="${MSG[ACTION_REMOVE]}" \
        "${MSG[REMOVE_CONFIRM]//%s/$pkg}")
    if [[ "$action" == "remove" ]]; then
        check_lock
        echo "${MSG[LOCK_REMOVE]//%s/$pkg}" > "$LOCK_FILE"
        output=$(pkexec xbps-remove -y "$pkg" 2>&1) || ret=$?
        rm -f "$LOCK_FILE"
        if [[ $ret -eq 0 ]]; then
			notify-send "${MSG[APP_NAME]}" "$pkg\n${MSG[REMOVE_OK]}"
		else
			notify-send "${MSG[APP_NAME]}" "$pkg\n${MSG[REMOVE_FAIL]}"
			log "ERROR" "${MSG[REMOVE_FAIL]}: xbps-remove $pkg msg:$output"
		fi
    fi
    exit_
fi

INSTALL_CHECK="xbps-query -R $pkg"
if eval "$INSTALL_CHECK" >/dev/null 2>&1; then
    action=$(notify-send "${MSG[APP_NAME]}" -t 0 \
        -A install="${MSG[ACTION_INSTALL]}" \
        "${MSG[INSTALL_CONFIRM]//%s/$pkg}")
    if [[ "$action" == "install" ]]; then
        check_lock
        echo "${MSG[LOCK_INSTALL]//%s/$pkg}" > "$LOCK_FILE"
        ret=0
        output=$(pkexec xbps-install -Sy "$pkg" 2>&1) || ret=$?
        rm -f "$LOCK_FILE"
        if [[ $ret -eq 0 ]]; then
            notify-send "${MSG[APP_NAME]}" "$pkg\n${MSG[INSTALL_OK]}"
        else
            notify-send "${MSG[APP_NAME]}" "$pkg\n${MSG[INSTALL_FAIL]}"
            log "ERROR" "${MSG[INSTALL_FAIL]}: xbps-install $pkg msg:$output"
        fi
    fi
    exit_
fi

action=$(notify-send "${MSG[APP_NAME]}" -t 0 -A install="${MSG[ACTION_INSTALL]}" "${MSG[INSTALL_CONFIRM]//%s/$pkg}")
if [[ "$action" = "install" ]]; then
	if ! cd "$PACKAGES_DIR"; then
		notify-send "${MSG[APP_NAME]}" "${MSG[CD_ERR]}"
		log ERROR "${MSG[CD_ERR]}"
		exit_
	fi
	check_lock
	echo "${MSG[LOCK_UPDATE]}" > "$LOCK_FILE"
	if ! fetch_out=$(git fetch 2>&1); then
		notify-send "${MSG[APP_NAME]}" "$pkg\n${MSG[INSTALL_FAIL]}"
		log ERROR "${MSG[INSTALL_FAIL]}: git fetch msg:$fetch_out"
		exit_
	fi
	if ! status_out=$(git status -uno 2>&1); then
		notify-send "${MSG[APP_NAME]}" "$pkg\n${MSG[INSTALL_FAIL]}"
		log ERROR $"${MSG[INSTALL_FAIL]}: git status msg:$status_out"
		exit_
	fi
	echo "${MSG[LOCK_UPDATE_INFO]}" > "$LOCK_FILE"
	if echo "$status_out" | grep -q "behind"; then
		if ! pull_out=$(git pull 2>&1); then
			notify-send "${MSG[APP_NAME]}" "$pkg\n${MSG[INSTALL_FAIL]}"
			log ERROR $"${MSG[INSTALL_FAIL]}: git pull msg:$pull_out"
			exit_	
		fi
	fi
	echo "${MSG[LOCK_BUILD]//%s/$pkg}" > "$LOCK_FILE"
	if ! compile_out=$(./xbps-src pkg "$pkg" 2>&1); then
		notify-send "${MSG[APP_NAME]}" "$pkg\n${MSG[INSTALL_FAIL]}"
		log ERROR $"${MSG[INSTALL_FAIL]}: xbps-src pkg $pkg msg:$compile_out"
		exit_		
	fi
	echo "${MSG[LOCK_INSTALL]//%s/$pkg}" > "$LOCK_FILE"
	xbpsdir=$(find $PACKAGES_DIR/hostdir/binpkgs/ -type f -name "*$pkg*" -exec dirname {} \; | uniq)
	output=$(pkexec xbps-install -Sy -R "$xbpsdir/" "$pkg" 2>&1) || ret=$?
	if [[ $ret -eq 0 ]]; then
	    notify-send "${MSG[APP_NAME]}" "$pkg\n${MSG[INSTALL_OK]}"
	else
	    notify-send "${MSG[APP_NAME]}" "$pkg\n${MSG[INSTALL_FAIL]}"
	    log "ERROR" $"${MSG[INSTALL_FAIL]}: xbps-install $pkg msg:$output"
	fi
	
fi
exit_

