class_name NetworkServerBroadcastUtils
extends RefCounted


static func broadcast_arena_shell_spawn(
	rpc_node: Node,
	connected_peers: PackedInt32Array,
	shot_id: int,
	firing_peer_id: int,
	shell_spec_path: String,
	spawn_position: Vector2,
	shell_velocity: Vector2,
	shell_rotation: float
) -> void:
	for peer_id: int in connected_peers:
		rpc_node.rpc_id(
			peer_id,
			"_receive_arena_shell_spawn",
			shot_id,
			firing_peer_id,
			shell_spec_path,
			spawn_position,
			shell_velocity,
			shell_rotation
		)


static func broadcast_arena_shell_impact(
	rpc_node: Node,
	connected_peers: PackedInt32Array,
	shot_id: int,
	firing_peer_id: int,
	target_peer_id: int,
	result_type: int,
	damage: int,
	remaining_health: int,
	hit_position: Vector2,
	post_impact_velocity: Vector2,
	post_impact_rotation: float,
	continue_simulation: bool
) -> void:
	for peer_id: int in connected_peers:
		rpc_node.rpc_id(
			peer_id,
			"_receive_arena_shell_impact",
			shot_id,
			firing_peer_id,
			target_peer_id,
			result_type,
			damage,
			remaining_health,
			hit_position,
			post_impact_velocity,
			post_impact_rotation,
			continue_simulation
		)
