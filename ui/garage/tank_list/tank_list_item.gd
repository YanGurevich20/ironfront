class_name TankListItem extends Control
var tank_id: TankManager.TankId
var tank_price: int = 0
@onready var _button: Button = %TankListItemButton
@onready var _tank_image: TextureRect = %TankImage
@onready var _lock_overlay: TextureRect = %LockOverlay
@onready var _lock_color_overlay: ColorRect = %LockColorOverlay
@onready var _unlockable_overlay: TextureRect = %UnlockableOverlay
@onready var _price_label: Label = %PriceLabel
@onready var _name_label: Label = %NameLabel

enum State {LOCKED, UNLOCKABLE, UNLOCKED, SELECTED}

signal item_pressed()

func _ready() -> void:
	_button.pressed.connect(func()->void: item_pressed.emit())

var _state: State = State.LOCKED
var state: State:
	set(value):
		_state = value
		match _state:
			State.LOCKED:
				_lock_overlay.visible = true
				_lock_color_overlay.visible = true
				_unlockable_overlay.visible = false
				_price_label.visible = true
				_price_label.theme_type_variation = ""
				_button.disabled = true
				_button.toggle_mode = false
				_button.button_pressed = false
			State.UNLOCKABLE:
				_lock_overlay.visible = false
				_lock_color_overlay.visible = false
				_unlockable_overlay.visible = true
				_price_label.visible = true
				_price_label.theme_type_variation = "GoldLabel"
				_button.disabled = false
				_button.toggle_mode = false
				_button.button_pressed = false
			State.UNLOCKED:
				_lock_overlay.visible = false
				_lock_color_overlay.visible = false
				_unlockable_overlay.visible = false
				_price_label.visible = false
				_button.disabled = false
				_button.toggle_mode = true
				_button.button_pressed = false
			State.SELECTED:
				_lock_overlay.visible = false
				_lock_color_overlay.visible = false
				_unlockable_overlay.visible = false
				_price_label.visible = false
				_button.disabled = false
				_button.toggle_mode = true
				_button.button_pressed = true
	get:
		return _state


func display_tank(_tank_id: TankManager.TankId) -> void:
	tank_id = _tank_id
	var tank_spec: TankSpec = TankManager.TANK_SPECS[_tank_id]
	tank_price = tank_spec.dollar_cost
	_tank_image.texture = tank_spec.preview_texture
	_price_label.text = Utils.format_dollars(tank_price)
	_name_label.text = tank_spec.display_name
