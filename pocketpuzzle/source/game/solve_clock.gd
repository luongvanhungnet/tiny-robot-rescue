extends RefCounted

var elapsed_ms: = 0
var running: = false
var paused: = false
var _last_ms: = 0

func start(now_ms: int) -> void :
	elapsed_ms = 0
	_last_ms = now_ms
	running = true
	paused = false

func tick(now_ms: int) -> void :
	if running and not paused:
		elapsed_ms += maxi(0, now_ms - _last_ms)
	_last_ms = now_ms

func pause(now_ms: int) -> void :
	tick(now_ms)
	paused = true

func resume(now_ms: int) -> void :
	_last_ms = now_ms
	paused = false

func finish(now_ms: int) -> void :
	tick(now_ms)
	running = false

static func format_time(milliseconds: int) -> String:
	var tenths: = maxi(0, milliseconds) / 100
	return "%02d:%02d.%d" % [tenths / 600, (tenths / 10) % 60, tenths % 10]
