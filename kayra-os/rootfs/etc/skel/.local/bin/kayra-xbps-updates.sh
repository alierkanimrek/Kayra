#!/usr/bin/env bash
#
# kayra-xbps-updates.sh - Shared "available updates" helpers (source it; do not execute).
#
# Lists the packages that have an update available:
#   * repository packages: from a fresh in-memory repository sync
#     (xbps-install -un -M). The -M flag fetches the repodata into memory, so it
#     works without root and never writes to /var/db/xbps.
#   * source packages: installed from a local repository (built with xbps-src)
#     and outdated in the void-packages tree (xbps-checkvers).
#
# The heavy commands run under nice to keep the CPU cost low.
#
# Functions:
#   local_source_pkgs   Names of the installed packages built from source.
#   xbps_updatable_pkgs Prints "name<TAB>type" per available update (type is
#                       "repo" or "source"). Returns non-zero when the
#                       repository check failed (e.g. offline), so callers can
#                       keep their previous state.
#
# Used commands: xbps-install, xbps-query, xbps-checkvers, nice, awk, comm,
#                sort, head, ls, printf.
#
# Usage:
#   source "$(dirname "$0")/kayra-xbps-updates.sh"
#   xbps_updatable_pkgs | while IFS=$'\t' read -r name type; do ...; done

export LC_ALL=C.UTF-8

# Directory of the local void-packages checkout (can be overridden by callers).
PACKAGES_DIR="${PACKAGES_DIR:-/var/spool/void-packages}"

# Names of the installed packages that come from a local repository (built
# from source), one per line. The package database plist is parsed in a single
# pass (fast); the slow per-package query is kept as a fallback. In the plist
# the top level keys are package names and every package dict carries a
# "repository" string, which is a local path for source-built packages.
local_source_pkgs() {
    local plist
    plist=$(ls /var/db/xbps/pkgdb-*.plist 2>/dev/null | head -n1)
    if [[ -n "$plist" && -r "$plist" ]]; then
        awk '
            /^[[:space:]]<key>/ {
                line = $0
                sub(/^[[:space:]]*<key>/, "", line)
                sub(/<\/key>.*/, "", line)
                name = line
            }
            /<key>repository<\/key>/ { want = 1; next }
            want {
                if (match($0, /<string>.*<\/string>/)) {
                    v = substr($0, RSTART + 8, RLENGTH - 17)
                    if (v !~ /^http/) print name
                }
                want = 0
            }
        ' "$plist"
        return
    fi

    xbps-query -l 2>/dev/null | awk '{ print $2 }' | while read -r pkgver; do
        [[ -n "$pkgver" ]] || continue
        repo=$(xbps-query --property repository "$pkgver" 2>/dev/null || true)
        case "$repo" in
            http*|"") continue ;;
        esac
        name="${pkgver%_*}"
        printf '%s\n' "${name%-*}"
    done
}

# All available updates, one "name<TAB>type" per line (type: repo|source).
xbps_updatable_pkgs() {
    local name repo_raw rc=0

    # Repository updates: fresh repodata fetched into memory (no root).
    repo_raw=$(nice -n 19 xbps-install -un -M 2>/dev/null) || rc=$?
    if [[ $rc -eq 0 && -n "$repo_raw" ]]; then
        printf '%s\n' "$repo_raw" | awk '$2 == "update" { print $1 }' | while read -r pkgver; do
            [[ -n "$pkgver" ]] || continue
            name="${pkgver%_*}"
            printf '%s\trepo\n' "${name%-*}"
        done
    fi

    # Source updates: installed from a local repo and outdated in the tree.
    comm -12 \
        <(local_source_pkgs | sort -u) \
        <(nice -n 19 xbps-checkvers -f '%n' -I -D "$PACKAGES_DIR" 2>/dev/null | sort -u) |
        while read -r name; do
            [[ -n "$name" ]] && printf '%s\tsource\n' "$name"
        done

    return "$rc"
}
