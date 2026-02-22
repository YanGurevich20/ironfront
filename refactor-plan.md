# Client Root Lifecycle Plan

## Goal
Create a clean-cut client architecture where `ClientApp` is the only state orchestrator and transitions between three mounted roots:
1. `LoginRoot`
2. `GarageRoot`
3. `ArenaRoot`

Rules:
1. No compatibility layers.
2. No dual login/auth flows.
3. No pre-instantiated login/garage/battle roots hidden by visibility toggles.
4. Root states are lifecycle-driven via mount/unmount.
5. After `/me` parser boundary, `Account` is trusted runtime state.
6. New root code is written from scratch where applicable; old flow files are retained only as short-lived reference and explicitly marked for deletion.

## Decisions Finalized
1. `ArenaRoot` is a full refactor target, not a wrapper shim.
2. `UIManager` is deleted (no overlay-service residue).
3. Login flow UI is redesigned under new login root.
4. Login flow auth starts automatically on `LoginRoot._ready()`.
5. All lifecycle-mutation signals flow root → `ClientApp` (no bus for transitions).
6. End transitions use separate signals (explicit end types).
7. Hydration completion is owned by `LoginRoot` state (no global account hydrated flag).
8. Auth/login `UiBus` cleanup is done fully in this migration.
9. Shared overlays (e.g. settings) stay in root UI; others move to the owning root.
10. `LevelContainer` is arena concern; `ArenaRoot` owns it.
11. `net/` stays as dedicated folder under `client/`.
12. `Account` is the sole source of truth; `PlayerData` is deprecated and fully replaced.
13. `game_data/` is for locally stored DataStore inheritors only (after migration: settings only).
14. `account_data/` moves to `singletons/account/` (account.gd, account_economy.gd, account_loadout.gd, tank_config.gd).
15. Drop `core/`: main, client, server become direct children of `src/`.
16. Drop `roots/`: login, garage, arena become direct children of `client/`; ArenaRoot co-locates with ArenaClient in `client/arena/`.
17. Auth moves under `client/login/` (auth owned exclusively by LoginRoot).

### Clarifications
- **Preferences**: Fully removed. `Account` is the sole source of truth (e.g. `Account.loadout.selected_tank_id`).
- **PlayerData**: Deprecated and fully replaced. Phase 1: write to `Account` directly (in-memory). Phase 2: API-bound writes later.
- **UiBus**: Deprecated entirely. All navigation/intents flow root → `ClientApp` via direct signals.
- **player_name, tank/shell unlocks**: All sourced from and written to `Account`. Local write first, API later.

## Target Hierarchy

### Top-level startup
1. `Main` keeps only server/client routing; lives at `src/main.gd`.
2. Client path mounts `ClientApp`; lives at `src/client/`.

### Client root hierarchy
1. `ClientApp` (`Node`/`Node2D`) owns a single `StateContainer` node.
2. `StateContainer` contains exactly one active child root at any time:
3. `LoginRoot` (auth + username + hydration)
4. `GarageRoot` (garage UI + menu actions)
5. `ArenaRoot` (online battle flow; existing arena orchestration)

## Target Folder Structure

No `core/` or `roots/`; flattened to `src/{main,client,server}` and `client/{net,arena,login,garage}`. Auth lives under `client/login/auth/`.

Create:
1. `game/src/client/login/`
2. `game/src/client/garage/`

Move/create root scenes/scripts:
1. `game/src/client/login/login_root.tscn`
2. `game/src/client/login/login_root.gd`
3. `game/src/client/garage/garage_root.tscn`
4. `game/src/client/garage/garage_root.gd`
5. `game/src/client/arena/arena_root.tscn`
6. `game/src/client/arena/arena_root.gd`

Notes:
1. `ArenaRoot` co-locates with ArenaClient in `client/arena/`; it is a full refactor target in this migration (no wrapper phase).
2. Existing `ui/login_menu` content moves under `client/login/`; old folder deleted.

### Visual End-State Tree
```text
game/src/
├── main.gd
├── main.tscn
├── client/
│   ├── client_app.gd
│   ├── client_app.tscn
│   ├── shared_ui/
│   │   ├── settings_overlay/
│   │   ├── shell_info_overlay/
│   │   └── base_overlay/
│   ├── net/
│   │   ├── enet_client.gd
│   │   ├── client_session_api.gd
│   │   └── client_gameplay_api.gd
│   ├── arena/
│   │   ├── arena_client.gd
│   │   ├── arena_client.tscn
│   │   ├── arena_root.gd
│   │   ├── arena_root.tscn
│   │   ├── battle_interface/
│   │   ├── touch_controls/
│   │   └── overlays/
│   │       ├── online_join_overlay/
│   │       ├── online_pause_overlay/
│   │       ├── online_match_result_overlay/
│   │       └── online_death_overlay/
│   │
│   │   └── runtime/
│   ├── login/
│   │   ├── login_root.gd
│   │   ├── login_root.tscn
│   │   ├── auth/
│   │   │   ├── auth_manager.gd
│   │   │   ├── auth_provider.gd
│   │   │   └── providers/
│   │   └── ui/
│   │       ├── bootstrap_login_panel.gd
│   │       └── bootstrap_login_panel.tscn
│   └── garage/
│       ├── garage_root.gd
│       ├── garage_root.tscn
│       ├── ui/
│       │   ├── garage/
│       │   │   ├── header/
│       │   │   ├── tank_display_panel/
│       │   │   ├── tank_list/
│       │   │   └── upgrade_panel/
│       │   └── overlays/
│       │       └── garage_menu_overlay/
├── server/
│   ├── server_app.gd
│   ├── server_app.tscn
│   ├── net/
│   └── arena/
├── game_data/
│   ├── data_store.gd
│   └── settings_data/
│       └── settings_data.gd
├── api/
│   └── user_service/
│       └── types/
│           └── me_response_parser.gd
├── singletons/
│   ├── ui_bus.gd
│   └── account/
│       ├── account.gd
│       ├── account_economy.gd
│       ├── account_loadout.gd
│       └── tank_config.gd
```

