class_name ArenaInputSync
extends Node

var gameplay_api: ClientGameplayApi
var enet_client: ENetClient
var world: ArenaWorld

var input_send_interval_seconds: float = 1.0 / float(MultiplayerProtocol.INPUT_SEND_RATE_HZ)
var input_send_elapsed_seconds: float = 0.0
var local_input_tick: int = 0
var local_fire_request_seq: int = 0
var local_shell_select_seq: int = 0
var pending_left_track_input: float = 0.0
var pending_right_track_input: float = 0.0
var pending_turret_input: float = 0.0
var active: bool = false


func _ready() -> void:
	Utils.connect_checked(GameplayBus.lever_input, _on_lever_input)
	Utils.connect_checked(GameplayBus.wheel_input, _on_wheel_input)
	Utils.connect_checked(GameplayBus.fire_input, _on_fire_input)
	Utils.connect_checked(GameplayBus.shell_selected, _on_shell_selected)


func configure(
	next_gameplay_api: ClientGameplayApi, next_enet_client: ENetClient, next_world: ArenaWorld
) -> void:
	gameplay_api = next_gameplay_api
	enet_client = next_enet_client
	world = next_world
	assert(gameplay_api != null, "ArenaInputSync requires ClientGameplayApi")
	assert(enet_client != null, "ArenaInputSync requires ENetClient")
	assert(world != null, "ArenaInputSync requires ArenaWorld")


func activate(reset_sequence_state: bool = true) -> void:
	_set_active(true, reset_sequence_state)


func deactivate(reset_sequence_state: bool = true) -> void:
	_set_active(false, reset_sequence_state)


func can_send_gameplay_requests() -> bool:
	return active and enet_client.is_connected_to_server()


func _process(delta: float) -> void:
	if not can_send_gameplay_requests():
		return
	input_send_elapsed_seconds += delta
	if input_send_elapsed_seconds < input_send_interval_seconds:
		return
	input_send_elapsed_seconds = 0.0
	local_input_tick += 1
	gameplay_api.send_input_intent(
		local_input_tick, pending_left_track_input, pending_right_track_input, pending_turret_input
	)


func _set_active(enabled: bool, reset_sequence_state: bool = true) -> void:
	active = enabled
	if not active:
		pending_left_track_input = 0.0
		pending_right_track_input = 0.0
		pending_turret_input = 0.0
		input_send_elapsed_seconds = 0.0
		world.set_local_input(0.0, 0.0, 0.0)
		if reset_sequence_state:
			local_input_tick = 0
			local_fire_request_seq = 0
			local_shell_select_seq = 0
	return


func _on_lever_input(lever_side: Lever.LeverSide, value: float) -> void:
	if not active or world.is_local_player_dead():
		return
	var clamped_value: float = clamp(value, -1.0, 1.0)
	if lever_side == Lever.LeverSide.LEFT:
		pending_left_track_input = clamped_value
	elif lever_side == Lever.LeverSide.RIGHT:
		pending_right_track_input = clamped_value
	world.set_local_input(pending_left_track_input, pending_right_track_input, pending_turret_input)


func _on_wheel_input(value: float) -> void:
	if not active or world.is_local_player_dead():
		return
	pending_turret_input = clamp(value, -1.0, 1.0)
	world.set_local_input(pending_left_track_input, pending_right_track_input, pending_turret_input)


func _on_fire_input() -> void:
	if not active or world.is_local_player_dead() or not can_send_gameplay_requests():
		return
	local_fire_request_seq += 1
	gameplay_api.request_fire(local_fire_request_seq)


func _on_shell_selected(shell_spec: ShellSpec, remaining_shell_count: int) -> void:
	if not active or world.is_local_player_dead() or remaining_shell_count < 0:
		return
	if not can_send_gameplay_requests():
		return
	local_shell_select_seq += 1
	gameplay_api.request_shell_select(local_shell_select_seq, ShellManager.get_shell_id(shell_spec))
