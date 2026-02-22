# Account Runtime Plan (Reframed)

## Goal
Keep account runtime state fully spec-native (`TankSpec`, `ShellSpec`) and keep all ID conversion at explicit boundaries only.

## Current Direction
1. Runtime account ownership is spec-native and should stay that way.
2. `/me` parser is the inbound ID -> spec boundary.
3. Arena join builder is the outbound spec -> ID boundary.
4. Extra ad hoc conversions outside boundaries should be removed.
5. We optimize for rapid simplification and delete legacy paths.

## Boundary Contract
1. Inbound boundary:
- `UserServiceMeResponseParser.hydrate_account_from_me_body` parses raw API IDs to specs.
2. Runtime interior:
- Account/garage/arena UI/runtime use `TankSpec`/`ShellSpec` directly.
3. Outbound boundary:
- Arena join payload builder converts specs back to IDs for RPC/network.

## Phase 1 - Runtime Invariants (Active)

### Objective
Lock runtime invariants so account behavior is deterministic after hydration, clear, unlock, and selection changes.

### Scope
1. `selected_tank_spec` defaults to first unlocked tank when unset.
2. Runtime account collections stay spec-keyed.
3. No gameplay/UI logic depends on raw loadout IDs.
4. Remove remaining non-boundary spec->ID conversions where possible.

### Exit Criteria
1. Account runtime state remains spec-native.
2. Selected tank fallback behavior is deterministic and spec-based.
3. `just game::fix` passes.

### Verification
```bash
just game::fix
rg -n "selected_tank_id|shell_loadout_by_id" game/src/client game/src/entities game/src/singletons/account
rg -n "find_tank_spec\\(|find_shell_spec\\(|get_shell_id\\(" game/src/client game/src/singletons game/src/api
```

## Phase 2 - Boundary Consolidation (Active)

### Objective
Keep spec->ID conversion discoverable and localized to explicit boundary code paths.

### Scope
1. Arena join flow uses the account->join payload builder exclusively.
2. No duplicate join conversion logic in gameplay/UI callsites.
3. Defer API patch serializer until a loadout patch endpoint exists.

### Exit Criteria
1. Boundary conversion points are explicit and minimal.
2. Join/API payload generation does not require ID-native account state.
3. `just game::fix` passes.

### Verification
```bash
just game::fix
rg -n "build_join_arena_payload|to_join_payload|to_api_payload" game/src
```

## Phase 3 - Hardening + Judge Signoff

### Objective
Finalize documentation and enforce Judge-ready completion evidence.

### Scope
1. Add invariant assertions/warnings where missing.
2. Update `game/agent-docs/code-patterns.md` if new access/serialization patterns were introduced.
3. Record completion notes in this file.

### Exit Criteria
1. No known regressions in login/hydrate/garage/unlock/join loop.
2. Judge can validate with reproducible commands and grep proofs.

## Judge Checklist
1. Runtime state is spec-native in account-facing gameplay/UI code.
2. Parser performs ID->spec conversion + compatibility filtering.
3. Join builder performs spec->ID conversion.
4. No scattered conversion logic in unrelated callsites.
5. `just game::fix` result included.

## Executor Handoff Template
1. Scope completed
2. Files touched
3. Verification commands + results
4. Remaining risks
5. Next executable step
