class_name ShellListItem extends Control

@export var shell_spec: ShellSpec
@export var amount_left: int

@export var is_expanded: bool = false:
	set(value):
		is_expanded = value
		stats_container.visible = is_expanded

@onready var shell_button: Button = %ShellButton
@onready var stats_container: PanelContainer = %StatsContainer
@onready var type_label: Label = %TypeLabel
@onready var amount_left_label: Label = %AmountLeftLabel
@onready var damage_label: Label = %DamageLabel
@onready var penetration_label: Label = %PenetrationLabel

func _ready() -> void:
	var base_shell_type: BaseShellType = shell_spec.base_shell_type
	shell_button.icon = base_shell_type.round_texture
	type_label.text = BaseShellType.ShellType.find_key(base_shell_type.shell_type)
	amount_left_label.text = "L: " + str(amount_left)
	damage_label.text = "D: " + str(shell_spec.damage)
	penetration_label.text = "P: " + str(shell_spec.penetration)

	stats_container.hide()
