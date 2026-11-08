#!/usr/bin/env bash
#
# nvidia-detect.sh - Find the NVIDIA driver package matching this system's GPU.
#
# Void Linux ships several NVIDIA driver branches: the unversioned "nvidia"
# package (newest branch) plus the legacy branches nvidia580 / nvidia470 /
# nvidia390. This script detects the NVIDIA GPU(s) present, determines which
# branch actually supports them using NVIDIA's official supported-GPU list,
# and offers to install the matching package through kayra-xbps.sh.
#
# How it works:
#   1. Enumerate NVIDIA GPUs (vendor 10de, display/3D classes) with lspci and
#      collect their PCI device IDs.
#   2. Ask the XBPS repositories for the newest NVIDIA branch and its version.
#   3. Download that branch's README/supportedchips.html from NVIDIA.
#        * A device ID in the main "Supported NVIDIA GPU Products" table is
#          supported by the newest branch.
#        * A device ID listed under a "legacy_XXX.xx" section needs that legacy
#          branch instead (the README states which branch supports it).
#   4. Map the branch to the Void package (nvidia / nvidia580 / nvidia470 /
#      nvidia390), compare it with what is installed, and, when the right
#      package is missing, ask the user and install it with kayra-xbps.sh.
#
# Note: on an Optimus laptop (Intel + NVIDIA) use prime-run to offload a
# program to the NVIDIA GPU.
#
# Commands used: lspci, xbps-query, curl, awk, sed, grep, sort, tr, mkdir,
#                mktemp, mv, rm, dirname, printf, date.
#
# Usage: nvidia-detect.sh
#
set -uo pipefail
export LC_ALL=C.UTF-8

source "$(dirname "$0")/i18n.sh"
declare -n MSG=i18n_NVIDIA_DETECT

source "$(dirname "$0")/klog.sh"
source "$(dirname "$0")/notify.sh"

# Material Symbols "memory" (chip) icon for the notifications.
ICON_GPU=$(printf '%b' '\U000E322')

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/kayra/nvidia-detect"
NVIDIA_LIST_BASE="https://download.nvidia.com/XFree86/Linux-x86_64"

# Detect the NVIDIA GPUs and print "device-id<TAB>name" for each of them.
# Device IDs are lower-case hexadecimal without the "0x" prefix (e.g. "1d11").
detect_gpus() {
    lspci -nn 2>/dev/null \
        | grep -E '\[10de:[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]\]' \
        | grep -E '\[03(00|02|80)\]' \
        | awk '{
            line = $0
            id = ""
            if (match(line, /\[10de:[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]\]/)) {
                id = substr(line, RSTART + 6, 4)
                id = tolower(id)
            }
            name = line
            sub(/^.*: /, "", name)
            sub(/ \[10de:[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]\].*$/, "", name)
            sub(/^NVIDIA Corporation /, "", name)
            print id "\t" name
        }'
}

# List the NVIDIA branch packages available in the repositories as
# "name<TAB>version", newest version first.
list_branch_packages() {
    xbps-query -R -s '^nvidia[0-9]*-[0-9]' --regex 2>/dev/null \
        | awk '{print $2}' \
        | sed -E 's/^([^-]+)-(.+)$/\1\t\2/' \
        | sort -t $'\t' -k2 -r
}

# Print the version (no revision) of a package available in the repositories.
repo_version() {
    local pkgver
    pkgver="$(xbps-query -R -p pkgver "$1" 2>/dev/null)"
    pkgver="${pkgver##*-}"
    printf '%s\n' "${pkgver%_*}"
}

# Download the supported-GPU list of the given driver version and print the
# path of the cached file. Returns non-zero when the download fails.
fetch_supported_list() {
    local ver="$1" cache tmp
    cache="$CACHE_DIR/supportedchips-${ver}.html"

    if [[ -s "$cache" ]]; then
        printf '%s\n' "$cache"
        return 0
    fi

    mkdir -p "$CACHE_DIR" || return 1
    tmp="$(mktemp "$CACHE_DIR/.supportedchips.XXXXXX")" || return 1

    if curl -fsSL --max-time 30 \
        "$NVIDIA_LIST_BASE/$ver/README/supportedchips.html" -o "$tmp"; then
        mv "$tmp" "$cache"
        printf '%s\n' "$cache"
        return 0
    fi

    rm -f "$tmp"
    return 1
}

