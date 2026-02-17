# Module Structure
__note: all paths in doc are relative to module root__

## Module Root
- `project.godot` is the Godot 4 project file.
- Prefer editor-driven changes for `project.godot`, `.tscn`, and `.tres` files.
- `android/` contains Android export/build artifacts and templates.

## Source Tree
- `src/` contains all game modules; `project.godot` references `res://src/...` paths.
- `src/core/` holds runtime orchestration and app entrypoints (`main`, `client`, `server`).
- `src/net/` contains networking transport/protocol handlers (`network_client`, `network_server`).
- `src/entities/` contains gameplay entities (tanks, shells, specs, shared assets).
- `src/controllers/` contains player and AI controller scenes/scripts.
- `src/levels/` stores playable level scenes and level logic.
- `src/ui/` contains UI scenes, widgets, overlays, and HUD elements.
- `src/global_assets/` contains shared art, audio, and UI resources.
- `src/game_data/` contains data resources and configuration assets.
- `src/config/` and `src/singletons/` contain config and autoload scripts.

## Runtime Architecture
- `src/core/main.gd` selects runtime mode (client vs dedicated server).
- `src/core/client.gd` owns client game flow and composes `$NetworkClient` (`src/net/client/network_client.gd`).
- `src/core/server.gd` owns server tick/runtime loop and composes `$NetworkServer` (`src/net/server/network_server.gd`).
- Keep transport/protocol code inside `src/net/`; avoid mixing server transport logic back into client runtime scripts.

## Development Commands
- `just game::fix`: run godot editor cache refresh, build, format, and lint.