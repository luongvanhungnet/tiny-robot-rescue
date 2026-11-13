extends RefCounted

const Hint = preload("res://game/puzzle_hint.gd")
const Parcel = preload("res://game/parcel_rules.gd")
const Block = preload("res://game/block_rules.gd")
const MAX_STATES: = 2500
const MAX_WORK_USEC: = 180000
var done: = false
var result: Dictionary = {}
var expanded: = 0
var work_usec: = 0
var peak_slice_usec: = 0
var state_limit: = MAX_STATES
var work_limit_usec: = MAX_WORK_USEC
var reason: = ""
var _mode: String
var _template
var _route: Dictionary
var _fallback: Dictionary
var _nodes: Array = []
var _seen: = {}
var _cursor: = 0
var _active_game
var _active_first: Array = []
var _active_actions: Array = []
var _action_cursor: = 0

func _init(mode: String, level: Dictionary, live) -> void :
	var started: = Time.get_ticks_usec()
	_mode = mode
	_template = Parcel.new() if mode == "parcel" else Block.new()
	_template.setup(level)
	if live.won():
		done = true
		reason = "won"
		return
	_route = Hint.verified_route(mode, level)
	_fallback = Hint.from_route(mode, live, _route)
	var key: = Hint.state_key(mode, live)
	if _route.has(key):
		result = {"kind": "move", "action": _route[key].duplicate(), "source": "verified"}
		done = true
		reason = "verified"
	elif _route.is_empty():
		done = true
		reason = "invalid_reference"
	else:
		_seen[key] = true
		_nodes.append({"state": _snapshot(live), "first": []})
	work_usec = Time.get_ticks_usec() - started

func _snapshot(game) -> Dictionary:
	if _mode == "parcel":
		return {"queues": game.queues.duplicate(true), "waiting": game.waiting.duplicate(), "delivered": game.delivered}
	return {"pieces": game.pieces.duplicate(true)}

func _board(state: Dictionary):
	if _mode == "parcel":
		var game = Parcel.new()
		game.route = _template.route
		game.capacity = _template.capacity
		game.queues = state.queues.duplicate(true)
		game.waiting = state.waiting.duplicate()
		game.delivered = state.delivered
		return game
	var game = Block.new()
	game.size = _template.size
	game.gates = _template.gates
	game.pieces = state.pieces.duplicate(true)
	return game

func _finish_fallback(why: String) -> void :
	result = _fallback.duplicate(true)
	result["source"] = "fallback"
	done = true
	reason = why
	_nodes.clear()
	_active_game = null
	_active_actions.clear()

func step(max_expansions: = 16, slice_usec: = 2500) -> void :
	if done:
		return
	var started: = Time.get_ticks_usec()
	var count: = 0
	var operations: = 0
	while not done:
		if work_usec + Time.get_ticks_usec() - started >= work_limit_usec or _seen.size() >= state_limit:
			_finish_fallback("limit")
			break
		if operations > 0 and Time.get_ticks_usec() - started >= slice_usec:
			break
		if _active_game == null:
			if _cursor >= _nodes.size():
				_finish_fallback("exhausted")
				break
			if count >= max_expansions:
				break
			var node: Dictionary = _nodes[_cursor]
			_nodes[_cursor] = null
			_cursor += 1
			expanded += 1
			count += 1
			_active_game = _board(node.state)
			_active_first = node.first
			_active_actions = []
			_action_cursor = 0
			if _mode == "parcel":
				for lane in range(_active_game.queues.size()):
					_active_actions.append([lane])
			else:
				for index in range(_active_game.pieces.size()):
					if _active_game.pieces[index].out:
						continue
					for direction in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
						_active_actions.append([index, direction.x, direction.y])
			operations += 1
			continue
		if _action_cursor >= _active_actions.size():
			_active_game = null
			continue
		var action: Array = _active_actions[_action_cursor]
		_action_cursor += 1
		operations += 1
		var accepted: bool = _active_game.send(action[0]) if _mode == "parcel" else _active_game.move_piece(action[0], Vector2i(action[1], action[2]))
		if not accepted:
			continue
		var key: = Hint.state_key(_mode, _active_game)
		var first: Array = action if _active_first.is_empty() else _active_first
		if _active_game.won() or _route.has(key):
			result = {"kind": "move", "action": first.duplicate(), "source": "search"}
			done = true
			reason = "found"
			_nodes.clear()
			_active_game = null
			_active_actions.clear()
			break
		if not _seen.has(key) and _seen.size() < state_limit:
			_seen[key] = true
			_nodes.append({"state": _snapshot(_active_game), "first": first.duplicate()})
		_active_game.undo()
	var elapsed: = Time.get_ticks_usec() - started
	work_usec += elapsed
	peak_slice_usec = maxi(peak_slice_usec, elapsed)

func visited_count() -> int:
	return _seen.size()
