class_name HeaderPanel extends PanelContainer

@onready var dollars_label: Label = %DollarsLabel
@onready var bonds_label: Label = %BondsLabel
@onready var garage_menu_button: Button = %GarageMenuButton

signal garage_menu_pressed

func _ready() -> void:
	garage_menu_button.pressed.connect(func()->void: garage_menu_pressed.emit())

func display_player_data() -> void:
	var game_progress: PlayerData = LoadableData.get_instance(PlayerData)
	print("game_progress dollars: %s" % game_progress.dollars)
	var dollars: int = game_progress.dollars
	var bonds: int = game_progress.bonds
	dollars_label.text = Utils.format_dollars(dollars)
	bonds_label.text = Utils.format_bonds(bonds)
