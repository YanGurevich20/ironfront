class_name BaseShellType extends Resource

enum ShellType{AP, APCR, APDS, APHE, HE, HEAT}
@export var shell_type: ShellType = ShellType.AP
@export var is_kinetic: bool = true
@export var is_tracer: bool = false
@export var is_subcaliber: bool = false
@export var is_explosive_damage: bool = false
@export var subcaliber_ratio: float = 1.0
@export var standard_damage_deviation: float = 0.05

@export var ricochet_angle_soft: float = 45.0
@export var ricochet_angle_hard: float = 50.0
@export var ricochet_ease_curve: float = 2.0 # ease in

@export_category("Textures")
@export var round_texture: Texture2D 
@export var projectile_texture: Texture