## Lifecycle and Transitions

### Boot
1. `Main` mounts `ClientApp` for client mode.
2. `ClientApp._ready()` mounts `LoginRoot`.
3. `LoginRoot` owns `AuthManager` and login UI.
4. On successful auth + `/me` hydration + username complete, `LoginRoot` emits `login_completed`.
5. `ClientApp` unmounts `LoginRoot`, mounts `GarageRoot`.

### Play
1. `GarageRoot` emits `play_requested`.
2. `ClientApp` unmounts `GarageRoot`, mounts `ArenaRoot`.
3. `ArenaRoot` starts/joins session in `_ready`/local flow.

### Return
1. `ArenaRoot` emits `arena_finished` or `return_to_garage_requested`.
2. `ClientApp` unmounts `ArenaRoot`, mounts `GarageRoot`.

### Logout
1. Any active root emits `logout_requested`.
2. `ClientApp` clears account state (`Account.clear()`).
3. `ClientApp` unmounts active root, mounts `LoginRoot`.

## Ownership Boundaries

### `ClientApp`
1. Root state machine only.
2. Mount/unmount root scenes.
3. No auth API details.
4. No garage/battle business logic.

### `LoginRoot`
1. AuthManager ownership.
2. Sign-in retries.
3. Username submission flow.
4. Hydration-complete gating before exit.

### `GarageRoot`
1. Garage UI ownership.
2. Emit navigation intents (`play_requested`, `logout_requested`).

### `ArenaRoot`
1. Arena/session lifecycle ownership.
2. `LevelContainer` ownership (arena spawn/concrete).
3. Battle UI/control subtree ownership.
4. Arena-specific overlays (OnlinePauseOverlay, OnlineMatchResultOverlay, OnlineDeathOverlay, OnlineJoinOverlay).
5. Emit explicit end signals: `arena_finished`, `return_to_garage_requested`, `logout_requested`.

## Remove Old Pattern

Must be removed:
1. Runtime-level pre-instantiated `LoginMenu` + `Garage` + `BattleInterface` in one always-on manager.
2. Global auth/login routing through `UiBus`.
3. `AuthManager` in `client_app.tscn`.
4. Root switching via visibility flags in `UIManager`.
5. `UIManager` itself.

Allowed to keep:
1. Shared overlays/components only if they are truly cross-root and not root-state owners.
2. Shared overlays must live in explicit shared scene(s) owned by `ClientApp` (not `UIManager`).

## Overlay Ownership
- **ClientApp shared UI**: shared overlays only (e.g. SettingsOverlay, ShellInfoOverlay), implemented as dedicated shared scene(s) under `client/` ownership.
- **GarageRoot**: GarageMenuOverlay.
- **ArenaRoot**: OnlinePauseOverlay, OnlineMatchResultOverlay, OnlineDeathOverlay, OnlineJoinOverlay, BattleInterface.

## UI Migration Map

Ownership mapping:
1. `LoginRoot`: everything from `game/src/ui/login_menu/*` (redesigned under `game/src/client/login/ui/`).
2. `GarageRoot`: everything from `game/src/ui/garage/*` plus `game/src/ui/overlays/garage_menu_overlay/*`.
3. `ArenaRoot`: everything from `game/src/ui/battle_interface/*`, `game/src/ui/touch_controls/*`, and `game/src/ui/overlays/online_*`.
4. `ClientApp shared_ui`: `game/src/ui/overlays/settings_overlay/*`, `game/src/ui/overlays/shell_info_overlay/*`, `game/src/ui/overlays/base_overlay/*`.

Delete set:
1. `game/src/ui/ui_manager.gd`
2. `game/src/ui/ui_manager.tscn`
3. `game/src/ui/login_menu/*` (after new login root is live)
4. Any emptied legacy folders under `game/src/ui/`

## Root Signal Contracts

### LoginRoot -> ClientApp
1. `login_completed`
2. `login_failed(reason: String)`

### GarageRoot -> ClientApp
1. `play_requested`
2. `logout_requested`

