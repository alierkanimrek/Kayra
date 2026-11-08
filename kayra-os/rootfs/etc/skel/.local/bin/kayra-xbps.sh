#!/usr/bin/env bash
#
# kayra-xbps.sh - Install/remove/update a package, building from source when needed.
#
# Called by the package menu with a package name, or with -update to update the
# whole system (it dispatches to kayra-xbps-update.sh). The action is decided
# from the xbps state:
#   * already installed, update available -> offers remove / update / system update
#   * already installed, no update        -> offers to remove it
#   * available in a repo                 -> offers to install it
#   * only in void-packages               -> updates the repo, builds with
#                                            xbps-src and installs it locally
# The privileged operations are serialised with the shared XBPS lock
# (kayra-xbps-lock.sh): while it is held, any xbps command the user starts by
# hand waits for it, and no other Kayra operation can overlap.
#
# Commands used: flock, xbps-query, xbps-install, xbps-checkvers, notify-send,
#                pkexec, xbps-remove, git (fetch/status/pull), xbps-src, find,
#                sort, head, dirname, grep, cd, date.
#
# Usage: kayra-xbps.sh <package-name>
#        kayra-xbps.sh -update

set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_XBPS_MANAGER

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"
source "$(dirname "$0")/kayra-xbps-lock.sh"

PACKAGES_DIR="/var/spool/void-packages"

# ---- lock ------------------------------------------------------------------

# Acquire the shared XBPS lock before doing any work. When another operation
# (a Kayra script or a command the user started by hand) holds it, warn and
# stop instead of overlapping. See kayra-xbps-lock.sh for the locking model.
check_lock() {
    if ! xbps_lock_acquire; then
        notify_warn "${MSG[APP_NAME]}" "${MSG[LOCK_MSG]}"
        exit 0
    fi
    # Make sure the lock and the status text are cleared on any exit path.
    trap 'xbps_status_clear; xbps_lock_release' EXIT
}

cleanup_and_exit() {
    xbps_status_clear
    xbps_lock_release
    exit 0
}

# ---- update detection ------------------------------------------------------

# Return 0 when a newer version of the installed package is in a repository.
repo_update() {
    xbps-install -un "$1" 2>/dev/null |
        awk -v n="$1" 'index($1, n "-") == 1 && $2 == "update" { f = 1 } END { exit(f ? 0 : 1) }'
}

# Return 0 when the package has a more recent template in the source tree.
source_update() {
    [[ -e "$PACKAGES_DIR/srcpkgs/$1" ]] &&
        xbps-checkvers -I -m "$1" -D "$PACKAGES_DIR" 2>/dev/null | grep -q .
}

# ---- source build ----------------------------------------------------------

# Build a source package and install it from the local repository. The caller
# must already hold the shared lock (check_lock). Returns non-zero on failure.
build_and_install_source() {
    local p="$1" xbpsdir ret=0 fetch_out status_out pull_out compile_out output

    if ! cd "$PACKAGES_DIR"; then
        notify_error "${MSG[APP_NAME]}" "${MSG[CD_ERR]}"
        log ERROR "${MSG[CD_ERR]}"
        return 1
    fi
    xbps_status_set "${MSG[LOCK_UPDATE]}"
    if ! fetch_out=$(git fetch 2>&1); then
        notify_error "${MSG[APP_NAME]}" "$p"$'\n'"${MSG[INSTALL_FAIL]}"
        log ERROR "${MSG[INSTALL_FAIL]}: git fetch msg:$fetch_out"
        return 1
    fi
    if ! status_out=$(git status -uno 2>&1); then
        notify_error "${MSG[APP_NAME]}" "$p"$'\n'"${MSG[INSTALL_FAIL]}"
        log ERROR "${MSG[INSTALL_FAIL]}: git status msg:$status_out"
        return 1
    fi
    xbps_status_set "${MSG[LOCK_UPDATE_INFO]}"
    if echo "$status_out" | grep -q "behind"; then
        if ! pull_out=$(git pull 2>&1); then
            notify_error "${MSG[APP_NAME]}" "$p"$'\n'"${MSG[INSTALL_FAIL]}"
            log ERROR "${MSG[INSTALL_FAIL]}: git pull msg:$pull_out"
            return 1
        fi
    fi
    xbps_status_set "$(i18n_template "${MSG[LOCK_BUILD]}" PACKAGE="$p")"
    if ! compile_out=$(./xbps-src pkg "$p" 2>&1); then
        notify_error "${MSG[APP_NAME]}" "$p"$'\n'"${MSG[INSTALL_FAIL]}"
        log ERROR "${MSG[INSTALL_FAIL]}: xbps-src pkg $p msg:$compile_out"
        return 1
    fi
    xbps_status_set "$(i18n_template "${MSG[LOCK_INSTALL]}" PACKAGE="$p")"
    # sort -u: uniq only removes adjacent duplicates.
    xbpsdir=$(find "$PACKAGES_DIR/hostdir/binpkgs/" -type f -name "*$p*" -exec dirname {} \; | sort -u | head -n1)
    if [[ -z "$xbpsdir" ]]; then
        # An empty directory would make "-R /" use the root as the repository.
        notify_error "${MSG[APP_NAME]}" "$p"$'\n'"${MSG[INSTALL_FAIL]}"
        log ERROR "${MSG[INSTALL_FAIL]}: built package not found for $p"
        return 1
    fi
    xbps_run_native pkexec xbps-install -Sy -R "$xbpsdir/" "$p" || ret=$?
    output="$XBPS_NATIVE_OUTPUT"
    if [[ $ret -eq 0 ]]; then
        notify_ok "${MSG[APP_NAME]}" "$p"$'\n'"${MSG[INSTALL_OK]}"
        return 0
    fi
    notify_error "${MSG[APP_NAME]}" "$p"$'\n'"${MSG[INSTALL_FAIL]}"
    log ERROR "${MSG[INSTALL_FAIL]}: xbps-install $p msg:$output"
    return 1
}

