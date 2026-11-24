# Cafe Irani (کافه ایرانی) — Godot

Persian idle/tycoon mobile game: run an Irani cafe, upgrade it, earn more.
Genre: idle tycoon. Camera: orthographic, isometric.
Android-first, portrait. The project is built from scratch.

## Workflow: glb-first
- The 3D models (the cafe sections, props) are **.glb files made by the owner** and live in `assets/`. Use them as they are; don't build those visuals in code (no procedural meshes, no `_draw()` worlds, no code-made buildings).
- Claude owns everything else in the project: scenes (`.tscn`), scripts, game logic, economy, UI, camera, animations, placement/movement/behavior of every object, save system, export setup, docs. Build and change whatever the task needs.
- Instance glb files in `.tscn` (`[ext_resource type="PackedScene"]`). Never edit or re-export the glb files themselves; adjust them at runtime in scripts (e.g. `queue_free()` unwanted nodes).
- Keep tunables (positions, speeds, camera values) in exported vars or a small config script, not buried in logic.
- Don't invent asset paths: check `assets/` first, and ask the owner if a model is missing.
- Asset paths are case-sensitive on Android (file names with spaces/parentheses are fine, keep them exactly).
- The game has no city and no vehicles: don't add them.

## Stack
- Godot 4.7, GDScript, GL Compatibility renderer.
- Camera: orthographic, isometric angle. Keep it orthographic; never switch to perspective for the main world.
- Background: ice white `Color(0.929, 0.969, 0.988)` (Environment in `world.tscn` + project clear color).
- Viewport 1080x1920 portrait, stretch `canvas_items`, aspect `expand`.
- Persian UI (RTL): Labels use `language = "fa"`. Fonts in `assets/fonts/`.

## Layout
- `scenes/main.tscn` -> `scripts/main.gd` builds the UI layers in code. It contains `scenes/world.tscn` (3D world, rendered behind the UI).
- `scenes/world.tscn` -> `scripts/world/world.gd` (`CafeWorld`): one glb per cafe section instanced under `Cafe`, ortho isometric camera (south-east corner), sun, environment.
- `scripts/world/camera_zoom.gd` (`CameraZoom`): pinch zoom + one-finger pan.
- `scripts/game/` game logic: `economy.gd` (pure static funcs), `storage.gd`, `game_state.gd` (autoload `Game`).
- `scripts/config/` balance numbers and strings (`balance.gd`, `strings.gd`).
- `scripts/ui/` HUD, bottom bar, upgrade panel, offline card, shared widgets (`ui_kit.gd`, `fa_format.gd`, ...).
- `assets/cafe/` one glb per section (hall, kitchen, storage, delivery, terrace; marketing glb is not in the repo yet, only `tehran_cafe_marketing_v2_texts.json`); `assets/fonts/`.
- `Game` owns state and emits `changed` / `offline_report_changed`. UI only reads it and calls `Game.upgrade()`.

## World facts (Godot units = meters, +Z = south, floor of every section at y = 0)
- Sections (instance transform under `Cafe`, hall at the origin). Plan seen from above, north up:
  `Kitchen (-5.66, -8.69)` `Delivery (2, -8.69)` / `Storage (-8.66, -2)` `Hall (0, 0)` `Terrace (9.71, 0.5)` / `Marketing (-8.66, 4.53)`.
- Section footprints: hall 10.4 x 10.4, kitchen 8.4 x 6.4, storage 6.4 x 6.4, delivery 6.4 x 6.4, terrace 8.3 x 8, walls 3.2 m high. Gap between sections 0.3 m. Models are not rotated.
- Parts inside each glb are named `<section>_<part>_L<1..5>` (L = upgrade level). `CafeWorld.unlock(section, stage)` shows parts with level <= stage; stage 0 hides the section.
- The glbs contain their own `DirectionalLight*` / `HemisphereLight*` nodes; `CafeWorld` frees them, the `Sun` in `world.tscn` lights the world.
- Texts (menus, boards, signs) are baked into the glb textures. The `*_texts.json` files only document them.

## Known leftovers (to adapt later)
- `scripts/config/balance.gd`, `strings.gd` and `scripts/game/economy.gd` still hold the numbers/texts of the previous theme. Rework them for the cafe when asked.
- `Marketing` is an empty `Node3D` placeholder (position set) until its glb is added: instance it there in `world.tscn`; its footprint (assumed ~6.4 x 6.4) may need a position tweak.

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
