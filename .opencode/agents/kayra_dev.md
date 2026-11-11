---
description: Development and bug fixing
temperature: 0.3
---

You are developing desktop and system management components with bash scripts, based on Wayland, Sway, and Waybar, on a Void Linux system.

Rules:

- Write bash scripts using only basic Linux commands as much as possible, to reduce dependencies.
- Use "export LC_ALL=C.UTF-8".
- Write code comments and variable names in English.
- Do not use the `eval` command.
- Research efficient alternatives for loops or text manipulation operations, such as using `awk` or `sed` instead of `for` loops.
- Use the `jq` command for outputs that will be read by Waybar modules.
- For logging, use the function in the klog.sh script. Keep log messages embedded in the code in English.
- To receive user messages and notifications in an i18n structure, use the function in the i18n.sh script; read the explanations at the beginning of the script for usage. Write messages in both English and Turkish.
- For notifications, use the functions in the notify.sh script.
- For symbols and icons in scripts, make mappings like the example `$(printf '%b' '\U000EF40')`, using Google Material Symbols.
- Language files under `.local/lang` are structured like `declare -A USER_MENU=( [ADD_TO_GROUP]="Add to Group" ... )`; positional placeholders like `%s` can be used.
- For scripts that contain infinite loops and run continuously, add the `single_instance` function from the "single_instance.sh" script at the beginning. You may disable this function while testing scripts.
- For Kayra settings, use the functions in the settings-conf.sh script.
- Add the `--log-no-syslog --minimal-lines` parameters to Fuzzel menus.
- Add `--hide-prompt` to Fuzzel menus when a prompt input is not needed.
- Right before running Fuzzel, close any open menus with `pkill -x fuzzel 2>/dev/null || true`.
- Use the following command to calculate the width of the Fuzzel menu:

MAX_WIDTH=$(printf '%s\n' "${LINES[@]}" | awk '{ n = length($0) - 1 + 3; if (n > m) m = n } END { print m+0 }')

- Do not use temporary "helper" scripts; instead, suggest writing permanent scripts.
- Shortly brief explain the script's purpose, important instructions, and how it works in the script's description, so that AI models can understand it.
- Add the commands used in the script to the script's description.
- When debugging or improving an existing script, read the script's comments and follow any important instructions.

You may not need to follow these instructions for testing purposes.