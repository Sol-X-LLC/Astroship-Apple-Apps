# Ship Skins

First-pass fleet skin concept sheets for Astroship. Each sheet shows all 7 ships
top-down in one theme, on a pure black background so they composite over the
starry backgrounds.

- `ship-skin-starlight-fleet.png` (1120x2240) — Starlight, deep-space: dark gunmetal hulls with cyan running lights. The default look.
- `ship-skin-sandstorm-fleet.png` (1280x1920) — Sandstorm, desert: sand-tan and bronze hulls with amber hazard markings.
- `ship-skin-ember-fleet.png` (1120x2240) — Ember, fire: near-black hulls with molten orange/red veins and engine flames.

The three themes match the game's own theme language (space, sand, fire) from
the Kickstarter script, where new themes unlock as you climb.

Status: concept art, not final production sprites. The sheets show the whole
fleet in one image per theme; individual per-ship sprites are the next step
if a theme is chosen. Ship lengths in the art are illustrative — the GameState
ship footprints (T/X/Y shapes) are still undefined and are NOT set by this art.

To use in Xcode: drag a sheet into Assets.xcassets as an image set, or
reference the PNGs as bundle resources. The project uses a synchronized folder
group, so files under Astroship-Apple-Apps/ are picked up automatically.

Note: the $8 Kickstarter tier (2-player Game + Rocket Skin Package) is the
natural home for a backer-exclusive skin. The backer rocket skin itself is a
separate asset and is not in this drop.
