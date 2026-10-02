#!/bin/bash
# Generate keyboard layout and variant data from evdev.lst
# Creates fuzzel-keyboard-menu and keyboard-data files for use by keyboard-settings.sh

EVDEV_FILE="/usr/share/X11/xkb/rules/evdev.lst"
MENU_FILE="$HOME/.local/bin/data/fuzzel-keyboard-menu"
DATA_FILE="$HOME/.local/bin/data/keyboard-data"

mkdir -p "$HOME/.local/bin/data"

# Extract layouts and variants from evdev.lst
{
  # Find line numbers for sections
  layouts_line=$(grep -n "^! layout" "$EVDEV_FILE" | head -1 | cut -d: -f1)
  variants_line=$(grep -n "^! variant" "$EVDEV_FILE" | head -1 | cut -d: -f1)
  options_line=$(grep -n "^! option" "$EVDEV_FILE" | head -1 | cut -d: -f1)
  
  # Get layout codes and descriptions (between layout and variant sections)
  sed -n "$((layouts_line + 1)),$((variants_line - 1))p" "$EVDEV_FILE" | \
    while read -r line; do
      # Skip empty lines
      [ -z "$(echo "$line" | tr -d ' ')" ] && continue
      # Extract code (first non-space group) and description (rest)
      code=$(echo "$line" | awk '{print $1}')
      desc=$(echo "$line" | sed 's/^[[:space:]]*[^[:space:]]*[[:space:]]\+//' | sed 's/[[:space:]]*$//')
      [ -z "$code" ] && continue
      echo "LAYOUT|$code|$desc"
    done
  
  # Get variant codes and their associated layouts (between variant and option sections)
  sed -n "$((variants_line + 1)),$((options_line - 1))p" "$EVDEV_FILE" | \
    while read -r line; do
      # Skip empty lines
      [ -z "$(echo "$line" | tr -d ' ')" ] && continue
      # Variant line format: "  code     layout: description"
      code=$(echo "$line" | awk '{print $1}')
      rest=$(echo "$line" | cut -d' ' -f2-)

      # Remove leading spaces
      rest=$(echo "$rest" | sed 's/^[[:space:]]*//g')

      # Extract layout code (before colon)
      layout=$(echo "$rest" | cut -d: -f1)
      # Extract description (after colon and trim spaces)
      desc=$(echo "$rest" | cut -d: -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

      [ -z "$code" ] && continue
      echo "VARIANT|$layout|$code|$desc"
    done
} > /tmp/keyboard-raw.tmp

# Generate fuzzel menu file (layout + variant combinations)
{
  echo "# Keyboard Layouts and Variants"
  
  # Get all layouts sorted by description
  grep "^LAYOUT|" /tmp/keyboard-raw.tmp | \
    sort -t'|' -k3 | \
    while IFS='|' read -r type code desc; do
      # Check if layout has variants
      if grep -q "^VARIANT|$code|" /tmp/keyboard-raw.tmp; then
        # Show layout with variants
        echo "$desc (Default)|LAYOUT|$code||"
        grep "^VARIANT|$code|" /tmp/keyboard-raw.tmp | \
          sort -t'|' -k4 | \
          while IFS='|' read -r vtype vlayout vcode vdesc; do
            echo "  $desc - $vdesc|VARIANT|$vlayout|$vcode|"
          done
      else
        # Layout without variants
        echo "$desc|LAYOUT|$code||"
      fi
    done
} > "$MENU_FILE"

# Generate data file for mapping (with leading spaces for variants to match fuzzel output)
{
  # Map each selectable item to layout|variant
  grep "^LAYOUT|" /tmp/keyboard-raw.tmp | \
    sort -t'|' -k3 | \
    while IFS='|' read -r type code desc; do
      if grep -q "^VARIANT|$code|" /tmp/keyboard-raw.tmp; then
        # Default variant (no variant specified) - no leading spaces
        echo "$desc (Default)|$code|"
        grep "^VARIANT|$code|" /tmp/keyboard-raw.tmp | \
          sort -t'|' -k4 | \
          while IFS='|' read -r vtype vlayout vcode vdesc; do
            # Variant entries WITH leading spaces (same as menu output)
            echo "  $desc - $vdesc|$vlayout|$vcode"
          done
      else
        echo "$desc|$code|"
      fi
    done
} > "$DATA_FILE"

rm -f /tmp/keyboard-raw.tmp

echo "✓ Menü dosyası oluşturuldu: $MENU_FILE"
echo "✓ Veri dosyası oluşturuldu: $DATA_FILE"
echo ""
echo "Kullanım:"
echo "  ~/.local/bin/keyboard-settings.sh"
