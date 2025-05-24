class_name PenetrationSimulator extends Panel

@onready var shell_texture: TextureRect = $ShellTexture
@onready var armour_texture: ColorRect = $ArmourTexture
@onready var penetration_line: Line2D = $PenetrationLine
@onready var armour_thickness_line_edit: LineEdit = $ArmourThicknessLineEdit
@onready var impact_point_marker: Marker2D = $ImpactPointMarker

const MIN_ARMOUR_THICKNESS_PIXELS: float = 1
const MAX_ARMOUR_THICKNESS_PIXELS: float = 22

const MIN_ARMOUR_THICKNESS_MM: float = 1
const MAX_ARMOUR_THICKNESS_MM: float = 40

func _ready() -> void:
	shell_texture.gui_input.connect(_process_shell_drag)
	display_shell_info(ShellManager.ShellId.M63)

func display_shell_info(shell_id: ShellManager.ShellId) -> void:
	var shell_spec: ShellSpec = ShellManager.SHELL_SPECS[shell_id] 
	shell_texture.texture = shell_spec.base_shell_type.round_texture

func _process_shell_drag(event: InputEvent) -> void:
	print(event)