#!/usr/bin/env bash
#
# socat-link.sh - IPC, job serialization and JSON messages for Kayra OS services
#
# Source this file; do not execute it.
# All Kayra shell libraries live in /usr/local/lib/kayra/.
#
#     . /usr/local/lib/kayra/socat-link.sh
#
# MODEL
#   A runit service listens on a Unix socket:
#
#       socat UNIX-LISTEN:<sock>,fork,unlink-early
#             EXEC:flock -o -w <grace> <lock> <handler>
#
#   flock holds an exclusive lock for the whole handler; the handler is the
#   job. The kernel releases the lock when the handler exits, so there are no
#   stale locks and no unlock call. SL_LOCK_GRACE lets a racing connection
#   wait briefly for the running job instead of being dropped immediately.
#
#   Clients wait for the lock (sl_wait), then connect (sl_connect). A client
#   may send one request and close at once (fire-and-forget): sl_serve uses
#   EXEC:...,nofork, so the handler keeps running after the client disconnects.
#
#   Monitors use a separate listener that streams an append-only event file:
#
#       socat UNIX-LISTEN:<events>,fork,unlink-early,mode=0666
#             "EXEC:stdbuf -oL tail -n 0 -F <events.ndjson>,stderr"
#
#   Monitors do not take the job lock and do not see EOF when a job ends.
#
# API
#   sl_serve   <sock> <handler> [lock]   start the listener (execs socat)
#   sl_connect <sock>                    set SL_IN, SL_OUT, SL_PID
#   sl_close                             close client fds and reap socat
#   sl_wait    <lock> [seconds]          0 free, 2 busy/timeout, 1 error
#   sl_owner                             print id -un (owner field)
#   sl_msg     <type> [field=value ...]  print one NDJSON message
#
#   sl_serve derives <lock> from <sock>: foo.sock -> foo.lock.
#   sl_wait with seconds=0 is a non-blocking check; without seconds it blocks.
#   sl_connect and sl_close manage one connection; call sl_close before
#   reconnecting.
#
# MESSAGE ENVELOPE
#   Every message is one NDJSON line with the same fields:
#
#     {"v":1,"type":"req|job|evt|res","ts":"...","id":"...","owner":"...",
#      "cmd":"...","parm":[],"level":null,"event":"","msg":"",
#      "ok":null,"code":null,"data":{}}
#
#   field   type        default  meaning
#   v       int         1        envelope version
#   type    string      -        req, job, evt or res
#   ts      string      now      UTC timestamp (sl_msg)
#   id      string      ""       job identifier
#   owner   string      ""       submitter name (sl_owner), for filtering only
#   cmd     string      ""       command matched by the service handler
#   parm    array/object []      command parameters, e.g. ["cups"]
#   level   int/null    null     evt severity: 0 debug, 1 info, 2 notice,
#                                3 warn, 4 err
#   event   string      ""       event name
#   msg     string      ""       human-readable text (English)
#   ok      bool/null   null     res success flag
#   code    int/null    null     res application code
#   data    object      {}       structured payload
#
#   A command may read its parameters from parm or from data; the service
#   handler and the client agree on this per cmd. sl_msg carries both.
#
#   sl_msg special cases:
#     level, code, ok, parm, data are always interpreted as JSON.
#     Other fields are strings and are escaped by jq.
#     v, type and ts are reserved and cannot be overridden.
#
# ENVIRONMENT
#   SL_SOCK_MODE     socket mode for sl_serve          (default 0660)
#   SL_SOCK_GROUP    socket group for sl_serve         (default: unset)
#   SL_LOCK_GRACE    flock wait in seconds             (default 1)
#   SL_SOCAT         socat path                        (default: command -v)
#   SL_FLOCK         flock path                        (default: command -v)
#   SL_JQ            jq path                           (default: command -v)
#   SL_LVL_DEBUG..ERR  numeric level constants         0..4
#
# EXAMPLES
#   Job listener (runit run):
#
#     #!/bin/bash
#     exec 2>&1
#     install -d -m 0755 -o root -g root /run/myservice
#     [ -e /run/myservice/job.lock ] ||
#       install -m 0640 -o root -g kayra-admin /dev/null /run/myservice/job.lock
#     . /usr/local/lib/kayra/socat-link.sh
#     SL_SOCK_MODE=0660 SL_SOCK_GROUP=kayra-admin \
#       sl_serve /run/myservice/job.sock /usr/local/libexec/myservice/handler.sh
#
#   Handler (runit starts one process per connection; the lock is already
#   held by sl_serve):
#
#     #!/bin/bash
#     set -uo pipefail
#     trap '' PIPE
#     . /usr/local/lib/kayra/socat-link.sh
#     IFS= read -r -t 10 req || exit 0
#     id=$(jq -r '.id // empty' <<<"$req")
#     owner=$(jq -r '.owner // "unknown"' <<<"$req")
#     cmd=$(jq -r '.cmd // empty' <<<"$req")
#     emit() {
#       local l d=${4:-'{}'}
#       l=$(sl_msg evt id="$id" owner="$owner" cmd="$cmd" \
#                   level="$1" event="$2" msg="$3" data="$d")
#       printf '%s\n' "$l" >> /run/myservice/events.ndjson
#       printf '%s\n' "$l" 2>/dev/null || true
#     }
#     emit "$SL_LVL_INFO" started "job started"
#     emit "$SL_LVL_INFO" done "job finished"
#     res=$(sl_msg res id="$id" owner="$owner" ok=true code=0 msg="done")
#     printf '%s\n' "$res" >> /run/myservice/events.ndjson
#     printf '%s\n' "$res" 2>/dev/null || true
#
#   Submitter (fire-and-forget):
#
#     . /usr/local/lib/kayra/socat-link.sh
#     sl_wait /run/myservice/job.lock 300 || exit 2
#     sl_connect /run/myservice/job.sock || exit 1
#     id="$(date +%s%N)-$$"
#     req=$(sl_msg req id="$id" owner="$(sl_owner)" cmd=do parm='["x"]')
#     printf '%s\n' "$req" >&"$SL_OUT"
#     sl_close
#
#   Monitor:
#
#     . /usr/local/lib/kayra/socat-link.sh
#     me=$(sl_owner)
#     tail -n 0 -F /run/myservice/events.ndjson |
#       jq -c --arg me "$me" 'select(.owner == $me)'
#
# FILES AND PERMISSIONS
#   /run/<service>/           0755 root:root
#   <service>.lock            0640 root:<group>
#   <service>.sock            0660 root:<group>
#   events.ndjson             0644 root:root  (readable by all, by design)
#   events.sock               0666 root:root  (readable by all, by design)
#
# DEPENDENCIES
#   bash >= 4.3, socat, util-linux (flock), coreutils (id, tail, stdbuf)
#   jq is required only by sl_msg.
#
# SECURITY
#   - Socket permissions are the authorization boundary.
#   - owner is self-declared; never use it for authorization.
#   - Never pass client data to eval, a shell, or unquoted command lines.
#   - Handlers must validate cmd, parm and data, and bound message sizes.
#   - A client disconnect must not abort a transaction: use nofork, trap PIPE
#     and ignore socket write errors.
#

