#!/usr/bin/env bash
# Install the Uzbek 2026 keyboard layouts for the current user.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/Library/Keyboard Layouts"
mkdir -p "$DEST"
rm -rf "$DEST/Uzbek2026.bundle"
cp -R "$DIR/Uzbek2026.bundle" "$DEST/"
echo "Installed to $DEST/Uzbek2026.bundle"
echo "Log out and back in, then add the layout in"
echo "System Settings > Keyboard > Text Input > Input Sources > + > Others."
