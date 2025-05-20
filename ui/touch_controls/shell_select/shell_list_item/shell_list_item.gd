class_name ShellListItem extends Control

@export var shell_spec: ShellSpec
@export var amount_left: int

signal shell_pressed(shell_spec: ShellSpec)

@onready var shell_button: Button = %ShellButton
@onready var stats_container: PanelContainer = %StatsContainer
@onready var type_label: Label = %TypeLabel
@onready var amount_left_label: Label = %AmountLeftLabel
@onready var damage_label: Label = %DamageLabel
@onready var penetration_label: Label = %PenetrationLabel
@onready var shell_load_progress_bar: TextureProgressBar = %ShellLoadProgressBar

func _ready() -> void:
	shell_button.icon = shell_spec.base_shell_type.round_texture
	type_label.text = shell_spec.shell_name
	amount_left_label.text = "L: %d" % amount_left
	damage_label.text = "D: %d" % shell_spec.damage
	penetration_label.text = "P: %d" % shell_spec.penetration

	stats_container.hide()
	# Allow the UI to react when this shell button is pressed.
	shell_button.pressed.connect(_on_shell_button_pressed)

func update_progress_bar(progress_left: float) -> void:
	shell_load_progress_bar.value = progress_left

func reset_progress_bar() -> void:
	shell_load_progress_bar.value = 0

func _on_shell_button_pressed() -> void:
	shell_pressed.emit(shell_spec)

func expand(should_expand: bool) -> void:
	stats_container.visible = should_expand
