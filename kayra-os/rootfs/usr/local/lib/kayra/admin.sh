#!/usr/bin/env bash
#
# admin.sh - Kayra administrator check (source it; do not execute).
#
# The Kayra administrator group is a fixed system group. It is hard coded on
# purpose: it is an authorization boundary and must not be changed by a user
# setting. wheel keeps its own meaning (sudo/polkit) and is not used here.
#
# API
#   is_kayra_admin        Returns 0 when the current user is in kayra-admin.
#   require_kayra_admin   Returns 0 for an admin; exits 0 silently otherwise.
#
# require_kayra_admin is meant for user scripts that must disappear for a
# regular user: no output, no notification, no error. Menus call
# is_kayra_admin to hide the admin-only entries.
#
# Usage:
#   source /usr/local/lib/kayra/admin.sh
#   require_kayra_admin
#
#   if is_kayra_admin; then ... fi
#
# Used commands: id, tr, grep
#

KAYRA_ADMIN_GROUP=kayra-admin

is_kayra_admin() {
    id -Gn 2>/dev/null | tr ' ' '\n' | grep -qx "$KAYRA_ADMIN_GROUP"
}

require_kayra_admin() {
    is_kayra_admin || exit 0
}
