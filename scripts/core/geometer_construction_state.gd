class_name GeometerConstructionState
extends RefCounted
## One run-local construction. Geometry/transactions only; never spends or deals damage.

enum Shape { EMPTY, VERTEX, PREPARATION, WALL, TRIANGLE }

var grammar := GeometerGrammarState.new()
var vertices: Array[GeometerAnchor] = []
var shape: Shape = Shape.EMPTY
var suspended := false
var figure_remaining := 0.0
var construction_id := 0
var _next_construction_id := 1
var _closed_once := false

func positions() -> PackedVector2Array:
	var points := PackedVector2Array()
	for anchor: GeometerAnchor in vertices:
		points.append(anchor.position)
	return points

func elements() -> Array[StringName]:
	var tokens: Array[StringName] = []
	for anchor: GeometerAnchor in vertices:
		tokens.append(anchor.element)
	return tokens

func preview_shot(point: Vector2, third: bool, triangle_rank: int, navigation: ArenaNavigation, element: StringName = &"") -> Dictionary:
	var points := positions()
	var tokens := elements()
	for pending: Dictionary in grammar.pending_snapshot():
		points.append(pending["point"])
		tokens.append(pending["element"])
	if (third and (vertices.size() != 2 or grammar.pending_count() > 0)) or (not third and points.size() >= 2):
		return {"ok": false, "reason": "Use Triangulação para o terceiro vértice." if not third else "Confirme dois vértices antes de triangular."}
	points.append(point)
	tokens.append(grammar.selected_element if element == &"" else element)
	return _validate_candidate(points, tokens, triangle_rank, navigation)

func reserve_shot(point: Vector2, actor_id: int, third: bool, triangle_rank: int, navigation: ArenaNavigation, vertex_duration: float = 8.0, figure_duration: float = 6.0, element: StringName = &"") -> int:
	if not _valid_durations(vertex_duration, figure_duration) or not preview_shot(point, third, triangle_rank, navigation, element)["ok"] or actor_id < 0:
		return 0
	return grammar.reserve(point, actor_id, vertices.size(), {"triangle_rank": triangle_rank, "vertex_duration": vertex_duration, "figure_duration": figure_duration}, 3.0, element)

func resolve_shot(ticket: int, success: bool, point: Vector2, alive_positions: Dictionary[int, Vector2], navigation: ArenaNavigation) -> Array[Dictionary]:
	refresh(alive_positions, navigation)
	return _commit_deliveries(grammar.resolve(ticket, success, point), alive_positions, navigation)

func _commit_deliveries(deliveries: Array[Dictionary], alive_positions: Dictionary[int, Vector2], navigation: ArenaNavigation) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for delivery: Dictionary in deliveries:
		var result := {"ok": false, "reason": "Disparo perdido.", "ticket": delivery["ticket"], "formation": false}
		if bool(delivery["success"]):
			var carrier_id := int(delivery["actor_id"])
			var point: Vector2 = delivery["point"]
			# A successful impact waiting for earlier shots may outlive its carrier.
			# It deposits at that impact's ground point, without binding a corpse.
			if carrier_id > 0:
				if alive_positions.has(carrier_id):
					point = alive_positions[carrier_id]
				else:
					carrier_id = 0
			var context: Dictionary = delivery["context"]
			result = add_vertex(delivery["element"], point, carrier_id, int(context["triangle_rank"]), navigation, float(context["vertex_duration"]), float(context["figure_duration"]))
			result["ticket"] = delivery["ticket"]
		results.append(result)
	return results

func add_vertex(element: StringName, point: Vector2, carrier_id: int, triangle_rank: int, navigation: ArenaNavigation, vertex_duration: float = 8.0, figure_duration: float = 6.0) -> Dictionary:
	if vertices.size() >= GeometerGeometry.MAX_VERTICES or carrier_id < 0 or not _valid_durations(vertex_duration, figure_duration):
		return {"ok": false, "reason": "Construção completa ou duração inválida.", "formation": false}
	var points := positions()
	var tokens := elements()
	points.append(point)
	tokens.append(element)
	var result := _validate_candidate(points, tokens, triangle_rank, navigation)
	result["formation"] = false
	if not result["ok"]:
		return result
	if vertices.is_empty():
		construction_id = _next_construction_id
		_next_construction_id += 1
	vertices.append(GeometerAnchor.create(element, point, carrier_id, vertex_duration))
	shape = _classify(tokens)
	suspended = false
	if shape in [Shape.WALL, Shape.TRIANGLE] and figure_remaining <= 0.0:
		figure_remaining = figure_duration
	if shape == Shape.TRIANGLE and not _closed_once:
		_closed_once = true
		result["formation"] = true
	return result

