class_name Account
extends Resource

signal username_updated(new_username: String)

const FILE_NAME: String = "account"

@export var account_id: String = ""
@export var username: String = "":
	set(value):
		username = value
		username_updated.emit(value)
@export var username_updated_at: int = 0
@export var economy: AccountEconomy = AccountEconomy.new()
@export var loadout: AccountLoadout = AccountLoadout.new()


static func get_instance() -> Account:
	return DataStore.load_or_create(Account, FILE_NAME)


func save() -> void:
	DataStore.save(self, FILE_NAME)
