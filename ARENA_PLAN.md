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
- [ ] Pick one arena map for the MVP.
- [ ] Load/use spawn points as the player spawn pool.
- [ ] Assign random spawn on successful join.
- [ ] Send assigned spawn transform to joining client.
- [ ] Add fallback behavior when all spawns are occupied.

### Notes
- 

## Phase 4: Client Arena Bootstrap
- [ ] Load arena level on successful `join_arena_ack`.
- [ ] Spawn local player at server-assigned transform.
- [ ] Ensure local input/HUD work in arena runtime.
- [ ] Keep local campaign flow (`PLAY` -> level select) untouched.

### Notes
- 

## Phase 5: Multiplayer Visibility and Replication
- [ ] Spawn/despawn remote players on all clients.
- [ ] Add server-authoritative state snapshots.
- [ ] Interpolate/extrapolate remote movement client-side.
- [ ] Sync key gameplay events (fire/hit/death) across peers.

### Notes
- Movement model: clients send input intents, server remains authoritative for simulation state.
- Local player uses client-side prediction + server reconciliation from periodic authoritative snapshots.
- Client-originated position data may be sent only as optional diagnostics and must never be trusted as authority.

## Phase 6: Validation and Hardening
- [ ] Verify join/leave behavior with multiple clients.
- [ ] Validate random spawn distribution and collision safety.
- [ ] Validate reconnect and server restart behavior.
- [ ] Add minimal logging/metrics for arena lifecycle.
- [ ] Trim noisy logs once stable.

### Notes
- 
