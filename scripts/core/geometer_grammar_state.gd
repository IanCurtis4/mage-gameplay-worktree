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
			continue
		delivery["remaining"] = maxf(0.0, float(delivery["remaining"]) - delta)
		if float(delivery["remaining"]) <= 0.0:
			delivery["resolved"] = true
			delivery["success"] = false
	return _drain_ready()

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
