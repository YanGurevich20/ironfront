class_name TankListItem extends Button
var tank_id: TankManager.TankId
var tank_price: int = 0
@onready var _tank_image: TextureRect = %TankImage
@onready var _lock_overlay: TextureRect = %LockOverlay
@onready var _unlockable_overlay: TextureRect = %UnlockableOverlay
@onready var _price_label: Label = %PriceLabel
@onready var _name_label: Label = %NameLabel

enum State {LOCKED, UNLOCKABLE, UNLOCKED, SELECTED}

var _state: State = State.LOCKED
var state: State:
	set(value):
		_state = value
		match _state:
			State.LOCKED:
				_lock_overlay.visible = true
				_unlockable_overlay.visible = false
				_price_label.visible = true
				_price_label.theme_type_variation = ""
				disabled = true
				toggle_mode = false
				button_pressed = false
			State.UNLOCKABLE:
				_lock_overlay.visible = false
				_unlockable_overlay.visible = true
				_price_label.visible = true
				_price_label.theme_type_variation = "GoldLabel"
				disabled = false
				toggle_mode = false
				button_pressed = false
			State.UNLOCKED:
				_lock_overlay.visible = false
				_unlockable_overlay.visible = false
				_price_label.visible = false
				disabled = false
				toggle_mode = true
				button_pressed = false
			State.SELECTED:
				_lock_overlay.visible = false
				_unlockable_overlay.visible = false
				_price_label.visible = false
				disabled = false
				toggle_mode = true
				button_pressed = true
	get:
		return _state


func display_tank(_tank_id: TankManager.TankId) -> void:
	tank_id = _tank_id
	var tank_spec: TankSpec = TankManager.get_tank_spec(_tank_id)
	tank_price = tank_spec.dollar_cost
	_tank_image.texture = tank_spec.preview_texture
	_price_label.text = Utils.format_dollars(tank_price)
	_name_label.text = tank_spec.display_name
