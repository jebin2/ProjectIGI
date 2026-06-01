# Project IGI: I'm Going In — Linux Setup Guide

Running on: **CachyOS / Arch Linux** via **Lutris + GE-Proton + Wine**

---

## Prerequisites

Install required tools:

```bash
sudo pacman -S wine wine-mono winetricks lutris mdf2iso p7zip unzip
```

---

## Step 1 — Download the game files

### From [myabandonware.com](https://www.myabandonware.com/game/project-i-g-i-i-m-going-in-b9h)

Download all three:

- **ISO Version** (337 MB) — `Project-IGI-Im-Going-In_Win_EN_ISO-Version.zip`
- **Game Loader fix** — `Project-IGI-Im-Going-In_Fix_Win_EN.zip`
- **IV50 Codec for Videos** — `Project-IGI-I-m-Going-In_Fix_Win_EN_IV50-Codec-for-Videos.zip`

### From [gamecopyworld.com](https://gamecopyworld.com/games/pc_project_igi.shtml)

Download:

- **No-CD Fixed EXE** → `Project I.G.I. v1.0 [ALL] Fixed EXE` → `igi_v10_all.zip`

> Scan with ClamAV or [VirusTotal](https://www.virustotal.com) before use. ClamAV result was clean; 2/70 detections on VirusTotal are known false positives for old game patches.

---

## Step 2 — Organise files

```bash
mkdir -p ~/Games/ProjectIGI/{source,iso,patches}

# Move downloaded zips into source/
mv Project-IGI-Im-Going-In_Win_EN_ISO-Version.zip ~/Games/ProjectIGI/source/
mv Project-IGI-Im-Going-In_Fix_Win_EN.zip ~/Games/ProjectIGI/source/
mv "Project-IGI-I-m-Going-In_Fix_Win_EN_IV50-Codec-for-Videos.zip" ~/Games/ProjectIGI/source/
mv igi_v10_all.zip ~/Games/ProjectIGI/source/
```

---

## Step 3 — Extract the ISO

```bash
cd ~/Games/ProjectIGI/source
7z x Project-IGI-Im-Going-In_Win_EN_ISO-Version.zip -o../iso/
```

The zip contains a `.mdf` disc image. Convert it to `.iso` since Wine cannot mount `.mdf` directly:

```bash
cd ~/Games/ProjectIGI/iso/"Project IGI ISO"
mdf2iso "Project IGI.mdf" "Project IGI.iso"
```

Mount the ISO:

```bash
sudo mkdir -p /mnt/igi
sudo mount -o loop "Project IGI.iso" /mnt/igi
ls /mnt/igi   # should show: setup.exe, autorun.exe, pc/, directx/, etc.
```

---

## Step 4 — Extract patches

```bash
cd ~/Games/ProjectIGI/source

unzip Project-IGI-Im-Going-In_Fix_Win_EN.zip -d ../patches/IGI_loader/
unzip "Project-IGI-I-m-Going-In_Fix_Win_EN_IV50-Codec-for-Videos.zip" -d "../patches/IV50 Codec/"
unzip igi_v10_all.zip -d ../patches/nocd/
```

---

## Step 5 — Install the game via Lutris

1. Open **Lutris** → click **+** → **Add locally installed game**
2. Set:
   - **Name:** `Project IGI`
   - **Runner:** `Wine` (select GE-Proton as the Wine version)
3. Go to **Game options** tab:
   - **Executable:** `/mnt/igi/setup.exe`
   - **Working directory:** `/mnt/igi`
4. Click **Save** → **Play** — a Windows-style installer will appear
5. Follow the installer with default settings

The game installs to:
```
~/Games/umu/umu-default/drive_c/Program Files (x86)/Eidos Interactive/I'm Going In/pc/
```

> The Wine prefix path may vary. Check `~/Games/umu/` or `~/.wine/` if not found.

---

## Step 6 — Apply the No-CD patch

The original `IGI.exe` requires the game CD on every launch. Replace it with the patched version:

```bash
GAME_DIR=~/"Games/umu/umu-default/drive_c/Program Files (x86)/Eidos Interactive/I'm Going In/pc"

cp ~/Games/ProjectIGI/patches/nocd/IGI.exe "$GAME_DIR/IGI.exe"
```

---

## Step 7 — Copy extra files into the game folder

**IGI Loader** (optional — CD bypass loader, fallback if no-CD patch alone doesn't work):

```bash
cp ~/Games/ProjectIGI/patches/IGI_loader/IGILoader.exe "$GAME_DIR/"
cp ~/Games/ProjectIGI/patches/IGI_loader/InjectIGI.dll "$GAME_DIR/"
```

**cnc-ddraw** (DirectDraw wrapper — fixes graphics glitches on modern systems):

Download from [github.com/CnCNet/cnc-ddraw/releases](https://github.com/CnCNet/cnc-ddraw/releases/latest):

```bash
cd ~/Games/ProjectIGI/patches
wget https://github.com/CnCNet/cnc-ddraw/releases/latest/download/cnc-ddraw.zip
unzip cnc-ddraw.zip -d cnc-ddraw
cp cnc-ddraw/ddraw.dll "$GAME_DIR/"
```

**IV50 Codec** (installs the Intel Indeo Video 5.0 decoder into Wine):

```bash
WINEPREFIX=~/Games/umu/umu-default wine ~/Games/ProjectIGI/patches/"IV50 Codec"/codinstl.exe
```

> **Note:** The IV50 codec installs the correct video decoder but does not fully fix video playback. The intro videos still crash Wine due to `winegstreamer.dll` missing the `winegstreamer_create_color_converter` function — a known unimplemented feature in Wine when using a 64-bit prefix. The workaround is to rename the intro videos (Step 8). A proper fix would require recreating the Wine prefix with `WINEARCH=win32`.

---

## Step 8 — Fix intro video crash

Wine crashes when trying to play the `.avi` intro videos due to a GStreamer incompatibility. Rename them so the game skips them:

```bash
INTRO_DIR=~/"Games/umu/umu-default/drive_c/Program Files (x86)/Eidos Interactive/I'm Going In/pc/screens/intro"

mv "$INTRO_DIR/eidos.avi"     "$INTRO_DIR/eidos.avi.bak"
mv "$INTRO_DIR/innerloop.avi" "$INTRO_DIR/innerloop.avi.bak"
mv "$INTRO_DIR/intro_us.avi"  "$INTRO_DIR/intro_us.avi.bak"
mv "$INTRO_DIR/vp.avi"        "$INTRO_DIR/vp.avi.bak"
```

> The `outro.avi` file can be left as-is — it only plays at the end of the game.

---

## Step 9 — Configure Lutris to launch the game

1. Right-click **Project IGI** in Lutris → **Configure**
2. **Game options** tab — update:
   - **Executable:**
     ```
     /home/YOUR_USERNAME/Games/umu/umu-default/drive_c/Program Files (x86)/Eidos Interactive/I'm Going In/pc/IGI.exe
     ```
   - **Working directory:**
     ```
     /home/YOUR_USERNAME/Games/umu/umu-default/drive_c/Program Files (x86)/Eidos Interactive/I'm Going In/pc
     ```
3. Click **Save** → **Play**

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `IGI CD not found` error | Apply the no-CD patch (Step 6) |
| Game crashes immediately | Rename intro `.avi` files (Step 8) |
| Black screen / graphics issues | Make sure `ddraw.dll` from cnc-ddraw is in the game folder (Step 7) |
| `wrong ELF class` errors in logs | Harmless warnings — game still runs |
| Game not detected as controller-compatible | Not applicable — IGI is keyboard/mouse only |

---

## File Structure Reference

```
~/Games/ProjectIGI/
├── source/         # original downloaded zips (keep as backup)
├── iso/
│   └── Project IGI ISO/
│       ├── Project IGI.mdf
│       ├── Project IGI.mds
│       └── Project IGI.iso   # converted, used for install
└── patches/
    ├── nocd/
    │   └── IGI.exe           # no-CD patched executable
    ├── IGI_loader/
    │   ├── IGILoader.exe
    │   └── InjectIGI.dll
    ├── IV50 Codec/
    │   └── codinstl.exe
    └── cnc-ddraw/
        └── ddraw.dll
```

---

## Notes

- The ISO does **not** need to be mounted after the no-CD patch is applied
- Wine prefix: `~/Games/umu/umu-default/`
- GStreamer errors in Lutris logs are harmless
- If the game has graphical issues, try setting **Wine architecture** to `win32` in Lutris → Runner options
