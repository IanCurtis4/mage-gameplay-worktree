class_name GeometerGrammarState
extends RefCounted
## Intrinsic selection and finite ordered delivery. No casts, spending or damage.

var selected_element: StringName = &"fire"
var _next_ticket := 1
var _pending: Array[Dictionary] = []

func select_element(element: StringName) -> bool:
	if element not in GeometerGeometry.ELEMENTS:
		return false
	selected_element = element
	return true

func reserve(point: Vector2, actor_id: int, confirmed_count: int, context: Dictionary = {}, timeout: float = 3.0, element: StringName = &"") -> int:
	var captured_element := selected_element if element == &"" else element
	if captured_element not in GeometerGeometry.ELEMENTS:
		return 0
	if not point.is_finite() or actor_id < 0 or confirmed_count < 0 or confirmed_count + _pending.size() >= GeometerGeometry.MAX_VERTICES or not is_finite(timeout) or timeout <= 0.0 or timeout > 12.0:
		return 0
	var ticket := _next_ticket
	_next_ticket += 1
	_pending.append({"ticket": ticket, "element": captured_element, "point": point, "actor_id": actor_id, "resolved": false, "success": false, "remaining": timeout, "context": context.duplicate(true)})
	return ticket

func resolve(ticket: int, success: bool, position: Vector2) -> Array[Dictionary]:
	var found := false
	for delivery: Dictionary in _pending:
		if int(delivery["ticket"]) == ticket:
			if bool(delivery["resolved"]):
				return []
			delivery["resolved"] = true
			delivery["success"] = success and position.is_finite()
			if bool(delivery["success"]):
				delivery["point"] = position
				delivery["last_valid_ground"] = position
				delivery["impact_age"] = 0.0
			found = true
			break
	if not found:
		return []
	return _drain_ready()

func advance(delta: float) -> Array[Dictionary]:
	if not is_finite(delta) or delta <= 0.0:
		return []
	for delivery: Dictionary in _pending:
		if bool(delivery["resolved"]):
			if bool(delivery["success"]):
				delivery["impact_age"] = float(delivery["impact_age"]) + delta
			continue
		delivery["remaining"] = maxf(0.0, float(delivery["remaining"]) - delta)
		if float(delivery["remaining"]) <= 0.0:
			delivery["resolved"] = true
			delivery["success"] = false
	return _drain_ready()

func refresh_impacts(alive_positions: Dictionary[int, Vector2], navigation: ArenaNavigation) -> void:
	# A confirmed impact is already an anchor, even while FIFO holds its commit.
	for delivery: Dictionary in _pending:
		if not bool(delivery["resolved"]) or not bool(delivery["success"]):
			continue
		var carrier_id := int(delivery["actor_id"])
		if carrier_id == 0:
			continue
		if not alive_positions.has(carrier_id):
			delivery["actor_id"] = 0
			delivery["point"] = delivery["last_valid_ground"]
			continue
		var point: Vector2 = alive_positions[carrier_id]
		delivery["point"] = point
		if point.is_finite() and navigation != null and navigation.is_segment_clear(point, point, 0.0):
			delivery["last_valid_ground"] = point

func _drain_ready() -> Array[Dictionary]:
	var ready: Array[Dictionary] = []
	while not _pending.is_empty() and bool(_pending[0]["resolved"]):
		ready.append(_pending.pop_front().duplicate(true))
	return ready

func pending_count() -> int:
	return _pending.size()

func pending_snapshot() -> Array[Dictionary]:
	return _pending.duplicate(true)

func clear() -> void:
	_pending.clear()
	# Tickets never reset: late impacts cannot claim a new construction's ticket.
