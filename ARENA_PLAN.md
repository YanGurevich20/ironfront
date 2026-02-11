# Arena Plan
## Concept
- Currently the game is local only, with a few offline levels.
- as a first stage to introduce online multiplayer, we will implement an arena mode.
- the server run a single, persistent global arena room, with a fixed player limit of 10.
- players will join the arena room by pressing 'play online' button in the garage.
- the server will assign a random spawn point to the player and spawn them there.

## Phase 1: Online Join Flow (Client <-> Server)
- [x] Keep transport handshake (`hello` / `ack`) working.
- [x] Add explicit `join_arena` client request RPC.
- [x] Add explicit `join_arena_ack` server response RPC.
- [x] Trigger online connect only from `PLAY ONLINE` button.
- [x] Show clear join success/failure feedback in UI.

### Notes
- 

## Phase 2: Server Arena Session (Single Global Room)
- [x] Create a server-owned arena session state object.
- [x] Keep one always-running global arena session.
- [x] Track players by `peer_id` in session state.
- [x] Handle disconnect cleanup and player removal.

### Notes
- 

## Phase 2.5: Arena Level Authoring (MVP Content Baseline)
- [x] Create/select one arena level scene for online play.
- [x] Define spawn markers in-scene with stable IDs/names.
- [x] Add a small spawn-point validation pass (count, uniqueness, transform sanity).
- [x] Document how server loads/references this level's spawn pool.

### Notes
- Arena scene path: `res://levels/arena/arena_level_mvp.tscn`.
- Server boot loads this scene, validates spawn markers, and caches `spawn_id -> Transform2D` for Phase 3 assignment.

## Phase 3: Random Spawn Assignment
- [x] Pick one arena map for the MVP.
- [x] Load/use spawn points as the player spawn pool.
- [x] Assign random spawn on successful join.
- [x] Send assigned spawn transform to joining client.
- [x] Add fallback behavior when all spawns are occupied.

### Notes
- `join_arena_ack` now carries `spawn_position` and `spawn_rotation` from server-authoritative assignment.
- Spawn occupancy is tracked by `spawn_id` and released on disconnect.
- Fallback when no free spawn exists is explicit join rejection (`NO SPAWN AVAILABLE`).

## Phase 4: Client Arena Bootstrap
- [x] Load arena level on successful `join_arena_ack`.
- [x] Spawn local player at server-assigned transform.
- [x] Ensure local input/HUD work in arena runtime.
- [ ] Keep local campaign flow (`PLAY` -> level select) untouched.

### Notes
- Both clients can connect, receive `join_arena_ack`, load the map, and start local tank runtime at server-assigned spawns.

## Phase 5: Multiplayer Visibility and Replication
- [x] Spawn/despawn remote players on all clients.
- [x] Add server-authoritative state snapshots.
- [x] Interpolate/extrapolate remote movement client-side.
- [ ] Sync key gameplay events (fire/hit/death) across peers.

### Notes
- Movement model: clients send input intents, server remains authoritative for simulation state.
- Local player uses client-side prediction + server reconciliation from periodic authoritative snapshots.
- Client-originated position data may be sent only as optional diagnostics and must never be trusted as authority.

### Current Hurdle (Phase 5)
- Resolved blocker: snapshot gate was firing but broadcast path failed due to typed peer list mismatch (`Array[int]` vs `PackedInt32Array`) in `net/network_server.gd`.
- Current behavior: both clients can see each other and receive ongoing replicated movement.
- Remaining quality gap: movement feel is jittery/too fast compared to offline due to simulation mismatch and basic reconciliation.

## Phase 5.5: Authoritative Simulation Alignment
- [x] Run server runtime from dedicated-server export preset.
- [ ] Keep standard gameplay flow on server.
- [ ] Defer peripheral gating (UI/audio/VFX/camera/input) until after gameplay parity is stable.
- [ ] Reuse existing movement/combat logic server-side as authority source.
- [ ] Keep client prediction/reconciliation but consume server-authored gameplay states.
- [x] Move movement snapshots and input intents to `unreliable_ordered`; keep critical events reliable.

### Notes
- Goal: preserve offline gameplay feel while keeping server authority.
- Server should run gameplay simulation as source of truth.
- Clients send intent only; server owns outcomes for combat-critical events.
- Practical approach: avoid a full rewrite first, keep peripherals out of scope for now, and validate gameplay parity incrementally.

## Phase 6: Validation and Hardening
- [ ] Verify join/leave behavior with multiple clients.
- [ ] Validate random spawn distribution and collision safety.
- [ ] Validate reconnect and server restart behavior.
- [ ] Add minimal logging/metrics for arena lifecycle.
- [ ] Trim noisy logs once stable.

### Notes
- 

## Phase 5.5 Execution Tracker (Started February 10, 2026)
This tracker is the source of truth for the "real server session" migration so we can resume without re-loading full context.

### Step 1: Server Arena Runtime Bootstrap
- [x] Add persistent server arena runtime node that keeps `res://levels/arena/arena_level_mvp.tscn` mounted during server lifetime.
- [x] Move spawn validation/load responsibility into server runtime initialization.
- [x] Keep `spawn_id -> Transform2D` cache exposed for existing join/spawn assignment path.
- [x] Add network lifecycle hooks (`join_succeeded`, `peer_removed`) so server runtime can react to session events.
- [x] Spawn one server-owned tank node per joined peer and maintain `peer_id -> tank` mapping in runtime.
- [x] Validate behavior with local dedicated server + multiple clients.

