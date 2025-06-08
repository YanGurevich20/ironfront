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

var engine_sounds_map: Dictionary
var engine_pitch_ranges: Dictionary
var input_force: float = 0.0
var track_sounds_map: Dictionary
var track_pitch_ranges: Dictionary

func setup_sounds(tank_size_class: Enums.TankSizeClass) -> void:
	setup_engine_sounds(tank_size_class)
	setup_track_sounds(tank_size_class)

func setup_engine_sounds(engine_size_class: Enums.TankSizeClass) -> void:
	engine_sounds_map = EngineSounds.ENGINE_SOUNDS[engine_size_class]
	engine_pitch_ranges = EngineSounds.ENGINE_PITCH_RANGES[engine_size_class]
	# Assign the correct AudioStream to each engine sound player
	engine_sound_slow.stream = engine_sounds_map[Enums.SpeedType.SLOW]
	engine_sound_normal.stream = engine_sounds_map[Enums.SpeedType.NORMAL]
	engine_sound_fast.stream = engine_sounds_map[Enums.SpeedType.FAST]

func setup_track_sounds(tank_size_class: Enums.TankSizeClass) -> void:
	track_sounds_map = TrackSounds.SMALL_TRACK_SOUNDS if tank_size_class == Enums.TankSizeClass.SMALL else (
		TrackSounds.MEDIUM_TRACK_SOUNDS if tank_size_class == Enums.TankSizeClass.MEDIUM else TrackSounds.LARGE_TRACK_SOUNDS)
	track_sound_slow.stream = track_sounds_map[Enums.SpeedType.SLOW]
	track_sound_normal.stream = track_sounds_map[Enums.SpeedType.NORMAL]
	track_sound_fast.stream = track_sounds_map[Enums.SpeedType.FAST]
	# Assign pitch ranges
	track_pitch_ranges = TrackSounds.TRACK_PITCH_RANGES[tank_size_class]

#* === Main sound and animation process === *#
func process(_left_track_input: float, _right_track_input: float, _linear_velocity: Vector2, _angular_velocity: float) -> void:
	play_engine_sound(_left_track_input, _right_track_input, _linear_velocity)
	play_track_sound(_linear_velocity)
	animate_tracks(_linear_velocity, _angular_velocity)

func play_engine_sound(_left_track_input: float, _right_track_input: float, _linear_velocity: Vector2) -> void:
	var target_force: float = (abs(_left_track_input) + abs(_right_track_input)) / 2.0
	input_force = lerpf(input_force, target_force, 1 * get_physics_process_delta_time()) 
	var speed_type: Enums.SpeedType
	if input_force < 1.0/3.0:
		speed_type = Enums.SpeedType.SLOW
	elif input_force < 2.0/3.0:
		speed_type = Enums.SpeedType.NORMAL
	else:
		speed_type = Enums.SpeedType.FAST

	var sound_player: AudioStreamPlayer2D
	var pitch_range: Vector2 = engine_pitch_ranges[speed_type]
	var t: float
	if speed_type == Enums.SpeedType.SLOW:
		sound_player = engine_sound_slow
		t = input_force * 3.0 # 0 to 1 in slow region
	elif speed_type == Enums.SpeedType.NORMAL:
		sound_player = engine_sound_normal
		t = (input_force - 1.0/3.0) * 3.0
	elif speed_type == Enums.SpeedType.FAST:
		sound_player = engine_sound_fast
		t = (input_force - 2.0/3.0) * 3.0

	var lerped_pitch: float = lerp(pitch_range.x, pitch_range.y, clamp(t, 0.0, 1.0))

	var fade_speed: float = 2.0 # Adjust this to control crossfade speed
	var delta: float = get_physics_process_delta_time()
	
	for sp: AudioStreamPlayer2D in [engine_sound_slow, engine_sound_normal, engine_sound_fast]:
		if sp == sound_player:
			if not sp.is_playing():
				sp.play()
			# Fade in - use linear_to_db for proper audio fading
			var current_linear := db_to_linear(sp.volume_db)
			var target_linear := 1.0 # 0 dB in linear scale
			var new_linear: float = lerp(current_linear, target_linear, fade_speed * delta)
			sp.volume_db = linear_to_db(new_linear)
			sp.pitch_scale = lerped_pitch
		else:
			if sp.is_playing():
				# Fade out - use linear_to_db for proper audio fading
				var current_linear := db_to_linear(sp.volume_db)
				var target_linear := 0.001 # Very quiet but not zero to avoid -inf dB
				var new_linear :float = lerp(current_linear, target_linear, fade_speed * delta)
				sp.volume_db = linear_to_db(new_linear)
				
				# Stop only when very quiet
				if new_linear <= 0.01: # Stop when below 1% volume
					sp.stop()
					sp.volume_db = -80.0 # Reset to very quiet for next fade-in


