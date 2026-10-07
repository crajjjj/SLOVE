SKSEMenuFramework.h - the client header of "SKSE Menu Framework" (Nexus 120352).

Vendored verbatim, never edited here. Plugins include it and call into the
framework's SKSEMenuFramework.dll at runtime through GetProcAddress: nothing is
linked, and the DLL itself is never redistributed with SLO VE.

Source:  https://github.com/QTR-Modding/SKSE-Menu-Framework-3/blob/master/resources/SKSEMenuFramework.h
Taken:   2026-10-07, from the copy in SexLab P+ (lib/ImGui, last changed 2026-07-11)
sha256:  48416e8220ca777e2fffc2ef2baf21f699ab2e6c409d437f44eec5e311c3524c

Why this version: it looks the framework module up lazily (older copies resolve
it at static-init time, which fails silently when our DLL loads first), and the
five functions it has that framework 3.8 lacks (AddWindowWithView, GetMainWindow,
SetHotkeyEnabled, IsHotkeyEnabled, PushFont) are null-guarded. SLOVE.dll uses
none of those five.

Rules for using it (see src\Ui.h):
- include it only through src\Ui.h, after the PCH;
- call ImGuiMCP:: functions only inside a callback the framework invoked - the
  wrappers do not null-check, so a call without the framework DLL is a crash;
- do not read ImGui structs (GetStyle, GetIO) directly.
