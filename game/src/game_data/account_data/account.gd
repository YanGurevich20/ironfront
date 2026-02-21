class_name Account
extends Resource

const FILE_NAME: String = "account"

@export var account_id: String
@export var username: String
@export var username_updated_at: String
@export var economy: AccountEconomy
@export var loadout: AccountLoadout


static func get_instance() -> Account:
	return DataStore.load_or_create(Account, FILE_NAME)


func save() -> void:
	DataStore.save(self, FILE_NAME)