# ---- argument handling -----------------------------------------------------

# "-update" updates the whole system through the dedicated, standalone script.
case "${1:-}" in
    -update|--update)
        exec "$(dirname "$0")/kayra-xbps-update.sh"
        ;;
esac

pkg="${1:-}"
[[ -z "$pkg" ]] && exit 1

# Package name validation: reject eval/find patterns, glob characters and the
# path separator (a simple command-injection guard).
if [[ ! "$pkg" =~ ^[A-Za-z0-9][A-Za-z0-9._+:-]*$ ]]; then
    exit 1
fi

# ---- installed package: remove / update / system update --------------------

if xbps-query -S "$pkg" >/dev/null 2>&1; then
    if repo_update "$pkg" || source_update "$pkg"; then
        action=$(notify_action "${MSG[APP_NAME]}" \
            "$(i18n_template "${MSG[INSTALLED_CONFIRM]}" PACKAGE="$pkg")" \
            "remove=${MSG[ACTION_REMOVE]}" \
            "update=${MSG[ACTION_UPDATE]}" \
            "sysupdate=${MSG[ACTION_SYS_UPDATE]}") || true
    else
        action=$(notify_action "${MSG[APP_NAME]}" \
            "$(i18n_template "${MSG[REMOVE_CONFIRM]}" PACKAGE="$pkg")" \
            "remove=${MSG[ACTION_REMOVE]}") || true
    fi

    case "$action" in
        remove)
            check_lock
            xbps_status_set "$(i18n_template "${MSG[LOCK_REMOVE]}" PACKAGE="$pkg")"
            ret=0
            xbps_run_native pkexec xbps-remove -y "$pkg" || ret=$?
            output="$XBPS_NATIVE_OUTPUT"
            if [[ $ret -eq 0 ]]; then
                notify_ok "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[REMOVE_OK]}"
            else
                notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[REMOVE_FAIL]}"
                log ERROR "${MSG[REMOVE_FAIL]}: xbps-remove $pkg msg:$output"
            fi
            ;;
        update)
            if repo_update "$pkg"; then
                check_lock
                xbps_status_set "$(i18n_template "${MSG[LOCK_INSTALL]}" PACKAGE="$pkg")"
                ret=0
                xbps_run_native pkexec xbps-install -Suy "$pkg" || ret=$?
                output="$XBPS_NATIVE_OUTPUT"
                if [[ $ret -eq 0 ]]; then
                    notify_ok "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[UPDATE_PKG_OK]}"
                else
                    notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[UPDATE_PKG_FAIL]}"
                    log ERROR "${MSG[UPDATE_PKG_FAIL]}: xbps-install $pkg msg:$output"
                fi
            else
                check_lock
                build_and_install_source "$pkg"
            fi
            ;;
        sysupdate)
            # The update script takes the lock itself, so do not lock here.
            exec "$(dirname "$0")/kayra-xbps-update.sh"
            ;;
    esac
    cleanup_and_exit
fi

# ---- package in repositories (not installed): offer to install -------------

if xbps-query -R "$pkg" >/dev/null 2>&1; then
    action=$(notify_action "${MSG[APP_NAME]}" \
        "$(i18n_template "${MSG[INSTALL_CONFIRM]}" PACKAGE="$pkg")" \
        "install=${MSG[ACTION_INSTALL]}") || true
    if [[ "$action" == "install" ]]; then
        check_lock
        xbps_status_set "$(i18n_template "${MSG[LOCK_INSTALL]}" PACKAGE="$pkg")"
        ret=0
        xbps_run_native pkexec xbps-install -Sy "$pkg" || ret=$?
        output="$XBPS_NATIVE_OUTPUT"
        if [[ $ret -eq 0 ]]; then
            notify_ok "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_OK]}"
        else
            notify_error "${MSG[APP_NAME]}" "$pkg"$'\n'"${MSG[INSTALL_FAIL]}"
            log ERROR "${MSG[INSTALL_FAIL]}: xbps-install $pkg msg:$output"
        fi
    fi
    cleanup_and_exit
fi

# ---- not in repositories: build from source --------------------------------

action=$(notify_action "${MSG[APP_NAME]}" \
    "$(i18n_template "${MSG[INSTALL_CONFIRM]}" PACKAGE="$pkg")" \
    "install=${MSG[ACTION_INSTALL]}") || true
if [[ "$action" == "install" ]]; then
    check_lock
    build_and_install_source "$pkg"
fi
cleanup_and_exit
