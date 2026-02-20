class_name LoginMenu
extends Control

@onready var login_button: Button = %LoginButton
@onready var quit_button: Button = %QuitButton
@onready var discord_link_button: Button = %DiscordLinkButton
@onready var username_prompt_panel: PanelContainer = %UsernamePromptPanel
@onready var username_prompt_title: Label = %UsernamePromptTitle
@onready var username_input: LineEdit = %UsernameInput
@onready var username_submit_button: Button = %UsernameSubmitButton
@onready var username_status_label: Label = %UsernameStatusLabel


func _ready() -> void:
	Utils.connect_checked(UiBus.log_out_pressed, _on_log_out_pressed)
	Utils.connect_checked(UiBus.auth_sign_in_started, _on_auth_sign_in_started)
	Utils.connect_checked(UiBus.auth_sign_in_finished, _on_auth_sign_in_finished)
	Utils.connect_checked(UiBus.username_prompt_requested, _on_username_prompt_requested)
	Utils.connect_checked(UiBus.username_submit_finished, _on_username_submit_finished)
	Utils.connect_checked(login_button.pressed, _on_login_button_pressed)
	Utils.connect_checked(quit_button.pressed, func() -> void: UiBus.quit_pressed.emit())
	Utils.connect_checked(username_submit_button.pressed, _on_username_submit_pressed)
	Utils.connect_checked(username_input.text_submitted, _on_username_input_submitted)
	Utils.connect_checked(
		discord_link_button.pressed,
		func() -> void:
			var open_result := OS.shell_open("https://discord.gg/SDBEpSu9DA")
			if open_result != OK:
				push_warning("Failed to open Discord link: ", open_result)
	)
	username_prompt_panel.visible = false
	username_status_label.visible = false
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
	username_prompt_panel.visible = false
	_set_idle_button_state("RETRY AUTH")


func _set_idle_button_state(button_text: String) -> void:
	login_button.disabled = false
	login_button.text = button_text


func _on_username_prompt_requested(initial_username: String) -> void:
	username_prompt_title.text = "WELCOME COMMANDER"
	username_prompt_panel.visible = true
	username_status_label.visible = false
	username_input.text = initial_username.strip_edges()
	username_submit_button.disabled = false
	username_submit_button.text = "CONTINUE"
	username_input.grab_focus()
	username_input.caret_column = username_input.text.length()


func _on_username_submit_pressed() -> void:
	var trimmed_username: String = username_input.text.strip_edges()
	if trimmed_username.is_empty():
		_show_username_status("USERNAME REQUIRED")
		return
	username_submit_button.disabled = true
	username_submit_button.text = "SAVING..."
	username_status_label.visible = false
	UiBus.username_submit_requested.emit(trimmed_username)


func _on_username_input_submitted(_text: String) -> void:
	_on_username_submit_pressed()


func _on_username_submit_finished(success: bool, reason: String) -> void:
	if success:
		username_prompt_panel.visible = false
		return
	username_submit_button.disabled = false
	username_submit_button.text = "CONTINUE"
	_show_username_status(_resolve_username_error_text(reason))


func _show_username_status(message: String) -> void:
	username_status_label.visible = true
	username_status_label.text = message


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
