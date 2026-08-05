# UBE tongue support (optional FOMOD patch)

This folder is the **staging source** for the FOMOD's *UBE Body → UBE tongue
support* option. `scripts\build.ps1` copies it verbatim into
`Release\FOMOD\UBESupport\` (only if `SLOVE_UBE_Support.esp` is present).

## What it is

`SLOVE_UBE_Support.esp` — an **override-only, ESL-flagged** patch that adds all
18 UBE races (`UBE_AllRace.esp`) to the *Additional Races* of SLO VE's 10 tongue
Armor Addons (`SLOVE_TongueAA1`..`10`, `SLOVE.esp` `000809`–`000812`).

Without it, an equipped tongue is **invisible on UBE custom-race actors**: a worn
mesh only renders on the races listed in its Armor Addon, and SLO VE's tongue
armatures list the vanilla/DLC races only. The tongue is head-attached (NPC Head
bone + the `tong1` HDT chain), not body-conforming, so **no UBE mesh conversion
is needed** — only the race-coverage fix. Same approach as Beeing Female NG's
`BF UBE Support` patch.

Masters: `SLOVE.esp` + `UBE_AllRace.esp` (+ `Skyrim.esm`/`Update.esm`/
`Dawnguard.esm`/`Dragonborn.esm` for the vanilla races already listed).

## How to (re)build the esp

The patch references `UBE_AllRace.esp`, so it can only be built with **UBE 2.0
loaded**. When UBE updates its race list, regenerate it.

**xEdit (recommended, matches the BF workflow):**

1. Copy `tools\xedit\SLOVE UBE Patch.pas` into your xEdit `Edit Scripts` folder.
2. Launch xEdit with your full load order; `SLOVE.esp` **and** `UBE_AllRace.esp`
   must be ticked.
3. Right-click any record → *Apply Script…* → **SLOVE UBE Patch** → OK.
4. When prompted, name the new file `SLOVE_UBE_Support.esp`; add masters when
   asked.
5. In the File Header, tick the **ESL** record flag, then Ctrl+S → Save.
6. Copy the resulting `SLOVE_UBE_Support.esp` into **this folder**, next to this
   README, then run `scripts\build.ps1` to fold it into the FOMOD.

The script sweeps every `SLOVE_Tongue*Armor` ARMO, follows its armature, and
adds the UBE races (de-duped) — so it survives new tongue armors automatically.
