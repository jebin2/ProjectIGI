# Project IGI: I'm Going In — Linux

One command to install and play Project IGI (2000) on Arch-based Linux with Wine.

```bash
git clone https://github.com/jebin2/ProjectIGI.git
cd ProjectIGI
./play.sh
```

The first run installs everything and starts the game. After that, `./play.sh` starts the game straight away. It's also in your app launcher as **Project IGI**.

---

## What `play.sh` does on first run

1. **Installs missing packages** with `sudo pacman -S --needed` (`wine`, `libisoburn`, `libarchive`, `unzip`, `curl`, `python`). It only asks for your password if something is missing.
2. **Downloads the original US disc** (Redump copy, ~260 MB) from [archive.org](https://archive.org/details/Nova_ProjectIGIUSA) and checks its MD5. It's kept in `~/Games/ProjectIGI/source/`, so re-runs don't download it again.
3. **Creates a dedicated Wine prefix** at `~/Games/ProjectIGI/prefix`. It uses a 32-bit prefix when your Wine build supports one, otherwise the default.
4. **Copies the game straight off the disc image**: it converts the data track to ISO and extracts `pc/`. No mounting, no sudo, no Windows installer.
5. **Applies the no-CD exe** (`igi_v10_all.zip`, the v1.0 Fixed EXE), so the disc is never needed.
6. **Skips the intro/outro videos.** They are Indeo 5 `.avi` files that crash Wine, so they are renamed to `.avi.bak`.
7. **Adds a launcher**: `~/Games/ProjectIGI/igi` plus an app-launcher entry with the game's own icon. On Wayland it uses Wine's native Wayland driver, which scales the game's 4:3 picture to fill the screen height. Through XWayland it would sit small in the top-left corner. It also turns off Wine's separate Direct3D render thread (`csmt=0`). IGI locks a vertex buffer on almost every draw, and with that thread on each lock stalls: about 8–9 fps instead of about 30.

**Resolution:** `play.sh` sets missions to 1600×1200. That's 4:3 like the game, and on a 1200-pixel-tall screen it needs no vertical scaling. Change it in-game under **Configuration → Graphics**. The menus are always 640×480 (their artwork is drawn at that size), so they look soft whatever you pick.

`./play.sh --reinstall` repairs the install. To install somewhere else, use `IGI_HOME=/path ./play.sh`.

### Uninstall

```bash
./play.sh --uninstall
```

This removes `~/Games/ProjectIGI` and the launcher entry. Packages such as `wine` are left installed.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Game won't start / need logs | Run `WINEDEBUG=err+all ~/Games/ProjectIGI/igi` in a terminal |
| `IGI CD not found` | Run `./play.sh --reinstall` (it re-applies the no-CD exe) |
| Broken download | Delete `~/Games/ProjectIGI/source/igi-usa.7z`, then `./play.sh --reinstall` |
| Game sits small in a corner | You're running it through XWayland; start it via `./play.sh` or `~/Games/ProjectIGI/igi`, which use the Wayland driver |
| Game keeps running after you quit | On Hyprland the launcher ends it automatically. Elsewhere it's cleared at the next launch, or run `WINEPREFIX=~/Games/ProjectIGI/prefix wineserver -k` |
| Want to start over | `./play.sh --reinstall` |

---

## Controller support (8BitDo Ultimate 2C)

IGI is keyboard + mouse only. `controller_mapping.gamecontroller.amgp` is an [AntiMicroX](https://github.com/AntiMicroX/antimicrox) profile that maps a controller to IGI's default keys.

**Automatic:** if a controller is plugged in, `play.sh` installs AntiMicroX. The launcher then loads this profile while the game runs and closes AntiMicroX afterwards, unless it was already running, in which case it leaves it alone. To set it up by hand instead: AntiMicroX → **Load Profile** → pick the `.amgp` file.

| Controller | Key sent | In-game action |
|-----------|----------|----------------|
| Left stick | Arrow keys | Move |
| Right stick | Mouse movement | Look / aim |
| RT | Left click | Fire |
| LT | Right click | Next weapon |
| A | Keypad 0 | Jump |
| B | Backspace | Alternate fire |
| X | Enter | Reload |
| Y | Right Shift | Activate |
| LB | C | Map computer |
| RB | Right Ctrl | Crouch |
| Left stick click | Keypad 1 | Peek |
| D-pad up / down | Page Up / Page Down | Zoom in / out |
| D-pad left | O | Previous weapon |
| D-pad right | W | Walk / run toggle |
| Back | Space | Binoculars |
| Start | Right Shift | Activate |
| Guide | Escape | Menu |

---

## Files in this repo

| File | Purpose |
|------|---------|
| `play.sh` | Installs on first run, then starts the game |
| `igi_v10_all.zip` | No-CD `IGI.exe` (v1.0, from gamecopyworld) |
| `controller_mapping.gamecontroller.amgp` | AntiMicroX controller profile |
| `igi.png` | App-launcher icon (from `IGI.exe`) |
