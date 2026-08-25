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

## First vertical slice

`project/` builds a removable Ghostship folder mod named **Project Reality
Core**. It continuously pins presentation to 30 FPS, disables refresh-rate
matching, and exposes a small runtime-status page in Ghostship's sidebar. It
does not change gameplay or overwrite engine files. A fresh development runtime
starts at 1280x720; resizing or fullscreen changes use the live viewport aspect,
so widescreen is native rather than stretched.

Build and stage it after the engine and private archives exist:

```powershell
& .\scripts\dev.ps1 -Task All
```

The staged executable is
`engine/build/project-reality/Release/Ghostship.exe`. The script copies the two
ignored resource archives next to it and stages the mod as
`mods/project-reality-core/`. Remove that one folder to return to unmodified
Ghostship behavior.

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
