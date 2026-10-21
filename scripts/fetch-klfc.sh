#!/usr/bin/env bash
# Download the KLFC binary used to generate the desktop layouts.
# Prints the path to the binary on stdout.
set -euo pipefail

VERSION="v1.5.7"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT/.tools"

case "$(uname -s)" in
  Darwin) PLATFORM="macos-amd64" ;;   # runs under Rosetta 2 on Apple Silicon
  Linux)  PLATFORM="linux-amd64" ;;
  *)      echo "unsupported host: $(uname -s)" >&2; exit 1 ;;
esac

# The platform belongs in the cache path: a checkout shared between a Mac and a Linux
# container must not hand one of them the other's binary.
BIN="$TOOLS/klfc-$VERSION-$PLATFORM/klfc"

if [ ! -x "$BIN" ]; then
  mkdir -p "$TOOLS/klfc-$VERSION-$PLATFORM"
  URL="https://github.com/39aldo39/klfc/releases/download/$VERSION/klfc-$PLATFORM-$VERSION.zip"
  echo "fetching $URL" >&2
  curl -sSfL -o "$TOOLS/klfc.zip" "$URL"
  unzip -oq "$TOOLS/klfc.zip" klfc -d "$TOOLS/klfc-$VERSION-$PLATFORM"
  rm -f "$TOOLS/klfc.zip"
  chmod +x "$BIN"
  xattr -d com.apple.quarantine "$BIN" 2>/dev/null || true
fi

echo "$BIN"