func play_track_sound(_linear_velocity: Vector2) -> void:
	var abs_speed: float = abs(tank.get_forward_speed(_linear_velocity))
	var speed_ratio: float = clamp(abs_speed / tank.tank_spec.max_speed, 0.0, 1.0)
	var speed_type: Enums.SpeedType
	if speed_ratio < 1.0/3.0:
		speed_type = Enums.SpeedType.SLOW
	elif speed_ratio < 2.0/3.0:
		speed_type = Enums.SpeedType.NORMAL
	else:
		speed_type = Enums.SpeedType.FAST

	var sound_player: AudioStreamPlayer2D
	var pitch_range: Vector2 = track_pitch_ranges[speed_type]
	var t: float
	if speed_type == Enums.SpeedType.SLOW:
		sound_player = track_sound_slow
		t = speed_ratio * 3.0
	elif speed_type == Enums.SpeedType.NORMAL:
		sound_player = track_sound_normal
		t = (speed_ratio - 1.0/3.0) * 3.0
	else:
		sound_player = track_sound_fast
		t = (speed_ratio - 2.0/3.0) * 3.0

	var lerped_pitch: float = lerp(pitch_range.x, pitch_range.y, clamp(t, 0.0, 1.0))
	
	# Calculate target volume based on speed
	var target_volume_db: float = -80.0
	if speed_ratio >= 0.2:
		target_volume_db = 0.0
	elif speed_ratio > 0.01:  # Small threshold to avoid playing at very low speeds
		target_volume_db = lerp(-40.0, 0.0, speed_ratio / 0.2)

	var fade_speed: float = 3.0  # Slightly faster for tracks
	var delta: float = get_physics_process_delta_time()
	
	if speed_ratio > 0.01:  # Only play if moving
		for sp: AudioStreamPlayer2D in [track_sound_slow, track_sound_normal, track_sound_fast]:
			if sp == sound_player:
				if not sp.is_playing():
					sp.volume_db = -80.0  # Start quiet for fade-in
					sp.play()
				# Fade in/adjust volume - use linear_to_db for proper audio fading
				var current_linear := db_to_linear(sp.volume_db)
				var target_linear := db_to_linear(target_volume_db)
				var new_linear := lerpf(current_linear, target_linear, fade_speed * delta)
				sp.volume_db = linear_to_db(new_linear)
				sp.pitch_scale = lerped_pitch
			else:
				if sp.is_playing():
					# Fade out - use linear_to_db for proper audio fading
					var current_linear := db_to_linear(sp.volume_db)
					var target_linear := 0.001  # Very quiet but not zero
					var new_linear: float = lerp(current_linear, target_linear, fade_speed * delta)
					sp.volume_db = linear_to_db(new_linear)
					
					# Stop only when very quiet
					if new_linear <= 0.01:  # Stop when below 1% volume
						sp.stop()
						sp.volume_db = -80.0
	else:
		# Fade out all sounds when stopped
		for sp: AudioStreamPlayer2D in [track_sound_slow, track_sound_normal, track_sound_fast]:
			if sp.is_playing():
				var current_linear := db_to_linear(sp.volume_db)
				var target_linear := 0.001
				var new_linear := lerpf(current_linear, target_linear, fade_speed * delta)
				sp.volume_db = linear_to_db(new_linear)
				
				if new_linear <= 0.01:
					sp.stop()
					sp.volume_db = -80.0

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
	engine_sound_slow.stop()
	engine_sound_normal.stop()
	engine_sound_fast.stop()
	track_sound_slow.stop()
	track_sound_normal.stop()
	track_sound_fast.stop()
