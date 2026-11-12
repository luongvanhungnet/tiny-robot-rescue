extends Node

const TOTAL_LEVELS := 60
const TOTAL_VERTICAL_SLICE_LEVELS := 60

var current_level_id: int = 1
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
var _music_player: AudioStreamPlayer
var _music_paused_by_bg: bool = false

func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	var ps: Variant = get_node_or_null("/root/ProgressSave")
	if ps != null:
		current_level_id = clampi(int(ps.data.get("last_selected_level", 1)), 1, TOTAL_LEVELS)
	
	for i in range(4):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)
	
	_music_player = AudioStreamPlayer.new()
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	_init_background_music()
	refresh_music_state()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _music_player != null and _music_player.playing:
			_music_player.stream_paused = true
			_music_paused_by_bg = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _music_paused_by_bg:
			_music_paused_by_bg = false
			refresh_music_state()

func start_level(level_id: int) -> void:
	current_level_id = clampi(level_id, 1, TOTAL_LEVELS)
	get_tree().call_deferred("change_scene_to_file", "res://scenes/gameplay.tscn")

func go_home() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/home.tscn")

func go_level_select() -> void:
	get_tree().call_deferred("change_scene_to_file", "res://scenes/level_select.tscn")

func is_sound_enabled() -> bool:
	var ps: Variant = get_node_or_null("/root/ProgressSave")
	if ps == null:
		return true
	return bool(ps.data["settings"].get("sound_enabled", true))

func is_music_enabled() -> bool:
	var ps: Variant = get_node_or_null("/root/ProgressSave")
	if ps == null:
		return true
	return bool(ps.data["settings"].get("music_enabled", true))

func is_vibration_enabled() -> bool:
	var ps: Variant = get_node_or_null("/root/ProgressSave")
	if ps == null:
		return true
	return bool(ps.data["settings"].get("vibration_enabled", true))

func is_reduced_motion() -> bool:
	var ps: Variant = get_node_or_null("/root/ProgressSave")
	if ps == null:
		return false
	return bool(ps.data["settings"].get("reduced_motion", false))

func is_clean_capture_mode() -> bool:
	var ps: Variant = get_node_or_null("/root/ProgressSave")
	if ps == null:
		return false
	return bool(ps.data["settings"].get("clean_capture_mode", false))

func vibrate(duration_ms: int = 18) -> void:
	if not is_vibration_enabled():
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms)

func refresh_music_state() -> void:
	if _music_player == null:
		return
	_music_player.stream_paused = false
	if is_music_enabled():
		if not _music_player.playing:
			_music_player.play()
	else:
		_music_player.stop()

func _init_background_music() -> void:
	# Generate a lightweight, playful 4-second chiptune arpeggio loop (8-bit, ~88KB)
	var sample_rate: int = 22050
	var bpm: float = 120.0
	var step_sec: float = 60.0 / bpm / 2.0 # eighth notes = 0.25s
	var notes: Array[float] = [
		261.63, 329.63, 392.00, 523.25, 392.00, 329.63, 293.66, 392.00,
		220.00, 261.63, 329.63, 440.00, 329.63, 261.63, 196.00, 293.66
	]
	var total_sec: float = step_sec * float(notes.size())
	var total_samples: int = maxi(1, int(float(sample_rate) * total_sec))
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(total_samples)
	var step_samples: int = maxi(1, int(float(sample_rate) * step_sec))
	for i in range(total_samples):
		@warning_ignore("integer_division")
		var idx: int = mini(i / step_samples, notes.size() - 1)
		var local_i: int = i % step_samples
		var env: float = pow(1.0 - (float(local_i) / float(step_samples)), 1.6)
		var t: float = float(i) / float(sample_rate)
		var freq: float = notes[idx]
		var wave: float = sin(TAU * freq * t) * 0.65 + sin(TAU * (freq * 0.5) * t) * 0.25
		buf[i] = int(clampf(wave * env * 42.0, -128.0, 127.0)) & 0xFF
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = total_samples
	stream.data = buf
	_music_player.stream = stream
	_music_player.volume_db = -18.0

func play_tone(freq_hz: float, duration_sec: float = 0.12, volume_db: float = -10.0, freq_end_hz: float = -1.0) -> void:
	if not is_sound_enabled() or _sfx_players.is_empty():
		return
	var sample_rate: int = 22050
	var num_samples: int = maxi(1, int(float(sample_rate) * duration_sec))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	var buf: PackedByteArray = PackedByteArray()
	buf.resize(num_samples)
	var phase: float = 0.0
	for i in range(num_samples):
		var prog: float = float(i) / float(num_samples)
		var env: float = 1.0 - prog
		var f: float = freq_hz if freq_end_hz < 0.0 else lerpf(freq_hz, freq_end_hz, prog)
		phase += TAU * f / float(sample_rate)
		var val: float = sin(phase) * env
		buf[i] = int(clampf(val * 120.0, -128.0, 127.0)) & 0xFF
	stream.data = buf
	var player: AudioStreamPlayer = _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()

func play_impact_spark() -> void:
	play_tone(420.0, 0.07, -14.0, 220.0)

func play_spring_boing() -> void:
	play_tone(240.0, 0.18, -9.0, 620.0)

func play_switch_click() -> void:
	play_tone(540.0, 0.10, -8.0, 780.0)

func play_win_fanfare() -> void:
	play_tone(523.25, 0.30, -8.0, 1046.5)

func play_fail_zap() -> void:
	play_tone(280.0, 0.28, -7.0, 95.0)
