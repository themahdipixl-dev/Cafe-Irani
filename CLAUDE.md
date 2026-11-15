# Cafe Irani (کافه ایرانی) — Godot

Persian idle/tycoon mobile game: run an Irani cafe, upgrade it, earn more.
Genre: idle tycoon. Camera: orthographic, isometric.
Android-first, portrait. The project is built from scratch.

## Workflow: glb-first (IMPORTANT)
- All visuals (cafe, city, cars, props) are **.glb models made by the owner** in `assets/`. Never build visuals in code (no procedural meshes, no `_draw()` worlds, no code-made buildings/cars).
- Claude's job in the world: write `.tscn` scenes and small scripts that decide **where** each glb object is, **what it does**, and **what happens to it** (placement, movement paths, animation triggers, interactions, upgrades visibility).
- Instance glb files in `.tscn` (`[ext_resource type="PackedScene"]`). Don't rewrite or re-export glb files.
- Keep tunables (positions, speeds, camera values) in exported vars or a small config script, not buried in logic.
- Don't invent asset paths: check `assets/` first, and ask the owner if a model is missing.

## Stack
- Godot 4.7, GDScript, GL Compatibility renderer.
- Camera: orthographic, isometric angle. Keep it orthographic; never switch to perspective for the main world.
- Viewport 1080x1920 portrait, stretch `canvas_items`, aspect `expand`.
- Persian UI (RTL): Labels use `language = "fa"`. Fonts in `assets/fonts/`.

## Layout
- `scenes/main.tscn` -> `scripts/main.gd` builds the UI layers in code. The glb world scene will be added under it.
- `scripts/game/` game logic: `economy.gd` (pure static funcs), `storage.gd`, `game_state.gd` (autoload `Game`).
- `scripts/config/` balance numbers and strings (`balance.gd`, `strings.gd`).
- `scripts/ui/` HUD, bottom bar, upgrade panel, offline card, shared widgets (`ui_kit.gd`, `fa_format.gd`, ...).
- `assets/` glb models, fonts (`assets/fonts/`).
- `Game` owns state and emits `changed` / `offline_report_changed`. UI only reads it and calls `Game.upgrade()`.

## Known leftovers (to adapt later)
- `scripts/config/balance.gd`, `strings.gd` and `scripts/game/economy.gd` still hold the numbers/texts of the previous theme. Rework them for the cafe when asked.

## Conventions
- snake_case files, one `class_name` per file, typed GDScript, `##` doc comments.
- Code, comments and commit messages in English. Reply to the user in Persian.
- Player-facing text uses the name "کافه ایرانی" / "Cafe Irani".
- UI sizes use dp via `UiKit.dp_scale`.

## Working rules (save tokens)
- Never read a whole big file. Find the relevant function first, then edit only that part.
- Prefer `.tscn` edits over scripts when the job is just placement/hierarchy.
- Make minimal edits. Don't rewrite whole files. One commit per task.
- Don't edit README.md or this file unless asked.
- If the game can't be run, say the change is untested and give 2-3 short manual test steps.
