# Project IGI on Linux

Play Project IGI: I'm Going In (2000) on Arch-based Linux with Wine, using one command.

```bash
git clone https://github.com/jebin2/ProjectIGI.git
cd ProjectIGI
./play.sh
```

The first run installs everything and starts the game. After that it just starts the game. It's also in your app launcher as **Project IGI**.

## Commands

| Command | Does |
|---------|------|
| `./play.sh` | Install if needed, then play |
| `./play.sh --reinstall` | Repair the install, then play |
| `./play.sh --uninstall` | Remove the game and launcher (packages stay) |
| `./play.sh --publish` | Upload your install as a ready-made bundle (private repo) |
| `./play.sh --export [FILE]` | Write that bundle to a local file |
| `./play.sh --import FILE` | Install from a bundle file |
| `./play.sh --mod FILE` | Add the Neonix Remastered HD mod (see below) |

The game installs to `~/Games/ProjectIGI`. Set `IGI_HOME=/path` to put it elsewhere.

## How it works

- **Packages:** installs anything missing with `sudo pacman` (`wine`, `libisoburn`, and AntiMicroX if a gamepad is plugged in).
- **Game files:** taken from the latest release of the **private** repo `jebin2/ProjectIGI-bundle` if `gh` can see it (1.6 GB with the HD mod included, ready in a few minutes). Otherwise it downloads the original US disc from [archive.org](https://archive.org/details/Nova_ProjectIGIUSA) (MD5-checked) and copies the game straight off the image. The bundle contains the full game: keep that repo private.
- **Fixes applied:**
  - No-CD exe, so no disc check.
  - The intro videos are skipped, because they crash Wine.
  - Missions run at 1600×1200 instead of 640×480. The menus stay 640×480.
  - Wine's Wayland driver, so the picture fills the screen instead of sitting in a corner.
  - `csmt=0`, which takes the game from about 8 fps to about 30.

## HD mod (optional)

[Project IGI Neonix Remastered](https://www.nexusmods.com/projectigi/mods/5) adds HD textures, sharp menus, a proper widescreen view and smoother timing. Download the main file from Nexus (free account, 1.6 GB), then:

```bash
./play.sh --mod ~/Downloads/"IGI 1 Neonix Remastered 1.4-5-1-4-1757006135.zip"
```

It installs the mod and sets your screen's native resolution. It leaves out two of the mod's files: `ddraw.dll`, because DDrawCompat conflicts with Wine, and `lod.qvm`, because under Wine it turns the ground black with red streaks. Rare one-frame black flashes remain.

## Controller

Built for an 8BitDo Ultimate 2C, but any gamepad works. With one plugged in, the launcher loads the AntiMicroX profile automatically.

| Button | Action | | Button | Action |
|--------|--------|-|--------|--------|
| Left stick | Move | | A | Jump |
| Right stick | Look | | B | Walk / run |
| RT | Fire | | X | Reload |
| LT | Alternate fire | | Y | Use |
| RB | Next weapon | | L3 | Crouch |
| LB (hold) + stick | Peek / lean | | R3 | Binoculars |
| D-pad ↑ / ↓ | Zoom in / out | | Back | Map |
| D-pad ← | Previous weapon | | Start | Menu |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Need logs | `WINEDEBUG=err+all ~/Games/ProjectIGI/igi` |
| Small picture in a corner | Start it with `./play.sh` or the app launcher, not under XWayland |
| Game lingers after quitting | Ended automatically on Hyprland. Otherwise run `WINEPREFIX=~/Games/ProjectIGI/prefix wineserver -k` |
| Anything else broken | `./play.sh --reinstall` |

## Files

| File | Purpose |
|------|---------|
| `play.sh` | Installer and launcher |
| `igi_v10_all.zip` | No-CD `IGI.exe` (v1.0) |
| `controller_mapping.gamecontroller.amgp` | AntiMicroX controller profile |
| `igi.png` | App-launcher icon |
