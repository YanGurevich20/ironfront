class_name ArenaInput
extends Node

var gameplay_api: ClientGameplayApi
var enet_client: ENetClient
var arena_match: ArenaMatch

var input_send_interval_seconds: float = 1.0 / float(MultiplayerProtocol.INPUT_SEND_RATE_HZ)
var input_send_elapsed_seconds: float = 0.0
var local_input_tick: int = 0
var local_fire_request_seq: int = 0
var local_shell_select_seq: int = 0
var pending_left_track_input: float = 0.0
var pending_right_track_input: float = 0.0
var pending_turret_input: float = 0.0
var session_running: bool = false
var _debug_logged_lever_events: int = 0
var _debug_logged_wheel_events: int = 0


func start_session(
	next_gameplay_api: ClientGameplayApi,
	next_enet_client: ENetClient,
	next_match: ArenaMatch,
	reset_sequence_state: bool = true
) -> void:
	gameplay_api = next_gameplay_api
	enet_client = next_enet_client
	arena_match = next_match
	assert(gameplay_api != null, "ArenaInput requires ClientGameplayApi")
	assert(enet_client != null, "ArenaInput requires ENetClient")
	assert(arena_match != null, "ArenaInput requires ArenaMatch")
	if reset_sequence_state:
		local_input_tick = 0
		local_fire_request_seq = 0
		local_shell_select_seq = 0
	input_send_elapsed_seconds = 0.0
	_connect_gameplay_bus()
	set_process(true)
	session_running = true
	print(
		(
			"[client-input] session_started connected=%s send_interval=%.4f reset_seq=%s"
			% [
				str(can_send_gameplay_requests()),
				input_send_interval_seconds,
				str(reset_sequence_state)
			]
		)
	)


func stop_session(reset_sequence_state: bool = true) -> void:
	if not session_running:
		return
	session_running = false
	_disconnect_gameplay_bus()
	set_process(false)
	pending_left_track_input = 0.0
	pending_right_track_input = 0.0
	pending_turret_input = 0.0
	input_send_elapsed_seconds = 0.0
	arena_match.set_local_input(0.0, 0.0, 0.0)
	if reset_sequence_state:
		local_input_tick = 0
		local_fire_request_seq = 0
		local_shell_select_seq = 0
	print(
		(
			"[client-input] session_stopped reset_seq=%s last_tick=%d"
			% [str(reset_sequence_state), local_input_tick]
		)
	)


func can_send_gameplay_requests() -> bool:
	return session_running and enet_client.is_connected_to_server()


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
	if local_input_tick <= 5 or (local_input_tick % 30) == 0:
		print(
			(
				"[client-input] send_input tick=%d left=%.2f right=%.2f turret=%.2f"
				% [
					local_input_tick,
					pending_left_track_input,
					pending_right_track_input,
					pending_turret_input
				]
			)
		)


func _on_lever_input(lever_side: Lever.LeverSide, value: float) -> void:
	if arena_match.is_local_player_dead():
		return
	var clamped_value: float = clamp(value, -1.0, 1.0)
	if lever_side == Lever.LeverSide.LEFT:
		pending_left_track_input = clamped_value
	elif lever_side == Lever.LeverSide.RIGHT:
		pending_right_track_input = clamped_value
	if _debug_logged_lever_events < 12:
		_debug_logged_lever_events += 1
		print(
			(
				"[client-input] lever side=%s value=%.2f pending_left=%.2f pending_right=%.2f"
				% [
					str(lever_side),
					clamped_value,
					pending_left_track_input,
					pending_right_track_input
				]
			)
		)
	arena_match.set_local_input(
		pending_left_track_input, pending_right_track_input, pending_turret_input
	)


func _on_wheel_input(value: float) -> void:
	if arena_match.is_local_player_dead():
		return
	pending_turret_input = clamp(value, -1.0, 1.0)
	if _debug_logged_wheel_events < 8:
		_debug_logged_wheel_events += 1
		print("[client-input] wheel value=%.2f pending_turret=%.2f" % [value, pending_turret_input])
	arena_match.set_local_input(
		pending_left_track_input, pending_right_track_input, pending_turret_input
	)


func _on_fire_input() -> void:
	if arena_match.is_local_player_dead() or not can_send_gameplay_requests():
		return
	local_fire_request_seq += 1
	print("[client-input] fire_request seq=%d" % local_fire_request_seq)
	gameplay_api.request_fire(local_fire_request_seq)


func _on_shell_selected(shell_spec: ShellSpec, remaining_shell_count: int) -> void:
	if arena_match.is_local_player_dead() or remaining_shell_count < 0:
		return
	if not can_send_gameplay_requests():
		return
	local_shell_select_seq += 1
	gameplay_api.request_shell_select(local_shell_select_seq, ShellManager.get_shell_id(shell_spec))


func _connect_gameplay_bus() -> void:
	if not GameplayBus.lever_input.is_connected(_on_lever_input):
		GameplayBus.lever_input.connect(_on_lever_input)
	if not GameplayBus.wheel_input.is_connected(_on_wheel_input):
		GameplayBus.wheel_input.connect(_on_wheel_input)
	if not GameplayBus.fire_input.is_connected(_on_fire_input):
		GameplayBus.fire_input.connect(_on_fire_input)
	if not GameplayBus.shell_selected.is_connected(_on_shell_selected):
		GameplayBus.shell_selected.connect(_on_shell_selected)


func _disconnect_gameplay_bus() -> void:
	if GameplayBus.lever_input.is_connected(_on_lever_input):
		GameplayBus.lever_input.disconnect(_on_lever_input)
	if GameplayBus.wheel_input.is_connected(_on_wheel_input):
		GameplayBus.wheel_input.disconnect(_on_wheel_input)
	if GameplayBus.fire_input.is_connected(_on_fire_input):
		GameplayBus.fire_input.disconnect(_on_fire_input)
	if GameplayBus.shell_selected.is_connected(_on_shell_selected):
		GameplayBus.shell_selected.disconnect(_on_shell_selected)
