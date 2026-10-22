#!/bin/sh
# Install the Uzbek 2026 keyboard layout on macOS or Linux, in one command:
#
#   curl -fsSL https://raw.githubusercontent.com/botirakhmedov/klfc_uzbek/main/install.sh | sh
#
# It asks which of the two layouts you want. To skip the question, or when there is no
# terminal to ask on, set the options in the environment instead:
#
#   VARIANT=uz-qserty   ş ç ö ğ on the w c [ ] keys (the default)
#   VARIANT=uz-altgr    US QWERTY untouched, the letters on AltGr
#   ACTION=uninstall    remove it again
#   REF=some-branch     install from a branch or tag other than main
#
#   curl -fsSL https://raw.githubusercontent.com/botirakhmedov/klfc_uzbek/main/install.sh \
#     | VARIANT=uz-altgr sh
#
# Windows is not covered: its .klc file has to be compiled with MSKLC, which is a GUI
# installer. See README.md.
set -eu

REPO="${REPO:-botirakhmedov/klfc_uzbek}"
REF="${REF:-main}"
VARIANT="${VARIANT:-}"
ACTION="${ACTION:-install}"

BUNDLE_NAME="Uzbek2026.bundle"
MACOS_DEST="$HOME/Library/Keyboard Layouts"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# What the AltGr key is called on this system.
altgr() {
  if [ "$(uname -s)" = "Darwin" ]; then
    printf 'Option'
  else
    printf 'AltGr'
  fi
}

# Whether there is a terminal to ask on. /dev/tty exists as a device node even with no
# controlling terminal behind it, and the permission bits look fine, so the only honest
# test is to open it.
have_tty() {
  { true > /dev/tty; } 2>/dev/null && { true < /dev/tty; } 2>/dev/null
}

# Ask which layout to install. Piping the script into sh puts the script itself on
# stdin, so the question has to go to the terminal directly; where there is no terminal
# — CI, a cron job, a container — the default stands.
choose_variant() {
  [ -n "$VARIANT" ] && return 0

  if [ "$ACTION" != "install" ] || ! have_tty; then
    VARIANT=uz-qserty
    return 0
  fi

  {
    printf '%s\n' "Which layout do you want?"
    printf '%s\n' ""
    printf '%s\n' "  1) uz-qserty   ş ç ö ğ get keys of their own, on w c [ ]"
    printf '%s\n' "                 c and w are not letters of the 2026 alphabet, so no"
    printf '%s\n' "                 letter has to move; w and c come back on $(altgr)."
    printf '%s\n' ""
    printf '%s\n' "  2) uz-altgr    US QWERTY is left exactly as it is"
    printf '%s\n' "                 ş ç ö ğ are on $(altgr) + s, c, o, g."
    printf '%s\n' ""
  } > /dev/tty

  while :; do
    printf '%s' "Choose 1 or 2 [1]: " > /dev/tty
    read -r answer < /dev/tty || answer=""
    case "$answer" in
      "" | 1) VARIANT=uz-qserty; break ;;
      2) VARIANT=uz-altgr; break ;;
      *) printf '%s\n' "Please answer 1 or 2." > /dev/tty ;;
    esac
  done
  printf '\n' > /dev/tty
}

# What the keys do, printed after installing, because an installed keyboard nobody knows
# how to type on is the same as no keyboard.
tutorial() {
  key="$(altgr)"
  say ""
  say "How it types:"
  say ""
  if [ "$VARIANT" = "uz-qserty" ]; then
    say "  the w key  ->  ş          the c key  ->  ç"
    say "  the [ key  ->  ö          the ] key  ->  ğ"
    say "  the ' key  ->  ʼ          tutuq belgisi (U+02BC), a letter, not a quote mark"
    say ""
    say "  Shift gives Ş Ç Ö Ğ, as usual."
    say ""
    say "  w c [ ] ' are still reachable, on $key:"
    say "    $key + w  ->  w       $key + c  ->  c       $key + '  ->  '"
    say "    $key + [  ->  [       $key + ]  ->  ]"
  else
    say "  $key + s  ->  ş          $key + c  ->  ç"
    say "  $key + o  ->  ö          $key + g  ->  ğ"
    say "  $key + '  ->  ʼ          tutuq belgisi (U+02BC), a letter, not a quote mark"
    say ""
    say "  Hold Shift as well for Ş Ç Ö Ğ."
    say "  Everything else is US QWERTY, unchanged."
  fi
}

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

  if [ "$VARIANT" = "uz-qserty" ]; then
    name="Uzbek (2026) QŞERTY"
  else
    name="Uzbek (2026) AltGr"
  fi

  say "Installed to $MACOS_DEST/$BUNDLE_NAME"
  say ""
  say "macOS only reads new keyboard layouts when you log in, so log out and back in."
  say "Then add '$name' under:"
  say "  System Settings > Keyboard > Text Input > Input Sources > + > Others"
  say ""
  say "Both layouts are in the bundle, so you can switch later without reinstalling."
  tutorial
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

# How to switch to the layout right now, which depends on the session. Under Wayland
# setxkbmap reaches XWayland only and leaves the real keyboard alone — it prints
# "Running setxkbmap against an Xwayland server" and appears to do nothing — so the
# compositor has to be told instead.
session_hint() {
  layout="$1"
  if [ "${XDG_SESSION_TYPE:-}" = "wayland" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    say "This is a Wayland session, where setxkbmap only reaches XWayland and leaves the"
    say "real keyboard alone. Add the layout in your desktop's keyboard settings, or on"
    say "GNOME run:"
    say "  gsettings set org.gnome.desktop.input-sources sources \"[('xkb','$layout')]\""
  else
    say "Pick it in your desktop's keyboard settings, or try it in this session with:"
    say "  setxkbmap $layout"
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
  session_hint "$layout"
  tutorial
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

choose_variant

case "$VARIANT" in
  uz-qserty | uz-altgr) ;;
  *) die "unknown variant '$VARIANT'; expected uz-qserty or uz-altgr" ;;
esac

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
