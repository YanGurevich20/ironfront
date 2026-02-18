class_name Env


static func get_parsed_cmdline_user_args(flags: bool = false) -> Dictionary[String, Variant]:
	var client_args: PackedStringArray = OS.get_cmdline_user_args()
	var parsed_client_args: Dictionary[String, Variant] = {}
	for arg: String in client_args:
		if arg.contains("=") and not flags:
			var key: String = arg.split("=")[0].trim_prefix("--")
			var value: String = arg.split("=")[1]
			parsed_client_args[key] = value
		else:
			parsed_client_args[arg.trim_prefix("--")] = true
	return parsed_client_args


static func get_env(property_name: StringName, default_value: Variant) -> Variant:
	var args: Dictionary[String, Variant] = get_parsed_cmdline_user_args(false)
	return args.get(property_name, default_value)


static func get_flag(property_name: StringName) -> bool:
	var args: Dictionary[String, Variant] = get_parsed_cmdline_user_args(true)
	return args.has(property_name)
