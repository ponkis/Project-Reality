# Project Reality

Project Reality is a native-PC game project built around the Super Mario 64
decompilation ecosystem. It targets a fixed 30 FPS presentation, native
widescreen rendering, opt-in quality-of-life improvements, and a layered mod
system while preserving the original game's feel. N64 output is deliberately
out of scope.

The current foundation is Ghostship 2.0.0 at commit
`762ce4a6dff8d69b934a41a326ae41e78431e6cd`. It builds C/C++ into a Windows
executable; it is not an emulator.

## Repository boundaries

- `engine/` is a pinned Ghostship source tree.
- `project/` contains Project Reality-owned source assets, configuration, and
  gameplay modules.
- `mods/` is reserved for local development mods and examples.
- ROM images and generated `.o2r`/`.otr` archives are private build inputs and
  are never tracked by Git.

The supported base input is a locally dumped US `.z64` ROM with SHA-1
`9bef1128717f958171a4afac3ed78ee2bb4e86ce`. The ROM is used only to generate
the private base-resource archive; the PC game is compiled natively.

## Current playable slice

`project/` builds a removable Ghostship folder mod named **Project Reality
Core**. It continuously pins presentation to 30 FPS, disables refresh-rate
matching, and exposes a small runtime-status page in Ghostship's Mods sidebar.
The File Select cheat is not part of that mod: it is compiled directly into the
game's native `engine/src/menu/file_select.c` input and rendering path. A fresh
development runtime starts at 1280x720; resizing or fullscreen changes use the
live viewport aspect, so widescreen is native rather than stretched.

Build and stage it after the engine and private archives exist:

```powershell
& .\scripts\dev.ps1 -Task All
```

The staged executable is
`engine/build/project-reality/Release/Ghostship.exe`. The script copies the two
ignored resource archives next to it and stages the mod as
`mods/project-reality-core/`. Removing that folder disables only its 30-FPS
runtime policy and status page; the native File Select cheat remains part of the
game executable. Its saved skip-intro state remains an ordinary Ghostship
preference until it is toggled again or the local configuration is reset.

## File-select cheats

Cheats are accepted only while the file-select screen is active. Enter the
ordered sequence `L`, `R`, `B`, `A` to toggle **Skip Intro**. Every accepted
input appears tightly spaced in the original colorful game font at the bottom
center and plays the cannon-aim camera sound. Completing the sequence layers the
original success sound with Mario's `Yippee!`, rapidly flashes the completed
`LRBA` sequence, and then removes it. Wrong inputs are silent and retain their
normal menu behavior; no ON/OFF text notification is shown.

This system is native game code. It reads and consumes input immediately before
File Select's own click handler and draws through the original game font and
display-list renderer; there is no external cheat program or mod-script hook.

The current toggle controls Ghostship's `DisablePeachCutscene` enhancement,
which bypasses the opening cutscene when an empty save is started. The setting
is saved immediately and can be toggled again with the same sequence.

## Expanding Peach's Castle

The castle interior can be made larger, reshaped, and extended with new wings
while retaining its original visual language. Its three original areas (lobby,
upper floors, and basement) are compiled level content, and each room's visible
geometry, collision room metadata, and room-switch resource must stay in sync.
That makes a staged workflow safer than replacing the whole castle at once:

1. Prove the asset path with one isolated lobby-side room using the original
   shell, texture palette, lighting, and landmark proportions.
2. Add matching custom collision and a deliberate doorway/warp into that room.
3. Build major new wings as Project Reality-owned compiled areas with unique
   resource paths, rather than squeezing a large expansion into one asset
   override.

No castle geometry is changed in this slice; its first new wing should start
from a layout brief so the expansion keeps the castle's recognizable hub flow.

## Private asset pipeline

Never rename or commit the ROM to satisfy an extractor. The extraction workflow
must verify the SHA-1, create an ignored temporary `engine/baserom.us.z64` hard
link, run Ghostship's `ExtractAssets` target, and remove the link in a `finally`
block. The generated `sm64.o2r` remains local and ignored.

Run the repository audit before committing:

```powershell
& .\scripts\check-sensitive-files.ps1
```

Only original Project Reality assets and source belong in commits or future mod
packages. A distributable PC build still needs a deliberate packaging policy;
the local development runtime is not a redistributable bundle.
