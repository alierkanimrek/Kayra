#!/usr/bin/env bash
#
# kayra-first-run-groups.sh - Prepare the installation user once.
#
# Called from /etc/runit/core-services/07-first-run-actions.sh on the first
# boot of an installed system. It never runs in the live/installer session and
# it is not called again after the first-boot marker exists.
#
# The script finds the first regular user (the lowest UID in the
# UID_MIN..UID_MAX range, normally the user created by the installer), creates
# the kayra-admin group when it is missing, and adds that user to:
#
#   wheel          sudo/polkit
#   kayra-admin    Kayra root services
#   required_groups from /etc/default/kayra.conf
#
# wheel is not part of required_groups: only this one-time helper grants it.
# The script is idempotent; running it manually as root only re-applies the
# same memberships.
#
# Usage: kayra-first-run-groups.sh
#
# Used commands: getent, groupadd, usermod, awk, sort, head, cut, logger,
#                settings-conf.sh (system_conf_get)
#

set -uo pipefail
export LC_ALL=C.UTF-8
PATH=/usr/bin:/usr/sbin:/bin:/sbin
umask 027

ADMIN_GROUP="kayra-admin"

log() {  # log <level> <message>
    logger -t kayra-first-run -p "user.$1" -- "$2" 2>/dev/null || true
}

# Only root can change group membership.
(( EUID == 0 )) || exit 0

# 07-first-run-actions.sh already returns early in the live session. Keep a
# manual run harmless as well.
[ -d /run/initramfs/live ] && exit 0

UID_MIN=$(awk '$1 == "UID_MIN" { print $2; exit }' /etc/login.defs 2>/dev/null)
UID_MAX=$(awk '$1 == "UID_MAX" { print $2; exit }' /etc/login.defs 2>/dev/null)
[[ $UID_MIN =~ ^[0-9]+$ ]] || UID_MIN=1000
[[ $UID_MAX =~ ^[0-9]+$ ]] || UID_MAX=65533

# The first regular user is the installation user on a fresh system.
USER_NAME=$(getent passwd 2>/dev/null |
    awk -F: -v min="$UID_MIN" -v max="$UID_MAX" \
        '$3 >= min && $3 <= max { print $3 "\t" $1 }' |
    sort -n | head -n 1 | cut -f2)

if [ -z "$USER_NAME" ]; then
    log warn "No regular user found; group initialization skipped"
    exit 0
fi

if ! getent group "$ADMIN_GROUP" >/dev/null 2>&1; then
    groupadd -r "$ADMIN_GROUP" || {
        log err "Could not create group $ADMIN_GROUP"
        exit 1
    }
fi

. /usr/local/lib/kayra/settings-conf.sh

REQUIRED_GROUPS=$(system_conf_get required_groups | head -n1 || true)

# The installation user always gets wheel and kayra-admin.
GROUP_LIST="$ADMIN_GROUP wheel"

for group in $REQUIRED_GROUPS; do
    case " $GROUP_LIST " in
        *" $group "*) continue ;;
    esac
    GROUP_LIST="$GROUP_LIST $group"
done

# Keep only groups that exist. The user's primary group is ignored by
# usermod -aG, so it needs no special case.
GROUPS_CSV=""
for group in $GROUP_LIST; do
    getent group "$group" >/dev/null 2>&1 || continue
    GROUPS_CSV="${GROUPS_CSV:+$GROUPS_CSV,}$group"
done

if [ -z "$GROUPS_CSV" ]; then
    log warn "No groups to add for user $USER_NAME"
    exit 0
fi

if usermod -aG "$GROUPS_CSV" "$USER_NAME"; then
    log info "Initialized groups for $USER_NAME: $GROUPS_CSV"
else
    log err "Could not add groups for $USER_NAME: $GROUPS_CSV"
    exit 1
fi
