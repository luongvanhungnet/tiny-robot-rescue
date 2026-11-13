extends Node

var sound_enabled: = true
var vibration_enabled: = false
var samples: Dictionary = {}
var _player: AudioStreamPlayer
var _last_play: = -1000

func _ready() -> void :
	_player = AudioStreamPlayer.new()
	_player.volume_db = -18
	add_child(_player)
	samples = {"move": tone([392.0], 0.075), "deliver": tone([523.25, 659.25], 0.09), "undo": tone([349.23], 0.075), "win": tone([523.25, 659.25, 783.99], 0.12)}

static func tone(notes: Array, seconds_per_note: float) -> AudioStreamWAV:
	var rate: = 22050
	var frames: = int(rate * seconds_per_note * notes.size())
	var pcm: = PackedByteArray()
	pcm.resize(frames * 2)
	for i in range(frames):
		var time: = float(i) / rate
		var index: = mini(int(time / seconds_per_note), notes.size() - 1)
		var local_time: = fmod(time, seconds_per_note)
		var envelope: = minf(local_time / 0.008, 1.0) * pow(maxf(0, 1.0 - local_time / seconds_per_note), 1.7)
		var frequency: float = notes[index]
		var wave: = (sin(TAU * frequency * time) + sin(TAU * frequency * 2 * time) * 0.14) * envelope * 0.32
		pcm.encode_s16(i * 2, int(wave * 32767))
	var stream: = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	return stream

func configure(settings: Dictionary) -> void :
	sound_enabled = settings.sound
	vibration_enabled = settings.vibration
	if not sound_enabled and is_instance_valid(_player):
		_player.stop()

func play(kind: String) -> void :
	var now: = Time.get_ticks_msec()
	if now - _last_play < 65 and kind != "win":
		return
	_last_play = now
	if sound_enabled and samples.has(kind) and DisplayServer.get_name() != "headless":
		_player.stream = samples[kind]
		_player.play()
	if vibration_enabled and OS.has_feature("android"):
		Input.vibrate_handheld(35 if kind == "win" else 16, 0.3)

func stop() -> void :
	if is_instance_valid(_player):
		_player.stop()
