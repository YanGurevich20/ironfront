# Godot High-Level Multiplayer API Research

Last reviewed: February 10, 2026  
Engine target: Godot 4.x (`stable` docs stream)

This document captures the key parts of Godot's high-level multiplayer API we should rely on for Ironfront's online gameplay.

## Primary official docs

- High-level multiplayer tutorial: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- Scene replication overview: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html#scene-replication
- `MultiplayerAPI`: https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html
- `SceneMultiplayer`: https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html
- `MultiplayerPeer`: https://docs.godotengine.org/en/stable/classes/class_multiplayerpeer.html
- `ENetMultiplayerPeer`: https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html
- `MultiplayerSpawner`: https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html
- `MultiplayerSynchronizer`: https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html

## What matters most for our architecture

Current Ironfront split:

- `core/client.gd` + `net/network_client.gd`
- `core/server.gd` + `net/network_server.gd`

This already aligns with Godot's recommended model:

- A single `MultiplayerPeer` assigned to `multiplayer.multiplayer_peer`.
- ENet transport via `ENetMultiplayerPeer` (`create_client` / `create_server`).
- RPC-based messaging via `@rpc` annotations.

## Core API concepts to standardize on

1. Authority model
- By default, server authority is peer `1`.
- Use `Node.set_multiplayer_authority(peer_id)` when ownership must move to a client.
- Gate sensitive logic with `multiplayer.is_server()` checks.

2. RPC declaration and direction
- Use explicit `@rpc` modes (`"authority"`, `"any_peer"`) and transfer modes (`"reliable"`, `"unreliable"`, `"unreliable_ordered"`) based on gameplay semantics.
- Use `multiplayer.get_remote_sender_id()` inside server-side `any_peer` handlers for trust boundaries and auditing.

3. Channels and transfer modes
- Keep critical game-state events on reliable channels.
- Move high-frequency transient data (e.g., frequent transform updates) to unreliable/unreliable_ordered on dedicated channels to avoid head-of-line blocking.

4. Scene replication primitives
- Prefer `MultiplayerSpawner` for authoritative runtime spawn/despawn.
- Prefer `MultiplayerSynchronizer` for replicated node properties, with clearly scoped sync configs and authority checks.

## Recommended usage pattern for Ironfront

1. Keep handshake and protocol versioning in `net/network_client.gd` and `net/network_server.gd` (already started).
2. Keep simulation authority on dedicated server for combat-critical logic (damage, kills, objective completion).
3. Add a small RPC contract table per gameplay subsystem:
- RPC name
- caller (`authority`/`any_peer`)
- transfer mode
- channel
- validation rules
4. Introduce `MultiplayerSpawner` for networked tank/shell lifecycle when server-side entity spawning is added.
5. Introduce `MultiplayerSynchronizer` only for state that must continuously mirror, and avoid syncing derivable values.
6. Keep per-feature bandwidth budgets and channel assignments documented to avoid accidental reliable-channel saturation.

## Security and robustness notes from docs

- Do not trust client input by default. Validate all client-originated RPC payloads on server.
- Keep protocol version checks (already present in your hello/ack flow) and disconnect on incompatibility.
- On Android exports, networking often requires enabling the `INTERNET` permission in export settings.

## Suggested next implementation steps

1. Define one shared protocol constants resource/script for:
- protocol version
- channel IDs
- transfer mode conventions

2. Add explicit disconnect path on protocol mismatch in both client and server handlers.

3. Add first replicated gameplay path using this sequence:
- client input RPC (`any_peer`, validated on server)
- authoritative server state update
- server-to-clients outcome RPC (`authority`, reliable/unreliable based on payload)

4. Add lightweight integration tests/log assertions for:
- connect
- hello/ack
- protocol mismatch rejection
- reconnect after disconnect

## Notes for future research

If we need custom replication behavior outside scene-tree convenience tools, review low-level APIs and custom packet serialization after high-level flow is stable.
