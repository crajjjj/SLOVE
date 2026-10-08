TrueHUDAPI.h - the modder interface of "TrueHUD - HUD Additions" (Nexus 62775).

Vendored verbatim, never edited here. SLOVE.dll includes it for the interface
class only and reaches TrueHUD.dll at runtime through GetProcAddress: nothing is
linked, and TrueHUD itself is never redistributed with SLO VE.

Source:  https://github.com/ersh1/TrueHUD/blob/master/src/TrueHUDAPI.h
Taken:   2026-10-08, commit 5f044598 (the file last changed 2022-10-09)
License: GPL-3.0, like SLO VE
sha256:  e33beb7954023fc92ec528a134329388370d3ad728b854f7511ad96f981c65ed

Rules for using it (see src\HudBar.cpp, its only include site):
- the header's own RequestPluginAPI() is not called: it hands GetProcAddress a
  null module when TrueHUD is not installed. HudBar looks the export up itself;
- the interface is a vtable of TrueHUD's build. Request V1 (the special bar has
  been there since the first version) and call nothing that a later version
  added without requesting that version;
- callbacks handed to TrueHUD are plain functions (no captures), so the
  std::function that crosses the DLL boundary never allocates.
