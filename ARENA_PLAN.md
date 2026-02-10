# Arena Plan

## Phase 1: Online Join Flow (Client <-> Server)
- [x] Keep transport handshake (`hello` / `ack`) working.
- [x] Add explicit `join_arena` client request RPC.
- [x] Add explicit `join_arena_ack` server response RPC.
- [x] Trigger online connect only from `PLAY ONLINE` button.
- [x] Show clear join success/failure feedback in UI.

### Notes
- 

## Phase 2: Server Arena Session (Single Global Room)
- [ ] Create a server-owned arena session state object.
- [ ] Keep one always-running global arena session.
- [ ] Track players by `peer_id` in session state.
- [ ] Handle disconnect cleanup and player removal.

### Notes
- 

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
- 

## Phase 6: Validation and Hardening
- [ ] Verify join/leave behavior with multiple clients.
- [ ] Validate random spawn distribution and collision safety.
- [ ] Validate reconnect and server restart behavior.
- [ ] Add minimal logging/metrics for arena lifecycle.
- [ ] Trim noisy logs once stable.

### Notes
- 
