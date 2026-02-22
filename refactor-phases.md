# Client Root Migration Phases

## Operating Model
1. Execute phases sequentially.
2. Each phase must end with `just game::fix` passing.
3. Each phase must produce a short handoff note section in this file.
4. No partial dual-flow handoff between phases.

## Handoff Template (append per phase)
1. Scope completed
2. Files touched
3. Outstanding risks
4. Verification run
5. Grep proofs
6. Next phase start point

---

## Phase 1: Structural Cut + Root Lifecycle Skeleton (Merged)

### Objective
Reshape folders and establish the new root lifecycle shell in one pass, without full auth/feature migration yet.

### Includes
1. Flatten source layout:
- `src/core/main.*` -> `src/main.*`
- `src/core/client/*` -> `src/client/*`
- `src/core/server/*` -> `src/server/*`
2. Move auth under login ownership path:
- `src/client/auth/*` -> `src/client/login/auth/*`
3. Move account runtime files:
- `src/game_data/account_data/*` -> `src/singletons/account/*`
4. Create root shells:
- `src/client/login/login_root.{gd,tscn}`
- `src/client/garage/garage_root.{gd,tscn}`
- `src/client/arena/arena_root.{gd,tscn}`
5. Convert `ClientApp` to state orchestrator with `StateContainer`.
6. Wire direct root -> `ClientApp` signals (skeleton only):
- `login_completed`, `login_failed`
- `play_requested`, `logout_requested`
- `arena_finished`, `return_to_garage_requested`, `logout_requested`
7. Keep old `UIManager` and old login files as temporary reference only, marked for deletion.

### Explicitly out of scope
1. Full login/auth flow migration.
2. Full garage/arena UI re-ownership.
3. UiBus auth signal removal.
4. PlayerData purge.

### Entry Criteria
1. Branch has `bootstrap-plan.md` current decisions.
2. `Account` autoload is active and runtime-only.

### Exit Criteria
1. New path structure exists and compiles.
2. `main.gd` still server/client routes only.
3. `ClientApp` mounts one root at a time in `StateContainer`.
4. Skeleton transitions work between root placeholders.
5. `just game::fix` passes.

### Checklist
1. Move files/folders and update script/scene paths.
2. Update `project.godot` `run/main_scene` path.
3. Update all moved script references in `.tscn` and code.
4. Create root shell scenes/scripts with typed signals.
5. Refactor `client_app.tscn` to minimal shell + `StateContainer`.
6. Implement root mounting helpers in `client_app.gd`.
7. Add temporary placeholder UI labels in each root for smoke testing.
8. Mark legacy files with `# TODO: delete in Phase 4/5` comments where applicable.
9. Run verification.

### Verification
1. `just game::fix`
2. Smoke boot:
- Client starts and mounts `LoginRoot` placeholder.
- Manual signal trigger can swap to `GarageRoot` and `ArenaRoot` placeholders.

### Grep Proofs
1. Ensure no stale old root paths:
```bash
rg -n "res://src/core/(main|client|server)"
```
Expected: zero relevant runtime references (except intentionally untouched docs/comments).

2. Ensure new roots exist and are referenced:
```bash
rg -n "login_root|garage_root|arena_root|StateContainer" src/client src/main.gd
```
Expected: non-empty.

