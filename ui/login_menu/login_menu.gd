class_name LoginMenu
extends Control

var player_data: PlayerData = PlayerData.get_instance()

@onready var login_button: Button = %LoginButton
@onready var username_input: LineEdit = %UsernameInput
@onready var quit_button: Button = %QuitButton
@onready var discord_link_button: Button = %DiscordLinkButton


func _ready() -> void:
	Utils.connect_checked(UiBus.log_out_pressed, _on_log_out_pressed)

	if player_data.player_name:
		username_input.text = player_data.player_name

	login_button.disabled = username_input.text.is_empty()

	Utils.connect_checked(username_input.text_changed, _handle_username_input)
	Utils.connect_checked(login_button.pressed, _on_login_button_pressed)
	Utils.connect_checked(quit_button.pressed, func() -> void: UiBus.quit_pressed.emit())
	Utils.connect_checked(
		discord_link_button.pressed,
		func() -> void:
			var open_result := OS.shell_open("https://discord.gg/SDBEpSu9DA")
			if open_result != OK:
				push_warning("Failed to open Discord link: ", open_result)
	)


func _handle_username_input(text: String) -> void:
	login_button.disabled = text.is_empty()

	player_data.player_name = text


func _on_login_button_pressed() -> void:
	player_data.player_name = username_input.text
	if player_data.player_name == "DEVELOPER":
		player_data.is_developer = true
	player_data.save()
	UiBus.login_pressed.emit()


func _on_log_out_pressed() -> void:
	username_input.text = ""
	login_button.disabled = true
