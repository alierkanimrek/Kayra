#!/usr/bin/env -S gjs -m
//
// kayra-theme-probe.gjs - Read the palette of the active GTK3 theme.
//
// Prints one JSON object with the colors used by Waybar, Fuzzel and SwayNC:
//   {"bg":"#rrggbb","surface":"#rrggbb","fg":"#rrggbb",
//    "selected_bg":"#rrggbb","selected_fg":"#rrggbb",
//    "warning":"#rrggbb","error":"#rrggbb"}
//
// The colors are read with Gtk.StyleContext.lookup_color() from the standard
// theme color names. No window is created and nothing is read from the screen,
// so the probe does not steal focus, touch the sway layout or disturb the
// session.
//
// There is no fallback: a missing color or a color with alpha < 1 is an error
// and the script exits with status 1 without printing a partial object.
//
// Usage: kayra-theme-probe.gjs
// Exit: 0 on success, 1 on error (message on stderr).
//
// Used commands: gjs, GTK3 (Gtk-3.0 typelib).
//
// This is a user script and must be run inside the desktop session; GTK needs
// a display connection. It does not use a window.

import Gtk from 'gi://Gtk?version=3.0';
import System from 'system';

const COLORS = {
    bg: 'theme_bg_color',
    surface: 'theme_base_color',
    fg: 'theme_fg_color',
    selected_bg: 'theme_selected_bg_color',
    selected_fg: 'theme_selected_fg_color',
    warning: 'warning_color',
    error: 'error_color',
};

function toHex(color) {
    const part = value => Math.round(value * 255).toString(16).padStart(2, '0');
    return '#' + part(color.red) + part(color.green) + part(color.blue);
}

Gtk.init(null);

const context = new Gtk.StyleContext();
const result = {};
let failed = false;

for (const [key, name] of Object.entries(COLORS)) {
    const [ok, color] = context.lookup_color(name);

    if (!ok) {
        printerr(`kayra-theme-probe: theme color is not defined: ${name}`);
        failed = true;
        continue;
    }

    if (Math.abs(color.alpha - 1) > 1e-6) {
        printerr(`kayra-theme-probe: theme color is not opaque: ${name} (alpha ${color.alpha})`);
        failed = true;
        continue;
    }

    result[key] = toHex(color);
}

if (failed)
    System.exit(1);

print(JSON.stringify(result));
