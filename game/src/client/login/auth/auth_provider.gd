class_name AuthProvider
extends Node

signal sign_in_succeeded(result: AuthResult)
signal sign_in_failed(reason: String)
signal sign_out_completed

const SIGN_IN_OPERATION_NODE_NAME: StringName = &"SignInOperation"


func sign_in() -> void:
	push_error("AuthProvider.sign_in must be overridden by subclasses")


func sign_out() -> void:
	_end_sign_in_operation()
	sign_out_completed.emit()


func has_sign_in_operation() -> bool:
	return _get_sign_in_operation() != null


func _begin_sign_in_operation() -> Node:
	if has_sign_in_operation():
		return null
	var operation: Node = Node.new()
	operation.name = String(SIGN_IN_OPERATION_NODE_NAME)
	add_child(operation)
	return operation


func _get_sign_in_operation() -> Node:
	return get_node_or_null(NodePath(SIGN_IN_OPERATION_NODE_NAME))


func _end_sign_in_operation() -> void:
	var operation: Node = _get_sign_in_operation()
	if operation != null:
		operation.queue_free()
