class_name PenetrationSimulator extends Control

@onready var shell_texture: TextureRect = %ShellTexture
@onready var armour_texture: ColorRect = %ArmourTexture
@onready var penetration_line: Line2D = %PenetrationLine
@onready var armour_thickness_line_edit: LineEdit = %ArmourThicknessLineEdit
@onready var impact_point_marker: Marker2D = %ImpactPointMarker
@onready var simulate_button: Button = %SimulateButton

@onready var damage_label: Label = %Damage
@onready var result_label: Label = %Result
@onready var angle_label: Label = %Angle
@onready var effective_thickness_label: Label = %Effective
@onready var bounce_chance_label: Label = %Bounce

const MIN_ARMOUR_THICKNESS_PIXELS: float = 1
const MAX_ARMOUR_THICKNESS_PIXELS: float = 24

const MIN_ARMOUR_THICKNESS_MM: float = 1
const MAX_ARMOUR_THICKNESS_MM: float = 500

var armour_thickness_mm: float = 10.0
var shell_spec: ShellSpec = ShellManager.SHELL_SPECS[ShellManager.ShellId.M63_T]
var impact_angle: float = 0.0
var previous_impact_angle: float = 0.0

func _ready() -> void:
	shell_texture.gui_input.connect(func(_event: InputEvent)->void:
		if _event is InputEventScreenDrag: _update_shell_rotation()
	)
	armour_thickness_line_edit.text_submitted.connect(_on_thickness_changed)
	simulate_button.pressed.connect(_update_simulation)

func display_shell_info(shell_id: ShellManager.ShellId) -> void:
	shell_spec = ShellManager.SHELL_SPECS[shell_id]
	shell_texture.texture = shell_spec.base_shell_type.round_texture
	_on_thickness_changed(str(shell_spec.penetration - 1.0))

func _update_shell_rotation() -> void:
	var global_mouse_position: Vector2 = get_global_mouse_position()
	var angle_to_impact_point: float = rad_to_deg(impact_point_marker.global_position.angle_to_point(global_mouse_position))
	var rotated_angle: float = angle_to_impact_point - 90
	var texture_rotation: float
	if rotated_angle > 0.0:
		texture_rotation = -270.0
	elif rotated_angle > -90.0:
		texture_rotation = -90.0
	else:
		texture_rotation = rotated_angle
	shell_texture.rotation_degrees = texture_rotation
	impact_angle = abs(texture_rotation + 180.0)
	if impact_angle != previous_impact_angle:
		previous_impact_angle = impact_angle
		_update_simulation()

func _update_simulation() -> void:
	var effective_thickness := shell_spec.get_effective_thickness(impact_angle, armour_thickness_mm)
	var impact_result := shell_spec.get_impact_result(impact_angle, armour_thickness_mm)
	var damage: float = impact_result.damage
	var result_type: ShellSpec.ImpactResultType = impact_result.result_type
	var result_name := str(ShellSpec.ImpactResultType.find_key(result_type)).capitalize()
	_update_labels(damage, result_name, effective_thickness)
	_update_penetration_line(result_type)

func _on_thickness_changed(new_text: String) -> void:
	var clamped_thickness: float = clamp(float(new_text), MIN_ARMOUR_THICKNESS_MM, MAX_ARMOUR_THICKNESS_MM)
	armour_thickness_mm = clamped_thickness
	armour_thickness_line_edit.text = str(armour_thickness_mm)
	var thickness_ratio: float = armour_thickness_mm / MAX_ARMOUR_THICKNESS_MM
	armour_texture.size.y = clamp(MAX_ARMOUR_THICKNESS_PIXELS * thickness_ratio, MIN_ARMOUR_THICKNESS_PIXELS, MAX_ARMOUR_THICKNESS_PIXELS)
	_update_simulation()

func _update_labels(damage: float, result_name: String, effective_thickness: float) -> void:
	damage_label.text = "DAMAGE: %d HP" % damage
	result_label.text = "RESULT: " + result_name
	angle_label.text = "ANGLE: %0.2f°" % impact_angle
	effective_thickness_label.text = "EFFECTIVE THICKNESS: %0.2f mm" % effective_thickness
	var bounce_chance_string: String = "%0.1f" % (shell_spec.get_bounce_chance(impact_angle)*100.0) + "%"
	bounce_chance_label.text = "BOUNCE CHANCE: " + ("0% (Overmatched)"  if result_name == "Overmatched" else bounce_chance_string)

const PENETRATION_LINE_COLORS: Dictionary = {
	ShellSpec.ImpactResultType.PENETRATED: Color.GREEN,
	ShellSpec.ImpactResultType.OVERMATCHED: Color.BLUE,
	ShellSpec.ImpactResultType.BOUNCED: Color.RED,
	ShellSpec.ImpactResultType.UNPENETRATED: Color.RED,
	ShellSpec.ImpactResultType.SHATTERED: Color.RED,
}

func _update_penetration_line(result_type: ShellSpec.ImpactResultType) -> void:
	penetration_line.modulate = PENETRATION_LINE_COLORS[result_type]
