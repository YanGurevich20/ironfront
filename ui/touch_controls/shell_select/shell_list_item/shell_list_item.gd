class_name ShellListItem extends Control

var shell_id: ShellManager.ShellId
var amount_left: int
var is_expanded: bool = false

signal shell_selected
signal shell_expand_requested

@onready var shell_button: Button = %ShellButton
@onready var stats_container: PanelContainer = %StatsContainer
@onready var stats_label: Label = %StatsLabel
@onready var shell_load_progress_bar: TextureProgressBar = %ShellLoadProgressBar

func _ready() -> void:
	stats_container.hide()
	shell_button.pressed.connect(_on_shell_button_pressed)

func display_shell(_shell_id: ShellManager.ShellId) -> void:
	shell_id = _shell_id
	var shell_spec: ShellSpec = ShellManager.SHELL_SPECS[shell_id]
	shell_button.icon = shell_spec.base_shell_type.round_texture
	update_stats_label(amount_left)

func reset_progress_bar() -> void:
	shell_load_progress_bar.value = 0

func _on_shell_button_pressed() -> void:
	if is_expanded: shell_selected.emit(shell_id)
	else: shell_expand_requested.emit()

func update_shell_amount(amount: int) -> void:
	if amount == 0:
		shell_button.disabled = true
	amount_left = amount
	update_stats_label(amount_left)

func update_is_expanded(expand:bool) -> void:
	is_expanded = expand
	stats_container.visible = is_expanded

func update_progress_bar(progress: float) -> void:
	if amount_left == 0: return
	shell_load_progress_bar.value = 1-progress

func update_stats_label(_amount_left: int) -> void:
	amount_left = _amount_left
	var shell_spec: ShellSpec = ShellManager.SHELL_SPECS[shell_id]
	var text: String = ""
	text += "D: %d\n" % shell_spec.damage
	text += "P: %d\n" % shell_spec.penetration
	text += "L: %d" % amount_left
	stats_label.text = text