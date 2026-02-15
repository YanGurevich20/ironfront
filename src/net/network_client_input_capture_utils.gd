class_name NetworkClientInputCaptureUtils
extends RefCounted

const NetworkClientConnectionUtilsData := preload(
	"res://src/net/network_client_connection_utils.gd"
)


static func setup_for_client(network_client: NetworkClient) -> void:
	Utils.connect_checked(
		GameplayBus.lever_input,
		func(lever_side: Lever.LeverSide, value: float) -> void:
			if lever_side == Lever.LeverSide.LEFT:
				network_client.pending_left_track_input = clamp(value, -1.0, 1.0)
			elif lever_side == Lever.LeverSide.RIGHT:
				network_client.pending_right_track_input = clamp(value, -1.0, 1.0)
	)
	Utils.connect_checked(
		GameplayBus.wheel_input,
		func(value: float) -> void: network_client.pending_turret_aim = clamp(value, -1.0, 1.0)
	)
	Utils.connect_checked(
		GameplayBus.fire_input,
		func() -> void:
			if not NetworkClientConnectionUtilsData.can_send_input_intents(
				network_client.multiplayer, network_client.arena_input_enabled
			):
				return
			network_client.local_fire_request_seq += 1
			network_client._request_fire.rpc_id(1, network_client.local_fire_request_seq)
	)
	Utils.connect_checked(
		GameplayBus.shell_selected,
		func(shell_spec: ShellSpec, remaining_shell_count: int) -> void:
			if remaining_shell_count < 0:
				return
			if shell_spec == null:
				return
			if shell_spec.resource_path.is_empty():
				return
			if not NetworkClientConnectionUtilsData.can_send_input_intents(
				network_client.multiplayer, network_client.arena_input_enabled
			):
				return
			network_client.local_shell_select_seq += 1
			network_client._request_shell_select.rpc_id(
				1, network_client.local_shell_select_seq, shell_spec.resource_path
			)
	)
