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
fleet in one image per theme. Ember is sliced into individual sprites (below);
Starlight and Sandstorm are still whole sheets only. Ship lengths in the art
are illustrative — the GameState ship footprints (T/X/Y shapes) are still
undefined and are NOT set by this art.

## Ember sprites

`Ember/` holds the Ember (fire) fleet sliced into individual transparent PNGs,
smallest to largest, top to bottom of the sheet:

- `ember-ship-01.png` 441x129
- `ember-ship-02.png` 678x180
- `ember-ship-03.png` 752x191
- `ember-ship-04.png` 866x205
- `ember-ship-05.png` 736x226
- `ember-ship-06.png` 904x240
- `ember-ship-07.png` 1096x255

Black was converted to transparency with a smooth ramp, so the sprites
composite directly over the starry backgrounds; engine flames are included
in each sprite. Numbering is by size rank on the sheet, not by GameState ship
length — the mapping to the 7 ship footprints is still TBD.

To use in Xcode: drag a sheet into Assets.xcassets as an image set, or
reference the PNGs as bundle resources. Note the skins live at the repo root
in ShipSkins/, outside the app folder — drag them into the Xcode project (or
move them under Astroship-Apple-Apps/) to bundle them. Files under
Astroship-Apple-Apps/ are picked up automatically by the project's
synchronized folder group.

Note: the $8 Kickstarter tier (2-player Game + Rocket Skin Package) is the
natural home for a backer-exclusive skin. The backer rocket skin itself is a
separate asset and is not in this drop.
