class_name DevAuthProvider
extends AuthProvider

@export var sign_in_delay_seconds: float = 1.0

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
	var instance_id: String = Env.get_env("instance_id", "0")
	var proof: String = "dev-%s" % [instance_id]
	sign_in_succeeded.emit(AuthResult.new("dev", proof, 0))
