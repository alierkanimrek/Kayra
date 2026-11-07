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

# User menu labels (icons and commands are defined in user-menu.sh)
declare -A user_menu=(
  [ADD_TO_GROUP]="Add to Group"
  [REMOVE_FROM_GROUP]="Remove from Group"
  [CHANGE_PASSWORD]="Change Password"
  [HOME_USAGE]="Home Directory Usage"
)

# Settings menu labels (icons and commands are defined in settings-menu.sh)
declare -A settings_menu=(
  [APPEARANCE_THEME]="Appearance & Theme"
  [LANGUAGE]="Language"
  [KEYBOARD]="Keyboard"
  [DISPLAY]="Display"
  [DEVICES]="Devices"
  [SERVICES]="Services"
)

# Appearance menu labels (icons and commands are defined in appearance-settings.sh)
declare -A appearance_menu=(
  [FONT]="Font"
  [FONT_SIZE]="Font Size"
  [CHANGE_THEME]="Change Theme"
  [AUTO_THEME]="Auto Theme"
  [WALLPAPER]="Wallpaper"
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
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
  [NOTIFY_TITLE]="User Menu"
  [MSG_SCRIPT_MISSING]="Menu command not found: {SCRIPT}"
)

declare -A i18n_CONNECTION_CHECK=(
  [MSG_ONLINE]="Online"
  [MSG_OFFLINE]="Offline"
  [MSG_CHECKING]="Checking connection..."
  [TOOLTIP_NO_WIFI_NO_INTERNET]="Wi-Fi device not found\nInternet connection status: {CONNECTIVITY}\nClick: Open Network Manager"
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
  [DEVICE_CONNECTED]=$'Device: {DEVICE}\nSSID: {SSID}\nIP: {IP}\nSignal: {SIGNAL}'
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_MEMORY_MONITOR=(
  [MEMORY_AVAILABLE]=$'Available memory: {RATIO}%'
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
  [MSG_FAILED]="Failed to add the missing groups."
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
  [MSG_NO_ITEMS]="No items found"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
  [NOTIFY_TITLE]="Appearance Settings"
  [MSG_SCRIPT_MISSING]="Menu command not found: {SCRIPT}"
)

declare -A i18n_SYSTEM_MENU=(
  [MSG_NO_ITEMS]="No settings found"
  [LABEL_auto_theme]="Automatic Theme Switching"
  [NOTIFY_TITLE]="System Settings"
  [MSG_TOGGLED]="{LABEL}: {STATE}"
  [STATE_ON]="enabled"
  [STATE_OFF]="disabled"
  [ACTION_UNDO]="Undo"
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

declare -A i18n_SET_LANGUAGE=(
  [NOTIFY_TITLE]="Language"
  [MSG_CHANGED]="Changed to: {LANG}"
  [MSG_FAILED]="Failed to change language to: {LANG}"
  [MSG_NO_LANG_DATA]="The language data for {LANG} was not found. The English data is used, the system locale is set to {LOCALE}."
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_LANGUAGE_SETTINGS=(
  [MSG_NO_LANGUAGES]="No language files were found."
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
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_BLUETOOTH_MONITOR=(
  [ADAPTER_OFF]="Bluetooth: Off"
  [DISCONNECTED]=$'Bluetooth: On\nNo device connected'
  [CONNECTED]=$'Bluetooth: Connected\n{DEVICES}'
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
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
  [LABEL_CONNECTED]="connected"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)
