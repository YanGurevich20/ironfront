class_name LoginMenu
extends Control

@onready var login_button: Button = %LoginButton
@onready var quit_button: Button = %QuitButton
@onready var discord_link_button: Button = %DiscordLinkButton


func _ready() -> void:
	Utils.connect_checked(UiBus.log_out_pressed, _on_log_out_pressed)
	Utils.connect_checked(UiBus.auth_sign_in_started, _on_auth_sign_in_started)
	Utils.connect_checked(UiBus.auth_sign_in_finished, _on_auth_sign_in_finished)
	Utils.connect_checked(login_button.pressed, _on_login_button_pressed)
	Utils.connect_checked(quit_button.pressed, func() -> void: UiBus.quit_pressed.emit())
	Utils.connect_checked(
		discord_link_button.pressed,
		func() -> void:
			var open_result := OS.shell_open("https://discord.gg/SDBEpSu9DA")
			if open_result != OK:
				push_warning("Failed to open Discord link: ", open_result)
	)
	_set_idle_button_state("SIGN IN")


func _on_login_button_pressed() -> void:
	UiBus.auth_retry_requested.emit()


func _on_log_out_pressed() -> void:
	_set_idle_button_state("SIGN IN")


func _on_auth_sign_in_started() -> void:
	login_button.disabled = true
	login_button.text = "SIGNING IN..."


func _on_auth_sign_in_finished(success: bool) -> void:
	if success:
		return
	_set_idle_button_state("RETRY AUTH")


func _set_idle_button_state(button_text: String) -> void:
	login_button.disabled = false
	login_button.text = button_text
