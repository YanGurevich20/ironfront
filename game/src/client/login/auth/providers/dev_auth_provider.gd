class_name DevAuthProvider
extends AuthProvider


func sign_in() -> void:
	if has_sign_in_operation():
		return
	_begin_sign_in_operation()
	call_deferred("_complete_sign_in")


func sign_out() -> void:
	_end_sign_in_operation()
	sign_out_completed.emit()


func _complete_sign_in() -> void:
	if not has_sign_in_operation():
		return
	_end_sign_in_operation()
	var instance_id: String = Env.get_env("instance_id", "0")
	var proof: String = "dev-%s" % [instance_id]
	sign_in_succeeded.emit(AuthResult.new("dev", proof, 0))
