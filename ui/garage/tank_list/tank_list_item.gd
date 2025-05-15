class_name TankListItem extends PanelContainer

@export var tank_name: String
@export var tank_image: Texture2D

func _ready() -> void:
	$TankListItemLabel.text = tank_name
	$TankListItemTexture.texture = tank_image