func edit(point: Vector2, carrier_id: int, rewrite: bool, triangle_rank: int, navigation: ArenaNavigation, vertex_duration: float = 8.0, figure_duration: float = 6.0) -> Dictionary:
	if vertices.is_empty() or grammar.pending_count() > 0 or carrier_id < 0 or not _valid_durations(vertex_duration, figure_duration):
		return {"ok": false, "reason": "Sem vértice editável ou disparo em trânsito."}
	var candidate: Array[GeometerAnchor] = vertices.duplicate()
	var element := grammar.selected_element if rewrite else candidate[-1].element
	if rewrite:
		candidate.pop_front()
	else:
		candidate.pop_back()
	candidate.append(GeometerAnchor.create(element, point, carrier_id, vertex_duration))
	var points := PackedVector2Array()
	var tokens: Array[StringName] = []
	for anchor: GeometerAnchor in candidate:
		points.append(anchor.position)
		tokens.append(anchor.element)
	var result := _validate_candidate(points, tokens, triangle_rank, navigation)
	if not result["ok"]:
		return result
	vertices = candidate
	shape = _classify(tokens)
	suspended = false
	if shape in [Shape.WALL, Shape.TRIANGLE] and figure_remaining <= 0.0:
		figure_remaining = figure_duration
	result["formation"] = false
	return result

func refresh(alive_positions: Dictionary[int, Vector2], navigation: ArenaNavigation) -> void:
	for anchor: GeometerAnchor in vertices:
		anchor.refresh(alive_positions, navigation)
	suspended = not vertices.is_empty() and not GeometerGeometry.validate(positions(), navigation)["ok"]

func advance(delta: float, alive_positions: Dictionary[int, Vector2], navigation: ArenaNavigation) -> Array[Dictionary]:
	if not is_finite(delta) or delta <= 0.0:
		return []
	refresh(alive_positions, navigation)
	for anchor: GeometerAnchor in vertices:
		anchor.advance(delta)
		if anchor.remaining <= 0.0:
			clear()
			return []
	if figure_remaining > 0.0:
		figure_remaining = maxf(0.0, figure_remaining - delta)
		if figure_remaining <= 0.0:
			clear()
			return []
	return _commit_deliveries(grammar.advance(delta), alive_positions, navigation)

func has_active_figure() -> bool:
	return shape in [Shape.WALL, Shape.TRIANGLE] and not suspended and figure_remaining > 0.0

func consume_collapse() -> Dictionary:
	if not has_active_figure():
		return {}
	var captured := {"construction_id": construction_id, "shape": shape, "points": positions(), "elements": elements(), "remaining": figure_remaining}
	clear()
	return captured

func clear() -> void:
	vertices.clear()
	grammar.clear()
	shape = Shape.EMPTY
	suspended = false
	figure_remaining = 0.0
	construction_id = 0
	_closed_once = false

func _validate_candidate(points: PackedVector2Array, tokens: Array[StringName], triangle_rank: int, navigation: ArenaNavigation) -> Dictionary:
	for token: StringName in tokens:
		if token not in GeometerGeometry.ELEMENTS:
			return {"ok": false, "reason": "Elemento inválido."}
	if tokens.size() == 3:
		var required := GeometerGeometry.triangle_rank(tokens)
		if required <= 0 or triangle_rank < required:
			return {"ok": false, "reason": "Receita requer Triangulação R%d." % required}
	return GeometerGeometry.validate(points, navigation)

func _classify(tokens: Array[StringName]) -> Shape:
	if tokens.size() == 3:
		return Shape.TRIANGLE
	if tokens.size() == 2:
		return Shape.PREPARATION if tokens[0] == tokens[1] else Shape.WALL
	return Shape.VERTEX if tokens.size() == 1 else Shape.EMPTY

func _valid_durations(vertex_duration: float, figure_duration: float) -> bool:
	return is_finite(vertex_duration) and is_finite(figure_duration) and vertex_duration > 0.0 and vertex_duration <= 12.0 and figure_duration > 0.0 and figure_duration <= 12.0
