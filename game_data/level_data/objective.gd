class_name Objective extends Resource

const OP_TEXTS: Dictionary[String, String] = {
	"=": "equal to",
	"!=": "not equal to",
	">": "more than",
	">=": "at least",
	"<": "less than",
	"<=": "at most"
}

@export var description: String
@export var metric: Metrics.Metric = Metrics.Metric.KILLS
@export_enum("=", "!=", ">=", ">", "<=", "<") var operator: String = "="
@export var required_value: int = 0
@export var score_value: int = 100

var is_complete: bool = false
var current_value: int = 0


func _check_operator_validity() -> void:
	if operator in [">", "<"] and required_value == 0:
		push_warning("objective required value should not be 0 for < or > operators")


func evaluate(stat_value: int) -> void:
	_check_operator_validity()
	current_value = stat_value
	is_complete = Utils.operate(stat_value, operator, required_value)


func get_progress_ratio() -> float:
	if operator in ["=", "!="]:
		return 1.0 if is_complete else 0.0
	if required_value == 0:
		return 1.0 if is_complete else 0.0
	var ratio: float = 0.0
	match operator:
		">", ">=":
			ratio = float(current_value) / required_value
		"<", "<=":
			ratio = 1.0 - float(current_value) / required_value
		_:
			return 0.0
	if is_complete:
		return 1.0
	return clamp(ratio, 0.0, 0.99)


func generate_description() -> String:
	var metric_name := str(Metrics.Metric.find_key(metric)).capitalize()
	var op_text := OP_TEXTS[operator]
	var generated_description := (
		"%s %s %d (%d)" % [metric_name, op_text, required_value, current_value]
	)
	return generated_description.capitalize()
