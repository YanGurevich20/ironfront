class_name DevAuthProvider
extends AuthProvider

@export var dev_user_id: String = "dev-local-user"
@export var dev_display_name: String = "DEV_PLAYER"
@export var sign_in_delay_seconds: float = 3.0


func sign_in() -> void:
	if _is_sign_in_in_progress:
		return
	_set_sign_in_in_progress(true)
	call_deferred("_complete_sign_in")


func sign_out() -> void:
	_set_sign_in_in_progress(false)
	sign_out_completed.emit()


func _complete_sign_in() -> void:
	if not _is_sign_in_in_progress:
		return
	var delay_seconds: float = maxf(sign_in_delay_seconds, 0.0)
	await get_tree().create_timer(delay_seconds).timeout
	if not _is_sign_in_in_progress:
		return
	_set_sign_in_in_progress(false)
	var issued_at_msec: int = int(Time.get_unix_time_from_system() * 1000)
	var proof: String = "%s:%d" % [dev_user_id, issued_at_msec]
	sign_in_succeeded.emit(AuthResult.new("dev", dev_user_id, dev_display_name, proof, 0))
