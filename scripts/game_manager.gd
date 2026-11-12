extends Node

const TOTAL_VERTICAL_SLICE_LEVELS := 10

var current_level_id: int = 1
var _sfx_player: AudioStreamPlayer

func _ready() -> void:
	current_level_id = clampi(int(ProgressSave.data.get("last_selected_level", 1)), 1, TOTAL_VERTICAL_SLICE_LEVELS)
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)

func start_level(level_id: int) -> void:
	current_level_id = clampi(level_id, 1, TOTAL_VERTICAL_SLICE_LEVELS)
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")

func go_home() -> void:
	get_tree().change_scene_to_file("res://scenes/home.tscn")

func go_level_select() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func play_tone(freq_hz: float, duration_sec: float = 0.12, volume_db: float = -10.0) -> void:
	if not bool(ProgressSave.data["settings"].get("sound_enabled", true)):
		return
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration_sec)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	var buf := PackedByteArray()
	buf.resize(num_samples)
	for i in range(num_samples):
		var t := float(i) / float(sample_rate)
		var env := 1.0 - (float(i) / float(num_samples))
		var val := sin(TAU * freq_hz * t) * env
		buf[i] = int(clampf(val * 127.0, -128.0, 127.0)) & 0xFF
	stream.data = buf
	_sfx_player.stream = stream
	_sfx_player.volume_db = volume_db
	_sfx_player.play()
