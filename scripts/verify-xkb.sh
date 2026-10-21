#!/usr/bin/env bash
# Check the generated XKB layouts the way a Linux desktop would use them: run the install
# script into a copy of the system's xkb directory, compile the layout through the
# installed rules, and ask xkbcli how each letter of the 2026 alphabet would be typed.
#
# Compiling the symbols file on its own is not enough. KLFC puts the shift levels in a
# custom key type, and until the install script registers that type every key compiles as
# ONE_LEVEL — the layout looks fine and Shift does nothing.
#
# Needs xkbcli (libxkbcommon-tools) and xkb-data. No root required.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYSTEM_XKB="${XKB_BASE:-/usr/share/X11/xkb}"

command -v xkbcli >/dev/null || { echo "xkbcli not found; install libxkbcommon-tools" >&2; exit 1; }
[ -d "$SYSTEM_XKB" ] || { echo "no xkb data at $SYSTEM_XKB; install xkb-data" >&2; exit 1; }

# The letters that make this layout worth installing, plus the ordinary characters a
# half-registered layout quietly loses.
CHECKS=(
  "ş 0x15F" "Ş 0x15E" "ö 0xF6" "Ö 0xD6" "ğ 0x11F" "Ğ 0x11E" "ç 0xE7" "Ç 0xC7"
  "ʼ 0x2BC" "w 0x77" "c 0x63" "q 0x71" "Q 0x51" "? 0x3F" "@ 0x40" "; 0x3B" "' 0x27"
)

failures=0

for dir in "$ROOT"/dist/linux/*/; do
  variant="$(basename "$dir")"
  layout="$(basename "$(find "$dir/symbols" -maxdepth 1 -type f | head -1)")"

  base="$(mktemp -d)"
  trap 'rm -rf "$base"' EXIT
  cp -r "$SYSTEM_XKB" "$base/xkb"
  "$dir/install-system.sh" -o "$base/xkb" >/dev/null
  export XKB_CONFIG_ROOT="$base/xkb"

  if ! keymap="$(xkbcli compile-keymap --layout "$layout" 2>&1)"; then
    echo "FAIL $variant: the installed layout does not compile"
    sed 's/^/    /' <<<"$keymap"
    failures=$((failures + 1))
    rm -rf "$base"
    continue
  fi

  if grep -q 'type= "ONE_LEVEL"' <<<"$keymap"; then
    echo "FAIL $variant: keys compiled as ONE_LEVEL, so Shift produces nothing"
    failures=$((failures + 1))
  fi

  missing=()
  for check in "${CHECKS[@]}"; do
    character="${check% *}"
    codepoint="${check#* }"
    if ! xkbcli how-to-type --layout "$layout" "$codepoint" 2>/dev/null \
         | grep -qE '^[[:space:]]*[0-9]+'; then
      missing+=("$character")
    fi
  done

  if [ "${#missing[@]}" -ne 0 ]; then
    echo "FAIL $variant: nothing types ${missing[*]}"
    failures=$((failures + 1))
  else
    echo "ok   $variant: installs as '$layout' and types all ${#CHECKS[@]} characters"
  fi

  rm -rf "$base"
done

if [ "$failures" -ne 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "OK: every XKB layout installs and works"
