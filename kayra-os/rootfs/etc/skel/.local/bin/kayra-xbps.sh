#!/usr/bin/env bash
#
# kayra-xbps.sh - Install/remove a package, building from source when needed.
#
# Called by the package menu with a package name. The action is decided from the
# xbps state:
#   * already installed     -> offers to remove it, then runs xbps-remove
#   * available in a repo   -> offers to install it, then runs xbps-install
#   * only in void-packages -> updates the repo, builds with xbps-src and
#                             installs the built package locally
# A lock file serialises the privileged operations: it is created before the
# work and removed on exit.
#
# Commands used: xbps-query, notify-send, pkexec, xbps-remove, xbps-install,
#                git (fetch/status/pull), xbps-src, find, sort, head, dirname,
#                grep, cd, date.
#
# Usage: kayra-xbps.sh <package-name>

set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

PACKAGES_DIR="/var/spool/void-packages"
LOCK_FILE="/tmp/xbps.lock"

check_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        lock_content=$(cat "$LOCK_FILE" 2>/dev/null || true)
        notify_warn "${MSG[APP_NAME]}" "${MSG[LOCK_MSG]}"$'\n'"$lock_content"
        exit 0
    fi
}

cleanup_and_exit() {
    rm -f "$LOCK_FILE"
    exit 0
}

pkg="${1:-}"
[[ -z "$pkg" ]] && exit 1

# Package name validation: reject eval/find patterns, glob characters and the
# path separator (a simple command-injection guard).
if [[ ! "$pkg" =~ ^[A-Za-z0-9][A-Za-z0-9._+:-]*$ ]]; then
    exit 1
fi

# The package is installed: offer to remove it.
if xbps-query -S "$pkg" >/dev/null 2>&1; then
    action=$(notify_action "${MSG[APP_NAME]}" \
        "$(i18n_template "${MSG[REMOVE_CONFIRM]}" PACKAGE="$pkg")" \
        "remove=${MSG[ACTION_REMOVE]}") || true
    if [[ "$action" == "remove" ]]; then
        check_lock
        echo "$(i18n_template "${MSG[LOCK_REMOVE]}" PACKAGE="$pkg")" > "$LOCK_FILE"
        ret=0
        output=$(pkexec xbps-remove -y "$pkg" 2>&1) || ret=$?
        rm -f "$LOCK_FILE"
        if [[ $ret -eq 0 ]]; then
            notify_ok "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[REMOVE_OK]}"
        else
            notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[REMOVE_FAIL]}"
            log ERROR "${MSG[REMOVE_FAIL]}: xbps-remove $pkg msg:$output"
        fi
    fi
    cleanup_and_exit
fi

# The package is in the repositories: offer to install it.
if xbps-query -R "$pkg" >/dev/null 2>&1; then
    action=$(notify_action "${MSG[APP_NAME]}" \
        "$(i18n_template "${MSG[INSTALL_CONFIRM]}" PACKAGE="$pkg")" \
        "install=${MSG[ACTION_INSTALL]}") || true
    if [[ "$action" == "install" ]]; then
        check_lock
        echo "$(i18n_template "${MSG[LOCK_INSTALL]}" PACKAGE="$pkg")" > "$LOCK_FILE"
        ret=0
        output=$(pkexec xbps-install -Sy "$pkg" 2>&1) || ret=$?
        rm -f "$LOCK_FILE"
        if [[ $ret -eq 0 ]]; then
            notify_ok "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_OK]}"
        else
            notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_FAIL]}"
            log ERROR "${MSG[INSTALL_FAIL]}: xbps-install $pkg msg:$output"
        fi
    fi
    cleanup_and_exit
fi

# The package is not in the repositories: build it from source.
action=$(notify_action "${MSG[APP_NAME]}" \
    "$(i18n_template "${MSG[INSTALL_CONFIRM]}" PACKAGE="$pkg")" \
    "install=${MSG[ACTION_INSTALL]}") || true
if [[ "$action" == "install" ]]; then
    if ! cd "$PACKAGES_DIR"; then
        notify_error "${MSG[APP_NAME]}" "${MSG[CD_ERR]}"
        log ERROR "${MSG[CD_ERR]}"
        cleanup_and_exit
    fi
    check_lock
    echo "${MSG[LOCK_UPDATE]}" > "$LOCK_FILE"
    if ! fetch_out=$(git fetch 2>&1); then
        notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_FAIL]}"
        log ERROR "${MSG[INSTALL_FAIL]}: git fetch msg:$fetch_out"
        cleanup_and_exit
    fi
    if ! status_out=$(git status -uno 2>&1); then
        notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_FAIL]}"
        log ERROR "${MSG[INSTALL_FAIL]}: git status msg:$status_out"
        cleanup_and_exit
    fi
    echo "${MSG[LOCK_UPDATE_INFO]}" > "$LOCK_FILE"
    if echo "$status_out" | grep -q "behind"; then
        if ! pull_out=$(git pull 2>&1); then
            notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_FAIL]}"
            log ERROR "${MSG[INSTALL_FAIL]}: git pull msg:$pull_out"
            cleanup_and_exit
        fi
    fi
    echo "$(i18n_template "${MSG[LOCK_BUILD]}" PACKAGE="$pkg")" > "$LOCK_FILE"
    if ! compile_out=$(./xbps-src pkg "$pkg" 2>&1); then
        notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_FAIL]}"
        log ERROR "${MSG[INSTALL_FAIL]}: xbps-src pkg $pkg msg:$compile_out"
        cleanup_and_exit
    fi
    echo "$(i18n_template "${MSG[LOCK_INSTALL]}" PACKAGE="$pkg")" > "$LOCK_FILE"
    # sort -u: uniq only removes adjacent duplicates.
    xbpsdir=$(find "$PACKAGES_DIR/hostdir/binpkgs/" -type f -name "*$pkg*" -exec dirname {} \; | sort -u | head -n1)
    if [[ -z "$xbpsdir" ]]; then
        # An empty directory would make "-R /" use the root as the repository.
        notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_FAIL]}"
        log ERROR "${MSG[INSTALL_FAIL]}: built package not found for $pkg"
        cleanup_and_exit
    fi
    ret=0
    output=$(pkexec xbps-install -Sy -R "$xbpsdir/" "$pkg" 2>&1) || ret=$?
    if [[ $ret -eq 0 ]]; then
        notify_ok "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_OK]}"
    else
        notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_FAIL]}"
        log ERROR "${MSG[INSTALL_FAIL]}: xbps-install $pkg msg:$output"
    fi
fi
cleanup_and_exit
