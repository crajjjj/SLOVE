# UBE tongue support (optional FOMOD option)

This folder is the **staging source** for the FOMOD's *UBE Body -> UBE tongue
support* option. `scripts\build.ps1` copies `SLOVE_UBE_Support.esp` and the
`meshes\` tree into `Release\FOMOD\UBESupport\` (this README stays out of the
install).

## What it does

UBE 2.0 ships its bodies as 18 separate custom races (`UBE_AllRace.esp`). A worn
item renders only on the races its Armor Addon lists, and SLO VE's tongue addons
list the vanilla and DLC races, so on a UBE actor the equipped tongue shows
nothing.

Since 0.6.28 the option gives UBE actors **their own tongues**, chosen by the
game from the wearer's race:

| Piece | Content |
|---|---|
| `meshes\!UBE\SLOVE\tongues\linga1..10.nif` | The ten tongues fitted to the UBE head. `!UBE\<same path>` is the UBE mesh convention. |
| `SLOVE_UBE_Support.esp` (ESL) | Ten new Armor Addons `SLOVE_TongueAA1_UBE`..`10_UBE` (`000800`-`000809`): slot 44, races = the 18 UBE races only, model = the mesh above, priority 10. Ten overrides of `SLOVE_Tongue1Armor`..`10Armor` (`SLOVE.esp` `000813`-`00081C`) that append the UBE addon after the standard one. |

Each tongue armor therefore carries two addons: the standard one (vanilla and DLC
races) and the UBE one (UBE races). An actor matches exactly one, so no script
has to know about UBE and `SLOVE_Expressions` equips the same ten armors as
before.

Masters: `Skyrim.esm`, `Update.esm`, `UBE_AllRace.esp`, `SLOVE.esp`.

## Rules that keep it working

- **Never add UBE races to the standard addons** (`SLOVE_TongueAA1`..`10`). That
  is what this patch did up to 0.6.27 (override-only, standard mesh on UBE heads).
  Doing both makes a UBE actor match two addons of the same armor.
- **The UBE addon outranks the standard one** (priority 10 against 0, and it is
  last in the list). The third-party *UBE Armor Race Patcher* DLL adds the UBE
  races to every Nord-fitting addon at load, the standard tongue addons
  included, so with that DLL installed both addons match. The priority makes the
  UBE one win slot 44, and the DLL redirects the standard addon to
  `meshes\!UBE\<path>` anyway, which is the same file.
- **Slot 44 lives in the records only.** The UBE meshes skin with a plain
  `NiSkinInstance` and carry no body-part partition, so unlike SLO VE's own
  meshes there is no slot to patch in the nif.
- The meshes reference `meshes\morten\lingas\tong.xml` (HDT-SMP) and
  `textures\Tongue\*`, both shipped by SLO VE's core install, so the option needs
  nothing from FillHerUp.

## Where the meshes come from

They are unmodified copies of the tongue meshes in the *sr_FillHerUp UBE patch*
(`meshes\!UBE\morten\lingas\linga1..10.nif`): the UBE conversions of FillHerUp's
ten tongues, the set SLO VE's standard meshes also come from. Credit for the
conversion goes to that patch's author.

## Rebuilding the esp

Needed when UBE changes its race list or SLO VE gains a tongue armor. The esp
needs `UBE_AllRace.esp` as a master, so author it with UBE in the load order.
The shipped file was written with houseCARL (Mutagen); xEdit works as well:

1. New plugin, masters `SLOVE.esp` and `UBE_AllRace.esp`, ESL flag set.
2. For each tongue N, add an Armor Addon `SLOVE_TongueAA{N}_UBE`: biped slot 44
   only, armor type Clothing, male and female priority 10, race = the first
   `UBE_AllRace.esp` race, additional races = the rest, male and female world
   model `!UBE\SLOVE\tongues\linga{N}.nif`.
3. Copy `SLOVE_Tongue{N}Armor` as an override and append the new addon to its
   Armature list, after the standard one.
4. Save it here as `SLOVE_UBE_Support.esp` and run `scripts\build.ps1`, which
   fails if the esp names a mesh that is not under `meshes\`.

Sanity check without the game: the file holds 20 records (10 `ARMO` overrides,
10 new `ARMA`) and no override of `SLOVE_TongueAA*`.
