extends CanvasLayer
class_name UIManager
#region Node Setup
# === Nodes ===
@onready var tank_control      : Control         = $TankControl
@onready var game_control      : Control         = $GameControl
@onready var main_menu         : Control         = $MainMenu
@onready var pause_overlay     : PauseOverlay    = $PauseOverlay
@onready var result_overlay    : ResultOverlay   = $ResultOverlay
@onready var settings_overlay  : SettingsOverlay = $SettingsOverlay
@onready var metrics_overlay   : MetricsOverlay  = $MetricsOverlay

# === Callables ===
var fetch_metrics_callable: Callable

# === Signals ===
signal pause_game
signal resume_game
signal start_level(level: int)
signal restart_level
signal abort_level
signal return_to_menu
signal quit_game
signal reset_player_metrics_pressed
signal reset_game_progress_pressed
# === Groups ===
var _menu_nodes     : Array[Control]
var _control_nodes  : Array[Control]
var _overlay_nodes  : Array[Control]
#endregion

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_nodes = [ main_menu ]
	_control_nodes = [ tank_control, game_control ]
	_overlay_nodes = [ pause_overlay, result_overlay, settings_overlay, metrics_overlay ]
	_connect_signals()
	show_menu()

#region Public functions
func setup(game: Game) -> void:
	fetch_metrics_callable = game.fetch_metrics
	main_menu.fetch_levels_callable        = game.fetch_levels
	main_menu.fetch_level_stars_callable   = game.fetch_level_stars

func show_menu() -> void:
	_hide_all()
	Utils.show_nodes(_menu_nodes)

func show_game_ui() -> void:
	_hide_all()
	Utils.show_nodes(_control_nodes)

func show_overlay(overlay: Control) -> void:
	if main_menu.visible:
		Utils.show_nodes(_menu_nodes)
	else:
		Utils.show_nodes(_control_nodes)
	Utils.hide_nodes(_overlay_nodes)
	overlay.visible = true

func hide_overlays() -> void:
	Utils.hide_nodes(_overlay_nodes)

func display_result(success: bool, metrics: Dictionary, objectives: Array) -> void:
	result_overlay.display_result(success, metrics, objectives)
	show_overlay(result_overlay)

func refresh_levels()->void:
	main_menu.refresh_level_buttons()

func reset_input() -> void:
	tank_control.reset_input()

func update_objectives(objectives: Array) -> void:
	pause_overlay.set_objectives(objectives)

#endregion
#region Signal handlers
func _on_metrics_pressed()-> void:
	var metrics :Dictionary= fetch_metrics_callable.call()
	metrics_overlay.display_metrics(metrics)
	show_overlay(metrics_overlay)

func _on_level_pressed(level: int) -> void:
	show_game_ui()
	start_level.emit(level)

func _on_pause_pressed() -> void:
	show_overlay(pause_overlay)
	pause_game.emit()

func _on_resume_pressed() -> void:
	hide_overlays()
	resume_game.emit()

func _on_settings_pressed() -> void:
	show_overlay(settings_overlay)

func _on_exit_settings_pressed() -> void:
	hide_overlays()

func _on_close_settings_pressed() -> void:
	settings_overlay.visible = false

func _on_return_pressed() -> void:
	show_menu()
	return_to_menu.emit()

func _on_retry_pressed() -> void:
	hide_overlays()
	restart_level.emit()

func _on_quit_pressed() -> void:
	quit_game.emit()

func _on_abort_pressed() -> void:
	hide_overlays()
	abort_level.emit()

#endregion
#region Helpers
func _connect_signals() -> void:
	main_menu.level_pressed.connect(_on_level_pressed)
	main_menu.settings_pressed.connect(_on_settings_pressed)
	main_menu.metrics_pressed.connect(_on_metrics_pressed)
	main_menu.quit_game_pressed.connect(_on_quit_pressed)

	game_control.pause_pressed.connect(_on_pause_pressed)

	pause_overlay.exit_overlay_pressed.connect(_on_resume_pressed)
	pause_overlay.settings_pressed.connect(_on_settings_pressed)
	pause_overlay.abort_pressed.connect(_on_abort_pressed)

	result_overlay.exit_overlay_pressed.connect(_on_return_pressed)
	result_overlay.retry_pressed.connect(_on_retry_pressed)

	settings_overlay.exit_overlay_pressed.connect(_on_exit_settings_pressed)
	settings_overlay.reset_player_metrics_pressed.connect(func()->void:reset_player_metrics_pressed.emit())
	settings_overlay.reset_game_progress_pressed.connect(func()->void:reset_game_progress_pressed.emit())

	metrics_overlay.exit_overlay_pressed.connect(hide_overlays)

func _hide_all() -> void:
	Utils.hide_nodes(_menu_nodes)
	Utils.hide_nodes(_control_nodes)
	Utils.hide_nodes(_overlay_nodes)
#endregion
