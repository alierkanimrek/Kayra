#!/usr/bin/env -S gjs -m

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GdkPixbuf from 'gi://GdkPixbuf';
import Gdk from 'gi://Gdk?version=4.0';
import Gtk from 'gi://Gtk?version=4.0';

const THUMB_WIDTH = 320;
const IMAGE_RE = /\.(png|jpe?g|webp|gif|bmp)$/i;

// Komut satırı argümanı yoksa varsayılan klasörler
function defaultDirs() {
    const pictures = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_PICTURES);
    const downloads = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DOWNLOAD);
    const desktop = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_DESKTOP);

    return [
        pictures,
        pictures && GLib.build_filenamev([pictures, 'wallpapers']),
        downloads,
        downloads && GLib.build_filenamev([downloads, 'images']),
        desktop,
    ].filter(d => !!d);
}

function scanDir(dir, out) {
    const folder = Gio.File.new_for_path(dir);
    if (!folder.query_exists(null))
        return;

    let en;
    try {
        en = folder.enumerate_children(
            'standard::name,time::modified',
            Gio.FileQueryInfoFlags.NONE,
            null);
    } catch (e) {
        return;
    }

    let info;
    while ((info = en.next_file(null)) !== null) {
        const name = info.get_name();
        if (!IMAGE_RE.test(name))
            continue;

        const date = info.get_modification_date_time();
        out.push({
            path: GLib.build_filenamev([dir, name]),
            mtime: date ? date.to_unix() : 0,
        });
    }
    en.close(null);
}

function loadThumbnail(path) {
    try {
        const pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
            path, THUMB_WIDTH, -1, true);
        const picture = Gtk.Picture.new_for_paintable(
            Gdk.Texture.new_for_pixbuf(pixbuf));
        picture.set_content_fit(Gtk.ContentFit.CONTAIN);
        picture.set_size_request(THUMB_WIDTH, -1);
        return picture;
    } catch (e) {
        return null;
    }
}

// Tarama
const dirs = ARGV.length > 0 ? ARGV : defaultDirs();
const found = [];
for (const d of dirs)
    scanDir(GLib.canonicalize_filename(d, null), found);

// Tekrarları kaldır, en yeni dosyayı en üste koy
const unique = [...new Map(found.map(f => [f.path, f])).values()];
unique.sort((a, b) => b.mtime - a.mtime);

let selected = null;

const app = new Gtk.Application({
    application_id: 'local.imgpick',
    flags: Gio.ApplicationFlags.NON_UNIQUE,
});

app.connect('activate', () => {
    const win = new Gtk.ApplicationWindow({
        application: app,
        title: 'Resim Seç',
        default_width: 1100,
        default_height: 700,
    });

    const flow = new Gtk.FlowBox({
        selection_mode: Gtk.SelectionMode.NONE,
        homogeneous: false,
        max_children_per_line: 100,
        min_children_per_line: 1,
        column_spacing: 8,
        row_spacing: 8,
        margin_top: 8,
        margin_bottom: 8,
        margin_start: 8,
        margin_end: 8,
        valign: Gtk.Align.START,
    });

    for (const file of unique) {
        const picture = loadThumbnail(file.path);
        if (!picture)
            continue;

        const button = new Gtk.Button({ child: picture });
        button.add_css_class('flat');
        button.connect('clicked', () => {
            selected = file.path;
            win.close();
        });
        flow.append(button);
    }

    const scroll = new Gtk.ScrolledWindow({
        child: flow,
        hexpand: true,
        vexpand: true,
    });
    win.set_child(scroll);

    // Esc ile iptal
    const keys = new Gtk.EventControllerKey();
    keys.connect('key-pressed', (_c, keyval) => {
        if (keyval === Gdk.KEY_Escape) {
            win.close();
            return true;
        }
        return false;
    });
    win.add_controller(keys);

    win.present();
});

app.run([]);

if (selected)
    print(selected);
