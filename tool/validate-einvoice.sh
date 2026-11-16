#!/usr/bin/env bash
# C15.5 — prüft die von WerkkernERP erzeugten E-Rechnungen gegen die
# amtlichen bzw. offiziellen Regeln:
#   * XRechnung 3.0 (CII): KoSIT-Validator + XRechnung-Konfiguration
#     (Schema, EN-16931-Schematron, XRechnung-CIUS) — Apache 2.0.
#   * ZUGFeRD EN 16931 (Hybrid-PDF): Mustang-CLI (PDF/A-3 + XML) — Apache 2.0.
# Die Werkzeuge landen in ~/.cache/werkkern-einvoice (einmaliger Download).
# Kein Teil von `flutter test` (braucht Netz und Java), läuft vor dem Merge.
#
# Aufruf: tool/validate-einvoice.sh            (Beispiele erzeugen + prüfen)
#         tool/validate-einvoice.sh DATEI...   (nur diese Dateien prüfen)
set -euo pipefail

cd "$(dirname "$0")/.."
CACHE="${WERKKERN_EINVOICE_CACHE:-$HOME/.cache/werkkern-einvoice}"
KOSIT_VERSION=1.6.3
XR_CONFIG_TAG=v2026-08-31
XR_CONFIG_ZIP=xrechnung-3.0.2-validator-configuration-2026-08-31.zip
MUSTANG_VERSION=2.26.0

mkdir -p "$CACHE"
fetch() { # url ziel
  [ -s "$2" ] || { echo "Lade $(basename "$2") …"; curl -fsSL -o "$2.tmp" "$1" && mv "$2.tmp" "$2"; }
}
fetch "https://github.com/itplr-kosit/validator/releases/download/v$KOSIT_VERSION/validator-$KOSIT_VERSION-standalone.jar" \
  "$CACHE/validator-$KOSIT_VERSION-standalone.jar"
fetch "https://github.com/itplr-kosit/validator-configuration-xrechnung/releases/download/$XR_CONFIG_TAG/$XR_CONFIG_ZIP" \
  "$CACHE/$XR_CONFIG_ZIP"
fetch "https://github.com/ZUGFeRD/mustangproject/releases/download/core-$MUSTANG_VERSION/Mustang-CLI-$MUSTANG_VERSION.jar" \
  "$CACHE/Mustang-CLI-$MUSTANG_VERSION.jar"
CONFIG_DIR="$CACHE/xrechnung-config-$XR_CONFIG_TAG"
[ -d "$CONFIG_DIR" ] || { mkdir -p "$CONFIG_DIR" && unzip -q "$CACHE/$XR_CONFIG_ZIP" -d "$CONFIG_DIR"; }

if [ $# -gt 0 ]; then
  FILES=("$@")
else
  SAMPLES="$(mktemp -d)"
  trap 'rm -rf "$SAMPLES"' EXIT
  echo "Erzeuge Beispiele in $SAMPLES …"
  EINVOICE_SAMPLES_DIR="$SAMPLES" flutter test test/tool/einvoice_samples_test.dart >/dev/null
  FILES=("$SAMPLES"/*)
fi

REPORTS="${EINVOICE_REPORTS:-build/einvoice-reports}"
mkdir -p "$REPORTS"
failed=0
for f in "${FILES[@]}"; do
  name="$(basename "$f")"
  case "$name" in
    xrechnung-*.xml|*.xml)
      if grep -q 'urn:xeinkauf.de:kosit:xrechnung' "$f"; then
        if java -jar "$CACHE/validator-$KOSIT_VERSION-standalone.jar" \
            -s "$CONFIG_DIR/scenarios.xml" -r "$CONFIG_DIR" -o "$REPORTS" "$f" >"$REPORTS/$name.log" 2>&1; then
          echo "OK      $name (KoSIT XRechnung 3.0)"
        else
          echo "FEHLER  $name (KoSIT) — siehe $REPORTS/$name.log und ${name%.xml}-report.xml"; failed=1
        fi
      else
        if java -jar "$CACHE/Mustang-CLI-$MUSTANG_VERSION.jar" --action validate --source "$f" --no-notices \
            >"$REPORTS/$name.log" 2>&1 && grep -q 'status="valid"' "$REPORTS/$name.log"; then
          echo "OK      $name (Mustang EN 16931)"
        else
          echo "FEHLER  $name (Mustang) — siehe $REPORTS/$name.log"; failed=1
        fi
      fi
      ;;
    *.pdf)
      if java -jar "$CACHE/Mustang-CLI-$MUSTANG_VERSION.jar" --action validate --source "$f" --no-notices \
          >"$REPORTS/$name.log" 2>&1 && grep -q 'status="valid"' "$REPORTS/$name.log"; then
        echo "OK      $name (Mustang PDF/A-3 + ZUGFeRD)"
      else
        echo "FEHLER  $name (Mustang) — siehe $REPORTS/$name.log"; failed=1
      fi
      ;;
  esac
done
exit $failed
