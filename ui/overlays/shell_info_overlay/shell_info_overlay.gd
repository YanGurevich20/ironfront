class_name ShellInfoOverlay
extends BaseOverlay

@export var default_shell_spec: ShellSpec

var current_shell_spec: ShellSpec

@onready var penetration_simulator: PenetrationSimulator = %PenetrationSimulator
@onready var basic_stats_label: Label = %BasicStats
@onready var shell_stats_label: Label = %ShellStats
@onready var base_shell_stats_label: Label = %BaseShellStats
@onready var advanced_info_button: Button = %AdvancedInfoButton
@onready var penetration_simulator_button: Button = %PenetrationSimulatorButton
@onready var advanced_info_section: BaseSection = %AdvancedInfoSection
@onready var penetration_simulator_section: BaseSection = %PenetrationSimulatorSection
@onready var shell_root_section: BaseSection = %RootSection


func _ready() -> void:
	super._ready()
	_setup_navigation()


func _setup_navigation() -> void:
	Utils.connect_checked(advanced_info_button.pressed, _show_advanced_info_section)
	Utils.connect_checked(penetration_simulator_button.pressed, _show_penetration_simulator_section)
	Utils.connect_checked(shell_root_section.back_pressed, _on_section_back_pressed)
	Utils.connect_checked(advanced_info_section.back_pressed, _on_section_back_pressed)
	Utils.connect_checked(penetration_simulator_section.back_pressed, _on_section_back_pressed)


func display_shell_info(shell_spec: ShellSpec) -> void:
	if not is_inside_tree():
		push_warning("ShellInfoOverlay not inside tree")
		return

	current_shell_spec = shell_spec
	penetration_simulator.display_shell_info(shell_spec)
	_update_basic_stats(shell_spec)
	_update_shell_stats(shell_spec)
	_update_base_shell_stats(shell_spec)
	_show_root_section()


func _show_root_section() -> void:
	shell_root_section.visible = true
	advanced_info_section.visible = false
	penetration_simulator_section.visible = false


func _show_advanced_info_section() -> void:
	shell_root_section.visible = false
	advanced_info_section.visible = true
	penetration_simulator_section.visible = false


func _show_penetration_simulator_section() -> void:
	shell_root_section.visible = false
	advanced_info_section.visible = false
	penetration_simulator_section.visible = true


func _on_section_back_pressed(is_root_section: bool) -> void:
	if is_root_section:
		exit_overlay_pressed.emit()
		return
	_show_root_section()


func _update_basic_stats(shell_spec: ShellSpec) -> void:
	var text: String = ""
	text += "Shell: %s\n" % shell_spec.shell_name
	var min_damage: int = int(
		shell_spec.damage * (1 - shell_spec.base_shell_type.standard_damage_deviation)
	)
	var max_damage: int = int(
		shell_spec.damage * (1 + shell_spec.base_shell_type.standard_damage_deviation)
	)
	text += "Damage: %d - %d HP\n" % [min_damage, max_damage]
	text += "Penetration: %0.1f mm\n" % shell_spec.penetration
	text += "Muzzle Velocity: %0.1f px/s" % shell_spec.muzzle_velocity
	basic_stats_label.text = text


func _update_shell_stats(shell_spec: ShellSpec) -> void:
	var text: String = ""
	var shell_type_name: String = BaseShellType.ShellType.find_key(
		shell_spec.base_shell_type.shell_type
	)
	text += "Shell Type: %s\n" % shell_type_name
	text += "Caliber: %0.1f mm\n" % shell_spec.caliber
	if shell_spec.base_shell_type.is_subcaliber:
		text += "Penetrator Caliber: %0.1f mm\n" % shell_spec.get_penetrator_caliber()
	text += "Unlock Cost: %s\n" % Utils.format_dollars(shell_spec.unlock_cost)
	text += "Flags: %s" % _get_flag_text(shell_spec)
	shell_stats_label.text = text


func _update_base_shell_stats(shell_spec: ShellSpec) -> void:
	var min_ricochet_angle: float = shell_spec.base_shell_type.ricochet_angle_soft
	var max_ricochet_angle: float = shell_spec.base_shell_type.ricochet_angle_hard
	var text: String = ""
	text += "Ricochet Angle: %0.1f° - %0.1f°\n" % [min_ricochet_angle, max_ricochet_angle]
	var min_damage: int = int(
		shell_spec.damage * (1 - shell_spec.base_shell_type.standard_damage_deviation)
	)
	var max_damage: int = int(
		shell_spec.damage * (1 + shell_spec.base_shell_type.standard_damage_deviation)
	)
	text += "Damage Range: %d - %d HP\n" % [min_damage, max_damage]
	text += "Tracer: %s" % ("Yes" if shell_spec.base_shell_type.is_tracer else "No")
	base_shell_stats_label.text = text


func _get_flag_text(shell_spec: ShellSpec) -> String:
	var flag_text: String = ""
	flag_text += "Kinetic, " if shell_spec.base_shell_type.is_kinetic else "Non-Kinetic, "
	if shell_spec.base_shell_type.is_subcaliber:
		flag_text += "Subcaliber, "
	if shell_spec.base_shell_type.is_explosive_damage:
		flag_text += "Explosive Damage, "
	return flag_text.trim_suffix(", ")
