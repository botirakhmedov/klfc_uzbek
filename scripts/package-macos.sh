#!/usr/bin/env bash
# Wrap the generated .keylayout files into a single installable macOS bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/dist/macos"
BUNDLE="$SRC/Uzbek2026.bundle"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/Resources"

# Each keylayout in a bundle needs its own unique negative id; KLFC emits -1337 for all of them.
ID=-2026
for KL in "$SRC"/uz-*.keylayout; do
  NAME="$(basename "$KL" .keylayout)"
  # XML 1.0 forbids references to control characters, which KLFC emits for Escape and
  # the function keys. Apple's own keylayouts declare XML 1.1, which allows them.
  # Three fixes on top of what KLFC emits:
  #  * a unique negative id per layout (KLFC hardcodes -1337, which collides in a bundle);
  #  * XML 1.1, because XML 1.0 forbids the references to control characters that KLFC
  #    emits for Escape and the function keys, and Apple's own keylayouts declare 1.1;
  #  * virtual key codes 10 and 50 swapped. KLFC puts the ` key on 10 and the ISO key on
  #    50, but Apple's own ABC layout is the other way round (50 = kVK_ANSI_Grave, left of
  #    the 1 key; 10 = kVK_ISO_Section). With KLFC's order the ` key is dead on ANSI
  #    keyboards, which is what most of our users have.
  sed -e "s/id=\"-1337\"/id=\"$ID\"/" \
      -e '1s/version="1.0"/version="1.1"/' \
      -e 's/code="10"/code="@@SWAP@@"/g' \
      -e 's/code="50"/code="10"/g' \
      -e 's/code="@@SWAP@@"/code="50"/g' \
      "$KL" > "$BUNDLE/Contents/Resources/$NAME.keylayout"
  ID=$((ID - 1))
done

INFO="$BUNDLE/Contents/Info.plist"

# Written out in full rather than assembled with PlistBuddy, so that a Linux machine can
# produce the macOS bundle as well.
{
  cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>uz.alifbo.keyboardlayouts</string>
	<key>CFBundleName</key>
	<string>Uzbek2026</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleSignature</key>
	<string>????</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
PLIST
  for KL in "$BUNDLE/Contents/Resources"/*.keylayout; do
    NAME="$(basename "$KL" .keylayout)"
    printf '\t<key>KLInfo_%s</key>\n' "$NAME"
    printf '\t<dict>\n'
    printf '\t\t<key>TISInputSourceID</key>\n\t\t<string>uz.alifbo.keyboardlayouts.%s</string>\n' "$NAME"
    printf '\t\t<key>TISIntendedLanguage</key>\n\t\t<string>uz-Latn</string>\n'
    printf '\t</dict>\n'
  done
  printf '</dict>\n</plist>\n'
} > "$INFO"

command -v plutil >/dev/null && plutil -lint "$INFO"

# The loose keylayout files were only the input to the bundle; the bundle is what gets
# installed, so leave only that behind.
rm -f "$SRC"/uz-*.keylayout

cat > "$SRC/install.sh" <<'INST'
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
INST
chmod +x "$SRC/install.sh"

cat > "$SRC/uninstall.sh" <<'UNINST'
#!/usr/bin/env bash
set -euo pipefail
rm -rf "$HOME/Library/Keyboard Layouts/Uzbek2026.bundle"
echo "Removed. Log out and back in to finish."
UNINST
chmod +x "$SRC/uninstall.sh"

echo "packaged $BUNDLE"
