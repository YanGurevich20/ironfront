class_name BaseShellType extends Resource

enum ShellType{AP, APCR, APDS, APHE, HE, HEAT}
@export var shell_type: ShellType = ShellType.AP
@export var is_kinetic: bool = true
@export var is_tracer: bool = false
@export var ricochet_angle_soft: float = 45.0
@export var ricochet_angle_hard: float = 50.0
@export var round_texture: Texture2D 
@export var projectile_texture: Texture
 