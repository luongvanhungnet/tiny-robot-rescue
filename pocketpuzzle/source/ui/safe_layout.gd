extends RefCounted

static func insets(safe: Rect2i, physical: Vector2i, logical: Vector2) -> Vector4i:
	if physical.x <= 0 or physical.y <= 0 or not safe.has_area():
		return Vector4i.ZERO
	var clipped: = safe.intersection(Rect2i(Vector2i.ZERO, physical))
	if not clipped.has_area():
		return Vector4i.ZERO
	var scale: = logical / Vector2(physical)
	return Vector4i(ceili(clipped.position.x * scale.x - 0.0001), ceili(clipped.position.y * scale.y - 0.0001), ceili((physical.x - clipped.end.x) * scale.x - 0.0001), ceili((physical.y - clipped.end.y) * scale.y - 0.0001))
