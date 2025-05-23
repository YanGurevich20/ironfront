class_name ShellListItem extends Control

var shell_id: ShellManager.ShellId
var amount_left: int
var is_expanded: bool = false

signal shell_selected
signal shell_expand_requested

@onready var shell_button: Button = %ShellButton
@onready var stats_container: PanelContainer = %StatsContainer
@onready var type_label: Label = %TypeLabel
@onready var amount_left_label: Label = %AmountLeftLabel
@onready var damage_label: Label = %DamageLabel
@onready var penetration_label: Label = %PenetrationLabel
@onready var shell_load_progress_bar: TextureProgressBar = %ShellLoadProgressBar

func _ready() -> void:
	stats_container.hide()
	shell_button.pressed.connect(_on_shell_button_pressed)

func display_shell(_shell_id: ShellManager.ShellId, amount: int) -> void:
	shell_id = _shell_id
	var shell_spec: ShellSpec = ShellManager.get_shell_spec(shell_id)
	shell_button.icon = shell_spec.base_shell_type.round_texture
	type_label.text = shell_spec.shell_name
	damage_label.text = "D: %d" % shell_spec.damage
	penetration_label.text = "P: %d" % shell_spec.penetration
	update_shell_amount(amount)

func update_progress_bar(progress_left: float) -> void:
	shell_load_progress_bar.value = progress_left

func reset_progress_bar() -> void:
	shell_load_progress_bar.value = 0

func _on_shell_button_pressed() -> void:
	if is_expanded: shell_selected.emit(shell_id)
	else: shell_expand_requested.emit()
func update_shell_amount(amount: int) -> void:
	amount_left = amount
	amount_left_label.text = "L: %d" % amount_left

func update_is_expanded(expand:bool) -> void:
	is_expanded = expand
	stats_container.visible = is_expanded
