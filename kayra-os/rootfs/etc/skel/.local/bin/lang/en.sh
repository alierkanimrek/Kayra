#!/bin/bash

declare -A i18n=(
  [WELCOME]="Welcome"
  [NOT_INSTALLED]="{BIN} is not installed"
  [OPERATION_CANCELLED]="Operation cancelled"
  [SUCCESS]="Success"
  [ERROR]="Error"
  [FAILED]="Failed"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A user_menu=(
  ["Change Password"]="change-passwd.sh"
  ["Add to Group"]="group-add.sh --anchor=top-right"
  ["Remove from Group"]="group-remove.sh --anchor=top-right"
  ["Home Directory Usage"]="home-usage.sh"
)

declare -A settings_menu=(
  ["Appearance & Theme"]="appearance-settings.sh"
  ["Language"]="language-settings.sh"
  ["Keyboard"]="keyboard-settings.sh"
  ["Display"]="display-settings.sh"
  ["System"]="system-menu.sh"
)

declare -A system_menu=(
  ["Log Monitor"]="toggle-log-monitor.sh"
)

declare -A appearance_menu=(
  ["Font"]="font-settings.sh"
  ["Font Size"]="font-size-settings.sh"
  ["Change Theme"]="/usr/bin/nwg-look"
  ["Auto Theme"]="toggle-auto-theme.sh"
  ["Wallpaper"]="change-wallpaper.sh"
)

declare -A i18n_HOME_USAGE=(
  [NOTIFY_TITLE]="Home directory size"
  [NOTIFY_MSG]="{HOME} directory uses {USAGE} of storage."
  [NOTIFY_BUTTON]="Open Baobab"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_CHANGE_PASSWD=(
  [PROMPT_CURRENT]="Current password: "
  [PROMPT_NEW]="New password: "
  [PROMPT_NEW_REPEAT]="New password (again): "
  [NOTIFY_TITLE]="Password change"
  [MSG_NOT_INSTALLED]="{BIN} is not installed (xbps-install -S {BIN})"
  [MSG_CANCELLED]="Operation cancelled"
  [MSG_MISMATCH]="New passwords do not match."
  [MSG_SUCCESS]="Password changed successfully."
  [MSG_FAILED]="Password change failed. Current password may be incorrect."
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_WIFI_MENU=(
  [NOTIFY_DEVICE_NOT_FOUND]="Wifi device not found"
  [NOTIFY_NO_NETWORKS]="No networks found nearby"
  [PROMPT_SELECT]="Select wifi network"
  [PROMPT_PASSWORD]="Password: {SSID}"
  [PROMPT_LABEL]="wifi> "
  [PROMPT_PASSWORD_LABEL]="password> "
  [MSG_DISCONNECTED]="Disconnected"
  [MSG_DISCONNECT_FAILED]="Failed to disconnect"
  [MSG_CONNECTED]="Connected"
  [MSG_CONNECT_FAILED]="Connection failed (password may be incorrect)"
  [MSG_HIDDEN]="<Hidden Network>"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_USER_INFO=(
  [LABEL_GROUPS]="Groups:"
  [LABEL_SUPERVISOR]="Supervisor"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_GROUP_MANAGEMENT=(
  [PROMPT_GROUP_NAME]="Group name: "
  [PROMPT_CONFIRM]="Are you sure?"
  [MSG_SUCCESS]="Operation completed."
  [MSG_FAILED]="Operation failed."
  [MSG_GROUP_EXISTS]="Group already exists."
  [MSG_GROUP_NOT_FOUND]="Group not found."
  [MSG_USER_NOT_FOUND]="User not found."
  [TITLE]="Group Management"
  [NO_GROUPS_AVAILABLE]="No groups available to add."
  [GROUP_ADDED]="{USER} user added to '{GROUP}' group."
  [ADD_FAILED]="Failed to add to '{GROUP}' group."
  [NO_GROUPS_TO_REMOVE]="No groups available to remove."
  [EXCEPTION_GROUP]="'{GROUP}' is an exception group, {USER} user cannot be removed from this group."
  [GROUP_REMOVED]="{USER} user removed from '{GROUP}' group."
  [REMOVE_FAILED]="Failed to remove from '{GROUP}' group."
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_USER_MENU=(
  [PROMPT_SEARCH]="Search: "
  [MSG_NO_ITEMS]="No items found"
  [USAGE_ERROR]="Usage: {SCRIPT} <json-file> [fuzzel parameters...]"
  [FILE_NOT_FOUND]="Error: File not found -> {FILE}"
  [PROMPT_ACTION]="Action: "
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_CONNECTION_CHECK=(
  [MSG_ONLINE]="Online"
  [MSG_OFFLINE]="Offline"
  [MSG_CHECKING]="Checking connection..."
  [TOOLTIP_NO_WIFI_NO_INTERNET]="Wi-Fi device not found\nInternet connection status: {CONNECTIVITY}\nClick: Open Network Manager"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_KAYRA_LOG_MONITOR=(
  [NOTIFY_TITLE]="Kayra error detected"
  [NOTIFY_APP]="kayra-log-monitor"
  [BUTTON_OPEN_LOG]="Open Log File"
  [BUTTON_DISABLE]="Disable these notifications"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_SYSLOG_NOTIFY=(
  [TITLE_MULTIPLE]="Log entries ({COUNT} entries)"
  [TITLE_SINGLE]="New log entry"
  [BUTTON_OPEN_LOG]="Open Log File"
  [NOTIFY_APP]="syslog"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_SYSLOG_BOOT_REPORT=(
  [TITLE_MULTIPLE]="Errors Since Boot ({COUNT} entries)"
  [TITLE_SINGLE]="Error Since Boot"
  [BUTTON_OPEN_LOG]="Open Log File"
  [NOTIFY_APP]="syslog"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_NET_MONITOR=(
  [USAGE_ERROR]="Usage: {SCRIPT} --ethernet <pattern1,pattern2,...> --other <pattern1,pattern2,...>"
  [UNKNOWN_PARAMETER]="Unknown parameter: {PARAM}"
  [LABEL_ETHERNET]="Ethernet:"
  [LABEL_OTHER]="Other:"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_WIFI_MONITOR=(
  [DEVICE_DISCONNECTED]=$'Device: {DEVICE}\nStatus: Not connected'
  [DEVICE_CONNECTED]=$'Device: {DEVICE}\nSSID: {SSID}\nIP: {IP}\nSignal: %{SIGNAL}'
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_MEMORY_MONITOR=(
  [MEMORY_AVAILABLE]=$'Available memory: %{RATIO}'
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_CHECK_GROUPS=(
  [NOTIFY_TITLE]="Group Check"
  [NOTIFY_MSG]="Missing group membership"
  [NOTIFY_ACTION]="Add groups"
  [MISSING_GROUPS]="You are not a member of: {GROUPS}"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_FIX_GROUPS=(
  [NOTIFY_TITLE]="Group Check"
  [TITLE_SUCCESS]="Groups added"
  [MSG_SUCCESS]="Log out and log back in for this to take effect."
  [TITLE_FAILED]="Operation cancelled or failed"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_TOGGLE_AUTO_THEME=(
  [NOTIFY_TITLE]="Auto Theme"
  [MSG_ON]="Automatic theme changes enabled"
  [MSG_OFF]="Automatic theme changes disabled"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_LOG_MONITOR=(
  [NOTIFY_TITLE]="Log Monitor"
  [MSG_ON]="Log error notifications enabled"
  [MSG_OFF]="Log error notifications disabled"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_SYSTEM_INFO=(
  [LABEL_SYSTEM]="System"
  [LABEL_KERNEL]="Kernel"
  [LABEL_CPU]="CPU"
  [LABEL_GPU]="GPU"
  [LABEL_RAM]="RAM"
  [LABEL_DISK]="Disk"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_SETTINGS_MENU=(
  [PROMPT_ACTION]="Action: "
  [MSG_NO_ITEMS]="No items found"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_SYSTEM_MENU=(
  [PROMPT_ACTION]="Setting: "
  [MSG_NO_ITEMS]="No settings found"
  [LABEL_auto_theme]="Automatic Theme Switching"
  [LABEL_error_log_notify]="System Log Warnings"
  [LABEL_kayra_error_log_notify]="Kayra Log Warnings"
)

declare -A i18n_FONT_SETTINGS=(
  [PROMPT_SELECT]="Select font: "
  [NOTIFY_TITLE]="Font Settings"
  [MSG_FONT_CHANGED]="Font changed to {FONT}"
  [MSG_FONT_UNCHANGED]="Font {FONT} is already selected"
  [MSG_FONT_FAILED]="Failed to change font to {FONT}"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_CHANGE_FONT_SIZE=(
  [USAGE_ERROR]="Usage: {SCRIPT} <size>"
  [ERROR_INVALID_SIZE]="Error: Font size must be between {MIN} and {MAX}"
  [ERROR_SETTINGS_NOT_FOUND]="Error: Settings file not found: {FILE}"
  [MSG_SUCCESS]="Success"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_LANGUAGE_SETTINGS=(
  [PROMPT_SELECT]="Select: "
  [NOTIFY_TITLE]="Language"
  [MSG_CHANGED]="Changed to: {LANG}"
  [MSG_FAILED]="Failed to change language to: {LANG}"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_KEYBOARD_SETTINGS=(
  [PROMPT_SELECT]="Select keyboard layout: "
  [NOTIFY_TITLE]="Keyboard Layout"
  [MSG_CHANGED]="Layout: {LAYOUT}"
  [MSG_VARIANT]="Variant: {VARIANT}"
  [MSG_FAILED]="Failed to change keyboard layout"
  [MSG_UNCHANGED]="Keyboard layout is already set"
  [ERROR_DATA_NOT_FOUND]="Keyboard data files not found. Please run generate-keyboard-data.sh"
  [ERROR_SELECTION_NOT_FOUND]="Selection not found in keyboard database"
  [ERROR_CONFIG_NOT_FOUND]="Keyboard config file not found"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A I18N_REMOVABLE_STORAGE_MONITOR=(
  [NEW_STORAGE]="New storage device"
  [ACTION_OPEN]="Open"
  [ACTION_MOUNT]="Mount"
  [ACTION_DEFAULT]="Open"
  [TOOLTIP_EMPTY]="No removable storage devices"
  [TOOLTIP_PRESENT]="Removable storage devices"
  [TOOLTIP_RIGHT_CLICK_INFO]="Right click: Eject device"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A I18N_REMOVABLE_MENU=(
  [MENU_TITLE]="Storage"
  [NO_PARTITIONS]="No removable partitions"
  [MOUNT_FAILED]="Mount failed"
  [MOUNT_FAILED_MSG]="{DEVICE}"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A I18N_REMOVABLE_EJECT_MENU=(
  [NO_DEVICES]="No connected removable devices"
  [EJECT_TITLE]="Eject"
  [EJECT_SUCCESS]="{DEVICE} can be safely removed"
  [EJECT_PARTIAL]="{DEVICE} unmounted (power-off may not be supported, safe to remove)"
  [EJECT_FAILED]="Eject failed"
  [EJECT_FAILED_MSG]="Could not unmount (may be busy): {DEVICES}"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)



declare -A i18n_WAYBAR_CONFIG=(
  [LOCK_TOOLTIP]="Lock"
  [LOGOUT_TOOLTIP]="Logout"
  [REBOOT_TOOLTIP]="Reboot"
  [SHUTDOWN_TOOLTIP]="Shutdown"
  [APP_MENU_TOOLTIP]="App Menu\nRight click: Install/Remove Applications"
  [CLIPBOARD_TOOLTIP]="Left click: Clipboard History\nRight click: Clear History"
  [BATTERY_TOOLTIP]="Capacity: {capacity}% ({time})"
  [BATTERY_TOOLTIP_CHARGING]="Charging: {capacity}% (Time remaining: {time})"
  [BATTERY_EVENT_WARNING]="Low Battery"
  [BATTERY_EVENT_CRITICAL]="Very Low Battery"
  [BATTERY_EVENT_FULL]="Battery Full!"
  [BATTERY_EVENT_DISCHARGING]="Power Switch Discharging"
  [BATTERY_EVENT_CHARGING]="Power Switch Charging"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_XBPS_MANAGER=(
  [NO_DATA]="Software data not downloaded"
  [ACTION_DOWNLOAD]="Download data"
  [LOCK_MSG]="Ongoing software operations exist, please wait for them to complete"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
  [REMOVE_OK]="Package removed successfully"
  [REMOVE_FAIL]="Failed to remove package"
  [INSTALL_CONFIRM]="Install %s software?"
  [INSTALL_OK]="Package installed successfully"
  [INSTALL_FAIL]="Failed to install package"
  [ACTION_INSTALL]="Install"
  [CD_ERR]="Software local repo not found."
  [APP_NAME]="Software Repository"
  [LOCK_DOWNLOAD]="Downloading software data."
  [LOCK_PREPARE]="Preparing build environment."
  [LOCK_REMOVE]="Removing software: %s"
  [LOCK_INSTALL]="Installing software: %s"
  [LOCK_UPDATE]="Updating software repository."
  [LOCK_UPDATE_INFO]="Updating software repo package info."
  [LOCK_BUILD]="Building software: %s"
  [DOWNLOAD_OK]="Software data downloaded, ready for installation."
)
