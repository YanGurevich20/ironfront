class_name Hull extends Sprite2D

@onready var tank :Tank= get_parent()
@onready var left_track: AnimatedSprite2D = %LeftTrack
@onready var right_track: AnimatedSprite2D = %RightTrack

@onready var engine_sound_slow :AudioStreamPlayer2D= %EngineSoundSlow
@onready var engine_sound_normal :AudioStreamPlayer2D= %EngineSoundNormal
@onready var engine_sound_fast :AudioStreamPlayer2D= %EngineSoundFast

@onready var track_sound_slow :AudioStreamPlayer2D = %TrackSoundSlow
@onready var track_sound_normal :AudioStreamPlayer2D = %TrackSoundNormal
@onready var track_sound_fast :AudioStreamPlayer2D = %TrackSoundFast

const ENGINE_PITCH_MIN: float = 0.7
const ENGINE_PITCH_MAX: float = 1.8
const TRACK_PITCH_MIN: float = 0.5
const TRACK_PITCH_MAX: float = 1.5
const FADE_THRESHOLD: float = 0.01
const SILENT_VOLUME_DB: float = -80.0

var engine_sounds_map: Dictionary
var engine_pitch_ranges: Dictionary
var input_force: float = 0.0
var track_sounds_map: Dictionary
var track_pitch_ranges: Dictionary

enum SoundType { ENGINE, TRACK }
const SpeedType = Enums.SpeedType

func setup_sounds(tank_size_class: Enums.TankSizeClass) -> void:
	setup_engine_sounds(tank_size_class)
	setup_track_sounds(tank_size_class)

func setup_engine_sounds(engine_size_class: Enums.TankSizeClass) -> void:
	engine_sounds_map = EngineSounds.ENGINE_SOUNDS[engine_size_class]
	engine_pitch_ranges = EngineSounds.ENGINE_PITCH_RANGES[engine_size_class]

	engine_sound_slow.stream = engine_sounds_map[SpeedType.SLOW]
	engine_sound_normal.stream = engine_sounds_map[SpeedType.NORMAL]
	engine_sound_fast.stream = engine_sounds_map[SpeedType.FAST]

func setup_track_sounds(tank_size_class: Enums.TankSizeClass) -> void:
	track_sounds_map = TrackSounds.get_track_sounds(tank_size_class)
	track_sound_slow.stream = track_sounds_map[SpeedType.SLOW]
	track_sound_normal.stream = track_sounds_map[SpeedType.NORMAL]
	track_sound_fast.stream = track_sounds_map[SpeedType.FAST]

	track_pitch_ranges = TrackSounds.TRACK_PITCH_RANGES[tank_size_class]

#* === Main sound and animation process === *#
func process(_left_track_input: float, _right_track_input: float, _linear_velocity: Vector2, _angular_velocity: float) -> void:
	play_engine_sound(_left_track_input, _right_track_input, _linear_velocity)
	play_track_sound(_linear_velocity)
	animate_tracks(_linear_velocity, _angular_velocity)

func play_engine_sound(_left_track_input: float, _right_track_input: float, _linear_velocity: Vector2) -> void:
	var target_force: float = (abs(_left_track_input) + abs(_right_track_input)) / 2.0
	input_force = lerpf(input_force, target_force, 1 * get_physics_process_delta_time()) 
	
	var speed_type := EngineSounds.get_speed_type_from_ratio(input_force)
	var lerped_pitch := EngineSounds.calculate_pitch(input_force, engine_pitch_ranges)
	
	var engine_sounds := [engine_sound_slow, engine_sound_normal, engine_sound_fast]
	var active_sound := _get_sound_player_for_speed_type(speed_type, SoundType.ENGINE)
	
	_crossfade_sounds(engine_sounds, active_sound, lerped_pitch, 2.0)

func play_track_sound(_linear_velocity: Vector2) -> void:
	var abs_speed: float = abs(tank.get_forward_speed(_linear_velocity))
	var speed_ratio: float = clamp(abs_speed / tank.tank_spec.max_speed, 0.0, 1.0)
	
	var speed_type := EngineSounds.get_speed_type_from_ratio(speed_ratio)
	var lerped_pitch := EngineSounds.calculate_pitch(speed_ratio, track_pitch_ranges)
	
	var target_volume_db: float = _calculate_track_volume(speed_ratio)

	var track_sounds :Array[AudioStreamPlayer2D] = [track_sound_slow, track_sound_normal, track_sound_fast]

	if speed_ratio > 0.01:
		var active_sound := _get_sound_player_for_speed_type(speed_type, SoundType.TRACK)
		_crossfade_sounds(track_sounds, active_sound, lerped_pitch, 3.0, target_volume_db)
	else:
		_fade_out_sounds(track_sounds, 3.0)

