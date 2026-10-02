class_name GeometerGeometry
extends RefCounted
## Shared arena-space geometry for construction, previews and effect consumers.

const MAX_VERTICES := 3
const MIN_SEPARATION := 24.0
const MAX_EDGE_LENGTH := 600.0
const MIN_TRIANGLE_AREA := 256.0
const ELEMENTS: Array[StringName] = [&"fire", &"ice", &"lightning"]

static func validate(points: PackedVector2Array, navigation: ArenaNavigation) -> Dictionary:
	if points.is_empty() or points.size() > MAX_VERTICES:
		return {"ok": false, "reason": "Use de um a três vértices."}
	if navigation == null:
		return {"ok": false, "reason": "Geometria da arena indisponível."}
	for point: Vector2 in points:
		if not point.is_finite() or not navigation.is_segment_clear(point, point, 0.0):
			return {"ok": false, "reason": "Vértice fora do chão livre."}
	for first: int in range(points.size()):
		for second: int in range(first + 1, points.size()):
			var distance := points[first].distance_to(points[second])
			if distance < MIN_SEPARATION:
				return {"ok": false, "reason": "Separe os vértices por ao menos 24 unidades."}
			if distance > MAX_EDGE_LENGTH:
				return {"ok": false, "reason": "Aresta excede 600 unidades."}
			if not navigation.is_segment_clear(points[first], points[second], 0.0):
				return {"ok": false, "reason": "Aresta atravessa um obstáculo."}
	if points.size() == 3:
		if triangle_area(points) < MIN_TRIANGLE_AREA:
			return {"ok": false, "reason": "Triângulo estreito demais."}
		if not navigation.is_polygon_clear(points):
			return {"ok": false, "reason": "Área atravessa um obstáculo."}
	return {"ok": true, "reason": ""}

static func triangle_area(points: PackedVector2Array) -> float:
	if points.size() != 3:
		return 0.0
	return absf((points[1] - points[0]).cross(points[2] - points[0])) * 0.5

static func triangle_contains(points: PackedVector2Array, center: Vector2, radius: float = 0.0) -> bool:
	if points.size() != 3 or not center.is_finite() or not is_finite(radius) or radius < 0.0 or triangle_area(points) < MIN_TRIANGLE_AREA:
		return false
	for point: Vector2 in points:
		if not point.is_finite():
			return false
	if Geometry2D.is_point_in_polygon(center, points):
		return true
	for index: int in range(3):
		if center.distance_to(Geometry2D.get_closest_point_to_segment(center, points[index], points[(index + 1) % 3])) <= radius:
			return true
	return false

static func triangle_rank(elements: Array[StringName]) -> int:
	if elements.size() != 3:
		return 0
	var distinct: Array[StringName] = []
	for element: StringName in elements:
		if element not in ELEMENTS:
			return 0
		if not distinct.has(element):
			distinct.append(element)
	return 1 if distinct.size() == 1 else 3 if distinct.size() == 2 else 5
