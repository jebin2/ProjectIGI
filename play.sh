#!/usr/bin/env bash
# Project IGI: I'm Going In — play on Linux (Arch-based distros).
#
#   ./play.sh              install on first run, then start the game
#   ./play.sh --reinstall  repair the install, then start the game
#   ./play.sh --uninstall  remove the game, prefix and launcher
#   ./play.sh --export [FILE]   pack the installed, patched game into one file
#   ./play.sh --publish         export + upload it to the private bundle repo
#   ./play.sh --import FILE     install from a bundle file, then start the game
#
# On first run everything is set up automatically:
#   - missing packages via pacman (asks for your sudo password once)
#   - the game: from the private bundle release if `gh` can see it, otherwise
#     the original US disc (Redump copy from archive.org, MD5-checked)
#   - a dedicated Wine prefix, the no-CD exe, an app-launcher entry
# No Lutris, no loop-mounting, no Windows installer.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${IGI_HOME:-$HOME/Games/ProjectIGI}"
CACHE="$ROOT/source"
PREFIX="$ROOT/prefix"
GAME="$PREFIX/drive_c/Games/IGI"
LAUNCHER="$ROOT/igi"
MARKER="$ROOT/.installed"
DESKTOP="${XDG_DATA_HOME:-$HOME/.local/share}/applications/project-igi.desktop"

DISC_URL="https://archive.org/download/Nova_ProjectIGIUSA/Project%20IGI%20-%20I%27m%20Going%20In%20%28USA%29%20%28En%2CFr%2CDe%2CEs%2CIt%29.7z"
DISC_FILE="$CACHE/igi-usa.7z"
DISC_MD5="40aa4f19d20c6dbfa65a16a54832af06"

# Ready-made bundle of the patched game folder, kept in a PRIVATE GitHub repo
# (it contains the full game, so it must not be public). Fetched with `gh`;
# anyone without access silently falls back to archive.org.
BUNDLE_REPO="${IGI_BUNDLE_REPO:-jebin2/ProjectIGI-bundle}"
BUNDLE_ASSET="igi-game.tar.zst"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

uninstall() {
  say "Removing $ROOT and the app-launcher entry"
  rm -rf "$ROOT"
  rm -f "$DESKTOP"
  say "Done. (Packages such as wine were left installed.)"
}

