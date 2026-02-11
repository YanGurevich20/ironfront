class_name ShellListItem
extends Control

signal shell_selected(shell_spec: ShellSpec)

signal shell_expand_requested

const DAMAGE_COLOR_HEX: String = "ff4d4d"
const PENETRATION_COLOR_HEX: String = "4da3ff"

var shell_spec: ShellSpec
var shell_amount: int
var is_expanded: bool = false

@onready var shell_button: Button = %ShellButton
@onready var count_label: Label = %CountLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var shell_load_progress_bar: TextureProgressBar = %ShellLoadProgressBar


func _ready() -> void:
	stats_label.hide()
	Utils.connect_checked(shell_button.pressed, _on_shell_button_pressed)


func display_shell(shell_spec_input: ShellSpec) -> void:
	shell_spec = shell_spec_input
	shell_button.icon = shell_spec.base_shell_type.round_texture


func reset_progress_bar() -> void:
	shell_load_progress_bar.value = 0


func _on_shell_button_pressed() -> void:
	if is_expanded:
		shell_selected.emit(shell_spec)
	else:
		shell_expand_requested.emit()


func update_shell_amount(amount: int) -> void:
	shell_button.disabled = amount == 0
	shell_amount = amount
	update_stats_label(shell_amount)


func update_is_expanded(expand: bool) -> void:
	is_expanded = expand
	stats_label.visible = is_expanded


func update_progress_bar(progress: float) -> void:
	if shell_amount == 0:
		return
	shell_load_progress_bar.value = 1 - progress


func update_stats_label(amount_left: int) -> void:
	shell_amount = amount_left
	count_label.text = str(shell_amount)
	stats_label.text = (
		"[center][color=#%s]%d[/color]\n[color=#%s]%d[/color][/center]"
		% [
			DAMAGE_COLOR_HEX,
			shell_spec.damage,
			PENETRATION_COLOR_HEX,
			roundi(shell_spec.penetration)
		]
	)
