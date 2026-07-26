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

Hentairim ships a large **animation tag database** — the `<stage><position><label>`
codes (e.g. `3asvp` = stage 3, actor A, slow vaginal penetration) that SLO VE reads
to pick the right beat per stage/position. Keeping that data gives SLO VE rich,
accurate labels instead of the generic lead-in fallback it uses on untagged
animations.

- On **P+**, tags also come from SexLab's own **Scene Builder / SexlabRegistry**, so
  Hentairim is optional here — but its database still fills in animations the Scene
  Builder doesn't tag.
- On **classic**, you need **SLATE + a Hentairim-convention tag database** anyway
  (see [SexLab Flavours](sexlab-flavours.md)), and Hentairim's database is exactly
  that.

So the coexistence is: **Hentairim provides the tag/scene data, SLO VE is the
audio/face engine on top of it.**

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
