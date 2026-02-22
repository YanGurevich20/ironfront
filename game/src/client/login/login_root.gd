class_name LoginRoot
extends Control

signal login_completed
signal login_failed(reason: String)

const BOOTSTRAP_PANEL_SCENE: PackedScene = preload(
	"res://src/client/login/ui/bootstrap_login_panel.tscn"
)

var _panel: BootstrapLoginPanel

@onready var auth_manager: AuthManager = %AuthManager


func _ready() -> void:
	_panel = BOOTSTRAP_PANEL_SCENE.instantiate()
	add_child(_panel)
	_connect_signals()
	auth_manager.retry_sign_in()
	_panel.set_signing_in()


func _connect_signals() -> void:
	Utils.connect_checked(auth_manager.sign_in_succeeded, _on_sign_in_succeeded)
	Utils.connect_checked(auth_manager.sign_in_failed, _on_sign_in_failed)
	Utils.connect_checked(auth_manager.username_setup_required, _on_username_setup_required)
	Utils.connect_checked(auth_manager.username_submit_completed, _on_username_submit_completed)
	Utils.connect_checked(_panel.sign_in_pressed, _on_panel_sign_in_pressed)
	Utils.connect_checked(_panel.quit_pressed, _on_panel_quit_pressed)
	Utils.connect_checked(_panel.username_submitted, _on_panel_username_submitted)


func _on_sign_in_succeeded(_result: AuthResult) -> void:
	if Account.username_updated_at <= 0:
		return
	_panel.hide_username_prompt()
	login_completed.emit()


func _on_sign_in_failed(reason: String) -> void:
	_panel.hide_username_prompt()
	_panel.set_idle("RETRY AUTH")
	login_failed.emit(reason)


func _on_username_setup_required(initial_username: String) -> void:
	_panel.set_idle("RETRY AUTH")
	_panel.show_username_prompt(initial_username)


func _on_username_submit_completed(success: bool, reason: String, _username: String) -> void:
	if success:
		_panel.hide_username_prompt()
		login_completed.emit()
		return
	_panel.set_username_idle()
	_panel.show_username_error(_resolve_username_error_text(reason))


func _on_panel_sign_in_pressed() -> void:
	_panel.set_signing_in()
	auth_manager.retry_sign_in()


func _on_panel_quit_pressed() -> void:
	UiBus.quit_pressed.emit()


func _on_panel_username_submitted(username: String) -> void:
	auth_manager.submit_username(username)


func _resolve_username_error_text(reason: String) -> String:
	match reason:
		"USERNAME_REQUIRED":
			return "USERNAME REQUIRED"
		"UNAUTHORIZED", "NOT_SIGNED_IN":
			return "SESSION EXPIRED. SIGN IN AGAIN"
		"INVALID_REQUEST":
			return "INVALID USERNAME"
		_:
			return "FAILED TO SAVE USERNAME"
