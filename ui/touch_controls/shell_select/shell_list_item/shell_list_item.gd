class_name ShellListItem extends Control
var shell_spec: ShellSpec

@onready var shell_button: Button = %ShellButton
@onready var stats_container: PanelContainer = %StatsContainer
@onready var stats_label: Label = %StatsLabel
@onready var shell_load_progress_bar: TextureProgressBar = %ShellLoadProgressBar

signal shell_selected(shell_spec: ShellSpec)
signal shell_expand_requested()

var shell_amount: int
var is_expanded: bool = false

func _ready() -> void:
	stats_container.hide()
	shell_button.pressed.connect(_on_shell_button_pressed)

func display_shell(_shell_spec: ShellSpec) -> void:
	shell_spec = _shell_spec
	shell_button.icon = shell_spec.base_shell_type.round_texture

func reset_progress_bar() -> void:
	shell_load_progress_bar.value = 0

func _on_shell_button_pressed() -> void:
	if is_expanded: shell_selected.emit(shell_spec)
	else: shell_expand_requested.emit()

func update_shell_amount(amount: int) -> void:
	if amount == 0:
		shell_button.disabled = true
	shell_amount = amount
	update_stats_label(shell_amount)

func update_is_expanded(expand:bool) -> void:
	is_expanded = expand
	stats_container.visible = is_expanded

func update_progress_bar(progress: float) -> void:
	if shell_amount == 0: return
	shell_load_progress_bar.value = 1-progress

func update_stats_label(_amount_left: int) -> void:
	shell_amount = _amount_left
	var text: String = ""
	text += "D: %d\n" % shell_spec.damage
	text += "P: %d\n" % shell_spec.penetration
	text += "L: %d" % shell_amount
	stats_label.text = text