install_deps() {
  # command -> pacman package
  local -A need=([wine]=wine [xorriso]=libisoburn [bsdtar]=libarchive
                 [unzip]=unzip [curl]=curl [python3]=python)
  local missing=() cmd
  for cmd in "${!need[@]}"; do
    command -v "$cmd" >/dev/null || missing+=("${need[$cmd]}")
  done
  # A gamepad is plugged in: get AntiMicroX so the bundled profile can map it.
  if compgen -G '/dev/input/by-id/*-event-joystick' >/dev/null && ! command -v antimicrox >/dev/null; then
    missing+=(antimicrox)
  fi
  if ((${#missing[@]})); then
    command -v pacman >/dev/null || die "Missing: ${missing[*]} (install them with your package manager)"
    say "Installing packages: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
  fi
}

fetch_disc() {
  mkdir -p "$CACHE"
  if [[ -f "$DISC_FILE" ]] && echo "$DISC_MD5  $DISC_FILE" | md5sum -c --status; then
    say "Disc image already downloaded"
    return
  fi
  say "Downloading the game disc (~260 MB) from archive.org"
  curl -fL --retry 3 -C - -o "$DISC_FILE.part" "$DISC_URL" || curl -fL --retry 3 -o "$DISC_FILE.part" "$DISC_URL"
  mv "$DISC_FILE.part" "$DISC_FILE"
  echo "$DISC_MD5  $DISC_FILE" | md5sum -c --status || die "Checksum mismatch on $DISC_FILE — delete it and re-run"
}

extract_game() {
  rm -rf "$ROOT"/.work.*
  local work; work="$(mktemp -d "$ROOT/.work.XXXXXX")"

  say "Unpacking disc image"
  bsdtar -xf "$DISC_FILE" -C "$work" '*Track 1).bin'
  local bin; bin="$(find "$work" -name '*Track 1).bin' | head -1)"
  [[ -n "$bin" ]] || die "Track 1 not found in $DISC_FILE"

  # Track 1 is raw MODE1/2352: keep the 2048 user-data bytes of each sector.
  python3 -I - "$bin" "$work/igi.iso" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
with open(src, "rb") as f, open(dst, "wb") as o:
    while b := f.read(2352 * 512):
        o.write(b"".join(b[i + 16:i + 2064] for i in range(0, len(b), 2352)))
PY
  rm -f "$bin"

  say "Copying game files"
  if [[ -e "$GAME" ]]; then chmod -R u+w "$GAME"; rm -rf "$GAME"; fi
  mkdir -p "$(dirname "$GAME")"
  xorriso -osirrox on -indev "$work/igi.iso" -extract /pc "$GAME" >/dev/null 2>&1 \
    || die "Could not read the game folder from the disc image"
  chmod -R u+w "$GAME"
  rm -rf "$work"
}

export_bundle() {  # [out-file] -> prints path
  [[ -f "$MARKER" && -f "$GAME/IGI.exe" ]] || die "Nothing to export: install the game first"
  local out="${1:-$PWD/$BUNDLE_ASSET}"
  say "Packing $GAME" >&2
  tar -C "$(dirname "$GAME")" -I 'zstd -19 -T0 -q' -cf "$out.part" "$(basename "$GAME")"
  mv "$out.part" "$out"
  (cd "$(dirname "$out")" && sha256sum "$(basename "$out")" >"$(basename "$out").sha256")
  say "Wrote $out ($(du -h "$out" | cut -f1)) and $(basename "$out").sha256" >&2
  printf '%s\n' "$out"
}

publish_bundle() {
  command -v gh >/dev/null || die "publish needs the GitHub CLI (gh)"
  local dir out tag
  dir="$(mktemp -d)"; out="$(export_bundle "$dir/$BUNDLE_ASSET")"
  if ! gh repo view "$BUNDLE_REPO" >/dev/null 2>&1; then
    say "Creating private repo $BUNDLE_REPO"
    gh repo create "$BUNDLE_REPO" --private --add-readme \
      --description "Private ready-made Project IGI bundle for ProjectIGI/play.sh" >/dev/null
  fi
  [[ "$(gh repo view "$BUNDLE_REPO" --json visibility -q .visibility)" == PRIVATE ]] \
    || die "$BUNDLE_REPO is not private; refusing to upload the game there"
  tag="bundle-$(date +%Y%m%d-%H%M%S)"
  say "Uploading to $BUNDLE_REPO release $tag"
  gh release create "$tag" -R "$BUNDLE_REPO" --latest --title "$tag" \
    --notes "Patched Project IGI game folder for play.sh --import (made by --publish)." \
    "$out" "$out.sha256" >/dev/null
  rm -rf "$dir"
  say "Published. New installs with access to $BUNDLE_REPO will use it."
}

get_bundle() {  # prints a verified local bundle path, or returns 1
  local f="${IGI_BUNDLE:-}"
  if [[ -n "$f" ]]; then
    [[ -f "$f" ]] || { warn "Bundle not found: $f"; return 1; }
    if [[ -f "$f.sha256" ]]; then
      (cd "$(dirname "$f")" && sha256sum -c --status "$(basename "$f").sha256") \
        || { warn "Checksum mismatch: $f"; return 1; }
    fi
    printf '%s\n' "$f"; return 0
  fi
  command -v gh >/dev/null || return 1
  gh release view -R "$BUNDLE_REPO" >/dev/null 2>&1 || return 1
  mkdir -p "$CACHE"
  say "Downloading the ready-made game bundle from $BUNDLE_REPO" >&2
  rm -f "$CACHE/$BUNDLE_ASSET" "$CACHE/$BUNDLE_ASSET.sha256"
  gh release download -R "$BUNDLE_REPO" -D "$CACHE" -p "$BUNDLE_ASSET" -p "$BUNDLE_ASSET.sha256" \
    || { warn "Bundle download failed"; return 1; }
  (cd "$CACHE" && sha256sum -c --status "$BUNDLE_ASSET.sha256") \
    || { warn "Bundle checksum mismatch"; return 1; }
  printf '%s\n' "$CACHE/$BUNDLE_ASSET"
}

unpack_bundle() {
  say "Unpacking the game bundle"
  if [[ -e "$GAME" ]]; then chmod -R u+w "$GAME"; rm -rf "$GAME"; fi
  mkdir -p "$(dirname "$GAME")"
  tar -C "$(dirname "$GAME")" -I zstd -xf "$1"
  [[ -f "$GAME/IGI.exe" ]] || die "Bundle did not contain the game folder"
}

make_prefix() {
  if [[ -f "$PREFIX/system.reg" ]]; then
    say "Wine prefix exists"
    return
  fi
  say "Creating Wine prefix (first run takes a minute)"
  mkdir -p "$PREFIX"
  # Prefer a 32-bit prefix (IGI is a 32-bit 2000-era game); fall back to the
  # default WoW64 prefix on Wine builds that cannot create win32 prefixes.
  if ! WINEARCH=win32 WINEPREFIX="$PREFIX" WINEDEBUG=-all wineboot -i >/dev/null 2>&1; then
    warn "32-bit prefix not supported by this Wine build, using the default"
    rm -rf "$PREFIX"; mkdir -p "$PREFIX"
    WINEPREFIX="$PREFIX" WINEDEBUG=-all wineboot -i >/dev/null 2>&1
  fi
  WINEPREFIX="$PREFIX" wineserver -w
}

patch_game() {
  say "Applying the no-CD exe"
  unzip -o -q "$REPO_DIR/igi_v10_all.zip" IGI.exe -d "$GAME"

  # Default mission resolution is 640x480 (GOGfxDisp in config.qvm), which looks
  # very blurry on modern screens. Switch it to 1600x1200 (4:3, fits 1200-line
  # screens exactly). Same byte length, so an in-place edit is safe.
  python3 -I - "$GAME/config.qvm" <<'PY' || warn "Could not set the resolution; pick one in Configuration > Graphics"
import sys
p = sys.argv[1]; b = open(p, "rb").read()
old = bytes.fromhex("04 80 02 00 04 e0 01 00 03 20 00")  # 640, 480, 32
new = bytes.fromhex("04 40 06 00 04 b0 04 00 03 20 00")  # 1600, 1200, 32
if b.count(old) != 1: sys.exit(0 if new in b else 1)
open(p, "wb").write(b.replace(old, new))
PY

  # The intro .avi files use Indeo 5 and crash Wine's video path; skip them.
  local f
  for f in "$GAME"/screens/intro/*.avi; do
    if [[ -e "$f" ]]; then mv -f "$f" "$f.bak"; fi
  done
}

make_launcher() {
  cp "$REPO_DIR/igi.png" "$ROOT/igi.png"
  cp "$REPO_DIR/controller_mapping.gamecontroller.amgp" "$ROOT/controller.amgp"

  {
    printf '#!/usr/bin/env bash\n# Project IGI launcher (generated by play.sh)\n'
    printf 'ROOT=%q\nGAME=%q\nexport WINEPREFIX=%q\n' "$ROOT" "$GAME" "$PREFIX"
    cat <<'EOF'
export WINEDEBUG="${WINEDEBUG:--all}"
# Controller: if AntiMicroX is installed and not already running, load the
# profile for the length of the game. Start it before DISPLAY is cleared below
# (it crashes without an X display) and send keys via uinput, which reaches a
# native Wayland window; its default (XTest) only reaches X11 apps.
pad=
if command -v antimicrox >/dev/null && ! pgrep -x antimicrox >/dev/null; then
  antimicrox --hidden --eventgen uinput --profile "$ROOT/controller.amgp" >/dev/null 2>&1 &
  pad=$!
fi

# Wayland: Wine's native Wayland driver scales IGI's 4:3 fullscreen mode to the
# whole screen (via XWayland it sits small in a corner).
[[ -n "${WAYLAND_DISPLAY:-}" ]] && unset DISPLAY
# csmt=0: IGI locks a vertex buffer on nearly every draw; with Wine's separate
# render thread each lock is a cross-thread stall (8-9 fps -> ~30 fps).
# (Wine's Vulkan renderer is not an option: it breaks IGI's HUD and walls.)
export WINE_D3D_CONFIG="${WINE_D3D_CONFIG:-csmt=0}"

# A previous session that hung on exit would block this one: clear it.
pgrep -x IGI.exe >/dev/null && wineserver -k && sleep 1


cd "$GAME"
wine IGI.exe "$@" &
game=$!

# IGI sometimes keeps running (and burning CPU) after its window closes on
# quit. On Hyprland, watch for that and end it.
if command -v hyprctl >/dev/null && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  seen=0 gone=0
  while kill -0 "$game" 2>/dev/null; do
    sleep 2
    if hyprctl clients -j 2>/dev/null | grep -q '"class": "igi.exe"'; then
      seen=1 gone=0
    elif ((seen)) && ((++gone >= 3)); then
      wineserver -k
      break
    fi
  done
fi
wait "$game" 2>/dev/null
[[ -n "$pad" ]] && kill "$pad" 2>/dev/null
exit 0
EOF
  } >"$LAUNCHER"
  chmod +x "$LAUNCHER"

  mkdir -p "$(dirname "$DESKTOP")"
  cat >"$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Project IGI
Comment=I'm Going In (2000) via Wine
Exec="$LAUNCHER"
Icon=$ROOT/igi.png
Categories=Game;ActionGame;
Terminal=false
EOF
  command -v update-desktop-database >/dev/null && update-desktop-database -q "$(dirname "$DESKTOP")" || true
}

install() {
  install_deps
  mkdir -p "$ROOT"
  rm -f "$MARKER"
  local bundle
  if bundle="$(get_bundle)"; then
    make_prefix
    unpack_bundle "$bundle"
  else
    [[ -z "${IGI_BUNDLE:-}" ]] || die "Could not use bundle $IGI_BUNDLE"
    fetch_disc
    make_prefix
    extract_game
  fi
  patch_game
  touch "$MARKER"
  say "Installed. Next time you can also start it from your app launcher (\"Project IGI\")."
}

main() {
  case "${1:-}" in
    --uninstall) uninstall; return ;;
    --reinstall) install ;;
    --export) export_bundle "${2:-}" >/dev/null; return ;;
    --publish) publish_bundle; return ;;
    --import) [[ -n "${2:-}" ]] || die "Usage: ./play.sh --import FILE"
              IGI_BUNDLE="$(realpath "$2")"; install ;;
    -h|--help) sed -n '2,18p' "$0"; return ;;
    "") if [[ -f "$MARKER" ]]; then install_deps; else install; fi ;;
    *) die "Unknown option: $1 (try --help)" ;;
  esac

  make_launcher >/dev/null  # refresh, so launcher fixes reach old installs
  say "Starting Project IGI"
  exec "$LAUNCHER"
}

main "$@"
