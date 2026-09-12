class_name SkillGeometry
extends RefCounted

static func cone_contains(offset: Vector2, direction: Vector2, radius: float, half_angle: float) -> bool:
	return offset.length() <= radius and absf(direction.angle_to(offset.normalized())) <= half_angle

static func cone_outline(origin: Vector2, direction: Vector2, radius: float, half_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array([origin])
	for index: int in range(33):
		var angle := direction.angle() - half_angle + 2.0 * half_angle * index / 32.0
		points.append(origin + Vector2.from_angle(angle) * radius)
	points.append(origin)
	return points
