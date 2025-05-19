class_name TankListPanel extends Control

@onready var tank_list: HBoxContainer = %TankList
@onready var _tank_list_item_scene: PackedScene = preload("res://ui/garage/tank_list/tank_list_item.tscn")

# Signals
signal unlock_requested(tank_id: TankManager.TankId) # Child -> Parent
signal tank_selected(tank_id: TankManager.TankId)    # Child -> Parent

var _player_dollars: int = 0
var _unlocked_tank_ids: Array[TankManager.TankId] = []
var _selected_item: TankListItem

func _ready() -> void:
	for child in tank_list.get_children():
		tank_list.remove_child(child)
		child.queue_free()

	var tank_ids := TankManager.TankId.values()
	var all_tank_ids: Array[TankManager.TankId] = []
	for id: int in tank_ids:
		all_tank_ids.append(id)

	var game_progress: PlayerData = LoadableData.get_instance(PlayerData)
	set_data(game_progress.dollars, game_progress.unlocked_tank_ids.duplicate())

	# Keep track of the latest unlocked tank item
	var latest_unlocked_item: TankListItem = null

	for tank_id in all_tank_ids:
		var tank_list_item: TankListItem = _tank_list_item_scene.instantiate()
		tank_list_item.pressed.connect(func()->void: _on_item_pressed(tank_list_item))
		tank_list.add_child(tank_list_item)
		tank_list_item.display_tank(tank_id)

		# If this tank is unlocked, update the latest unlocked item
		if _unlocked_tank_ids.has(tank_id):
			latest_unlocked_item = tank_list_item

	_update_item_states()

	# Auto-select the latest unlocked tank if any was found
	if latest_unlocked_item != null:
		_select_tank(latest_unlocked_item)

func _update_item_states() -> void:
	for item in tank_list.get_children():
		var unlocked: bool = _unlocked_tank_ids.has(item.tank_id)
		if unlocked:
			if item == _selected_item:
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
			unlock_requested.emit(item.tank_id)
		item.State.UNLOCKED, item.State.SELECTED:
			_select_tank(item)
		_:
			pass

func _select_tank(item: TankListItem) -> void:
	if item.state in [item.State.LOCKED, item.State.UNLOCKABLE]:
		return
	for other in tank_list.get_children():
		if other == item: other.state = other.State.SELECTED
		elif other.state == other.State.SELECTED: other.state = other.State.UNLOCKED
	_selected_item = item
	tank_selected.emit(item.tank_id)

# Allow parent node to programmatically select a tank by its ID.
func select_tank_by_id(tank_id: TankManager.TankId) -> void:
	for item in tank_list.get_children():
		if item.tank_id == tank_id:
			_select_tank(item)
			return

# Public API for parent to provide latest player data.
func set_data(player_dollars: int, unlocked_tank_ids: Array[TankManager.TankId]) -> void:
	_player_dollars = player_dollars
	_unlocked_tank_ids = unlocked_tank_ids
	_update_item_states()
