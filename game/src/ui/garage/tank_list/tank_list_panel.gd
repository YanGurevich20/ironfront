class_name TankListPanel
extends Control

signal unlock_tank_requested(tank_id: String)

signal tank_selected(tank_id: String)

var _player_dollars: int = 0
var _unlocked_tank_ids: Array[String] = []

@onready var tank_list: HBoxContainer = %TankList
@onready var _tank_list_item_scene: PackedScene = preload(
	"res://src/ui/garage/tank_list/tank_list_item.tscn"
)


#TODO: Convert the tank list panel to use a display_player_data() method instead of _ready()
func _ready() -> void:
	for child in tank_list.get_children():
		tank_list.remove_child(child)
		child.queue_free()

	var all_tank_ids: Array[String] = TankManager.get_tank_ids()

	var player_data: PlayerData = PlayerData.get_instance()
	if !player_data.is_developer:
		all_tank_ids.remove_at(all_tank_ids.find(TankManager.TANK_ID_DEBUG_TANK))
	display_player_data(player_data)

	# Keep track of the latest unlocked tank item
	var latest_unlocked_item: TankListItem = null

	for tank_id in all_tank_ids:
		var tank_list_item: TankListItem = _tank_list_item_scene.instantiate()
		Utils.connect_checked(
			tank_list_item.item_pressed, func() -> void: _on_item_pressed(tank_list_item)
		)
		tank_list.add_child(tank_list_item)
		tank_list_item.display_tank(tank_id)

		# If this tank is unlocked, update the latest unlocked item
		if _unlocked_tank_ids.has(tank_id):
			latest_unlocked_item = tank_list_item

	_update_item_states()

	# Determine which tank should be selected initially
	var saved_tank_id: String = player_data.selected_tank_id
	# If the saved tank is unlocked, select it; otherwise fall back to the latest unlocked
	if _unlocked_tank_ids.has(saved_tank_id):
		select_tank_by_id(saved_tank_id)
	elif latest_unlocked_item != null:
		_select_tank(latest_unlocked_item)


func _update_item_states() -> void:
	for item: TankListItem in tank_list.get_children():
		var unlocked: bool = _unlocked_tank_ids.has(item.tank_id)
		var player_data: PlayerData = PlayerData.get_instance()
		var selected_id: String = player_data.selected_tank_id
		if unlocked:
			if item.tank_id == selected_id:
				item.state = item.State.SELECTED
			else:
				item.state = item.State.UNLOCKED
		else:
			if _player_dollars >= item.tank_price:
				item.state = item.State.UNLOCKABLE
			else:
				item.state = item.State.LOCKED


func _on_item_pressed(item: TankListItem) -> void:
	match item.state:
		item.State.UNLOCKABLE:
			unlock_tank_requested.emit(item.tank_id)
		item.State.UNLOCKED, item.State.SELECTED:
			_select_tank(item)
		_:
			pass


func _select_tank(item: TankListItem) -> void:
	if item.state in [item.State.LOCKED, item.State.UNLOCKABLE]:
		return
	for other: TankListItem in tank_list.get_children():
		if other == item:
			other.state = other.State.SELECTED
		elif other.state == other.State.SELECTED:
			other.state = other.State.UNLOCKED
	tank_selected.emit(item.tank_id)


# Allow parent node to programmatically select a tank by its ID.
func select_tank_by_id(tank_id: String) -> void:
	for item: TankListItem in tank_list.get_children():
		if item.tank_id == tank_id:
			_select_tank(item)
			return


# Public API for parent to provide latest player data.
func display_player_data(player_data: PlayerData) -> void:
	_player_dollars = player_data.dollars
	_unlocked_tank_ids = player_data.get_unlocked_tank_ids()
	_update_item_states()
