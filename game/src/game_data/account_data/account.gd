class_name Account
extends Resource

const FILE_NAME: String = "account"

@export var account_id: String = ""
@export var username: String = ""
@export var username_updated_at: int = 0
@export var economy: AccountEconomy = AccountEconomy.new()
@export var loadout: AccountLoadout = AccountLoadout.new()


static func get_instance() -> Account:
	return DataStore.load_or_create(Account, FILE_NAME)


func save() -> void:
	DataStore.save(self, FILE_NAME)


func hydrate_frm_auth_result(result: AuthResult) -> void:
	account_id = result.account_id.strip_edges()
	username = result.username.strip_edges()
	username_updated_at = (
		int(result.username_updated_at_unix) if result.username_updated_at_unix != null else 0
	)
	economy = result.economy.duplicate(true)
	loadout = result.loadout.duplicate(true)
