#!/usr/bin/env bash
# Erzeugt Favicon und PWA-Icons für Web-App (web/) und Superadmin-Panel
# (superadmin/web/) sowie die Launcher-Icons der Android-App aus einer
# gemeinsamen Bildmarke: weißes „W“ mit Kern-Punkt auf Indigo. Das Panel
# bekommt den dunklen Hintergrund, damit die Browser-Tabs unterscheidbar
# sind. Braucht rsvg-convert.
#   tool/branding/render_icons.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

# $1 = Verlauf oben links, $2 = unten rechts, $3 = Eckenradius (0 = randlos/maskable),
# $4 = Skalierung der Marke (maskable: in der sicheren Zone bleiben),
# $5 = Hintergrund zeichnen (1/0), $6 = Strichfarbe, $7 = Punktfarbe
mark() {
  local from=$1 to=$2 radius=$3 scale=$4 background=${5:-1} stroke=${6:-#ffffff} dot=${7:-#FBBF24}
  local offset; offset=$(awk "BEGIN{print 256*(1-$scale)}")
  local mark_only=1
  [ "$scale" = 0 ] && mark_only=0
  cat <<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="$from"/>
      <stop offset="1" stop-color="$to"/>
    </linearGradient>
  </defs>
$( [ "$background" = 1 ] && echo "  <rect width=\"512\" height=\"512\" rx=\"$radius\" fill=\"url(#bg)\"/>" )
$( [ "$mark_only" = 1 ] && cat <<MARK
  <g transform="translate($offset $offset) scale($scale)">
    <polyline points="104,176 180,372 256,224 332,372 408,176" fill="none" stroke="$stroke"
      stroke-width="60" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="256" cy="120" r="36" fill="$dot"/>
  </g>
MARK
)
</svg>
SVG
}

render() {
  local dir=$1 from=$2 to=$3
  mark "$from" "$to" 112 1 > "$dir/favicon.svg"
  rsvg-convert -w 32 -h 32 "$dir/favicon.svg" -o "$dir/favicon.png"
  rsvg-convert -w 192 -h 192 "$dir/favicon.svg" -o "$dir/icons/Icon-192.png"
  rsvg-convert -w 512 -h 512 "$dir/favicon.svg" -o "$dir/icons/Icon-512.png"
  local maskable; maskable=$(mktemp --suffix=.svg)
  mark "$from" "$to" 0 0.72 > "$maskable"
  rsvg-convert -w 192 -h 192 "$maskable" -o "$dir/icons/Icon-maskable-192.png"
  rsvg-convert -w 512 -h 512 "$maskable" -o "$dir/icons/Icon-maskable-512.png"
  rm -f "$maskable"
}

# Android: klassisches Icon (48 dp, abgerundet) für Android < 8, ab
# Android 8 adaptives Icon aus Hintergrund (randloser Verlauf) und
# Vordergrund (Marke), je 108 dp. Der Launcher zeigt davon nur die
# mittleren 72 dp und schneidet je nach Gerät rund oder eckig zu — die
# Marke bleibt mit 0,64 im sicheren Kreis (66 dp). Ab Android 13 färbt
# das System das einfarbige Icon passend zum Hintergrundbild ein.
render_android() {
  local res=android/app/src/main/res from=$1 to=$2
  local tmp; tmp=$(mktemp -d)
  mark "$from" "$to" 112 1 > "$tmp/legacy.svg"
  mark "$from" "$to" 0 0 > "$tmp/background.svg"
  mark "$from" "$to" 0 0.64 0 > "$tmp/foreground.svg"
  mark "$from" "$to" 0 0.64 0 '#000000' '#000000' > "$tmp/monochrome.svg"
  local density legacy adaptive
  for entry in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
    IFS=: read -r density legacy adaptive <<< "$entry"
    mkdir -p "$res/mipmap-$density"
    rsvg-convert -w "$legacy" -h "$legacy" "$tmp/legacy.svg" -o "$res/mipmap-$density/ic_launcher.png"
    for layer in background foreground monochrome; do
      rsvg-convert -w "$adaptive" -h "$adaptive" "$tmp/$layer.svg" -o "$res/mipmap-$density/ic_launcher_$layer.png"
    done
  done
  mkdir -p "$res/mipmap-anydpi-v26"
  cat > "$res/mipmap-anydpi-v26/ic_launcher.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<!-- Erzeugt von tool/branding/render_icons.sh -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
XML
  rm -rf "$tmp"
}

render web '#6366F1' '#4338CA'
render superadmin/web '#312E81' '#1E1B4B'
render_android '#6366F1' '#4338CA'
echo "Icons erzeugt."
