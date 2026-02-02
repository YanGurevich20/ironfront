class_name TankListItem
extends Control

signal item_pressed

enum State { LOCKED = 0, UNLOCKABLE = 1, UNLOCKED = 2, SELECTED = 3 }

var tank_id: TankManager.TankId
var tank_price: int = 0
var state: State:
	set(value):
		_state = value
		match _state:
			State.LOCKED:
				lock_visible(true)
				set_unlockable_overlay_visibility(false)
				set_price_label_properties(true, "")
				set_button_properties(true, false, false)
			State.UNLOCKABLE:
				lock_visible(false)
				set_unlockable_overlay_visibility(true)
				set_price_label_properties(true, "GoldLabel")
				set_button_properties(false, false, false)
			State.UNLOCKED:
				lock_visible(false)
				set_unlockable_overlay_visibility(false)
				set_price_label_properties(false, "")
				set_button_properties(false, true, false)
			State.SELECTED:
				lock_visible(false)
				set_unlockable_overlay_visibility(false)
				set_price_label_properties(false, "")
				set_button_properties(false, true, true)
	get:
		return _state

var _state: State = State.LOCKED

@onready var _button: Button = %TankListItemButton
@onready var _tank_image: TextureRect = %TankImage
@onready var _lock_overlay: TextureRect = %LockOverlay
@onready var _lock_color_overlay: ColorRect = %LockColorOverlay
@onready var _name_lock_color_overlay: ColorRect = %NameLockColorOverlay
@onready var _unlockable_overlay: TextureRect = %UnlockableOverlay
@onready var _price_label: Label = %PriceLabel
@onready var _name_label: Label = %NameLabel


func set_button_properties(disabled: bool, toggle_mode: bool, button_pressed: bool) -> void:
	_button.disabled = disabled
	_button.toggle_mode = toggle_mode
	_button.button_pressed = button_pressed


func set_price_label_properties(show_price_label: bool, _theme_type_variation: String) -> void:
	_price_label.visible = show_price_label
	_price_label.theme_type_variation = _theme_type_variation


func set_unlockable_overlay_visibility(show_unlockable_overlay: bool) -> void:
	_unlockable_overlay.visible = show_unlockable_overlay


func display_tank(_tank_id: TankManager.TankId) -> void:
	tank_id = _tank_id
	var tank_spec: TankSpec = TankManager.tank_specs[_tank_id]
	tank_price = tank_spec.dollar_cost
	_tank_image.texture = tank_spec.preview_texture
	_price_label.text = Utils.format_dollars(tank_price)
	_name_label.text = tank_spec.display_name


func lock_visible(show_lock_overlay: bool) -> void:
	_lock_overlay.visible = show_lock_overlay
	_lock_color_overlay.visible = show_lock_overlay
	_name_lock_color_overlay.visible = show_lock_overlay
