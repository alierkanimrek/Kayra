---
description: Kayra OS user and service script development
temperature: 0.3
---

You develop Kayra OS bash components on Void Linux. Classify each file first:

- **User script**: runs in the desktop session (Wayland, Sway, Waybar,
  Fuzzel); lives in `/usr/local/bin/` as `kayra-*`; runs as the logged-in user.
- **Service script**: runit-supervised; lives in
  `/usr/local/libexec/<service>/` and `/etc/sv/<name>/`; runs as root and has
  no desktop session.

A task may contain both; apply each section to the relevant file. On
conflict, class rules override shared rules.

## Paths

Source -> live target:

- User commands: `kayra-os/rootfs/usr/local/bin/kayra-*` -> `/usr/local/bin/`.
- Libraries: `kayra-os/rootfs/usr/local/lib/kayra/` -> `/usr/local/lib/kayra/`.
- Static data: `kayra-os/rootfs/usr/local/share/kayra/` -> `/usr/local/share/kayra/`
  (`lang/<code>.sh`, `data/`). `kayra-generate-keyboard-data.sh` regenerates
  `data/` and therefore runs as root.
- Generated user data: `~/.cache/kayra/` (for example `devices.json`); the
  scripts that produce it run as the user, so it never goes under `/usr/local`.
- Services: `usr/local/libexec/<service>/` and `etc/sv/<service>/`.
- Generated system data (services): `/var/cache/kayra/`; never under `$HOME`.
- Service runtime: `/run/<service>/` (sockets, lock, events).
- User settings: `~/.config/kayra/settings.conf` (`lang=<code>`), via
  `settings-conf.sh`.
- Deploy: `sudo utils/kayra-deploy <scripts|lang|data|services|core|config|all>`;
  the tool itself is not installed.

## Shared

**Do**
- Use bash and minimal dependencies; add required packages to
  `kayra-os/packages.txt` and document them in the script header.
- `export LC_ALL=C.UTF-8`.
- Write comments, variable names, and log messages in English.
- Quote variables, validate input, and fail with a clear message.
- Prefer `awk`/`sed` over shell loops for text processing.
- Use `jq` for JSON.
- Write permanent scripts with a header: purpose, usage, commands used.
- Read existing comments and follow them before editing.
- Test without damaging the running system.

**Don't**
- No `eval`; no shell interpolation of untrusted data.
- No secrets in logs.
- No temporary helper scripts.
- No destructive tests on the host.

## User scripts

**Do**
- Name user scripts `kayra-*` and deploy with
  `sudo utils/kayra-deploy scripts`.
- Source libraries with absolute paths from `/usr/local/lib/kayra/`.
- Read the UI language from `lang` in `settings.conf` via `settings-conf.sh`;
  never use a `lang/current.sh` symlink.
- Log with `klog.sh` ; with embedded only English messages.
- Notify with `notify.sh`; use translated messages with `i18n.sh`. use Material Symbols codepoints.
- Read/write settings with `settings-conf.sh`.
- Guard continuous loops with `single_instance.sh`.
- Fuzzel: `--log-no-syslog --minimal-lines`; `--hide-prompt` when no input
  is needed; `pkill -x fuzzel 2>/dev/null || true` before opening.
- Fuzzel width:
  `MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')`
- Use `jq` for Waybar module output.

**Don't**
- Don't install new user scripts into service directories
  (`/usr/local/libexec`, `/etc/sv`); only `/usr/local/bin/kayra-*`.
- Don't call `notify-send` directly.
- Don't hardcode user-facing English; use i18n.
- Don't run a permanent loop without a single-instance guard.

## Service scripts

**Do**
- Keep system files `root:root` and not writable by users.
- `run` script: `#!/bin/bash`, `exec 2>&1`, fixed `PATH`, restrictive
  `umask`, and `exec` the real process.
- Set `LC_ALL=C.UTF-8` and absolute paths; never inherit a user environment.
- Log with `logger -t <tag> -p user.<level>`; levels `0=debug 1=info
  2=notice 3=warn 4=err`; English, single line, no ANSI.
- Serialize jobs with `flock` on `/run/<service>/<name>.lock`
  (`0640 root:<group>`); the kernel releases it on exit.
- Keep runtime files in `/run/<service>/`; sockets `0660` + service group,
  `unlink-early`.
- Validate input, whitelist `cmd`, bound message size.
- `trap '' PIPE`; write the event stream before the client socket; ignore
  socket write errors.
- Bound work with timeouts; finish the transaction on client disconnect.
- Use NDJSON with the standard envelope; build messages with `jq`.
- Use `/usr/local/lib/kayra/socat-link.sh` for IPC and locking; read its header.
- Test with a temporary runtime directory and dry-run; destructive tests in
  a VM or ISO.

**Don't**
- Don't use `klog.sh`, `i18n.sh`, `notify.sh`, `settings-conf.sh`, or
  `single_instance.sh`.
- Don't rely on `$HOME`, user `PATH`, Wayland, DBus, polkit, Fuzzel, or
  Waybar.
- Don't background, `nohup`, or self-daemonize; runit supervises.
- Don't use PID files or stale locks; `flock` is the only lock.
- Don't put sockets in `/tmp`.
- Don't trust `owner` for authorization; socket permissions authorize.
- Don't use `set -e` where a client disconnect would abort a transaction.

## Library headers

Read the library header before use; signatures, return codes, and examples
belong there, not in this file:

- User: `klog.sh`, `i18n.sh`, `notify.sh`, `settings-conf.sh`,
  `single_instance.sh`.
- Service: `/usr/local/lib/kayra/socat-link.sh` (job socket, lock, monitor
  stream, JSON messages).

Do not duplicate their API or examples here.
