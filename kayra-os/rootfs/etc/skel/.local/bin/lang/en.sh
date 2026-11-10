#!/bin/bash

# User menu labels (icons and commands are defined in user-menu.sh)
declare -A user_menu=(
  [ADD_TO_GROUP]="Add to Group"
  [REMOVE_FROM_GROUP]="Remove from Group"
  [CHANGE_PASSWORD]="Change Password"
  [HOME_USAGE]="Home Directory Usage"
)

# System menu labels (icons and commands are defined in system-menu.sh)
declare -A system_menu=(
  [APPEARANCE_THEME]="Appearance & Theme"
  [LANGUAGE]="Language"
  [KEYBOARD]="Keyboard"
  [DISPLAY]="Display"
  [DEVICES]="Devices"
  [SERVICES]="Services"
  [SETTINGS]="Settings"
  [UPDATES]="Check for Updates"
)

# Appearance menu labels (icons and commands are defined in appearance-settings.sh)
declare -A appearance_menu=(
  [FONT]="Font"
  [FONT_SIZE]="Font Size"
  [CHANGE_THEME]="Change Theme"
  [WALLPAPER]="Wallpaper"
)

declare -A i18n_HOME_USAGE=(
  [NOTIFY_TITLE]="Home directory size"
  [NOTIFY_MSG]="{HOME} directory uses {USAGE} of storage."
  [NOTIFY_BUTTON]="Open Baobab"
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
)

declare -A i18n_WIFI_MENU=(
  [NOTIFY_TITLE]="Wi-Fi"
  [NOTIFY_DEVICE_NOT_FOUND]="Wi-Fi device not found"
  [NOTIFY_NO_NETWORKS]="No networks found nearby"
  [NOTIFY_COMMAND_NOT_FOUND]="Required command not found: {COMMAND}"
  [PROMPT_SELECT]="Select a Wi-Fi network"
  [PROMPT_PASSWORD]="Password: {SSID}"
  [PROMPT_LABEL]="wifi> "
  [PROMPT_PASSWORD_LABEL]="password> "
  [MSG_DISCONNECTED]="Disconnected from {SSID}"
  [MSG_DISCONNECT_FAILED]="Failed to disconnect from {SSID}"
  [MSG_CONNECTED]="Connected to {SSID}"
  [MSG_CONNECT_FAILED]="Failed to connect to {SSID} (the password may be incorrect)"
  [MSG_HIDDEN]="<Hidden Network>"
)

declare -A i18n_GROUP_MANAGEMENT=(
  [TITLE]="Group Management"
  [NO_GROUPS_AVAILABLE]="No groups available to add."
  [GROUP_ADDED]="{USER} user added to '{GROUP}' group."
  [ADD_FAILED]="Failed to add to '{GROUP}' group."
  [NO_GROUPS_TO_REMOVE]="No groups available to remove."
  [EXCEPTION_GROUP]="'{GROUP}' is an exception group, {USER} user cannot be removed from this group."
  [GROUP_REMOVED]="{USER} user removed from '{GROUP}' group."
  [REMOVE_FAILED]="Failed to remove from '{GROUP}' group."
)

declare -A i18n_USER_MENU=(
  [NOTIFY_TITLE]="User Menu"
  [MSG_SCRIPT_MISSING]="Menu command not found: {SCRIPT}"
)

declare -A i18n_CONNECTION_CHECK=(
  [TOOLTIP_NO_WIFI_NO_INTERNET]="Wi-Fi device not found\nInternet connection status: {CONNECTIVITY}\nClick: Open Network Manager"
)

declare -A i18n_NET_MONITOR=(
  [USAGE_ERROR]="Usage: {SCRIPT} --ethernet <pattern1,pattern2,...> --other <pattern1,pattern2,...>"
  [UNKNOWN_PARAMETER]="Unknown parameter: {PARAM}"
  [LABEL_ETHERNET]="Ethernet:"
  [LABEL_OTHER]="Other:"
)