# Print the driver branch that supports the given device ID: "main" for the
# newest branch, the legacy branch number (e.g. "580") for a legacy GPU, or
# "unknown" when the device is not listed at all.
resolve_branch() {
    local html="$1" devid="$2"
    awk -v want="devid${devid^^}" '
        /legacy_[0-9]+\.xx/ {
            match($0, /legacy_[0-9]+/)
            cur = substr($0, RSTART + 7, RLENGTH - 7)
        }
        $0 ~ ("id=\"" want "\"") { print (cur == "" ? "main" : cur); found = 1; exit }
        END { if (!found) print "unknown" }
    ' "$html"
}

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------
for cmd in lspci curl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log ERROR "Required command not found: $cmd"
        notify_error "${MSG[APP_NAME]}" "$(i18n_template "${MSG[MISSING_CMD]}" COMMAND="$cmd")"
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# 1. Detect the NVIDIA GPUs
# ---------------------------------------------------------------------------
mapfile -t GPUS < <(detect_gpus)

if (( ${#GPUS[@]} == 0 )); then
    log WARN "No NVIDIA GPU found"
    notify_warn "${MSG[APP_NAME]}" "${MSG[NO_GPU]}"
    exit 0
fi

mapfile -t GPU_IDS   < <(printf '%s\n' "${GPUS[@]}" | awk -F'\t' '{print $1}')
mapfile -t GPU_NAMES < <(printf '%s\n' "${GPUS[@]}" | awk -F'\t' '{print $2}')
GPU_NAMES_JOINED="$(printf '%s, ' "${GPU_NAMES[@]}")"
GPU_NAMES_JOINED="${GPU_NAMES_JOINED%, }"
log INFO "Detected NVIDIA GPU(s): ${GPU_NAMES_JOINED}"

# ---------------------------------------------------------------------------
# 2. Newest NVIDIA branch in the repositories
# ---------------------------------------------------------------------------
mapfile -t BRANCHES < <(list_branch_packages)

if (( ${#BRANCHES[@]} == 0 )); then
    log ERROR "No NVIDIA driver package found in the repositories"
    notify_error "${MSG[APP_NAME]}" "${MSG[REPO_EMPTY]}"
    exit 1
fi

# Pick the branch with the highest major version number.
mapfile -t NEWEST < <(
    printf '%s\n' "${BRANCHES[@]}" | awk -F'\t' '
        {
            ver = $2
            sub(/_.*$/, "", ver)
            split(ver, p, ".")
            major = p[1] + 0
            if (major > best) { best = major; bn = $1; bv = ver }
        }
        END { print bn; print bv }
    '
)
NEWEST_PKG="${NEWEST[0]:-}"
NEWEST_VER="${NEWEST[1]:-}"
log INFO "Newest NVIDIA branch: ${NEWEST_PKG} (${NEWEST_VER})"

# ---------------------------------------------------------------------------
# 3. Official supported-GPU list of the newest branch
# ---------------------------------------------------------------------------
if ! SC_HTML="$(fetch_supported_list "$NEWEST_VER")"; then
    log ERROR "Could not download the supported GPU list for $NEWEST_VER"
    notify_error "${MSG[APP_NAME]}" "${MSG[DOWNLOAD_FAIL]}"
    exit 1
fi

# ---------------------------------------------------------------------------
# 4. Decide which package supports the detected GPUs
# ---------------------------------------------------------------------------
TARGET_PKG=""
TARGET_MAJOR=-1
UNSUPPORTED_GPUS=""

for i in "${!GPU_IDS[@]}"; do
    id="${GPU_IDS[$i]}"
    name="${GPU_NAMES[$i]}"
    branch="$(resolve_branch "$SC_HTML" "$id")"

    case "$branch" in
        main)    pkg="$NEWEST_PKG" ;;
        unknown) pkg="" ;;
        *)       pkg="nvidia${branch}" ;;
    esac

    # Verify the branch is packaged by Void (a legacy branch may be absent).
    if [[ -n "$pkg" && "$pkg" != "$NEWEST_PKG" ]] && ! xbps-query -R "$pkg" >/dev/null 2>&1; then
        pkg=""
    fi

    if [[ -z "$pkg" ]]; then
        log WARN "No repository driver supports $name ($id, branch: $branch)"
        UNSUPPORTED_GPUS="${UNSUPPORTED_GPUS:+$UNSUPPORTED_GPUS, }$name"
        continue
    fi

    # Rank the package by branch: "nvidia" (newest) ranks highest.
    major=99999
    [[ "$pkg" =~ ^nvidia([0-9]+)$ ]] && major="${BASH_REMATCH[1]}"
    if (( major > TARGET_MAJOR )); then
        TARGET_MAJOR=$major
        TARGET_PKG="$pkg"
    fi
done

if [[ -z "$TARGET_PKG" ]]; then
    log ERROR "No driver package supports the detected GPU(s)"
    notify_error "${MSG[APP_NAME]}" \
        "$(i18n_template "${MSG[UNSUPPORTED]}" GPU="$GPU_NAMES_JOINED")"
    exit 1
fi

TARGET_REPO_VER="$(repo_version "$TARGET_PKG")"
RECOMMEND_MSG="$(i18n_template "${MSG[RECOMMEND]}" GPU="$GPU_NAMES_JOINED" PACKAGE="$TARGET_PKG")"
log INFO "Recommended driver package: $TARGET_PKG ($TARGET_REPO_VER)"

# ---------------------------------------------------------------------------
# 5. Compare with the installed state and offer to install
# ---------------------------------------------------------------------------
# Other NVIDIA branch packages installed on the system (potential conflicts).
mapfile -t OTHER_BRANCHES < <(
    xbps-query -l 2>/dev/null | awk '{print $2}' \
        | grep -E '^nvidia[0-9]*-[0-9]' \
        | sed -E 's/^([^-]+)-.*$/\1/' \
        | grep -vx "$TARGET_PKG" \
        | sort -u
)

CONFLICT_MSG=""
if (( ${#OTHER_BRANCHES[@]} > 0 )); then
    CONFLICT_MSG="$(i18n_template "${MSG[CONFLICT]}" PACKAGES="$(printf '%s, ' "${OTHER_BRANCHES[@]}" | sed 's/, $//')")"
    log WARN "Other NVIDIA branch package(s) installed: ${OTHER_BRANCHES[*]}"
fi

if xbps-query -S "$TARGET_PKG" >/dev/null 2>&1; then
    # The right package is already installed.
    INSTALLED_VER="$(xbps-query -p pkgver "$TARGET_PKG" 2>/dev/null)"
    INSTALLED_VER="${INSTALLED_VER##*-}"
    INSTALLED_VER="${INSTALLED_VER%_*}"

    if [[ "$INSTALLED_VER" == "$TARGET_REPO_VER" ]]; then
        body="$RECOMMEND_MSG"$'\n'"$(i18n_template "${MSG[ALREADY_OK]}" PACKAGE="$TARGET_PKG" VERSION="$INSTALLED_VER")"
        [[ -n "$CONFLICT_MSG" ]] && body="$body"$'\n'"$CONFLICT_MSG"
        log INFO "$TARGET_PKG is installed and up to date ($INSTALLED_VER)"
        notify_ok "${MSG[APP_NAME]}" "$body"
    else
        body="$RECOMMEND_MSG"$'\n'"$(i18n_template "${MSG[UPDATE_INFO]}" INSTALLED="$INSTALLED_VER" AVAILABLE="$TARGET_REPO_VER")"$'\n'"${MSG[UPDATE_HINT]}"
        [[ -n "$CONFLICT_MSG" ]] && body="$body"$'\n'"$CONFLICT_MSG"
        log INFO "$TARGET_PKG is outdated ($INSTALLED_VER -> $TARGET_REPO_VER)"
        notify_warn "${MSG[APP_NAME]}" "$body"
    fi
    exit 0
fi

# The right package is missing: ask the user and install it via kayra-xbps.sh.
body="$RECOMMEND_MSG"$'\n\n'"$(i18n_template "${MSG[INSTALL_CONFIRM]}" PACKAGE="$TARGET_PKG")"
[[ -n "$CONFLICT_MSG" ]] && body="$body"$'\n'"$CONFLICT_MSG"

NOTIFY_ICON="$ICON_GPU"
action="$(notify_action "${MSG[APP_NAME]}" "$body" "install=${MSG[ACTION_INSTALL]}")" || true
unset NOTIFY_ICON

if [[ "$action" == "install" ]]; then
    log INFO "Installing $TARGET_PKG through kayra-xbps.sh"
    "$(dirname "$0")/kayra-xbps.sh" "$TARGET_PKG"
else
    log INFO "Installation of $TARGET_PKG cancelled by the user"
fi

exit 0
