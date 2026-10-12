#!/usr/bin/env bash
# tema-probe.sh: GTK3 probe penceresi açar, renkleri sway'de ekrandan (grim) okur.
# Çıktı: {"bg":"#...","fg":"#...","selected_bg":"#...","selected_fg":"#..."}
#
# Gerekenler: sway (swaymsg), jq, grim, gjs (+ GTK3 typelib), od, awk
# GTK3 kullanılır, çünkü waybar da GTK3'tür ve gtk-theme-name temasını gösterir.
set -u

for c in swaymsg jq grim gjs od awk; do
  command -v "$c" >/dev/null 2>&1 || { echo "eksik komut: $c" >&2; exit 1; }
done
[ -n "${SWAYSOCK:-}" ] || { echo "SWAYSOCK tanımsız: sway oturumu içinden çalıştır" >&2; exit 1; }

APP=renk-probe
TMP=$(mktemp -d)
OUT="$TMP/points"
PID=""
cleanup() { [ -n "$PID" ] && kill "$PID" 2>/dev/null; rm -rf "$TMP"; }
trap cleanup EXIT

# ---------------------------------------------------------------- probe penceresi
# Pencere çerçevesiz: sway'in window_rect'i ile pencere içi koordinatlar birebir örtüşür.
# fg/selected_fg için "█" glifi kullanılır, içi düz dolu olduğundan ortası tam yazı rengidir.
# Okunacak noktaları GTK kendi yerleşiminden hesaplayıp dosyaya yazar.
cat > "$TMP/probe.js" <<'JS'
imports.gi.versions.Gtk = '3.0';
const { Gtk, GLib } = imports.gi;

GLib.set_prgname('renk-probe');
Gtk.init(null);

const out = GLib.getenv('PROBE_OUT');
const win = new Gtk.Window({ title: 'renk-probe', decorated: false, resizable: false });
win.set_default_size(320, 180);

const GLYPHS = '<span size="xx-large">██████████████</span>';
const box = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 16, margin: 16 });

const fgLabel = new Gtk.Label();
fgLabel.set_markup(GLYPHS);
box.pack_start(fgLabel, false, false, 0);

const list = new Gtk.ListBox({ selection_mode: Gtk.SelectionMode.SINGLE, can_focus: false });
const row = new Gtk.ListBoxRow({ can_focus: false });
const selLabel = new Gtk.Label({ margin: 8 });
selLabel.set_markup(GLYPHS);
row.add(selLabel);
list.add(row);
box.pack_start(list, false, false, 0);

win.add(box);
win.connect('destroy', () => Gtk.main_quit());
win.show_all();
list.select_row(row);

// widget'ın (dx, dy) noktasını pencere koordinatına çevirir
function at(widget, fx, fy, dx, dy) {
    const a = widget.get_allocation();
    const [ok, x, y] = widget.translate_coordinates(
        win, Math.floor(a.width * fx) + dx, Math.floor(a.height * fy) + dy);
    return ok ? `${x},${y}` : null;
}

GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
    const W = win.get_allocated_width(), H = win.get_allocated_height();
    const glyphPts = w => [-24, -12, 0, 12, 24].map(d => at(w, 0.5, 0.5, d, 0));
    const lines = [
        'bg ' + [`4,4`, `${W - 5},4`, `4,${H - 5}`].join(' '),
        'fg ' + glyphPts(fgLabel).filter(Boolean).join(' '),
        'selected_bg ' + [at(row, 0, 0.5, 4, 0), at(row, 1, 0.5, -5, 0)].filter(Boolean).join(' '),
        'selected_fg ' + glyphPts(selLabel).filter(Boolean).join(' '),
    ];
    GLib.file_set_contents(out, imports.byteArray.fromString(lines.join('\n') + '\n'));
    return GLib.SOURCE_REMOVE;
});

Gtk.main();
JS

# ---------------------------------------------------------------- yardımcılar
win_origin() {  # pencere iç alanının ekrandaki sol-üst köşesi: "x y"
  swaymsg -t get_tree 2>/dev/null | jq -r --arg a "$APP" '
    .. | objects
    | select(.pid? != null and (.app_id? == $a or .name? == $a))
    | "\(.rect.x + .window_rect.x) \(.rect.y + .window_rect.y)"' | head -n1
}

px() {  # px <x> <y>: ekrandaki tek pikselin rengini #rrggbb olarak basar
  grim -s 1 -g "$1,$2 1x1" -t ppm - 2>/dev/null | tail -c 3 | od -An -tu1 \
    | awk 'NF == 3 { printf "#%02x%02x%02x", $1, $2, $3 }'
}

role_color() {  # role_color <rol>: dosyadaki noktaları okur, en sık geçen rengi basar
  local role=$1 pts p x y
  pts=$(awk -v r="$role" '$1 == r { $1 = ""; print }' "$OUT")
  for p in $pts; do
    x=${p%,*}; y=${p#*,}
    px $((OX + x)) $((OY + y)); echo
  done | grep . | sort | uniq -c | sort -rn | awk 'NR == 1 { print $2 }'
}

# ---------------------------------------------------------------- akış
# Pencere floating olsun ki tiling düzeni bozulmasın (kural sway yeniden yüklenene dek kalır)
swaymsg "for_window [app_id=\"$APP\"] floating enable" >/dev/null 2>&1

PROBE_OUT="$OUT" gjs "$TMP/probe.js" 2>"$TMP/probe.err" &
PID=$!

# pencere sway ağacında görünene kadar bekle (en fazla ~5 sn)
geom=""
for _ in $(seq 50); do
  geom=$(win_origin)
  [ -n "$geom" ] && break
  sleep 0.1
done
if [ -z "$geom" ]; then
  echo "probe penceresi sway ağacında bulunamadı" >&2
  [ -s "$TMP/probe.err" ] && cat "$TMP/probe.err" >&2
  exit 1
fi

swaymsg "[app_id=\"$APP\"] focus" >/dev/null 2>&1   # backdrop (odaksız) renklerini önlemek için

# probe noktaları yazana kadar bekle (en fazla ~5 sn)
for _ in $(seq 50); do
  [ -s "$OUT" ] && break
  sleep 0.1
done
[ -s "$OUT" ] || { echo "probe nokta dosyası oluşmadı" >&2; cat "$TMP/probe.err" >&2; exit 1; }
sleep 0.3   # kompozitörün son kareyi çizmesi için

read -r OX OY < <(win_origin)

bg=$(role_color bg);              fg=$(role_color fg)
sbg=$(role_color selected_bg);    sfg=$(role_color selected_fg)

[ -n "$bg" ] && [ "$fg" = "$bg" ]   && echo "uyarı: fg, bg ile aynı çıktı (glif çizilmemiş ya da nokta kaçmış olabilir)" >&2
[ -n "$sbg" ] && [ "$sfg" = "$sbg" ] && echo "uyarı: selected_fg, selected_bg ile aynı çıktı" >&2

printf '{"bg":"%s","fg":"%s","selected_bg":"%s","selected_fg":"%s"}\n' "$bg" "$fg" "$sbg" "$sfg"
