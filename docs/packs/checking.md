# Checking Your Pack

You can look at your own folders all day and still not know the thing that
matters: **which of them can SLO VE actually reach?** A folder is only heard if
some call site in the engine asks for a name that resolves to it — and when it
doesn't, nothing breaks. The line plays a stock SexLab moan and sounds like a
beat you simply didn't record.

That is how thirteen beats went unheard for months before SLO VE 0.6.15.

`packcheck` answers the question offline, before you ship.

## Running it

Needs **Python 3.11+** and nothing else.

```
python tools/packcheck/packcheck.py "C:\path\to\My IVDT Pack"
```

Point it at your pack's root — it finds your `[[slot]]` overlay, follows the
slot's `path` to your audio, and reads your `variation` and `fallback`. You can
also hand it the voice folder itself.

Your pack ships one overlay per installable slot — `Slot_PC`, `Slot_F2` … `Slot_F10`
— and they don't all back onto the same stock slot, so which one you installed
into can change what reaches you. The tool checks the first and names the rest:

```
SLO VE pack check - as slot F1 (backs onto F0), variation B
  this pack also installs as F2, F3 ... - re-run with --slot to check those
```

If you're not working from a SLO VE checkout, point it at your installed copy
(SLO VE ships both its script sources and its config, so an installed mod folder
is enough):

```
python packcheck.py "C:\path\to\My Pack" --slove "E:\mods\SLO VE"
```

## Reading the report

```
SLO VE pack check - as slot F2 (backs onto F0B), variation B
  ...\Core\Sound\fx\SLOVE\MyVoice
  70 folders, 778 clips
  against 256 spoken call sites in SLOVE_Voice.psc
```

### Suspected name mismatch

```
SUSPECTED NAME MISMATCH (1) - check each of these
    PenetrativeCommentsIntense
        you ship 'Penetrated Comments Intense' - plays F0 instead
        asked at SLOVE_Voice.psc:2105 +2 more
```

SLO VE asks for a name your pack doesn't use, while you ship a folder that looks
like the same beat. **These are the ones to act on.** Either rename your folder
to what the engine asks for, or — if the engine is the one that's wrong — open an
issue, because a bridge belongs in `[category_fallbacks.female]` so it fixes
every pack at once.

The suggested folder is a guess from the name alone. You know which of your
folders the beat belongs in; the tool only knows spelling.

### Dead folders

```
DEAD FOLDERS (4) - shipped but never heard
    'Penetrated Comments Victim Intense'  (11 clips) - nothing ever requests it
    'Kissing'  (0 clips) - no clips in it
```

Audio you recorded that nothing can ever play. Two causes: the folder is empty,
or no call site in the engine requests that beat (yet). The second kind is worth
reporting — it usually means the engine has a gap, not your pack.

This section is the backstop for renames the name-matching can't see. `CameInMouth`
and `Ending Orgasmed Inside Mouth` are the same beat, and no amount of spelling
comparison will say so — but the folder showing up dead will.

### Not voiced by this pack

Beats that leave your pack and have nothing close to them in it. Completely
normal — no pack voices every beat. `--all` lists them with the slot each one
falls through to, which is a reasonable shopping list if you want to record more.

## Exit code

`1` if anything in the first or second section was reported, `0` if not, so you
can wire it into your own build.

## Watching it happen in game

`packcheck` tells you what *can* reach your pack. When you want to know what a
particular scene actually did — a line that felt wrong, a beat you never hear —
turn on the two logs and play it.

### Turn them on

**1. `Data\SKSE\Plugins\SLOVE\SLOVE.toml`** — two separate switches, you want
both:

```toml
[director]
printdebug = 1      # one line per voice line: category, facts, animation, and the wav that played

[voice]
printdebug = 1      # the voice engine's own reasoning: beats chosen, lines skipped and why
```

Then `sloveconfig reload` in the console — no restart.

**2. `SkyrimCustom.ini`** (or `Skyrim.ini`). Without this, Papyrus writes no user
logs at all and you will see nothing:

```ini
[Papyrus]
bEnableLogging=1
```

This one needs a restart.

**3. In the console:** `autest voicelog player`, which takes effect immediately.
Use `all` instead if you are checking an NPC pack — it logs every speaker in
every nearby scene, which gets loud fast. Note that it **restarts the file every
time you run it**, so run it once at the start of a session, not before each
scene.

### Where they land

| File | Holds |
|---|---|
| `Documents\My Games\Skyrim Special Edition\Logs\Script\User\SLOVE.0.log` | SLO VE's side: the beat, the scene, and the wav that played |
| `Documents\My Games\Skyrim Special Edition\SKSE\AudioUtil_Voices.log` | AudioUtil's side — the tag pool, and why nothing played |

Not the console. Both go to files, so they survive past the scene.

### Reading them

Start with **SLOVE.0.log**. One line per voice line, ending in the file that played:

```
Voice : Play 'PenetrativeCommentsIntense' actor=Lily slot=F2 facts=[rcv vaginal intense]
        anim=FB_Missionary stage=3 group=pc_low chan=slove_pc
        -> Sound\fx\SLOVE\Lily\Penetrated Comments Intense\pci_03.wav
```

If that path is not inside your own folder, the beat is not reaching you — and
you now have the animation and the stage it happened in.

Go to **AudioUtil_Voices.log** for the layer underneath, which SLO VE cannot see:
which tagged **pool** answered the line, whether the pick had to drop to a lower
pool because your best one ran out of clips (marked `v`), and the reason a call
played nothing at all (`MISS`). That is the log to read when the right *folder*
is being chosen but the wrong *clips* keep coming out of it.

!!! tip "Use both, in that order"
    SLO VE's log says which beat it asked for and what came out. AudioUtil's says
    how resolution got there. A pack question is usually answered by the first; a
    tagging question always needs the second.
