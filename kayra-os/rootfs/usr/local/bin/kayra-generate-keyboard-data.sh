#!/bin/bash
#
# kayra-generate-keyboard-data.sh - Generate the keyboard layout data files.
#
# Reads the X11 keyboard rules (evdev.lst) and writes the two data files used
# by kayra-keyboard-settings.sh:
#   /usr/local/share/kayra/data/fuzzel-keyboard-menu
#   /usr/local/share/kayra/data/keyboard-data
#
# The output directory is root owned, so run this as root. It can be
# overridden with KAYRA_DATA_DIR (useful while developing).
#
# Usage: sudo kayra-generate-keyboard-data.sh
#
# Used commands: grep, sed, awk, sort, cut, tr, mktemp
#
set -uo pipefail
export LC_ALL=C.UTF-8

EVDEV_FILE="/usr/share/X11/xkb/rules/evdev.lst"
DATA_DIR="${KAYRA_DATA_DIR:-/usr/local/share/kayra/data}"
MENU_FILE="$DATA_DIR/fuzzel-keyboard-menu"
DATA_FILE="$DATA_DIR/keyboard-data"

if [[ ! -r "$EVDEV_FILE" ]]; then
    echo "error: keyboard rules not found: $EVDEV_FILE" >&2
    exit 1
fi

if ! mkdir -p "$DATA_DIR" 2>/dev/null || [[ ! -w "$DATA_DIR" ]]; then
    echo "error: $DATA_DIR is not writable (run as root)" >&2
    exit 1
fi

RAW="$(mktemp)" || exit 1
trap 'rm -f "$RAW"' EXIT

# Extract layouts and variants from evdev.lst
{
  # Section line numbers
  layouts_line=$(grep -n "^! layout" "$EVDEV_FILE" | head -1 | cut -d: -f1)
  variants_line=$(grep -n "^! variant" "$EVDEV_FILE" | head -1 | cut -d: -f1)
  options_line=$(grep -n "^! option" "$EVDEV_FILE" | head -1 | cut -d: -f1)

  # Layout codes and descriptions (between the layout and variant sections)
  sed -n "$((layouts_line + 1)),$((variants_line - 1))p" "$EVDEV_FILE" | \
    while read -r line; do
      [ -z "$(echo "$line" | tr -d ' ')" ] && continue
      code=$(echo "$line" | awk '{print $1}')
      desc=$(echo "$line" | sed 's/^[[:space:]]*[^[:space:]]*[[:space:]]\+//' | sed 's/[[:space:]]*$//')
      [ -z "$code" ] && continue
      echo "LAYOUT|$code|$desc"
    done

  # Variant codes and their layouts (between the variant and option sections)
  sed -n "$((variants_line + 1)),$((options_line - 1))p" "$EVDEV_FILE" | \
    while read -r line; do
      [ -z "$(echo "$line" | tr -d ' ')" ] && continue
      code=$(echo "$line" | awk '{print $1}')
      rest=$(echo "$line" | cut -d' ' -f2-)
      rest=$(echo "$rest" | sed 's/^[[:space:]]*//g')
      layout=$(echo "$rest" | cut -d: -f1)
      desc=$(echo "$rest" | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      [ -z "$code" ] && continue
      echo "VARIANT|$layout|$code|$desc"
    done
} > "$RAW"

# Fuzzel menu file (layout + variant combinations)
{
  echo "# Keyboard Layouts and Variants"

  grep "^LAYOUT|" "$RAW" | \
    sort -t'|' -k3 | \
    while IFS='|' read -r type code desc; do
      if grep -q "^VARIANT|$code|" "$RAW"; then
        echo "$desc (Default)|LAYOUT|$code||"
        grep "^VARIANT|$code|" "$RAW" | \
          sort -t'|' -k4 | \
          while IFS='|' read -r vtype vlayout vcode vdesc; do
            echo "  $desc - $vdesc|VARIANT|$vlayout|$vcode|"
          done
      else
        echo "$desc|LAYOUT|$code||"
      fi
    done
} > "$MENU_FILE"

# Data file for mapping (variants use the same leading spaces as the menu)
{
  grep "^LAYOUT|" "$RAW" | \
    sort -t'|' -k3 | \
    while IFS='|' read -r type code desc; do
      if grep -q "^VARIANT|$code|" "$RAW"; then
        echo "$desc (Default)|$code|"
        grep "^VARIANT|$code|" "$RAW" | \
          sort -t'|' -k4 | \
          while IFS='|' read -r vtype vlayout vcode vdesc; do
            echo "  $desc - $vdesc|$vlayout|$vcode"
          done
      else
        echo "$desc|$code|"
      fi
    done
} > "$DATA_FILE"

echo "Menu file written: $MENU_FILE"
echo "Data file written: $DATA_FILE"
echo ""
echo "Usage:"
echo "  kayra-keyboard-settings.sh"
