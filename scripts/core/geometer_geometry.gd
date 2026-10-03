class_name GeometerGeometry
extends RefCounted
## Shared arena-space geometry for construction, previews and effect consumers.

const MAX_VERTICES := 3
const MIN_SEPARATION := 24.0
const MAX_EDGE_LENGTH := 600.0
const MIN_TRIANGLE_AREA := 256.0
const WALL_HALF_WIDTH := 12.0
const CONTACT_EPSILON := 0.00001
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

static func wall_contact(from: Vector2, to: Vector2, first: Vector2, second: Vector2, radius: float = 0.0) -> Dictionary:
	# First contact with the finite capsule. Position stays on the actual motion;
	# wall_point is its closest point on A/B, not a teleport destination.
	if not valid_wall_motion(from, to, first, second, radius):
		return {}
	var axis := (second - first).normalized()
	var normal := Vector2(-axis.y, axis.x)
	var offset := from - first
	var step := to - from
	var local_from := Vector2(offset.dot(axis), offset.dot(normal))
	var local_step := Vector2(step.dot(axis), step.dot(normal))
	var width := WALL_HALF_WIDTH + radius
	var length := first.distance_to(second)
	var low := 0.0
	var high := 1.0
	var rectangle_hit := true
	for coordinate: int in range(2):
		var minimum := 0.0 if coordinate == 0 else -width
		var maximum := length if coordinate == 0 else width
		if absf(local_step[coordinate]) <= CONTACT_EPSILON:
			if local_from[coordinate] < minimum or local_from[coordinate] > maximum:
				rectangle_hit = false
				break
		else:
			var near := (minimum - local_from[coordinate]) / local_step[coordinate]
			var far := (maximum - local_from[coordinate]) / local_step[coordinate]
			low = maxf(low, minf(near, far))
			high = minf(high, maxf(near, far))
			if low > high:
				rectangle_hit = false
				break
	var fraction := low if rectangle_hit else 2.0
	for endpoint: Vector2 in [first, second]:
		var delta := from - endpoint
		var a := step.length_squared()
		var b := 2.0 * delta.dot(step)
		var c := delta.length_squared() - width * width
		if c <= 0.0:
			fraction = 0.0
			continue
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var near := (-b - sqrt(discriminant)) / (2.0 * a)
			if near >= 0.0 and near <= 1.0:
				fraction = minf(fraction, near)
	if fraction > 1.0:
		return {}
	var point := from.lerp(to, fraction)
	return {"fraction": fraction, "position": point, "wall_point": Geometry2D.get_closest_point_to_segment(point, first, second)}

static func wall_crossing(from: Vector2, to: Vector2, first: Vector2, second: Vector2, radius: float = 0.0) -> Dictionary:
	if not valid_wall_motion(from, to, first, second, radius):
		return {}
	var normal := Vector2(-(second - first).y, (second - first).x).normalized()
	var before := (from - first).dot(normal)
	var after := (to - first).dot(normal)
	# Reaching/staying on the centerline alone is not crossing it.
	if absf(after) <= CONTACT_EPSILON or before * after > 0.0:
		return {}
	var fraction := before / (before - after)
	var point := from.lerp(to, fraction)
	var closest := Geometry2D.get_closest_point_to_segment(point, first, second)
	if point.distance_to(closest) > WALL_HALF_WIDTH + radius:
		return {}
	return {"fraction": fraction, "position": point, "wall_point": closest}

static func valid_wall_motion(from: Vector2, to: Vector2, first: Vector2, second: Vector2, radius: float) -> bool:
	if not from.is_finite() or not to.is_finite() or not first.is_finite() or not second.is_finite() or not is_finite(radius) or radius < 0.0 or from.distance_squared_to(to) <= CONTACT_EPSILON * CONTACT_EPSILON:
		return false
	var length := first.distance_to(second)
	return length >= MIN_SEPARATION and length <= MAX_EDGE_LENGTH
