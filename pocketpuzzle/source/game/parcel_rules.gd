extends RefCounted



var queues: Array = []
var route: Array = []
var capacity: int = 3
var waiting: Array = []
var delivered: int = 0
var moves: int = 0
var history: Array = []

func setup(level: Dictionary) -> void :
	queues = level.queues.duplicate(true)

	for lane in range(queues.size()):
		queues[lane] = queues[lane].map( func(value): return int(value))
	route = level.route.map( func(value): return int(value))
	capacity = int(level.capacity)
	waiting.clear()
	delivered = 0
	moves = 0
	history.clear()

func send(lane: int) -> bool:
	if lane < 0 or lane >= queues.size() or queues[lane].is_empty() or won():
		return false
	var color: int = int(queues[lane][0])
	if color != int(route[delivered]) and waiting.size() >= capacity:
		return false
	history.append({"queues": queues.duplicate(true), "waiting": waiting.duplicate(),
		"delivered": delivered, "moves": moves})
	queues[lane].pop_front()
	moves += 1
	if color == int(route[delivered]):
		delivered += 1
	else:
		waiting.append(color)
	while delivered < route.size() and waiting.has(route[delivered]):
		waiting.erase(route[delivered])
		delivered += 1
	return true

func undo() -> bool:
	if history.is_empty():
		return false
	var previous: Dictionary = history.pop_back()
	queues = previous.queues
	waiting = previous.waiting
	delivered = previous.delivered
	moves = previous.moves
	return true

func won() -> bool:
	return not route.is_empty() and delivered == route.size()

func stuck() -> bool:
	if won() or waiting.size() < capacity:
		return false
	for queue in queues:
		if not queue.is_empty() and queue[0] == route[delivered]:
			return false
	return true