declare -A i18n_WIFI_MONITOR=(
  [DEVICE_DISCONNECTED]=$'Device: {DEVICE}\nStatus: Not connected'
  [DEVICE_CONNECTED]=$'Device: {DEVICE}\nSSID: {SSID}\nIP: {IP}\nSignal: {SIGNAL}'
)

declare -A i18n_MEMORY_MONITOR=(
  [MEMORY_AVAILABLE]=$'Available memory: {RATIO}%'
  [TOP_PROCESSES]="Top memory processes:"
  [NOTIFY_TITLE]="Low memory"
  [NOTIFY_LOW_MEMORY]=$'Available memory dropped to {RATIO}%.'
)

declare -A i18n_CHECK_GROUPS=(
  [NOTIFY_MSG]="Missing group membership"
  [NOTIFY_ACTION]="Add groups"
  [MISSING_GROUPS]="You are not a member of: {GROUPS}"
)

declare -A i18n_FIX_GROUPS=(
  [TITLE_SUCCESS]="Groups added"
  [MSG_SUCCESS]="Log out and log back in for this to take effect."
  [TITLE_FAILED]="Operation cancelled or failed"
  [MSG_FAILED]="Failed to add the missing groups."
)

declare -A i18n_APPEARANCE_MENU=(
  [MSG_NO_ITEMS]="No items found"
  [NOTIFY_TITLE]="Appearance Settings"
  [MSG_SCRIPT_MISSING]="Menu command not found: {SCRIPT}"
)

declare -A i18n_SETTINGS_MENU=(
  [MSG_NO_ITEMS]="No settings found"
  [LABEL_auto_theme]="Automatic Theme Switching"
  [LABEL_auto_update]="Automatic Updates"
  [LABEL_auto_group_management]="Automatic Group Management"
  [NOTIFY_TITLE]="System Settings"
  [MSG_TOGGLED]="{LABEL}: {STATE}"
  [STATE_ON]="enabled"
  [STATE_OFF]="disabled"
  [ACTION_UNDO]="Undo"
)

declare -A i18n_SYSTEM_MENU=(
  [MSG_NO_ITEMS]="No items found"
)

declare -A i18n_SHOW_DEVICES=(
  [PROMPT_DEVICE]="Device: "
  [MSG_NO_DEVICES]="No devices found"
  [MSG_NO_DATA]="No device data found"
  [MSG_NO_FUZZEL]="fuzzel is not installed"
  [MSG_NO_JQ]="jq is not installed"
)

declare -A i18n_SHOW_DEVICE_MODS=(
  [MSG_MESG]="Modules"
  [PROMPT_MODULE]="Module: "
  [MSG_NO_MODULES]="No modules found for this device"
  [MSG_NO_DATA]="No device data found"
  [MSG_DEVICE_NOT_FOUND]="Device not found: "
  [MSG_BAD_DEVICE]="Unknown device: "
  [MSG_ALREADY_IN_USE]="Module {MODULE} is already in use."
  [MSG_USAGE]="Usage: show-device-mods.sh <device-key>"
  [MSG_NO_FUZZEL]="fuzzel is not installed"
  [MSG_NO_JQ]="jq is not installed"
)

declare -A i18n_SHOW_SERVICES=(
  [MSG_MESG]="Services"
  [PROMPT_SERVICE]="Service: "
  [MSG_NO_SERVICES]="No services found"
  [LABEL_DISABLED]="disabled"
  [MSG_NO_FUZZEL]="fuzzel is not installed"
)

declare -A i18n_TOGGLE_SERVICE=(
  [NOTIFY_TITLE]="Services"
  [MSG_STARTED]="Service {SERVICE} started"
  [MSG_STOPPED]="Service {SERVICE} stopped"
  [MSG_ENABLED]="Service {SERVICE} enabled and started"
  [MSG_PROTECTED]="Service {SERVICE} can not be stopped"
  [MSG_FAILED]="Failed to toggle service {SERVICE}"
  [MSG_NOT_FOUND]="Service not found: {SERVICE}"
  [MSG_USAGE]="Usage: toggle-service.sh <service-name>"
)