### ArenaRoot -> ClientApp
1. `arena_finished(summary: Dictionary)`
2. `return_to_garage_requested`
3. `logout_requested`

## File Touch Manifest

### Create
1. `bootstrap-plan.md` (this document)
2. `game/src/client/login/login_root.gd`
3. `game/src/client/login/login_root.tscn`
4. `game/src/client/garage/garage_root.gd`
5. `game/src/client/garage/garage_root.tscn`
6. `game/src/client/arena/arena_root.gd`
7. `game/src/client/arena/arena_root.tscn`

### Move and modify startup
1. Move `game/src/core/main.gd` → `game/src/main.gd`
2. Move `game/src/core/main.tscn` → `game/src/main.tscn`
3. Move `game/src/core/client/*` → `game/src/client/*`
4. Move `game/src/core/server/*` → `game/src/server/*`
5. Delete `game/src/core/` (empty)
6. Update `project.godot` run/main_scene → `res://src/main.tscn`
7. Move `game/src/client/auth/*` → `game/src/client/login/auth/*`
8. Delete `game/src/client/auth/` (empty)
9. `game/src/client/client_app.gd` (becomes root-state orchestrator)
10. `game/src/client/client_app.tscn` (reduce to shell + state container)

### Modify auth ownership
1. `game/src/client/login/auth/auth_manager.gd`
Changes:
- Remove auth/login `UiBus` coupling.
- Keep pure auth signals for `LoginRoot`.
- Keep `sign_out` behavior as root intent + account clear path.

### Move account to singletons
1. Move `game/src/game_data/account_data/` → `game/src/singletons/account/`
2. `account.gd`, `account_economy.gd`, `account_loadout.gd`, `tank_config.gd`
3. `game/src/api/user_service/types/me_response_parser.gd` (update imports)
Changes:
- Runtime-only account state; `Account` is the sole source of truth.
- In-place mutation of nested instances.
- No local persistence path.
- `PlayerData` deprecated and fully replaced; remove all `PlayerData` usage (username, tank/shell unlocks, etc.).

### Modify runtime UI ownership
1. `game/src/ui/ui_manager.gd`
2. `game/src/ui/ui_manager.tscn`
Changes:
- Remove from runtime architecture.
- Delete files after root migration is complete.

### Modify signal surface
1. `game/src/singletons/ui_bus.gd`
Delete auth/root-navigation signals:
- `login_pressed`
- `log_out_pressed`
- `auth_retry_requested`
- `auth_sign_in_started`
- `auth_sign_in_finished`
- `username_prompt_requested`
- `username_submit_requested`
- `username_submit_finished`
- `return_to_menu_requested`
Keep runtime/gameplay intents that remain cross-root.
Required in same migration:
1. Replace all emitters/consumers of removed signals with direct root -> `ClientApp` signal wiring.
2. No deleted signal names may remain referenced in runtime code.

### Migrate and delete login UI path
1. Implement new login root UI from scratch under `game/src/client/login/*`.
2. Keep old `game/src/ui/login_menu/*` temporarily as reference while new root stabilizes.
3. Delete old login menu folder in the same migration once verified.

### Arena and garage integration updates
1. `game/src/client/arena/arena_client.gd`
2. `game/src/client/arena/arena_client.tscn`
3. `game/src/ui/garage/garage.gd`
4. `game/src/ui/garage/garage.tscn`
5. `game/src/ui/overlays/garage_menu_overlay/garage_menu_overlay.gd`

Purpose:
1. Emit root transition intents to `ClientApp` instead of directly manipulating global login/runtime state.
2. GarageMenuOverlay emits to GarageRoot; GarageRoot emits `logout_requested` to ClientApp.

### Transitional reference files (mark for deletion)
1. `game/src/ui/ui_manager.gd`
2. `game/src/ui/ui_manager.tscn`
3. `game/src/ui/login_menu/login_menu.gd`
4. `game/src/ui/login_menu/login_menu.tscn`
5. `game/src/ui/login_menu/assets/*`
6. `game/src/game_data/player_data/*` (and related; `PlayerData` fully replaced by `Account`)
7. `game/src/game_data/account_data/*` (moved to `singletons/account/`)

Rule:
1. These files are read-only reference during implementation and must be removed before migration completion.

## Clean-Cut Checklist

1. `ClientApp` mounts exactly one of `LoginRoot/GarageRoot/ArenaRoot` at a time.
2. Runtime cannot start before successful login + hydration.
3. `AuthManager` exists only in `LoginRoot`.
4. `UIManager` no longer owns root-state switching.
5. No remaining references to deleted auth/login `UiBus` signals.
6. Logout from garage/arena returns to `LoginRoot` via `ClientApp` transition.
7. `PlayerData` fully removed; `Account` is sole source of truth for username, loadout, economy.
8. `LevelContainer` owned by `ArenaRoot`.
9. `game_data/` contains only DataStore inheritors (settings); `account_data/` moved to `singletons/account/`.
10. `core/` removed; main, client, server at `src/` level; roots at `client/` level (login, garage, arena).
11. Auth under `client/login/auth/`.
12. `just game::fix` passes.
