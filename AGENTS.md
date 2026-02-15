# Repository Guidelines

## Project Structure & Module Organization
- `project.godot` is the root Godot 4 project file (edit via the Godot editor UI when possible).
- `src/` contains all game modules; `project.godot` references `res://src/...` paths.
- `src/core/` holds runtime orchestration and app entrypoints (`main`, `client`, `server`).
- `src/net/` contains networking transport/protocol handlers (`network_client`, `network_server`).
- `src/entities/` contains gameplay entities (tanks, shells, specs, shared assets).
- `src/controllers/` provides player/AI controller scenes and scripts.
- `src/levels/` stores playable level scenes and related logic.
- `src/ui/` contains UI scenes, widgets, and HUD elements.
- `src/global_assets/` is for shared art, audio, and UI resources.
- `src/game_data/` includes data resources and configuration assets.
- `src/config/` and `src/singletons/` hold config and autoload scripts.
- `android/` houses Android export/build artifacts and templates.

## Build, Test, and Development Commands
- `godot --editor --path .` opens the project in the Godot editor.
- `godot --path .` runs the project using the configured main scene.
- Exports use presets in `export_presets.cfg`; use **Project → Export** in the editor to build platform packages (e.g., Android).
- `just build` performs a headless load to catch parse/resource errors.
- `just lint` runs `gdlint` recursively.
- `just fmt` runs `gdformat` recursively.
- `just fmt-check` runs `gdformat --check` recursively.
- `just fix` runs `just build`, `just fmt`, and `just lint` in sequence.

## Coding Style & Naming Conventions
- GDScript uses tabs for indentation (Godot default).
- Functions and variables are `snake_case`; classes declared with `class_name` use `PascalCase` (see `core/client.gd` and `core/server.gd`).
- Scene files are `snake_case.tscn`; resources typically use `snake_case.tres`.
- Prefer editor-driven changes for `.tscn`, `.tres`, and `project.godot` to avoid format drift.

## Networking Architecture
- `core/main.gd` selects runtime mode (client vs dedicated server).
- `core/client.gd` owns client game flow and composes `%Network` (`net/network_client.gd`).
- `core/server.gd` owns server tick/runtime loop and composes `%Network` (`net/network_server.gd`).
- Keep transport/protocol logic inside `net/`; avoid mixing server logic back into client runtime scripts.

## Security & Configuration Tips
- Treat `ironfront.keystore` as sensitive; don’t rotate or replace it without explicit maintainer approval.
- Avoid committing new secrets or local export settings. Use local overrides where possible.


## Rules
- Always run `just fix` after making changes to the codebase.
- Avoid using leading-underscore parameter names (e.g., `_visible`) as a workaround for shadowing base class members; rename to a more specific, descriptive name instead.
- When nodes need to be referenced in a script, always set a Unique Name for the node and reference it via the `%NodeName` syntax.
- Never use `.call(...)` as a type-resolution workaround; if types misbehave or do not sync, first check for open Godot editor files/tabs and refresh there.
- When you discover a new, more efficient GDScript coding pattern in this repo, document it in `docs/GDScript.md`.
