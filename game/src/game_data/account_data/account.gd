extends Node

signal username_updated(new_username: String)
signal account_cleared

var account_id: String = ""
var username: String = "":
	set(value):
		username = value
		username_updated.emit(value)
var username_updated_at: int = 0
var economy: AccountEconomy = AccountEconomy.new()
var loadout: AccountLoadout = AccountLoadout.new()


func _ready() -> void:
	_ensure_nested_instances()


func clear() -> void:
	account_id = ""
	username = ""
	username_updated_at = 0
	_ensure_nested_instances()
	economy.dollars = 0
	economy.bonds = 0
	loadout.tanks = {}
	loadout.selected_tank_id = ""
	account_cleared.emit()


func _ensure_nested_instances() -> void:
	if economy == null:
		economy = AccountEconomy.new()
	if loadout == null:
		loadout = AccountLoadout.new()