func _get_sound_player_for_speed_type(speed_type: SpeedType, sound_type: SoundType) -> AudioStreamPlayer2D:
	var is_engine := sound_type == SoundType.ENGINE
	match speed_type:
		SpeedType.SLOW:
			return engine_sound_slow if is_engine else track_sound_slow
		SpeedType.NORMAL:
			return engine_sound_normal if is_engine else track_sound_normal
		SpeedType.FAST:
			return engine_sound_fast if is_engine else track_sound_fast
		_:
			return engine_sound_slow if is_engine else track_sound_slow

func _calculate_track_volume(speed_ratio: float) -> float:
	if speed_ratio >= 0.2:
		return 0.0
	elif speed_ratio > 0.01:
		return lerp(-40.0, 0.0, speed_ratio / 0.2)
	else:
		return SILENT_VOLUME_DB

func _crossfade_sounds(sounds: Array, active_sound: AudioStreamPlayer2D, pitch: float, fade_speed: float, target_volume_db: float = 0.0) -> void:
	var delta: float = get_physics_process_delta_time()
	
	for sp: AudioStreamPlayer2D in sounds:
		if sp == active_sound:
			_fade_in_sound(sp, target_volume_db, pitch, fade_speed * 2, delta)
		else:
			_fade_out_sound(sp, fade_speed, delta)

func _fade_in_sound(sound: AudioStreamPlayer2D, target_volume_db: float, pitch: float, fade_speed: float, delta: float) -> void:
	if not sound.is_playing():
		sound.volume_db = SILENT_VOLUME_DB  # Start quiet for fade-in
		sound.play()
	
	# Fade in - use linear_to_db for proper audio fading
	var current_linear := db_to_linear(sound.volume_db)
	var target_linear := db_to_linear(target_volume_db)
	var new_linear := lerpf(current_linear, target_linear, fade_speed * delta)
	sound.volume_db = linear_to_db(new_linear)
	sound.pitch_scale = pitch

func _fade_out_sound(sound: AudioStreamPlayer2D, fade_speed: float, delta: float) -> void:
	if sound.is_playing():
		# Fade out - use linear_to_db for proper audio fading
		var current_linear := db_to_linear(sound.volume_db)
		var target_linear := 0.001  # Very quiet but not zero to avoid -inf dB
		var new_linear := lerpf(current_linear, target_linear, fade_speed * delta)
		sound.volume_db = linear_to_db(new_linear)
		
		# Stop only when very quiet
		if new_linear <= FADE_THRESHOLD:
			sound.stop()
			sound.volume_db = SILENT_VOLUME_DB

func _fade_out_sounds(sounds: Array[AudioStreamPlayer2D], fade_speed: float) -> void:
	var delta := get_physics_process_delta_time()
	for sound in sounds:
		_fade_out_sound(sound, fade_speed, delta)

func animate_tracks(linear_velocity: Vector2, angular_velocity: float) -> void:
	var tank_speed: float = tank.get_forward_speed(linear_velocity)

	var angular_contribution: float = angular_velocity * tank.tank_spec.track_offset.y
	var left_speed: float = tank_speed + angular_contribution
	var right_speed: float = tank_speed - angular_contribution

	update_track_animation(left_track, left_speed)
	update_track_animation(right_track, right_speed)

func update_track_animation(track_node: AnimatedSprite2D, speed: float) -> void:
	if abs(speed) > 0.01:
		track_node.play("default")
		track_node.flip_v = -speed < 0
		track_node.speed_scale = speed
	else:
		track_node.stop()
		track_node.speed_scale = 0.0

func stop_sounds() -> void:
	var all_sounds :Array[AudioStreamPlayer2D] = [
		engine_sound_slow, engine_sound_normal, engine_sound_fast,
		track_sound_slow, track_sound_normal, track_sound_fast,
	]
	for sound in all_sounds:
		sound.stop()
