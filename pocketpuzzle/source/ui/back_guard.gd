extends RefCounted


const PAIR_WINDOW_MS: = 100
var _last: = -1000

func accept(now_ms: int) -> bool:
	if now_ms - _last < PAIR_WINDOW_MS:
		return false
	_last = now_ms
	return true
