# Using SLO VE with Hentairim & Accurate Penetration (PPA)

Two mods people often already run when they find SLO VE. Neither is required, and
both are safe alongside it — this page is the recipe.

---

## Hentairim (IVDT)

SLO VE is a standalone port of **Hentairim's IVDT** voice / expression / SFX /
resistance system. You don't have to uninstall Hentairim to use it — you can keep
Hentairim installed and let SLO VE take over, as long as Hentairim's own modules are
switched **off** so the two aren't driving the same actors at once. That is safe
(see [Why it's safe](#why-its-safe)).

### Why keep Hentairim installed at all

Mostly you don't need to. SLO VE **replaces** Hentairim's voice, expression, SFX and
resistance modules outright, and the animation **tags** SLO VE reads don't require
Hentairim either:

- On **P+**, per-stage/position tags come from SexLab's own **Scene Builder /
  SexlabRegistry**.
- On **classic**, you need **SLATE + a Hentairim-convention tag database** (see
  [SexLab Flavours](sexlab-flavours.md)). That tag database is standalone — it does
  **not** need Hentairim's ESP or engine running. Hentairim's own database is *one*
  such database, so it can fill that role if you don't already have another, but any
  Hentairim-convention SLATE database works.

The real reason to keep Hentairim is its **other features that SLO VE never ported** —
for example its **armor swap** — which are still useful on their own. If you want
those, keep Hentairim installed but switch **off** the four modules SLO VE replaces
(below), so the two never drive the same actor.

So the coexistence is: **SLO VE owns the voice / face / SFX / willpower layer;
Hentairim stays — those modules off — only for its extra features** (and, if you have
nothing else, its tag database can double as the classic tag source).

### The recipe — disable Hentairim's engines

In Hentairim's MCM (or its `Config.json` files under `SKSE\Plugins\`), turn **off**
every module SLO VE replaces:

| Hentairim module | Set | Config key |
|---|---|---|
| IVDT voice | **off** | `IVDTHentai/Config.json` → `enableivdt = 0` |
| Facial expressions | **off** | expression config → `enableexpressions = 0` |
| Body SFX | **off** | SFX config → `enablesfx = 0` |
| Resistance / willpower | **off** | resistance config → `enableaggressionresistance = 0` |

With those off, Hentairim applies **none** of its scene spells, and SLO VE owns the
whole voice / face / SFX / willpower layer. Enable the matching SLO VE modules in
[`SLOVE.toml`](config/slove.md) (`[director] enablevoice / enableexpressions`,
`[sfx] enable`, `[resistance] enable`) as usual.

> **Load order:** keep **SLO VE last** among the audio/`.toml` mods so it wins the
> `AudioUtil` config merge. Voice packs are loose WAVs and can go anywhere.

### Why it's safe

Hentairim only touches a scene through the four modules above, and each one acts
**only while its own toggle is on**. With them off, Hentairim adds nothing to the
scene — it doesn't grab voices, write faces, play SFX, or drain willpower. It also
never *mutes* SexLab's audio (the one thing it does at load is *un*-mute it, which
only helps), and it only ever touched the **player's** voice, never NPCs — so it
can't collide with SLO VE's NPC voicing either. (Confirmed by reading Hentairim's
own scripts.)

If a scene still sounds doubled, the usual cause is the IVDT toggle not actually
saving — double-check `enableivdt = 0` and reload the save.

---

## Accurate Penetration (PPA)

**PPA** (Accurate Penetration) is an optional soft-dependency. When it's installed,
SLO VE's penetration cues become **measured instead of guessed** — real penetration
and depth from the physics, rather than the animation's stage tag.

### What it changes

- **Expressions & SFX** react to what's actually happening: gape and insertion cues
  fire on real penetration and depth, and the pull-out **gape SFX** reads the measured
  opening. Without PPA, SLO VE falls back to the animation's labels — everything still
  works, just less precise. PPA is an enhancement, never a requirement.
- If the gape sounds fire too early or late, tune the `[sfx] gape*` thresholds in
  [`SLOVE.toml`](config/slove.md).

### It's safe to share

SLO VE only **reads** PPA (through AudioUtil) — it never drives it, so PPA can feed
any number of mods at once. Running it for something else (including Hentairim's own
SFX, if you left that on) doesn't conflict with SLO VE reading it too.

### Enable & verify

1. Install PPA — no patch needed.
2. Make sure the bridge is on: `[ppa] enable = true` in `AudioUtil.toml` (the default).
3. In-game, `AudioUtil.log` shows a **`PPA bridge connected`** line at load.

See [Troubleshooting & Logs](troubleshooting.md) if it doesn't connect.
