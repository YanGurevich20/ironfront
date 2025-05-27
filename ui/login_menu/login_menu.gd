class_name LoginMenu extends Control


@onready var login_button: Button = %LoginButton
@onready var username_input: LineEdit = %UsernameInput
@onready var quit_button: Button = %QuitButton

var player_data: PlayerData = PlayerData.get_instance()

func _ready() -> void:
	SignalBus.log_out_pressed.connect(_on_log_out_pressed)

	if player_data.player_name:
		username_input.text = player_data.player_name

	login_button.disabled = username_input.text.is_empty()

	username_input.text_changed.connect(_handle_username_input)
	login_button.pressed.connect(_on_login_button_pressed)
	quit_button.pressed.connect(func() -> void: SignalBus.quit_pressed.emit())

func _handle_username_input(text: String) -> void:
	login_button.disabled = text.is_empty()

	player_data.player_name = text

func _on_login_button_pressed() -> void:
	player_data.player_name = username_input.text
	if player_data.player_name == "DEVELOPER":
		player_data.is_developer = true
	player_data.save()
	SignalBus.login_pressed.emit()

func _on_log_out_pressed() -> void:
	username_input.text = ""
	login_button.disabled = true