declare -A i18n_FONT_SETTINGS=(
  [NOTIFY_TITLE]="Font Settings"
  [MSG_FONT_CHANGED]="Font changed to {FONT}"
  [MSG_FONT_UNCHANGED]="Font {FONT} is already selected"
  [MSG_FONT_FAILED]="Failed to change font to {FONT}"
)

declare -A i18n_SET_LANGUAGE=(
  [NOTIFY_TITLE]="Language"
  [MSG_CHANGED]="Changed to: {LANG}"
  [MSG_FAILED]="Failed to change language to: {LANG}"
  [MSG_NO_LANG_DATA]="The language data for {LANG} was not found. The English data is used, the system locale is set to {LOCALE}."
)

declare -A i18n_LANGUAGE_SETTINGS=(
  [MSG_NO_LANGUAGES]="No language files were found."
  [NOTIFY_TITLE]="Language"
  [MSG_FAILED]="Failed to change language to: {LANG}"
)

declare -A i18n_KEYBOARD_SETTINGS=(
  [PROMPT_SELECT]="Select keyboard layout: "
  [NOTIFY_TITLE]="Keyboard Layout"
  [MSG_CHANGED]="Keyboard layout changed: {LAYOUT}"
  [MSG_VARIANT]="Variant: {VARIANT}"
  [MSG_FAILED]="Failed to change the keyboard layout"
  [MSG_UNCHANGED]="The keyboard layout is already set"
  [ERROR_DATA_NOT_FOUND]="Keyboard data files not found. Please run generate-keyboard-data.sh"
  [ERROR_SELECTION_NOT_FOUND]="Selection not found in the keyboard database"
  [ERROR_CONFIG_NOT_FOUND]="Keyboard config file not found"
  [ERROR_NO_SELECTION]="No keyboard layout was given"
)

declare -A I18N_REMOVABLE_STORAGE_MONITOR=(
  [NEW_STORAGE]="New storage device"
  [ACTION_OPEN]="Open"
  [ACTION_MOUNT]="Mount"
  [ACTION_DEFAULT]="Open"
  [TOOLTIP_EMPTY]="No removable storage devices"
  [TOOLTIP_PRESENT]="Removable storage devices"
  [TOOLTIP_RIGHT_CLICK_INFO]="Right click: Eject device"
)

declare -A I18N_REMOVABLE_MENU=(
  [MENU_TITLE]="Storage"
  [NO_PARTITIONS]="No removable partitions"
  [MOUNT_FAILED]="Mount failed"
  [MOUNT_FAILED_MSG]="{DEVICE}"
)

declare -A I18N_REMOVABLE_EJECT_MENU=(
  [NO_DEVICES]="No connected removable devices"
  [EJECT_TITLE]="Eject"
  [EJECT_SUCCESS]="{DEVICE} can be safely removed"
  [EJECT_PARTIAL]="{DEVICE} unmounted (power-off may not be supported, safe to remove)"
  [EJECT_FAILED]="Eject failed"
  [EJECT_FAILED_MSG]="Could not unmount (may be busy): {DEVICES}"
)



declare -A i18n_WAYBAR_CONFIG=(
  [APP_MENU_TOOLTIP]="App Menu\nRight click: Install/Remove Applications"
  [APP_PINS_TOOLTIP]="Pinned applications\nLeft click: Add application\nRight click: Add command"
  [CLIPBOARD_TOOLTIP]="Left click: Clipboard History\nRight click: Clear History"
  [BATTERY_TOOLTIP]="Capacity: {capacity}% ({time})"
  [BATTERY_TOOLTIP_CHARGING]="Charging: {capacity}% (Time remaining: {time})"
  [BATTERY_EVENT_WARNING]="Low Battery"
  [BATTERY_EVENT_CRITICAL]="Very Low Battery"
  [BATTERY_EVENT_FULL]="Battery Full!"
  [BATTERY_EVENT_DISCHARGING]="Power Switch Discharging"
  [BATTERY_EVENT_CHARGING]="Power Switch Charging"
)

