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
- [ ] Extract a server-safe shared simulation core (no UI/audio/VFX dependencies).
- [ ] Run the same tank movement/combat simulation rules on server authority and client prediction paths.
- [ ] Replace blend-only local correction with rollback + input replay reconciliation.
- [ ] Keep remote entities interpolation-only with a fixed render delay buffer.
- [ ] Move movement snapshots and input intents to `unreliable_ordered`; keep critical events reliable.

### Notes
- Goal: preserve offline gameplay feel while keeping server authority.
- Server should run gameplay simulation as source of truth, with peripherals (UI/audio/VFX) decoupled.
- Clients send intent only; server owns outcomes for combat-critical events.

## Phase 6: Validation and Hardening
- [ ] Verify join/leave behavior with multiple clients.
- [ ] Validate random spawn distribution and collision safety.
- [ ] Validate reconnect and server restart behavior.
- [ ] Add minimal logging/metrics for arena lifecycle.
- [ ] Trim noisy logs once stable.

### Notes
- 
