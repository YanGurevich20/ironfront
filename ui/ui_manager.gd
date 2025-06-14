extends CanvasLayer
class_name UIManager
#region Node Setup
# === Nodes ===
@onready var tank_control	: TankControl = $TankControl
@onready var garage : Garage = $Garage
@onready var login_menu : Control = $LoginMenu
@onready var pause_overlay: PauseOverlay = $PauseOverlay
@onready var result_overlay: ResultOverlay = $ResultOverlay
@onready var settings_overlay: SettingsOverlay = $SettingsOverlay
@onready var metrics_overlay: MetricsOverlay = $MetricsOverlay
@onready var garage_menu_overlay: GarageMenuOverlay = $GarageMenuOverlay
@onready var level_select_overlay: LevelSelectOverlay = $LevelSelectOverlay
@onready var shell_info_overlay: ShellInfoOverlay = $ShellInfoOverlay

# === Signals ===
signal resume_game
signal restart_level
signal abort_level
signal return_to_menu
signal log_out_pressed

# === Groups ===
var _menu_nodes     : Array[Control]
var _control_nodes  : Array[Control]
var _overlay_nodes  : Array[Control]
#endregion

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_nodes = [ login_menu, garage ]
	_control_nodes = [ tank_control ]
	_overlay_nodes = [ pause_overlay, result_overlay, settings_overlay, metrics_overlay, garage_menu_overlay, level_select_overlay, shell_info_overlay ]
	_connect_signals()
	show_menu(login_menu)

#region Public functions
func show_menu(menu: Control) -> void:
	_hide_all()
	menu.visible = true

func show_game_ui() -> void:
	_hide_all()
	Utils.show_nodes(_control_nodes)
	tank_control.display_controls()

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
	# TODO: temporary fix for sub-menu back press.
	resume_game.emit()

func display_result(success: bool, metrics: Dictionary, objectives: Array, reward_info: Game.RewardInfo) -> void:
	result_overlay.display_result(success, metrics, objectives, reward_info)
	show_overlay(result_overlay)

func reset_input() -> void:
	tank_control.reset_input()

func update_objectives(objectives: Array) -> void:
	pause_overlay.set_objectives(objectives)

#endregion
#region Signal handlers
func _on_play_pressed() -> void:
	show_overlay(level_select_overlay)
	level_select_overlay.display_levels()

func _on_shell_info_requested(shell_spec: ShellSpec) -> void:
	shell_info_overlay.display_shell_info(shell_spec)
	show_overlay(shell_info_overlay)

func _on_metrics_pressed()->void:
	var metrics := Metrics.get_instance().metrics
	metrics_overlay.display_metrics(metrics)
	show_overlay(metrics_overlay)

func _on_level_started() -> void:
	show_game_ui()

func _on_pause_pressed() -> void:
	show_overlay(pause_overlay)

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
	show_menu(garage)
	return_to_menu.emit()

func _on_retry_pressed() -> void:
	print("retry pressed ui manager")
	hide_overlays()
	restart_level.emit()

func _on_abort_pressed() -> void:
	hide_overlays()
	abort_level.emit()

func _on_login_pressed() -> void:
	show_menu(garage)

func _on_log_out_pressed() -> void:
	show_menu(login_menu)

func _on_garage_menu_pressed() -> void:
	show_overlay(garage_menu_overlay)

#endregion
#region Helpers
func _connect_signals() -> void:
	#* login menu *#
	SignalBus.login_pressed.connect(_on_login_pressed)

	#* garage menu *#
	SignalBus.play_pressed.connect(_on_play_pressed)
	SignalBus.shell_info_requested.connect(_on_shell_info_requested)
	garage.garage_menu_pressed.connect(_on_garage_menu_pressed)
	garage_menu_overlay.exit_overlay_pressed.connect(hide_overlays)
	garage_menu_overlay.settings_pressed.connect(_on_settings_pressed)
	garage_menu_overlay.metrics_pressed.connect(_on_metrics_pressed)

	#* garage menu overlay *#
	SignalBus.log_out_pressed.connect(_on_log_out_pressed)

	#* level select overlay *#
	SignalBus.level_started.connect(_on_level_started)
	level_select_overlay.exit_overlay_pressed.connect(hide_overlays)

	#* shell info overlay *#
	shell_info_overlay.exit_overlay_pressed.connect(hide_overlays)
 
	#* tank controls *#
	SignalBus.pause_input.connect(_on_pause_pressed)

	#* pause overlay *#
	pause_overlay.exit_overlay_pressed.connect(_on_resume_pressed)
	pause_overlay.settings_pressed.connect(_on_settings_pressed)
	pause_overlay.abort_pressed.connect(_on_abort_pressed)

	#* result overlay *#
	result_overlay.exit_overlay_pressed.connect(_on_return_pressed)
	result_overlay.retry_pressed.connect(_on_retry_pressed)

	#* settings overlay *#
	settings_overlay.exit_overlay_pressed.connect(_on_exit_settings_pressed)

	#* metrics overlay *#
	metrics_overlay.exit_overlay_pressed.connect(hide_overlays)

func _hide_all() -> void:
	Utils.hide_nodes(_menu_nodes)
	Utils.hide_nodes(_control_nodes)
	Utils.hide_nodes(_overlay_nodes)
#endregion
