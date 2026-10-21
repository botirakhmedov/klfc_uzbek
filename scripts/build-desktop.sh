#!/usr/bin/env bash
# Generate the macOS / Windows / Linux layout files from src/*.json into dist/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The layout names carry Ş, and KLFC is a Haskell program: under the C locale that CI
# images and containers default to, GHC refuses to write them and the build dies with
# "commitBuffer: invalid argument (invalid character)".
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *UTF-8 | *utf8 | *UTF8) ;;
  *) export LC_ALL=C.UTF-8 ;;
esac

KLFC="$("$ROOT/scripts/fetch-klfc.sh")"
BUILD="$ROOT/.build"

rm -rf "$BUILD" "$ROOT/dist/macos" "$ROOT/dist/windows" "$ROOT/dist/linux"
mkdir -p "$BUILD" "$ROOT/dist/macos" "$ROOT/dist/windows" "$ROOT/dist/linux"

for SRC in "$ROOT"/src/uz-*.json; do
  VARIANT="$(basename "$SRC" .json)"
  OUT="$BUILD/$VARIANT"
  echo "==> $VARIANT"
  # TMK targets custom-firmware keyboards and cannot encode these letters; skip it.
  "$KLFC" "$SRC" \
    --keylayout "$OUT/keylayout" \
    --klc "$OUT/klc" \
    --xkb "$OUT/xkb" \
    --pkl "$OUT/pkl" \
    --ahk "$OUT/ahk"

  # --- macOS: .keylayout, wrapped in a bundle by package-macos.sh ---
  cp "$OUT"/keylayout/*.keylayout "$ROOT/dist/macos/$VARIANT.keylayout"

  # --- Windows: MSKLC source + two no-install options (AHK, Portable Keyboard Layout) ---
  mkdir -p "$ROOT/dist/windows/$VARIANT"
  cp "$OUT"/klc/*.klc "$ROOT/dist/windows/$VARIANT/$VARIANT.klc"
  cp "$OUT"/ahk/*.ahk "$ROOT/dist/windows/$VARIANT/$VARIANT.ahk"
  cp -R "$OUT"/pkl "$ROOT/dist/windows/$VARIANT/pkl"

  # --- Linux: XKB symbols + install scripts ---
  cp -R "$OUT/xkb" "$ROOT/dist/linux/$VARIANT"
  # KLFC's helper scripts ask for `python`, which distributions stopped shipping when
  # Python 2 was retired; their code is Python 3 already. Written through a temporary
  # file because `sed -i` takes a suffix on BSD and refuses one on GNU.
  for PY in "$ROOT/dist/linux/$VARIANT"/scripts/*.py; do
    sed '1s|/usr/bin/env python$|/usr/bin/env python3|' "$PY" > "$PY.tmp"
    mv "$PY.tmp" "$PY"
    chmod +x "$PY"
  done
done

"$ROOT/scripts/package-macos.sh"
echo "done -> dist/"
