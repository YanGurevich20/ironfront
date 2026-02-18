class_name AuthManager
extends Node

signal sign_in_succeeded(result: AuthResult)
signal sign_in_failed(reason: String)

const DEV_PROVIDER_SCENE: PackedScene = preload(
	"res://src/core/client/auth/providers/dev_auth_provider.tscn"
)
const PGS_PROVIDER_SCENE: PackedScene = preload(
	"res://src/core/client/auth/providers/pgs_auth_provider.tscn"
)

var _active_provider: AuthProvider
var _is_signed_in: bool = false


func _ready() -> void:
	_active_provider = _instantiate_provider()
	Utils.connect_checked(_active_provider.sign_in_succeeded, _on_provider_sign_in_succeeded)
	Utils.connect_checked(_active_provider.sign_in_failed, _on_provider_sign_in_failed)


func retry_sign_in() -> void:
	if _is_signed_in:
		return
	UiBus.auth_sign_in_started.emit()
	_active_provider.sign_in()


func sign_out() -> void:
	if _active_provider == null:
		return
	_is_signed_in = false
	_active_provider.sign_out()


func _on_provider_sign_in_succeeded(result: AuthResult) -> void:
	_is_signed_in = true
	sign_in_succeeded.emit(result)


func _on_provider_sign_in_failed(reason: String) -> void:
	_is_signed_in = false
	sign_in_failed.emit(reason)


func _instantiate_provider() -> AuthProvider:
	var use_pgs_provider: bool = Env.get_env("stage", "dev") == "prod" or OS.has_feature("android")
	var provider_scene: PackedScene = PGS_PROVIDER_SCENE if use_pgs_provider else DEV_PROVIDER_SCENE
	var provider_node: Node = provider_scene.instantiate()
	var provider: AuthProvider = provider_node as AuthProvider
	assert(provider != null, "Provider scene root must inherit AuthProvider")
	add_child(provider)
	return provider
