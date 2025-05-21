class_name ShellSpec extends Resource

@export_category("Physics")
@export var base_shell_type: BaseShellType
@export var muzzle_velocity: float = 600.0
@export var damage: int = 500
@export var penetration: float = 100.0
@export var explosive_yield: float = 0.0

@export_category("Info")
@export var shell_name: String = "M75"
@export var caliber: int = 75
@export var unlock_cost: int = 10_000
@export var resupply_cost: int = 200