class_name ShellSpec extends Resource

@export_category("Physics")
@export var base_shell_type: BaseShellType
@export var muzzle_velocity: float = 600.0
@export var damage: int = 500
@export var penetration: float = 100.0

@export_category("Info")
@export var shell_name: String = "M75"
@export var caliber: int = 75
@export var unlock_cost: int = 10_000

enum ImpactResultType{ PENETRATED, OVERMATCHED, BOUNCED, UNPENETRATED, SHATTERED}

class ImpactResult:
	var damage : int
	var result_type : ImpactResultType
	func _init(_damage: int, _result_type: ImpactResultType) -> void:
		damage = _damage
		result_type = _result_type

const OVERMATCH_RATIO: float = 3.0
const MAX_DAMAGE_MULTIPLIER: float = 1.25
const MIN_DAMAGE_MULTIPLIER: float = 0.25
const CALIBER_DIVISOR: float = 10.0

func get_penetrator_caliber() -> float:
	return caliber * base_shell_type.subcaliber_ratio

func get_should_overmatch(armor_thickness: float) -> bool:
	if not base_shell_type.is_kinetic: return false
	return get_penetrator_caliber() > armor_thickness * OVERMATCH_RATIO

func get_bounce_chance(impact_angle: float) -> float:
	if impact_angle < base_shell_type.ricochet_angle_soft:
		return 0.0
	elif impact_angle < base_shell_type.ricochet_angle_hard:
		var normalized_angle: float = (impact_angle - base_shell_type.ricochet_angle_soft) / (base_shell_type.ricochet_angle_hard - base_shell_type.ricochet_angle_soft)
		return ease(normalized_angle, base_shell_type.ricochet_ease_curve)
	else:
		return 1.0

func get_effective_thickness(impact_angle: float, armor_thickness: float) -> float:
	if impact_angle == 90.0: return INF
	if base_shell_type.is_explosive_damage:
		return armor_thickness
	return armor_thickness / cos(deg_to_rad(impact_angle))

func should_penetrate(impact_angle: float, armor_thickness: float) -> bool:
	if base_shell_type.is_explosive_damage: return penetration > armor_thickness
	var effective_thickness: float = get_effective_thickness(impact_angle, armor_thickness)
	#* Note to self - Edit here if using penetration chance instead of binary decision
	return penetration >= effective_thickness

#* Idea - Subcaliber will benefit from larger armor thickness
func get_damage_roll(penetrated: bool, armour_thickness: float) -> int:
	var rolled_damage: float = Utils.trandfn(damage, damage * base_shell_type.standard_damage_deviation)
	if penetrated:
		return roundi(rolled_damage)
	if base_shell_type.is_explosive_damage:
		return calculate_unpenetrated_explosive_damage(armour_thickness, rolled_damage)
	else:
		return 0

func calculate_unpenetrated_explosive_damage(armour_thickness: float, rolled_damage: float) -> int:
	var caliber_factor: float = caliber / CALIBER_DIVISOR
	var explosion_damage: float = rolled_damage * (caliber_factor / armour_thickness)
	var max_damage: float = explosion_damage * MAX_DAMAGE_MULTIPLIER
	var min_damage: float = explosion_damage * MIN_DAMAGE_MULTIPLIER
	return roundi(clamp(explosion_damage, min_damage, max_damage))

func get_impact_result(impact_angle: float, armor_thickness: float) -> ImpactResult:
	randomize()
	var should_overmatch: bool = get_should_overmatch(armor_thickness)
	var should_bounce: bool = get_bounce_chance(impact_angle) >= randf()
	var penetrated: bool = should_penetrate(impact_angle, armor_thickness)
	var damage_roll: int = get_damage_roll(true if should_overmatch else penetrated, armor_thickness)
	if should_overmatch: return ImpactResult.new(damage_roll, ImpactResultType.OVERMATCHED)
	if should_bounce: return ImpactResult.new(0, ImpactResultType.BOUNCED if base_shell_type.is_kinetic else ImpactResultType.SHATTERED)
	return ImpactResult.new(damage_roll,ImpactResultType.PENETRATED if penetrated else ImpactResultType.UNPENETRATED)
