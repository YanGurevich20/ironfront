class_name ClientApp
extends Node2D

const LOGIN_ROOT_SCENE: PackedScene = preload("res://src/client/login/login_root.tscn")
const GARAGE_ROOT_SCENE: PackedScene = preload("res://src/client/garage/garage_root.tscn")
const ARENA_ROOT_SCENE: PackedScene = preload("res://src/client/arena/arena_root.tscn")
const SETTINGS_OVERLAY_SCENE: PackedScene = preload(
	"res://src/ui/overlays/settings_overlay/settings_overlay.tscn"
)
const SHELL_INFO_OVERLAY_SCENE: PackedScene = preload(
	"res://src/ui/overlays/shell_info_overlay/shell_info_overlay.tscn"
)

var _settings_overlay: SettingsOverlay
var _shell_info_overlay: ShellInfoOverlay

@onready var world_state_container: Node2D = %WorldStateContainer
@onready var ui_state_container: CanvasLayer = %UiStateContainer
@onready var network_client: ENetClient = %Network
@onready var session_api: ClientSessionApi = %Session
@onready var gameplay_api: ClientGameplayApi = %Gameplay


func _ready() -> void:
	Utils.connect_checked(UiBus.quit_pressed, func() -> void: get_tree().quit())
	Utils.connect_checked(UiBus.shell_info_requested, _on_shell_info_requested)
	_setup_shared_overlays()
	_mount_login_root()


func _mount_login_root() -> void:
	_unmount_active_root()
	var login_root: LoginRoot = LOGIN_ROOT_SCENE.instantiate()
	ui_state_container.add_child(login_root)
	Utils.connect_checked(login_root.login_completed, _on_login_completed)


func _setup_shared_overlays() -> void:
	var overlay_layer: CanvasLayer = CanvasLayer.new()
	overlay_layer.name = "SharedOverlays"
	overlay_layer.layer = 10
	add_child(overlay_layer)
	_settings_overlay = SETTINGS_OVERLAY_SCENE.instantiate()
	_settings_overlay.visible = false
	overlay_layer.add_child(_settings_overlay)
	Utils.connect_checked(_settings_overlay.exit_overlay_pressed, _on_settings_exit)
	_shell_info_overlay = SHELL_INFO_OVERLAY_SCENE.instantiate()
	_shell_info_overlay.visible = false
	overlay_layer.add_child(_shell_info_overlay)
	Utils.connect_checked(_shell_info_overlay.exit_overlay_pressed, _on_shell_info_exit)


func _mount_garage_root() -> void:
	_unmount_active_root()
	var garage_root: GarageRoot = GARAGE_ROOT_SCENE.instantiate()
	ui_state_container.add_child(garage_root)
	Utils.connect_checked(garage_root.play_requested, _on_play_requested)
	Utils.connect_checked(garage_root.logout_requested, _on_logout_requested)
	Utils.connect_checked(garage_root.settings_requested, _on_settings_requested)


func _mount_arena_root() -> void:
	_unmount_active_root()
	var arena_root: ArenaRoot = ARENA_ROOT_SCENE.instantiate()
	world_state_container.add_child(arena_root)
	Utils.connect_checked(arena_root.return_to_garage_requested, _on_return_to_garage_requested)
	Utils.connect_checked(arena_root.arena_finished, _on_arena_finished)
	Utils.connect_checked(arena_root.logout_requested, _on_logout_requested)
	Utils.connect_checked(arena_root.settings_requested, _on_settings_requested)


func _unmount_active_root() -> void:
	for child: Node in world_state_container.get_children():
		child.queue_free()
	for child: Node in ui_state_container.get_children():
		child.queue_free()


func _on_login_completed() -> void:
	_mount_garage_root()


func _on_play_requested() -> void:
	_mount_arena_root()


func _on_return_to_garage_requested() -> void:
	_mount_garage_root()


func _on_arena_finished(_summary: Dictionary) -> void:
	_mount_garage_root()


func _on_logout_requested() -> void:
	Account.clear()
	_mount_login_root()


func _on_settings_requested() -> void:
	_shell_info_overlay.visible = false
	_settings_overlay.visible = true


func _on_settings_exit() -> void:
	_settings_overlay.visible = false
	UiBus.resume_requested.emit()


func _on_shell_info_requested(shell_spec: ShellSpec) -> void:
	_settings_overlay.visible = false
	_shell_info_overlay.display_shell_info(shell_spec)
	_shell_info_overlay.visible = true


func _on_shell_info_exit() -> void:
	_shell_info_overlay.visible = false
	UiBus.resume_requested.emit()
