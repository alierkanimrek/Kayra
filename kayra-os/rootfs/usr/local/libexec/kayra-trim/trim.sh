#!/bin/bash
#
# trim.sh - run one periodic SSD TRIM pass for kayra-trim.
#
# Trims every mounted filesystem that supports discard. The output is written
# to the service log with logger. The snooze time file is touched even when
# fstrim fails, so a failure cannot make the supervised service retry in a
# tight loop; the next attempt is one week later.
#
# Used commands: fstrim (util-linux), install, logger, timeout, touch
#

exec 2>&1

export LC_ALL=C.UTF-8
PATH=/usr/bin:/usr/sbin:/bin:/sbin
umask 027

STATE_DIR="/var/lib/kayra-trim"
TIMEFILE="$STATE_DIR/last-run"

install -d -m 0755 -o root -g root "$STATE_DIR" || exit 1

logger -t kayra-trim -p user.info "Starting weekly TRIM (fstrim -av)" 2>/dev/null || true

output=$(timeout 5m fstrim -av 2>&1)
rc=$?

if [ -n "$output" ]; then
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        logger -t kayra-trim -p user.info -- "$line" 2>/dev/null || true
    done <<<"$output"
fi

# snooze schedules from the mtime of the time file. Touch it even on failure
# so a broken filesystem does not cause an immediate retry after the restart.
touch "$TIMEFILE" ||
    logger -t kayra-trim -p user.err \
        "Cannot update time file: $TIMEFILE" 2>/dev/null || true

if (( rc == 0 )); then
    logger -t kayra-trim -p user.info "Weekly TRIM finished" 2>/dev/null || true
else
    logger -t kayra-trim -p user.err \
        "Weekly TRIM finished with errors (fstrim exit $rc)" 2>/dev/null || true
fi

exit "$rc"
