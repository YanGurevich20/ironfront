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
@export var resupply_cost: int = 200

enum ImpactResultType{
	PENETRATED,
	BOUNCED,
	UNPENETRATED,
	SHATTERED,
}

enum ImpactResult{
	DAMAGE,
	RESLT_TYPE
}

const CALIBER_DIVISOR: float = 100.0
const ARMOR_DIVISOR: float = 100.0
const MAX_DAMAGE_MULTIPLIER: float = 0.25
const MIN_DAMAGE_MULTIPLIER: float = 0.01

func get_bounce_chance(impact_angle: float, armor_thickness: float) -> float:
	var penetrator_caliber: float = caliber * base_shell_type.subcaliber_ratio
	if penetrator_caliber * 3 > armor_thickness and base_shell_type.is_kinetic:
		return 0.0
	if impact_angle < base_shell_type.ricochet_angle_soft:
		return 0.0
	elif impact_angle < base_shell_type.ricochet_angle_hard:
		var normalized_angle: float = (impact_angle - base_shell_type.ricochet_angle_soft) / (base_shell_type.ricochet_angle_hard - base_shell_type.ricochet_angle_soft)
		return ease(normalized_angle, base_shell_type.ricochet_ease_curve)
	else:
		return 1.0

func should_penetrate(impact_angle: float, armor_thickness: float) -> bool:
	var penetrator_caliber: float = caliber * base_shell_type.subcaliber_ratio
	if penetrator_caliber * 3 > armor_thickness and base_shell_type.is_kinetic:
		return true
	var effective_thickness: float = armor_thickness / cos(impact_angle)
	#* Note to self - Edit here if using penetration chance instead of binary decision
	return penetration >= effective_thickness

#* Idea - Subcaliber will benefit from larger armor thickness
func get_damage_roll(penetrated: bool, armour_thickness: float) -> float:
	randomize()
	var rolled_damage: float = randfn(damage, base_shell_type.standard_damage_deviation)
	if penetrated:
		return rolled_damage
	if base_shell_type.is_explosive_damage:
		return calculate_unpenetrated_explosive_damage(armour_thickness)
	else:
		return 0

func calculate_unpenetrated_explosive_damage(armour_thickness: float) -> float:
	var caliber_factor: float = caliber / CALIBER_DIVISOR
	var armor_factor: float = armour_thickness / ARMOR_DIVISOR + 1.0
	var explosion_damage: float = damage * (caliber_factor / armor_factor)
	var max_damage: float = explosion_damage * MAX_DAMAGE_MULTIPLIER
	var min_damage: float = explosion_damage * MIN_DAMAGE_MULTIPLIER
	return clamp(explosion_damage, min_damage, max_damage)

func get_impact_result(impact_angle: float, armor_thickness: float) -> Dictionary[ImpactResult, float]:
	var should_bounce: bool = get_bounce_chance(impact_angle, armor_thickness) < 0.5
	if should_bounce:
		return {
			ImpactResult.DAMAGE: 0,
			ImpactResult.RESLT_TYPE: ImpactResultType.SHATTERED if base_shell_type.is_kinetic else ImpactResultType.BOUNCED,
		}
	var penetrated: bool = should_penetrate(impact_angle, armor_thickness)
	var damage_roll: float = get_damage_roll(penetrated, armor_thickness)
	return {
		ImpactResult.DAMAGE: damage_roll,
		ImpactResult.RESLT_TYPE: ImpactResultType.PENETRATED if penetrated else ImpactResultType.UNPENETRATED,
	}