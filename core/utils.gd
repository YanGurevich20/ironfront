class_name Utils

const PIXELS_PER_METER: int = 10

static var operators: Dictionary[String,Callable] = {
	"=": func(a: Variant,b: Variant) -> bool: return a==b,
	"!=": func(a: Variant,b: Variant) -> bool: return a!=b,
	"<": func(a: Variant,b: Variant) -> bool: return a<b,
	"<=": func(a: Variant,b: Variant) -> bool: return a<=b,
	">": func(a: Variant,b: Variant) -> bool: return a>b,
	">=": func(a: Variant,b: Variant) -> bool: return a>=b
}

static func operate(a: Variant, operator: String, b: Variant) -> bool:
	return operators[operator].call(a,b)

static func format_seconds(seconds: float) -> String:
	var mins: int = int(seconds / 60)
	var secs: int = int(seconds) % 60
	return "%02d:%02d" % [mins, secs]

static func show_nodes(nodes: Array[Control]) -> void:
	for n in nodes:
		n.visible = true

static func hide_nodes(nodes: Array[Control]) -> void:
	for n in nodes:
		n.visible = false
