# Merjino (مرجینو) — Godot

Mobile merge + restoration game. Each chapter has its own theme and setting.
Android-first, portrait. 2D true-isometric, art made with an AI image generator (not code).
Chapter 1 = a walled 30x30 m garden (Achaemenid four-part garden theme, Cyrus/Darius era). **Only the chapter 1 environment exists right now**; merge logic, steps, orders and UI are not built yet.

## Source of truth
The game design spec (`achaemenid_garden_game_spec.md`, owned by the user, not in the repo) defines the grid, items, layout table, zones and merge chains. Keep the numbers below in sync with it.

## Fixed conventions (never change after art production started)
- 1 m = 1 world unit, `PPM = 100` px per meter. Ground is 30x30 m, x and z from -15 to +15.
- True isometric: 45 deg rotation, `EL = 35.26 deg`. `GardenConfig.world_to_screen(x, y, z)` is the only conversion.
- On screen: +x = bottom-right, +z = bottom-left. Light is always from the top-right.
- `z_index = round((x + z) * 100)` (+ optional `z_bias`); bigger = in front.
- Back walls (x = -15, z = -15) are 3 m high; front walls (x = +15, z = +15) are 1.2 m. Corner towers 4 m.
- Entry gate: `(0, 14.6)` facing +z. Palace gate: `(0, -14.5)` facing +z. Never `flip_h` directional items (gate, palace_gate, takht).
- Only the `restored` state exists. Do not add `ruined` until the owner asks.
- Do not put brand/game/character names in image-generator prompts.

## Layout
- `scenes/main.tscn`: `Garden` (instance of `garden.tscn`) + `Camera2D` with `garden_camera.gd`.
- `scripts/config/garden_config.gd` (`GardenConfig`): constants + `world_to_screen` + `z_for`.
- `scripts/world/garden.gd` (`Garden`): builds flat Polygon2D ground, paths, plazas, canals, four walls (5 m pieces, gaps for both gates), item sprites, zone fog and a debug human reference. Public API: `set_zone_fogged(zone, fogged)`.
- `scripts/world/garden_camera.gd` (`GardenCamera`): one-finger pan, pinch zoom (0.7 to 2.0, default 1.5), `focus_on_world(x, z)`.
- `data/garden_layout.json`: `sprites` (footprint size per image id) and `items` (every placed instance: name, sprite, x, z, zone, optional flip/scale/y/z_bias). Change positions here, not in code.
- `assets/meta/<id>.png`: transparent item images, stored at **2x** of the final size (`texture_scale = 0.5`). Do not rename or edit them; ids match `sprites` keys.

## Item pivot
Each sprite is a `Sprite2D` with `centered = false` and `offset = -pivot`, where `pivot.x = width / 2` and
`pivot.y = height - footprint_half_diamond / texture_scale`. Half diamond is `(w + d) * 20.41` for rectangular items and `diameter * 28.85` for round ones. The pivot is the center of the item's footprint on the ground.

## Zones
A entry, B central fountain, C flower beds / left and front quadrants, D platform and tables, E palace path. Fog polygons per zone exist but are hidden by default (`fog_enabled`).

## Conventions
- snake_case files, one `class_name` per file, typed GDScript, `##` doc comments.
- Code, comments and commit messages in English. Reply to the user in Persian.
- Keep tunables in exported vars, constants or the layout JSON.
- Make minimal edits, one commit per task. Don't edit the PNGs.
- If the game can't be run, say the change is untested and give 2-3 short manual test steps.
