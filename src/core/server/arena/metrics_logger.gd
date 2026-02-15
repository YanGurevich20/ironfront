class_name MetricsLogger
extends RefCounted

var _server: ServerApp
var _last_log_tick_count: int = 0
var _last_rx: int = 0
var _last_applied: int = 0
var _last_snapshots: int = 0


func _init(server: ServerApp) -> void:
	_server = server


func log_periodic() -> void:
	if _server.tick_count % (_server.tick_rate_hz * 5) != 0:
		return
	var network_gameplay: ServerGameplayApi = _server.network_gameplay
	var tick_count: int = _server.tick_count
	var tick_rate_hz: int = _server.tick_rate_hz
	var arena_player_count: int = _server.arena_session_state.get_player_count()
	var physics_step_ms: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var peers_count: int = _server.get_multiplayer().get_peers().size()

	var uptime_seconds: int = int(tick_count / float(tick_rate_hz))
	var tick_delta: int = tick_count - _last_log_tick_count
	var achieved_physics_hz: float = (
		tick_delta / 5.0 if _last_log_tick_count > 0 else float(tick_rate_hz)
	)
	var rx: int = network_gameplay.total_input_messages_received
	var applied: int = network_gameplay.total_input_messages_applied
	var fire_rx: int = network_gameplay.total_fire_requests_received
	var fire_applied: int = network_gameplay.total_fire_requests_applied
	var snapshots: int = network_gameplay.total_snapshots_broadcast
	var rx_delta: int = rx - _last_rx
	var applied_delta: int = applied - _last_applied
	var snapshots_delta: int = snapshots - _last_snapshots
	var rx_per_sec: float = rx_delta / 5.0 if _last_log_tick_count > 0 else 0.0
	var applied_per_sec: float = applied_delta / 5.0 if _last_log_tick_count > 0 else 0.0
	var snapshots_per_sec: float = snapshots_delta / 5.0 if _last_log_tick_count > 0 else 0.0
	var rejected_delta: int = rx_delta - applied_delta
	var rejection_rate_pct: float = (
		(rejected_delta / float(rx_delta) * 100.0) if rx_delta > 0 else 0.0
	)
	var interval: int = network_gameplay.snapshot_interval_ticks
	var last_snapshot_tick: int = network_gameplay.last_snapshot_tick

	print(
		(
			"[server][uptime] seconds=%d peers=%d arena_players=%d"
			% [uptime_seconds, peers_count, arena_player_count]
		)
	)
	print(
		(
			"[server][perf] achieved_physics_hz=%.1f physics_ms=%.2f"
			% [achieved_physics_hz, physics_step_ms]
		)
	)
	print(
		(
			(
				"[server][sync] interval=%d rx_per_sec=%.1f applied_per_sec=%.1f "
				+ "rejection_rate_pct=%.1f snapshots_per_sec=%.1f fire_rx=%d fire_applied=%d "
				+ "last_tick=%d"
			)
			% [
				interval,
				rx_per_sec,
				applied_per_sec,
				rejection_rate_pct,
				snapshots_per_sec,
				fire_rx,
				fire_applied,
				last_snapshot_tick,
			]
		)
	)

	var is_minute_boundary: bool = uptime_seconds > 0 and uptime_seconds % 60 == 0
	if is_minute_boundary:
		print(
			(
				(
					"[server][sync][cumulative] rx=%d applied=%d snapshots=%d "
					+ "active_tick_calls=%d gate_hits=%d"
				)
				% [
					rx,
					applied,
					snapshots,
					network_gameplay.total_on_server_tick_active_calls,
					network_gameplay.total_snapshot_gate_hits,
				]
			)
		)
	print("")

	_last_log_tick_count = tick_count
	_last_rx = rx
	_last_applied = applied
	_last_snapshots = snapshots