SL_SOCAT=${SL_SOCAT:-$(command -v socat 2>/dev/null || true)}
SL_FLOCK=${SL_FLOCK:-$(command -v flock 2>/dev/null || true)}
SL_JQ=${SL_JQ:-$(command -v jq 2>/dev/null || true)}

SL_LVL_DEBUG=0
SL_LVL_INFO=1
SL_LVL_NOTICE=2
SL_LVL_WARN=3
SL_LVL_ERR=4

sl_serve() {  # sl_serve <sock> <handler> [lock]   (execs socat)
  local sock=${1:?socket path required}
  local handler=${2:?handler path required}
  local lock=${3:-${sock%.sock}.lock}

  [[ -n $SL_SOCAT ]] || { echo "socat-link: socat not found" >&2; return 4; }
  [[ -n $SL_FLOCK ]] || { echo "socat-link: flock not found" >&2; return 4; }

  exec "$SL_SOCAT" \
    "UNIX-LISTEN:${sock},fork,unlink-early,mode=${SL_SOCK_MODE:-0660}${SL_SOCK_GROUP:+,group=${SL_SOCK_GROUP}}" \
    "EXEC:${SL_FLOCK} -o -w ${SL_LOCK_GRACE:-1} -E 2 ${lock} ${handler},nofork,stderr"
}

sl_connect() {  # sl_connect <sock> -> SL_IN, SL_OUT, SL_PID
  local sock=${1:?socket path required}
  [[ -n $SL_SOCAT ]] || return 1
  [[ -S $sock ]] || return 1
  coproc SL { exec "$SL_SOCAT" -t 0.1 - "UNIX-CONNECT:${sock}"; }
  SL_IN=${SL[0]}
  SL_OUT=${SL[1]}
}

sl_close() {
  if [[ -n ${SL_OUT:-} ]]; then exec {SL_OUT}>&- 2>/dev/null || true; fi
  if [[ -n ${SL_IN:-}  ]]; then exec {SL_IN}<&-  2>/dev/null || true; fi
  if [[ -n ${SL_PID:-} ]]; then wait "$SL_PID" 2>/dev/null || true; fi
  unset SL_IN SL_OUT SL_PID
}

sl_wait() {  # sl_wait <lock> [seconds] -> 0 free, 2 busy/timeout, 1 error
  local lock=${1:?lock path required}
  [[ -n $SL_FLOCK ]] || return 1
  if [[ -n ${2:-} ]]; then
    "$SL_FLOCK" -s -w "$2" -E 2 "$lock" -c true
  else
    "$SL_FLOCK" -s -E 2 "$lock" -c true
  fi
}

sl_owner() {  # owner field: effective user name
  id -un 2>/dev/null || printf 'unknown\n'
}

sl_msg() {  # sl_msg <req|job|evt|res> [field=value | field:=json ...]
  local type=${1:?message type required}; shift
  case $type in req|job|evt|res) ;; *)
    echo "sl_msg: invalid type: $type" >&2; return 2 ;;
  esac
  [[ -n $SL_JQ ]] || { echo "socat-link: jq not found" >&2; return 4; }

  local -a a=(--arg type "$type" --arg ts "$(date -u +%FT%TZ)")
  local kv k v json
  for kv in "$@"; do
    [[ $kv == *=* ]] || { echo "sl_msg: 'field=value' expected: $kv" >&2; return 2; }
    k=${kv%%=*}; v=${kv#*=}
    [[ -n $k ]] || { echo "sl_msg: empty field name" >&2; return 2; }
    json=0
    if [[ $k == *: ]]; then k=${k%:}; json=1; fi
    case $k in
      v|type|ts)         echo "sl_msg: '$k' is reserved" >&2; return 2 ;;
      level)             [[ $v =~ ^[0-4]$ ]] ||
                           { echo "sl_msg: level must be 0..4" >&2; return 2; }
                         json=1 ;;
      code|ok|parm|data) json=1 ;;
    esac
    if (( json )); then a+=(--argjson "$k" "$v")
    else                 a+=(--arg "$k" "$v"); fi
  done

  "$SL_JQ" -cn "${a[@]}" '
    {v:1,type:"",ts:"",id:"",owner:"",cmd:"",parm:[],
     level:null,event:"",msg:"",ok:null,code:null,data:{}}
    + $ARGS.named'
}
