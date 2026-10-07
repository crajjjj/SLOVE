# In-game settings menu

From 0.6.29 on, every setting in [`SLOVE.toml`](slove.md) can be changed in game, on pages in the **Mod Control Panel** of [SKSE Menu Framework](https://www.nexusmods.com/skyrimspecialedition/mods/120352).

The menu is a front end for the file, not a second place where settings live: each change is written to `SLOVE.toml` as you make it, and editing the file by hand keeps working exactly as before.

## What you need

- **SKSE Menu Framework** (version 3). It is optional. Without it SLO VE runs as it always has, and you edit `SLOVE.toml` in a text editor.
- Nothing else. The menu is `SKSE\Plugins\SLOVE.dll`, which is part of SLO VE for both SexLab flavours and needs no plugin slot.

Open the Mod Control Panel with the framework's own key (**F1** unless you changed it in `SKSEMenuFramework.ini`) and pick **SLO VE** in the list on the left. There are six pages, one per section of the file: **Director**, **Voice**, **Expressions**, **SFX**, **Resistance** and **Milk**.

## Using it

- **Hover a setting** for what it does, its default value, and the name of its key in `SLOVE.toml` (the name to search for in the [reference](slove.md)).
- **Changes save themselves.** A checkbox is written when you click it, a slider when you let go of it, a typed number or text when you leave the field. There is no Save button.
- **reset** appears beside a setting that differs from its default and puts the default back. **Reset this page to defaults** does the same for a whole page, after asking once.
- **Dimmed settings** only do something on a SexLab build you are not running (SexLab P+, or P+ 2.19 and newer). You can still change them; the tooltip says which build they need.
- **Reload from disk** shows the file as it is right now, for when you changed it in a text editor while the menu was open. Closing and reopening the menu does the same.

### When a change takes effect

| What you changed | When you notice |
|---|---|
| A volume (player voice, partners, orgasm cries, NPC-only scenes, body sounds) | At once, also in the middle of a scene |
| Everything else | From the next scene that starts |

A scene reads its settings when it starts, so a scene that is already running keeps most of the values it started with. The exceptions are small: a few values are read as they are used, so some changes show up sooner than promised, never later.

!!! note "NPC-only scenes"
    A scene the player is not in picks up changed settings when it starts, as long as no scene of your own is running at that moment. While you are in a scene, NPC scenes that start nearby use the settings your scene started with.

## Good to know

- **Comments and layout of your file survive.** A change replaces the one value it is about; every other byte of the file is left alone.
- **Other programs can change the file while the menu is open.** A change you make goes into the file as it is at that moment, so an edit made in a text editor in the meantime is kept, not overwritten.
- **Settings missing from your file** are marked *not in your file*, with an **add** button. This happens when your `SLOVE.toml` is older than the mod or a line was deleted. Until a setting is in the file the scripts use a built-in fallback for it, which is often `0` and not the default the menu shows, so adding it can change behaviour.
- **Settings the menu does not know** (a key added to the file by a newer version or by hand) still show up, as plain fields under *Other*.
- **If the file is broken** (a typo from a hand edit), the page says where, and nothing is written until you fix the file and press **Reload from disk**. The menu never overwrites a file it cannot read.
- **An update of SLO VE replaces `SLOVE.toml`**, as it always has, and your settings go back to the defaults. Keep a copy of your file. In Mod Organizer 2 you can avoid the problem altogether: put a copy of `SKSE\Plugins\SLOVE\SLOVE.toml` in a small mod of your own that wins over SLO VE. The menu edits whichever copy wins.
- **The menu covers `SLOVE.toml` only.** Voice slots, routing and the engine settings stay in the [AudioUtil files](index.md), and the face presets in their JSON files.
- **The console commands still work.** `sloveconfig reload` re-reads the file after a hand edit; the menu does that for you after each change it makes.

## If something is wrong

The menu writes its own short log, next to the other SKSE logs:

```
Documents\My Games\Skyrim Special Edition\SKSE\SLOVE.log
```

| What you see | What it means |
|---|---|
| No **SLO VE** entry in the Mod Control Panel | SKSE Menu Framework is not installed, or it is a version the menu cannot use. `SLOVE.log` says which, in a line starting with `Menu disabled`. The rest of SLO VE is not affected. |
| *AudioUtil is not loaded* | SLO VE reads its settings through AudioUtil, so nothing takes effect until AudioUtil is installed. See [Getting Started](../getting-started.md). |
| *AudioUtil has not confirmed re-reading the file yet* | Your change **is** saved. Type `sloveconfig reload` in the console, or load a save, and it applies. |
| *A change could not be written* | The file is read-only, held open by another program, or was broken by a hand edit after the menu read it. The change is not saved yet, and the menu keeps trying while it is open. If the message stays, fix the file and press **Reload from disk**. |
| *SLOVE.defaults.toml is missing* | The file that holds the shipped defaults was removed. The menu still works, without default values and reset. Reinstall SLO VE to get it back. |

That log is not the script log. The scripts keep writing `Documents\My Games\Skyrim Special Edition\Logs\Script\User\SLOVE.0.log`, described in [Troubleshooting & Logs](../troubleshooting.md).
