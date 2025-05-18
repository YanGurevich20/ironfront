class_name TankListItem extends Button

@onready var _tank_image: TextureRect = %TankImage
@onready var _lock_overlay: TextureRect = %LockOverlay
@onready var _price_label: Label = %PriceLabel
@onready var _name_label: Label = %NameLabel

var tank_id: String

func display_tank(tank_spec: TankSpec) -> void:
	print("tank image: ", _tank_image)
	tank_id = tank_spec.id
	_tank_image.texture = tank_spec.preview_texture
	_price_label.text  = str(tank_spec.price) + " $"
	_name_label.text = tank_spec.display_name

func _unlock_tank() -> void:
	_lock_overlay.visible = false
	_price_label.visible = false
