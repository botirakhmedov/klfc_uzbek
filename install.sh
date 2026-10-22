#!/bin/sh
# Install the Uzbek 2026 keyboard layout on macOS or Linux, in one command:
#
#   curl -fsSL https://raw.githubusercontent.com/botirakhmedov/klfc_uzbek/main/install.sh | sh
#
# Options, which have to be passed as environment variables because the script is read
# from a pipe and cannot ask anything:
#
#   VARIANT=uz-altgr    install the AltGr variant instead of the default uz-qserty
#   ACTION=uninstall    remove it again
#   REF=some-branch     install from a branch or tag other than main
#
#   curl -fsSL .../install.sh | VARIANT=uz-altgr sh
#
# Windows is not covered: its .klc file has to be compiled with MSKLC, which is a GUI
# installer. See README.md.
set -eu

REPO="${REPO:-botirakhmedov/klfc_uzbek}"
REF="${REF:-main}"
VARIANT="${VARIANT:-uz-qserty}"
ACTION="${ACTION:-install}"

BUNDLE_NAME="Uzbek2026.bundle"
MACOS_DEST="$HOME/Library/Keyboard Layouts"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

case "$VARIANT" in
  uz-qserty | uz-altgr) ;;
  *) die "unknown variant '$VARIANT'; expected uz-qserty or uz-altgr" ;;
esac

download() {
  url="$1"
  target="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$target" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$target" "$url"
  else
    die "neither curl nor wget is installed"
  fi
}

# Where the layout files come from. Running the script out of a checkout uses that
# checkout, so the copy being tested is the copy being installed; piping it from the web
# downloads the repository. SOURCE=download forces the download either way.
#
# Sets SOURCE_ROOT, and TEMP_ROOT when there is something to delete afterwards.
prepare_source() {
  script_dir=""
  case "${0:-}" in
    */*) script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)" ;;
  esac

  if [ -n "$script_dir" ] && [ -d "$script_dir/dist" ] && [ "${SOURCE:-}" != "download" ]; then
    SOURCE_ROOT="$script_dir"
    TEMP_ROOT=""
    return
  fi

  TEMP_ROOT="$(mktemp -d)"
  download "https://codeload.github.com/$REPO/tar.gz/refs/heads/$REF" "$TEMP_ROOT/repo.tar.gz" \
    || die "could not download $REPO at $REF"
  tar -xzf "$TEMP_ROOT/repo.tar.gz" -C "$TEMP_ROOT"
  # The archive unpacks into a single <repo>-<ref> directory, whose name we read rather
  # than guess, because a ref with a slash in it is flattened.
  SOURCE_ROOT="$(find "$TEMP_ROOT" -maxdepth 1 -mindepth 1 -type d | head -1)"
  [ -n "$SOURCE_ROOT" ] || die "the downloaded archive was empty"
}

clean_source() {
  [ -n "${TEMP_ROOT:-}" ] && rm -rf "$TEMP_ROOT"
  return 0
}

install_macos() {
  prepare_source
  source_bundle="$SOURCE_ROOT/dist/macos/$BUNDLE_NAME"
  [ -d "$source_bundle" ] || die "no $BUNDLE_NAME in the repository at $REF"

  mkdir -p "$MACOS_DEST"
  rm -rf "${MACOS_DEST:?}/${BUNDLE_NAME:?}"
  cp -R "$source_bundle" "$MACOS_DEST/"
  clean_source

  say "Installed to $MACOS_DEST/$BUNDLE_NAME"
  say ""
  say "macOS only reads new keyboard layouts when you log in, so log out and back in."
  say "Then add the layout under:"
  say "  System Settings > Keyboard > Text Input > Input Sources > + > Others"
  say ""
  say "Both variants are in the bundle; pick 'Uzbek (2026) QŞERTY' or 'Uzbek (2026) AltGr'."
}

uninstall_macos() {
  if [ -d "$MACOS_DEST/$BUNDLE_NAME" ]; then
    rm -rf "${MACOS_DEST:?}/${BUNDLE_NAME:?}"
    say "Removed $MACOS_DEST/$BUNDLE_NAME. Log out and back in to finish."
  else
    say "Nothing to remove: $MACOS_DEST/$BUNDLE_NAME does not exist."
  fi
}

# The XKB install scripts write into /usr/share/X11/xkb, so they need root.
as_root() {
  if [ "$(id -u)" = "0" ]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "this step needs root and sudo is not installed; rerun as root"
  fi
}

install_linux() {
  prepare_source
  source_dir="$SOURCE_ROOT/dist/linux/$VARIANT"
  [ -d "$source_dir" ] || die "no $VARIANT layout in the repository at $REF"

  chmod +x "$source_dir"/*.sh "$source_dir"/scripts/* 2>/dev/null || true
  as_root "$source_dir/install-system.sh"
  layout="$(basename "$(find "$source_dir/symbols" -maxdepth 1 -type f | head -1)")"
  clean_source

  say "Installed the XKB layout '$layout'."
  say ""
  say "Pick it in your desktop's keyboard settings, or try it in the current session with:"
  say "  setxkbmap $layout"
}

uninstall_linux() {
  prepare_source
  source_dir="$SOURCE_ROOT/dist/linux/$VARIANT"
  [ -d "$source_dir" ] || die "no $VARIANT layout in the repository at $REF"
  chmod +x "$source_dir"/*.sh "$source_dir"/scripts/* 2>/dev/null || true
  as_root "$source_dir/uninstall-system.sh"
  clean_source
  say "Removed."
}

case "$(uname -s)" in
  Darwin)
    case "$ACTION" in
      install) install_macos ;;
      uninstall) uninstall_macos ;;
      *) die "unknown action '$ACTION'; expected install or uninstall" ;;
    esac
    ;;
  Linux)
    case "$ACTION" in
      install) install_linux ;;
      uninstall) uninstall_linux ;;
      *) die "unknown action '$ACTION'; expected install or uninstall" ;;
    esac
    ;;
  *)
    die "$(uname -s) is not supported by this script. On Windows, compile
dist/windows/$VARIANT/$VARIANT.klc with MSKLC — see README.md."
    ;;
esac
