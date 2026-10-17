#!/usr/bin/env -S gjs -m
import Gtk from 'gi://Gtk?version=4.0';
import GLib from 'gi://GLib';
import Gdk from 'gi://Gdk?version=4.0';

const IMAGE = GLib.build_filenamev([
    GLib.get_home_dir(),
    '.local', 'bin', 'data',
    'backlight-testing-image.png',
]);

const APP_ID = 'local.imgshow';
const SHOW_MS = 3000;

const app = new Gtk.Application({ application_id: APP_ID });
let win = null;

app.connect('activate', () => {
    // Pencere zaten açıksa yeni bir şey yapma
    if (win !== null)
        return;

    win = new Gtk.Window({
        application: app,
        decorated: false,
        resizable: false,
        default_width: 480,
        default_height: 270,
    });

let texture;
try {
    texture = Gdk.Texture.new_from_filename(IMAGE);
} catch (e) {
    printerr(`Görsel yüklenemedi: ${IMAGE}: ${e.message}`);
    app.quit();
    return;
}

const pic = Gtk.Picture.new_for_paintable(texture);
pic.set_size_request(480, 270);
pic.set_can_shrink(false);
win.set_child(pic);
    pic.set_size_request(480, 270);
    pic.set_can_shrink(false);
    win.set_child(pic);

    win.connect('close-request', () => {
        win = null;
        return false;
    });

    win.present();

    GLib.timeout_add(GLib.PRIORITY_DEFAULT, SHOW_MS, () => {
        if (win !== null)
            win.close();
        app.quit();
        return GLib.SOURCE_REMOVE;
    });
});

app.run([]);
