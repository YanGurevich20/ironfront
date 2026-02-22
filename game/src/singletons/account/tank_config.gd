class_name TankConfig
extends RefCounted

var tank_spec: TankSpec
var unlocked_shell_specs: Array[ShellSpec] = []
var shell_loadout_by_spec: Dictionary[ShellSpec, int] = {}
