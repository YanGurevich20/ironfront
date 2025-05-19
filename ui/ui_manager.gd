extends CanvasLayer
class_name UIManager
#region Node Setup
# === Nodes ===
@onready var tank_control	: Control         = $TankControl
@onready var game_control	: Control         = $GameControl
@onready var garage : Garage          = $Garage
@onready var login_menu : Control         = $LoginMenu
@onready var pause_overlay: PauseOverlay    = $PauseOverlay
@onready var result_overlay    : ResultOverlay   = $ResultOverlay
@onready var settings_overlay  : SettingsOverlay = $SettingsOverlay
@onready var metrics_overlay   : MetricsOverlay  = $MetricsOverlay
@onready var garage_menu_overlay : GarageMenuOverlay = $GarageMenuOverlay


# === Signals ===
signal pause_game
signal resume_game
signal start_level(level: int)
signal restart_level
signal abort_level
signal return_to_menu
signal quit_game
# === Groups ===
var _menu_nodes     : Array[Control]
var _control_nodes  : Array[Control]
var _overlay_nodes  : Array[Control]
#endregion

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_nodes = [ login_menu, garage ]
	_control_nodes = [ tank_control, game_control ]
	_overlay_nodes = [ pause_overlay, result_overlay, settings_overlay, metrics_overlay, garage_menu_overlay ]
	_connect_signals()
	show_login_menu()

#region Public functions
func setup(game: Game) -> void:
	garage.fetch_levels_callable = game.fetch_levels
	garage.fetch_level_stars_callable = game.fetch_level_stars

func show_login_menu() -> void:
	_hide_all()
	login_menu.visible = true

func show_garage() -> void:
	_hide_all()
	garage.visible = true

func show_game_ui() -> void:
	_hide_all()
	Utils.show_nodes(_control_nodes)

func show_overlay(overlay: Control) -> void:
	if login_menu.visible:
		login_menu.visible = true
	elif garage.visible:
		garage.visible = true
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
	if garage.has_method("refresh_level_buttons"):
		garage.refresh_level_buttons()

func reset_input() -> void:
	tank_control.reset_input()

func update_objectives(objectives: Array) -> void:
	pause_overlay.set_objectives(objectives)

#endregion
#region Signal handlers
func _on_metrics_pressed()->void:
	var metrics :Dictionary= LoadableData.get_instance(Metrics).metrics
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
	show_garage()
	return_to_menu.emit()

func _on_retry_pressed() -> void:
	hide_overlays()
	restart_level.emit()

func _on_quit_pressed() -> void:
	quit_game.emit()

func _on_abort_pressed() -> void:
	hide_overlays()
	abort_level.emit()

func _on_play_pressed() -> void:
	show_garage()

func _on_garage_menu_pressed() -> void:
	show_overlay(garage_menu_overlay)

#endregion
#region Helpers
func _connect_signals() -> void:
	login_menu.play_pressed.connect(_on_play_pressed)
	login_menu.login_pressed.connect(func()->void: print("Login pressed - functionality to be implemented"))

	garage.garage_menu_pressed.connect(_on_garage_menu_pressed)
	garage.level_pressed.connect(_on_level_pressed)

	game_control.pause_pressed.connect(_on_pause_pressed)

	pause_overlay.exit_overlay_pressed.connect(_on_resume_pressed)
	pause_overlay.settings_pressed.connect(_on_settings_pressed)
	pause_overlay.abort_pressed.connect(_on_abort_pressed)

	result_overlay.exit_overlay_pressed.connect(_on_return_pressed)
	result_overlay.retry_pressed.connect(_on_retry_pressed)

	settings_overlay.exit_overlay_pressed.connect(_on_exit_settings_pressed)
	
	metrics_overlay.exit_overlay_pressed.connect(hide_overlays)

	garage_menu_overlay.exit_overlay_pressed.connect(hide_overlays)
	garage_menu_overlay.settings_pressed.connect(_on_settings_pressed)
	garage_menu_overlay.metrics_pressed.connect(_on_metrics_pressed)

func _hide_all() -> void:
	Utils.hide_nodes(_menu_nodes)
	Utils.hide_nodes(_control_nodes)
	Utils.hide_nodes(_overlay_nodes)
#endregion
