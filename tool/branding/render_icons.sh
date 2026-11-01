#!/usr/bin/env bash
# Erzeugt Favicon und PWA-Icons für Web-App (web/) und Superadmin-Panel
# (superadmin/web/) aus einer gemeinsamen Bildmarke: weißes „W“ mit
# Kern-Punkt auf Indigo. Das Panel bekommt den dunklen Hintergrund, damit
# die Browser-Tabs unterscheidbar sind. Braucht rsvg-convert.
#   tool/branding/render_icons.sh
set -euo pipefail
cd "$(dirname "$0")/../.."

# $1 = Verlauf oben links, $2 = unten rechts, $3 = Eckenradius (0 = randlos/maskable),
# $4 = Skalierung der Marke (maskable: in der sicheren Zone bleiben)
mark() {
  local from=$1 to=$2 radius=$3 scale=$4
  local offset; offset=$(awk "BEGIN{print 256*(1-$scale)}")
  cat <<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="$from"/>
      <stop offset="1" stop-color="$to"/>
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="$radius" fill="url(#bg)"/>
  <g transform="translate($offset $offset) scale($scale)">
    <polyline points="104,176 180,372 256,224 332,372 408,176" fill="none" stroke="#ffffff"
      stroke-width="60" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="256" cy="120" r="36" fill="#FBBF24"/>
  </g>
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

render web '#6366F1' '#4338CA'
render superadmin/web '#312E81' '#1E1B4B'
echo "Icons erzeugt."