### Handoff Notes
1. **Scope completed**: Flattened layout (core→src), auth under client/login/auth, account under singletons/account, root shells (LoginRoot, GarageRoot, ArenaRoot), ClientApp as StateContainer orchestrator with skeleton transitions.
2. **Files touched**: main.{gd,tscn}, project.godot, client_app.{gd,tscn}, auth_manager.gd, arena_client.gd, arena_session_runtime.tscn, pgs/dev_auth_provider.tscn, server_app.tscn; created login_root.{gd,tscn}, garage_root.{gd,tscn}, arena_root.{gd,tscn}; moved core/*→src/*, client/auth→client/login/auth, game_data/account_data→singletons/account.
3. **Outstanding risks**: UIManager, login_menu, ArenaClient, Network, LevelContainer removed from ClientApp; Phase 2 must wire AuthManager and real login flow into LoginRoot.
4. **Verification run**: `just game::fix` passes.
5. **Grep proofs**: `rg "res://src/core/"` empty; `rg "login_root|garage_root|arena_root|StateContainer"` in client/main non-empty.
6. **Next phase start point**: LoginRoot owns AuthManager; implement auth+hydration; remove UiBus auth signals.

---

## Phase 2: Login/Auth Migration (Functional)

### Objective
Make `LoginRoot` fully own auth + username + hydration and gate entry into `GarageRoot`.

### Includes
1. Move/redesign login UI under `src/client/login/ui/*`.
2. Place `AuthManager` exclusively under `LoginRoot`.
3. Remove auth handling from runtime `ClientApp`.
4. Remove auth/login coupling through `UiBus` for migrated paths.
5. Ensure autostart auth on `LoginRoot._ready()`.

### Entry Criteria
1. Phase 1 complete.
2. Root lifecycle skeleton is working.

### Exit Criteria
1. Successful auth + hydration emits `login_completed` from `LoginRoot`.
2. Username-required flow resolves entirely inside `LoginRoot`.
3. `ClientApp` receives signals and transitions to `GarageRoot`.
4. Runtime has no `AuthManager` node.
5. `just game::fix` passes.

### Checklist
1. Implement `LoginRoot` state machine (idle, signing_in, username_required, failed, complete).
2. Connect `AuthManager` signals directly in `LoginRoot`.
3. Move login panel logic from old `ui/login_menu` into new login UI.
4. Remove auth signal emissions/consumptions from `UiBus` in migrated files.
5. Remove auth handlers from `client_app.gd`.
6. Remove `AuthManager` from `client_app.tscn`.
7. Verify sign-out while in login remains clean (`Account.clear()`).

### Verification
1. `just game::fix`
2. Manual smoke:
- bad auth -> stays login with retry
- username required -> prompt -> submit -> success -> garage
- successful auth -> garage

### Grep Proofs
1. No runtime auth ownership:
```bash
rg -n "AuthManager|auth_sign_in|username_prompt|username_submit" src/client/client_app.* src/ui
```
Expected: no auth flow ownership in runtime app/ui manager path.

2. Login root owns auth wiring:
```bash
rg -n "AuthManager|retry_sign_in|submit_username" src/client/login
```
Expected: non-empty.

### Handoff Notes
1. **Scope completed**: LoginRoot owns AuthManager; auth + hydration flow implemented; new bootstrap_login_panel under client/login/ui; autostart auth on _ready(); UiBus.auth_sign_in_started removed from AuthManager.
2. **Files touched**: login_root.gd, login_root.tscn, auth_manager.gd; created bootstrap_login_panel.gd, bootstrap_login_panel.tscn. Old ui/login_menu/* retained as Phase 4 reference.
3. **Outstanding risks**: ui/login_menu still uses UiBus auth signals but is no longer in runtime path (UIManager not mounted). Phase 4 will delete it and clean UiBus.
   Known transitional warning: headless/editor shutdown can report leaked `GDScriptFunctionState`
   and `auth_result.gd` resource while auth HTTP awaits are in-flight. Deferred intentionally to
   Phase 4 teardown-hardening (cancel/unblock pending auth requests on root shutdown).
4. **Verification run**: `just game::fix` passes.
5. **Grep proofs**: No AuthManager/auth in client_app or client path; LoginRoot owns auth wiring.
6. **Next phase start point**: Phase 3 Garage/Arena UI ownership.

---

## Phase 3: Garage/Arena UI Ownership Migration

### Objective
Move UI/state ownership into `GarageRoot` and `ArenaRoot`; delete root-switch logic from `UIManager`.

### Includes
1. Garage UI + garage overlay ownership under `GarageRoot`.
2. Battle interface, touch controls, online overlays under `ArenaRoot`.
3. `UIManager` removed from root-state control path.
4. `LevelContainer` owned by `ArenaRoot`.

### Entry Criteria
1. Phase 2 complete.
2. Login flow functional via `LoginRoot`.

### Exit Criteria
1. `GarageRoot` emits `play_requested` and `logout_requested`.
2. `ArenaRoot` emits explicit end signals (`arena_finished`, `return_to_garage_requested`, `logout_requested`).
3. No visibility-toggle-based root switching remains.
4. `just game::fix` passes.

### Checklist
1. Move/rewire garage files to `client/garage/ui/*` ownership.
2. Move/rewire battle + overlay files to `client/arena/*` ownership.
3. Add root-local wiring in each root `_ready()`.
4. Remove `UIManager` login/garage/battle switching methods and signal bindings.
5. Keep only shared overlays in `client/shared_ui/*` if required.

### Verification
1. `just game::fix`
2. Manual smoke:
- login -> garage -> arena -> garage
- logout from garage -> login
- logout from arena -> login

### Grep Proofs
1. No root switching in legacy manager:
```bash
rg -n "show_menu\(|login_menu|battle_interface|garage" src/ui/ui_manager.gd
```
Expected: file deleted or no root-switch logic.

### Handoff Notes
1. **Scope completed**: Garage UI + garage_menu_overlay under GarageRoot; battle interface, touch controls, online overlays under ArenaRoot; UIManager deleted; LevelContainer + net stack (Network, Session, Gameplay) in ArenaRoot; ClientApp owns shared overlays (SettingsOverlay, ShellInfoOverlay) via SharedOverlays CanvasLayer.
2. **Files touched**: Moved ui/garage/* → client/garage/ui/garage/*, ui/overlays/garage_menu_overlay → client/garage/ui/overlays/, ui/battle_interface/* → client/arena/battle_interface/, ui/touch_controls/* → client/arena/touch_controls/, ui/overlays/online_* → client/arena/overlays/; updated all path references; garage_root.gd/.tscn, arena_root.gd/.tscn, client_app.gd; deleted ui_manager.gd, ui_manager.tscn; garage.gd, header_panel.gd, garage_menu_overlay.gd signal changes.
3. **Outstanding risks**: None. Auth leak warning on exit (Phase 2 known issue) remains.
4. **Verification run**: `just game::fix` passes.
5. **Grep proofs**: `rg "show_menu|login_menu|battle_interface" src/ui/` — UIManager deleted, no root-switch logic.
6. **Footnote — shared UI**: SettingsOverlay and ShellInfoOverlay remain in `src/ui/overlays/` (not moved). ClientApp instances them in a SharedOverlays CanvasLayer. Future: consider `client/shared_ui/` if relocating shared overlays.

---

## Phase 4: Cleanup/Purge (No Legacy Crumbs)

### Objective
Delete legacy paths, remove deprecated signals/APIs, and complete data ownership cut to `Account`.

### Includes
1. Full auth/login signal cleanup from `UiBus`.
2. Delete old login menu files.
3. Delete `UIManager` files.
4. Remove `PlayerData` usage replaced by `Account` (username/loadout/economy flow).
5. Delete temporary reference files marked in earlier phases.

### Entry Criteria
1. Phases 1-3 complete and functional.

### Exit Criteria
1. No references to removed signals/files/classes.
2. `PlayerData` no longer participates in account-facing client flow.
3. `just game::fix` passes.

### Checklist
1. Remove deprecated signals from `src/singletons/ui_bus.gd`.
2. Replace all emitters/consumers with direct root->`ClientApp` signals.
3. Delete `src/ui/login_menu/*`.
4. Delete `src/ui/ui_manager.*`.
5. Remove/replace `PlayerData` calls in client paths.
6. Remove stale folders left empty by migration.

### Verification
1. `just game::fix`
2. Grep zero checks:
```bash
rg -n "login_pressed|auth_retry_requested|auth_sign_in_started|auth_sign_in_finished|username_prompt_requested|username_submit_requested|username_submit_finished|return_to_menu_requested|log_out_pressed"
rg -n "PlayerData\.get_instance\(|player_data\."
rg -n "ui_manager|login_menu"
```
Expected: zero relevant runtime references.

### Handoff Notes
1. **Scope completed**: UiBus auth signals removed; login_menu deleted; PlayerData replaced by Account; AccountLoadout.unlock_tank added; gameplay_bus.player_data_changed removed; login assets moved to client/login/ui/assets.
2. **Files touched**: ui_bus.gd, gameplay_bus.gd, account_loadout.gd, garage.gd, arena_client.gd, tank_hud.gd, bootstrap_login_panel.tscn; created client/login/ui/assets/*; deleted ui/login_menu/*, game_data/player_data/*.
3. **Outstanding risks**: Auth leak on exit (Phase 2 known) remains. Dev auth with empty /me returns may show garage with no tanks; /me hydration provides loadout.
4. **Verification run**: `just game::fix` passes.
5. **Grep proofs**: Deprecated UiBus signals, PlayerData, ui_manager, login_menu — all zero in src/.
6. **Next phase start point**: Phase 4 complete. Final acceptance checklist applies.

---

## Final Acceptance
1. Client runs exclusively through `ClientApp` root lifecycle.
2. Exactly one of `LoginRoot/GarageRoot/ArenaRoot` mounted at a time.
3. Auth flow is bootstrap/login-root only.
4. Runtime has no legacy login/auth crumbs.
5. `Account` is sole source of truth for account-facing client state.
6. `just game::fix` passes on final tree.
