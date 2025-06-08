class_name ShellInfoOverlay  extends BaseOverlay

@onready var penetration_simulator: PenetrationSimulator = %PenetrationSimulator
@onready var shell_stats_label: Label = %ShellStats
@onready var base_shell_stats_label: Label = %BaseShellStats

func _ready() -> void:
	super._ready()
	display_shell_info(ShellManager.ShellId.PZGR40)

func display_shell_info(shell_id: ShellManager.ShellId) -> void:
	if not is_inside_tree():
		push_warning("ShellInfoOverlay not inside tree")
	var shell_spec: ShellSpec = ShellManager.SHELL_SPECS[shell_id]
	penetration_simulator.display_shell_info(shell_id)
	_update_shell_stats(shell_spec)
	_update_base_shell_stats(shell_spec)

func _update_shell_stats(shell_spec: ShellSpec) -> void:
	var text: String = ""
	text += "Shell: %s\n" % shell_spec.shell_name
	text += _get_flag_text(shell_spec) + "\n"
	if shell_spec.base_shell_type.is_tracer: text +="Tracer\n"
	var shell_type_name: String = BaseShellType.ShellType.find_key(shell_spec.base_shell_type.shell_type)
	text += "Shell Type: %s\n" % shell_type_name
	text += "Caliber: %0.1f mm\n" % shell_spec.caliber
	if shell_spec.base_shell_type.is_subcaliber:
		text += "Penetrator Caliber: %0.1f mm\n" % shell_spec.get_penetrator_caliber()
	text += "Unlock Cost: %s\n" % Utils.format_dollars(shell_spec.unlock_cost)
	shell_stats_label.text = text

func _update_base_shell_stats(shell_spec: ShellSpec) -> void:
	var min_ricochet_angle: float = shell_spec.base_shell_type.ricochet_angle_soft
	var max_ricochet_angle: float = shell_spec.base_shell_type.ricochet_angle_hard
	var text: String = ""
	text += "Muzzle Velocity: %0.2f px/s\n" % shell_spec.muzzle_velocity
	text += "Ricochet Angle: %0.1f° - %0.1f°\n" % [min_ricochet_angle, max_ricochet_angle]
	var min_damage: int = int(shell_spec.damage * (1 - shell_spec.base_shell_type.standard_damage_deviation))
	var max_damage: int = int(shell_spec.damage * (1 + shell_spec.base_shell_type.standard_damage_deviation))
	text += "Damage range: %d - %d\n" % [min_damage, max_damage]
	text += "Penetration: %0.2f mm\n" % shell_spec.penetration
	base_shell_stats_label.text = text

func _get_flag_text(shell_spec: ShellSpec) -> String:
	var flag_text: String = ""
	flag_text += "Kinetic, " if shell_spec.base_shell_type.is_kinetic else "Non-Kinetic, "
	if shell_spec.base_shell_type.is_subcaliber: flag_text += "Subcaliber, "
	if shell_spec.base_shell_type.is_explosive_damage: flag_text += "Explosive Damage, "
	return flag_text.trim_suffix(", ")