declare -A i18n_XBPS_MANAGER=(
  [NO_DATA]="Software data not downloaded"
  [ACTION_DOWNLOAD]="Download data"
  [LOCK_MSG]="Ongoing software operations exist, please wait for them to complete"
  [REMOVE_CONFIRM]="Remove {PACKAGE} software?"
  [ACTION_REMOVE]="Remove"
  [REMOVE_OK]="Package removed successfully"
  [REMOVE_FAIL]="Failed to remove package"
  [INSTALL_CONFIRM]="Install {PACKAGE} software?"
  [INSTALL_OK]="Package installed successfully"
  [INSTALL_FAIL]="Failed to install package"
  [ACTION_INSTALL]="Install"
  [CD_ERR]="Software local repo not found."
  [APP_NAME]="Software Repository"
  [LOCK_DOWNLOAD]="Downloading software data."
  [LOCK_PREPARE]="Preparing build environment."
  [LOCK_REMOVE]="Removing software: {PACKAGE}"
  [LOCK_INSTALL]="Installing software: {PACKAGE}"
  [LOCK_UPDATE]="Updating software repository."
  [LOCK_UPDATE_INFO]="Updating software repo package info."
  [LOCK_BUILD]="Building software: {PACKAGE}"
  [DOWNLOAD_OK]="Software data downloaded, ready for installation."
  [INSTALLED_CONFIRM]="{PACKAGE} is installed and an update is available. What do you want to do?"
  [ACTION_UPDATE]="Update"
  [ACTION_SYS_UPDATE]="Update system"
  [ACTION_CANCEL]="Cancel"
  [ACTION_CLEAN]="Clean"
  [ACTION_DISK_USAGE]="Show Disk Usage"
  [ACTION_OK]="OK"
  [UPDATE_PKG_OK]="Package updated successfully"
  [UPDATE_PKG_FAIL]="Failed to update package"
  [UPDATE_CONFIRM]="{COUNT} package(s): download {DOWNLOAD}, install {INSTALL}, {FREE} free. Update the system now?"
  [UPDATE_CLEAN_CONFIRM]="Not enough free space (need {INSTALL}, {FREE} free). Clear the package cache and the whole download cache, then continue?"
  [UPDATE_DOWNLOAD]="Downloading and installing updates."
  [UPDATE_SOURCE]="Rebuilding source packages: {PACKAGES}"
  [UPDATE_OK]="System updated"
  [UPDATE_NONE]="System is up to date"
  [DISK_LOW]="Not enough free disk space."
  [CHECK_UPDATES]="Check for Updates"
  [UPDATES_PROMPT]="Updates"
  [UPDATES_TITLE]="Updates available: {COUNT}"
  [UPDATES_SOURCE_TAG]="(source)"
)

declare -A i18n_POWER_MENU=(
  [ITEM_SHUTDOWN]="Shutdown"
  [ITEM_REBOOT]="Reboot"
  [ITEM_LOGOUT]="Logout"
  [ITEM_LOCK]="Lock"
  [NOTIFY_TITLE]="Power Menu"
  [LOCK_MSG]="Wait for the software changes to complete."
  [MSG_BLOCKED]="This action is blocked."
  [MSG_UNKNOWN_ACTION]="Unknown action selected."
)

declare -A i18n_BLUETOOTH_MONITOR=(
  [ADAPTER_OFF]="Bluetooth: Off"
  [DISCONNECTED]=$'Bluetooth: On\nNo device connected'
  [CONNECTED]=$'Bluetooth: Connected\n{DEVICES}'
)

