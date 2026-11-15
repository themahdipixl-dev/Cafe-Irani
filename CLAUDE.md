# Cafe Irani (کافه ایرانی) — Godot

Persian idle/tycoon mobile game: run an Irani cafe, upgrade it, earn more.
Genre: idle tycoon. Camera: orthographic, isometric.
Android-first, portrait. The project is built from scratch.

## Stack
- Godot 4.7, GDScript, GL Compatibility renderer.
- Camera: orthographic, isometric projection. Keep it orthographic; never switch to perspective for the main world.
- Viewport 1080x1920 portrait, stretch `canvas_items`, aspect `expand`.
- Persian UI (RTL): Labels use `language = "fa"`. Fonts in `assets/fonts/`.

## Conventions
- snake_case files, one `class_name` per file, typed GDScript, `##` doc comments.
- Code, comments and commit messages in English. Reply to the user in Persian.
- Player-facing text uses the name "کافه ایرانی" / "Cafe Irani".
- UI sizes use dp, not raw pixels.

## Working rules (save tokens)
- Never read a whole big file. Find the relevant function first, then edit only that part.
- Make minimal edits. Don't rewrite whole files. One commit per task.
- Don't edit README.md or this file unless asked.
- If the game can't be run, say the change is untested and give 2-3 short manual test steps.
