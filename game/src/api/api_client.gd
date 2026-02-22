class_name ApiClient
extends Node


func _exit_tree() -> void:
	cancel_all_requests()


func request_json(
	url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String
) -> Dictionary[String, Variant]:
	if not is_inside_tree():
		return {"success": false, "reason": "USER_SERVICE_HTTP_REQUEST_CANCELED"}
	_log_api("http request method=%d url=%s" % [method, url])
	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	var request_error: Error = request.request(url, headers, method, body)
	if request_error != OK:
		request.queue_free()
		_log_api("http request creation failed error=%d url=%s" % [request_error, url])
		return {"success": false, "reason": "USER_SERVICE_HTTP_REQUEST_FAILED"}
	var response: Array = await request.request_completed
	if is_instance_valid(request):
		request.queue_free()

	var result: int = int(response[0])
	if result != HTTPRequest.RESULT_SUCCESS:
		_log_api("http transport failed result=%d url=%s" % [result, url])
		return {"success": false, "reason": "USER_SERVICE_HTTP_TRANSPORT_FAILED"}
	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]
	var parsed_body: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	var parsed_dictionary: Dictionary = parsed_body if parsed_body is Dictionary else {}
	_log_api("http response code=%d url=%s" % [response_code, url])
	if response_code < 200 or response_code >= 300:
		var error_reason: String = str(parsed_dictionary.get("error", "USER_SERVICE_HTTP_ERROR"))
		return {"success": false, "reason": error_reason}
	return {"success": true, "body": parsed_dictionary}


func cancel_all_requests() -> void:
	for child: Node in get_children():
		var request: HTTPRequest = child as HTTPRequest
		if request == null:
			continue
		request.cancel_request()
		# Release any await request.request_completed callsites during teardown.
		request.emit_signal(
			"request_completed",
			HTTPRequest.RESULT_CANT_CONNECT,
			0,
			PackedStringArray(),
			PackedByteArray()
		)
		request.queue_free()


func _log_api(message: String) -> void:
	print("[api-client] %s" % message)