Implementation notes (February 10, 2026):
- New runtime: `core/server_arena_runtime.gd`.
- `core/server.gd` now boots runtime first and wires network events to runtime spawn/despawn.
- `net/network_server.gd` now emits arena lifecycle signals that are consumed by server runtime.
- Temporary controller choice is `DUMMY` (mapping/bootstrap only). Per-peer network-driven controller arrives in Step 3.
- Validation complete in dev environment: `just fix` passed and `just server-export` produced `./dist/server/ironfront_server.x86_64`.
- Follow-up fix after first dedicated bundle run: `entities/tank/tank.gd` now treats destruction material preload as `Resource` and casts at runtime, avoiding `PlaceholderMaterial -> ShaderMaterial` parse failure in stripped server exports.
- Local runtime verification (February 10, 2026): two clients joined dedicated server successfully, `tank_spawned` emitted for each peer, both clients saw each other, and input/snapshot traffic stayed active (`rx/applied/snapshots` counters increasing in server uptime logs).

### Step 2: Authority Source Swap (validated February 10, 2026)
- [x] Stop using simplified state simulation as gameplay authority in `net/network_server.gd`.
- [x] Build snapshots from live server tank nodes.
- [x] Keep transport/validation inside `net/`; keep gameplay state mutation in server runtime.

Implementation notes (February 10, 2026):
- `core/server_arena_runtime.gd` now applies per-peer validated input intents (`left_track_input`, `right_track_input`, `turret_aim`, `fire`) directly onto spawned server tank nodes each tick.
- Runtime now writes authoritative state from live tank nodes (`global_position`, `global_rotation`, `linear_velocity`) back into `ArenaSessionState` and returns snapshot-ready player dictionaries.
- `core/server.gd` tick flow now executes runtime authority step first, then hands runtime-authored snapshot states to `NetworkServer`.
- `net/network_server.gd` no longer runs `_simulate_authoritative_state`; it only validates/accepts inputs and handles snapshot broadcast transport.
- `net/network_server.gd` now consumes runtime-provided authoritative player states with a safe fallback to `ArenaSessionState` snapshots when runtime cache is unavailable/mismatched (for join-transition safety).
- Local validation status: `just fix` passed after this refactor.
- Runtime validation (February 10, 2026): fresh dedicated server bundle tested with local clients; join/visibility remains correct and movement feel is notably improved versus prior simplified sim path.
- Known quality gap after validation: movement feels slightly sluggish. Next pass should focus on responsiveness tuning (input/snapshot cadence and reconciliation gains) before or alongside Step 3 controller migration.

### Step 2.1: Responsiveness and Tick Loop Pass (validated February 11, 2026)
- [x] Replace manual server timer tick loop with `_physics_process`-driven fixed-step loop.
- [x] Keep explicit server tick counter and existing sync metrics.
- [x] Increase input send cadence and snapshot cadence for lower perceived latency.
- [x] Tighten client-side snapshot delay and reconciliation blend for faster convergence.

Implementation notes (February 10, 2026):
- `core/server.gd` now configures `Engine.physics_ticks_per_second` from `tick_rate_hz` and runs server authority/snapshot flow inside `_physics_process(delta)`.
- `net/multiplayer_protocol.gd` updated rates to `INPUT_SEND_RATE_HZ=60` and `SNAPSHOT_RATE_HZ=30`.
- `core/online_arena_sync_runtime.gd` updated interpolation/reconciliation defaults: `snapshot_render_delay_ticks=1` and `reconciliation_soft_blend=0.5`.
- Follow-up control parity fix: online input transport now sends direct `left_track_input`/`right_track_input` and server applies those directly, matching `mobile_player_tank_controller` semantics instead of reconstructing from throttle/steer.
- Client HUD visibility add-on: battle interface now includes a small bottom ping indicator shown during online arena sessions, using ENet RTT stats from `NetworkClient`.
- Validation complete (February 11, 2026): dedicated server bundle tested with local clients; joins remained stable, movement responsiveness improved, and server sync counters (`rx/applied/snapshots`) advanced consistently under live play.
- Follow-up validation result (February 11, 2026): left/right control parity issue was fixed by direct track-input transport, and battle HUD ping indicator was confirmed visible during online arena sessions.

### Step 3: Per-Peer Network Controller (planned)
- [ ] Add a server-side network controller that consumes peer-scoped input intents.
- [ ] Attach the network controller to each server player tank.
- [ ] Remove reliance on global `GameplayBus` input signals for server-authoritative player tanks.

### Step 4: Session State Simplification (planned)
- [ ] Keep `ArenaSessionState` for membership/session metadata.
- [ ] Move live transform authority to runtime tank nodes.
- [ ] Keep only validated input/session data in `ArenaSessionState`.

### Step 5: Combat Event Authority (planned)
- [ ] Broadcast fire/hit/death as server-authored events.
- [ ] Keep critical combat events reliable.
- [ ] Keep movement/snapshot traffic on `unreliable_ordered`.

### Step 6: Verification Gate (planned)
- [ ] 2-4 client join/leave soak test.
- [ ] Reconnect and server-restart behavior checks.
- [ ] Remove temporary verbose logs after stability pass.
