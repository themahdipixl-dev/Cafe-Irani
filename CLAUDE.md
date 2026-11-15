# Cafe Irani (کافه ایرانی) — Godot

Persian idle/tycoon mobile game: run an Irani cafe, upgrade it, earn more.
Genre: idle tycoon. Camera: orthographic, isometric.
Android-first, portrait. The project is built from scratch.

## Workflow: glb-first
- The 3D models (cafe, city, cars, props) are **.glb files made by the owner** and live in `assets/`. Use them as they are; don't build those visuals in code (no procedural meshes, no `_draw()` worlds, no code-made buildings/cars).
- Claude owns everything else in the project: scenes (`.tscn`), scripts, game logic, economy, UI, camera, animations, placement/movement/behavior of every object, save system, export setup, docs. Build and change whatever the task needs.
- Instance glb files in `.tscn` (`[ext_resource type="PackedScene"]`). Never edit or re-export the glb files themselves; adjust them at runtime in scripts (e.g. `queue_free()` unwanted nodes).
- Keep tunables (positions, speeds, camera values) in exported vars or a small config script, not buried in logic.
- Don't invent asset paths: check `assets/` first, and ask the owner if a model is missing.
- Asset paths are case-sensitive on Android: the cars folder is `assets/Cars/` (capital C).

## Stack
- Godot 4.7, GDScript, GL Compatibility renderer.
- Camera: orthographic, isometric angle. Keep it orthographic; never switch to perspective for the main world.
- Viewport 1080x1920 portrait, stretch `canvas_items`, aspect `expand`.
- Persian UI (RTL): Labels use `language = "fa"`. Fonts in `assets/fonts/`.

## Layout
- `scenes/main.tscn` -> `scripts/main.gd` builds the UI layers in code. It contains `scenes/world.tscn` (3D world, rendered behind the UI).
- `scenes/world.tscn` -> `scripts/world/world.gd` (`CafeWorld`): city+cafe glb, ortho isometric camera (south-east corner, looks at the cafe), sun, environment, `Traffic`.
- `scripts/world/traffic.gd` (`Traffic`): animated glb cars (two ring-road loops, wheels spin) + parked cars. All tunables are exported vars.
- `scripts/game/` game logic: `economy.gd` (pure static funcs), `storage.gd`, `game_state.gd` (autoload `Game`).
- `scripts/config/` balance numbers and strings (`balance.gd`, `strings.gd`).
- `scripts/ui/` HUD, bottom bar, upgrade panel, offline card, shared widgets (`ui_kit.gd`, `fa_format.gd`, ...).
- `assets/cafe/` city+cafe glb (`tehran_with_cafe_v15_asphalt.glb`) and its text JSONs; `assets/Cars/` six car glbs; `assets/fonts/`.
- `Game` owns state and emits `changed` / `offline_report_changed`. UI only reads it and calls `Game.upgrade()`.

## World facts (from the glb, Godot units = meters, +Z = south, entrance faces +Z)
- Cafe is centered on the origin: ~24 x 20 m plot (x -12..12, z -10..10), ~3.5 m tall. Node `Cafe_Root`.
- City is 100 x 100 m around it, keep it visible (the owner built it on purpose). 46 `Bld_*` buildings.
- Ring road around the cafe: asphalt x ±22, z ±20, lanes at x ±17.5 / ±20.5 and z ±15.5 / ±18.5. Surface y = -0.05.
- Parking x 6.3..12, z 3..10. Drive-thru x 2..12, z -10..-6 (booth `DriveThru_Booth`).
- Car models: length 1 unit along +X (front = +X), body + 4 wheel nodes. Scaled to `Traffic.car_length` (2.4 m).
- Text JSONs: `cafe11_text_labels.json` (111 cafe labels) and `tehran_text_anchors_v5.json` (46 city shop signs). No text exists as mesh in the glb; labels are created as `Label3D` (needs a Persian font in `assets/fonts/`).

## Known leftovers (to adapt later)
- `scripts/config/balance.gd`, `strings.gd` and `scripts/game/economy.gd` still hold the numbers/texts of the previous theme. Rework them for the cafe when asked.
- `assets/cafe/place_labels.gd` is an untested helper from the owner; its paths don't match the repo yet.

## Conventions
- snake_case files, one `class_name` per file, typed GDScript, `##` doc comments.
- Code, comments and commit messages in English. Reply to the user in Persian.
- Player-facing text uses the name "کافه ایرانی" / "Cafe Irani".
- UI sizes use dp via `UiKit.dp_scale`.

## Working rules (save tokens)
- Never read a whole big file. Find the relevant function first, then edit only that part.
- glb files are big: inspect them with a script (parse the JSON chunk) instead of dumping them.
- Prefer `.tscn` edits over scripts when the job is just placement/hierarchy.
- Make minimal edits. Don't rewrite whole files. One commit per task.
- Don't edit README.md or this file unless asked.
- If the game can't be run, say the change is untested and give 2-3 short manual test steps.
