class_name TankListPanel
extends Control

signal unlock_tank_requested(tank_spec: TankSpec)

var _unlocked_tank_specs: Array[TankSpec] = []

@onready var tank_list: HBoxContainer = %TankList
@onready var _tank_list_item_scene: PackedScene = preload(
	"res://src/client/garage/ui/garage/tank_list/tank_list_item.tscn"
)


func _ready() -> void:
	Utils.connect_checked(
		Account.loadout.selected_tank_spec_updated,
		func(_spec: TankSpec) -> void: _update_item_states()
	)
	Utils.connect_checked(
		Account.loadout.tanks_updated,
		func(_tanks: Dictionary) -> void: _refresh_unlocked_tank_specs()
	)
	Utils.connect_checked(
		Account.economy.dollars_updated, func(_new_dollars: int) -> void: _update_item_states()
	)
	for child in tank_list.get_children():
		child.queue_free()

	var all_tank_specs: Array[TankSpec] = []
	for tank_id: String in TankManager.get_tank_ids():
		all_tank_specs.append(TankManager.require_tank_spec(tank_id))
	_refresh_unlocked_tank_specs()

	var latest_unlocked_item: TankListItem = null

	for spec: TankSpec in all_tank_specs:
		var tank_list_item: TankListItem = _tank_list_item_scene.instantiate()
		Utils.connect_checked(
			tank_list_item.item_pressed, func() -> void: _on_item_pressed(tank_list_item)
		)
		tank_list.add_child(tank_list_item)
		tank_list_item.display_tank(spec)

		if _unlocked_tank_specs.has(spec):
			latest_unlocked_item = tank_list_item

	_update_item_states()

	var saved_spec: TankSpec = Account.loadout.selected_tank_spec
	if _unlocked_tank_specs.has(saved_spec):
		select_tank_by_spec(saved_spec)
	elif latest_unlocked_item != null:
		_select_tank(latest_unlocked_item)


func _update_item_states() -> void:
	var selected_spec: TankSpec = Account.loadout.selected_tank_spec
	var player_dollars: int = Account.economy.dollars
	for item: TankListItem in tank_list.get_children():
		var unlocked: bool = _unlocked_tank_specs.has(item.tank_spec)
		if unlocked:
			if item.tank_spec == selected_spec:
				item.state = item.State.SELECTED
			else:
				item.state = item.State.UNLOCKED
		else:
			if player_dollars >= item.tank_price:
				item.state = item.State.UNLOCKABLE
			else:
				item.state = item.State.LOCKED


func _on_item_pressed(item: TankListItem) -> void:
	match item.state:
		item.State.UNLOCKABLE:
			unlock_tank_requested.emit(item.tank_spec)
		item.State.UNLOCKED, item.State.SELECTED:
			_select_tank(item)
		_:
			pass


func _select_tank(item: TankListItem) -> void:
	if item.state in [item.State.LOCKED, item.State.UNLOCKABLE]:
		return
	Account.loadout.selected_tank_spec = item.tank_spec
	for other: TankListItem in tank_list.get_children():
		if other == item:
			other.state = other.State.SELECTED
		elif other.state == other.State.SELECTED:
			other.state = other.State.UNLOCKED


func select_tank_by_spec(tank_spec: TankSpec) -> void:
	for item: TankListItem in tank_list.get_children():
		if item.tank_spec == tank_spec:
			_select_tank(item)
			return


func _refresh_unlocked_tank_specs() -> void:
	_unlocked_tank_specs = Account.loadout.get_tank_specs()
	_update_item_states()
