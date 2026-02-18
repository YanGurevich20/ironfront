class_name AuthProvider
extends Node

signal sign_in_succeeded(result: AuthResult)
signal sign_in_failed(reason: String)
signal sign_out_completed

var _is_sign_in_in_progress: bool = false


func sign_in() -> void:
	push_error("AuthProvider.sign_in must be overridden by subclasses")


func sign_out() -> void:
	sign_out_completed.emit()


func is_sign_in_in_progress() -> bool:
	return _is_sign_in_in_progress


func _set_sign_in_in_progress(next_value: bool) -> void:
	_is_sign_in_in_progress = next_value
