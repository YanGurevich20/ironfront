class_name BootstrapLoginPanel
extends Control

signal sign_in_pressed
signal quit_pressed
signal username_submitted(username: String)

@onready var login_button: Button = %LoginButton
@onready var quit_button: Button = %QuitButton
@onready var username_prompt_container: CenterContainer = %UsernamePromptContainer
@onready var username_input: LineEdit = %UsernameInput
@onready var username_submit_button: Button = %UsernameSubmitButton
@onready var username_status_label: Label = %UsernameStatusLabel

@onready var discord_button: Button = %DiscordLinkButton


func _ready() -> void:
	Utils.connect_checked(login_button.pressed, func() -> void: sign_in_pressed.emit())
	Utils.connect_checked(quit_button.pressed, func() -> void: quit_pressed.emit())
	Utils.connect_checked(
		discord_button.pressed, func() -> void: OS.shell_open("https://discord.gg/SDBEpSu9DA")
	)
	Utils.connect_checked(username_submit_button.pressed, _on_username_submit_pressed)
	Utils.connect_checked(username_input.text_submitted, _on_username_input_submitted)
	username_prompt_container.visible = false
	username_status_label.visible = false
	set_idle("SIGN IN")


func set_signing_in() -> void:
	login_button.disabled = true
	login_button.text = "SIGNING IN..."


func set_idle(button_text: String) -> void:
	login_button.disabled = false
	login_button.text = button_text


func show_username_prompt(initial_username: String) -> void:
	username_prompt_container.visible = true
	username_status_label.visible = false
	username_input.text = initial_username
	username_submit_button.disabled = false
	username_submit_button.text = "CONTINUE"
	username_input.grab_focus()
	username_input.caret_column = username_input.text.length()


func hide_username_prompt() -> void:
	username_prompt_container.visible = false


func set_username_saving() -> void:
	username_submit_button.disabled = true
	username_submit_button.text = "SAVING..."


func set_username_idle() -> void:
	username_submit_button.disabled = false
	username_submit_button.text = "CONTINUE"


func show_username_error(message: String) -> void:
	username_status_label.visible = true
	username_status_label.text = message


func _on_username_submit_pressed() -> void:
	var trimmed: String = username_input.text.strip_edges()
	if trimmed.is_empty():
		username_status_label.visible = true
		username_status_label.text = "USERNAME REQUIRED"
		return
	username_status_label.visible = false
	set_username_saving()
	username_submitted.emit(trimmed)


func _on_username_input_submitted(_text: String) -> void:
	_on_username_submit_pressed()