declare -A i18n_BLUETOOTH_MENU=(
  [NOTIFY_TITLE]="Bluetooth"
  [NOTIFY_NO_DEVICE]="No Bluetooth adapter found"
  [NOTIFY_COMMAND_NOT_FOUND]="Required command not found: {COMMAND}"
  [PROMPT_SELECT]="Select a Bluetooth device"
  [PROMPT_LABEL]="bt> "
  [ACTION_POWER_ON]="Turn Bluetooth on"
  [ACTION_POWER_OFF]="Turn Bluetooth off"
  [ACTION_SCAN]="Scan for devices"
  [MSG_POWER_ON]="Bluetooth turned on"
  [MSG_POWER_OFF]="Bluetooth turned off"
  [MSG_POWER_FAILED]="Failed to change the Bluetooth power state"
  [MSG_CONNECTED]="{NAME} connected"
  [MSG_DISCONNECTED]="{NAME} disconnected"
  [MSG_CONNECT_FAILED]="Failed to connect to {NAME}"
  [MSG_DISCONNECT_FAILED]="Failed to disconnect from {NAME}"
  [MSG_PAIRED]="{NAME} paired and connected"
  [MSG_PAIR_FAILED]="Failed to pair with {NAME}"
  [MSG_SCAN_STARTED]="Scanning for devices..."
  [MSG_NO_DEVICES]="No devices found"
)

# NVIDIA driver detection (nvidia-detect.sh)
declare -A i18n_NVIDIA_DETECT=(
  [APP_NAME]="NVIDIA Driver"
  [MISSING_CMD]="Required command not found: {COMMAND}"
  [NO_GPU]="No NVIDIA GPU was found on this system."
  [REPO_EMPTY]="No NVIDIA driver package was found in the repositories."
  [DOWNLOAD_FAIL]="Could not download the supported GPU list from NVIDIA. Check your network connection."
  [UNSUPPORTED]="No driver package in the repositories supports {GPU}. Consider the open-source nouveau driver."
  [RECOMMEND]=$'Detected: {GPU}\nRecommended driver: {PACKAGE}'
  [INSTALL_CONFIRM]="Install the {PACKAGE} driver package?"
  [ACTION_INSTALL]="Install"
  [ALREADY_OK]="Already installed and up to date: {PACKAGE} ({VERSION})."
  [UPDATE_INFO]="Installed: {INSTALLED} - available: {AVAILABLE}."
  [UPDATE_HINT]="Update it with your package manager."
  [CONFLICT]="Warning: another NVIDIA driver branch is also installed: {PACKAGES}."
)

# Pinned application bar (waybar-app-pins.sh, waybar-app-pins-slot.sh)
declare -A i18n_APP_PINS=(
  [NOTIFY_TITLE]="Application Bar"
  [MENU_PROMPT]="Add application"
  [COMMAND_PROMPT]="Command"
  [REMOVE_ACTION]="Remove"
  [MSG_ADDED]="{APP} added to the bar"
  [MSG_CMD_ADDED]="{CMD} command added to the bar"
  [MSG_REMOVED]="{APP} removed from the bar"
  [MSG_ALREADY]="{APP} is already on the bar"
  [MSG_NO_APPS]="No applications found"
  [MSG_FULL]="All slots are full. Add a slot with: waybar-app-pins-slot.sh add"
  [MSG_SLOT_COUNT]="Pinned slots (used/total): {COUNT}"
  [MSG_SLOT_ADDED]="Slot {INDEX} added"
  [MSG_SLOT_REMOVED]="Slot {INDEX} removed"
  [MSG_SLOT_LAST_FULL]="Slot {INDEX} is in use and cannot be removed"
  [MSG_NO_SLOTS]="No slot to remove"
  [MSG_FAILED]="Operation failed"
)
