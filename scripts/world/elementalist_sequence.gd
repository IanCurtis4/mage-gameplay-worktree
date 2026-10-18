extends Node2D
## Finite simulation-time pulses; no Timer, damage formula or persistent state.

signal pulse_requested(skill_id: StringName, center: Vector2, radius: float, request: DamageRequest, element: StringName, marked_bonus: float, once_per_target: bool, hit_ids: Dictionary)

var _caster: WeakRef
var _centers: Array[Vector2] = []
var _requests: Array[DamageRequest] = []
var _elements: Array[StringName] = []
var _radius := 0.0
var _interval := 0.0
var _marked_bonus := 0.0
var _once_per_target := false
var _hit_ids: Dictionary[int, bool] = {}
var _elapsed := 0.0
var _next_pulse := 0
var _world_areas: Array[WorldEffectArea] = []
var world_failure: StringName = &""
signal world_pulse_requested(skill_id: StringName, area: WorldEffectArea, radius: float, request: DamageRequest, element: StringName, marked_bonus: float, once_per_target: bool, hit_ids: Dictionary)

func configure_world(caster: PlayerActor, anchors: Array[ExpeditionWorldPoint], requests: Array[DamageRequest], elements: Array[StringName], radius: float, interval: float, once_per_target: bool, revision: int, marked_bonus: float = 0.0) -> Dictionary:
	if caster == null or caster.world_motion == null or anchors.is_empty() or anchors.size() != requests.size() or anchors.size() != elements.size(): return {"ok":false,"error_code":&"invalid_sequence"}
	if not caster.world_motion.is_current_world() or not is_finite(radius) or radius < 0.0 or not is_finite(interval) or interval < 0.0: return {"ok":false,"error_code":&"invalid_sequence"}
	for request: DamageRequest in requests:
		if request == null: return {"ok":false,"error_code":&"invalid_request"}
	var areas: Array[WorldEffectArea] = []
	var centers: Array[Vector2] = []
	for anchor: ExpeditionWorldPoint in anchors:
		var area := WorldEffectArea.new()
		var valid := area.configure(caster.world_motion.geometry,anchor,caster.world_motion.profile(),&"ground_connected",revision)
		if not valid["ok"]: return valid
		areas.append(area)
		centers.append(Vector2.ZERO) # Presentation placeholder, never a gameplay distance.
	_world_areas = areas
	configure(caster,centers,requests,elements,radius,interval,once_per_target,marked_bonus)
	return {"ok":true,"error_code":&""}


func configure(caster: PlayerActor, centers: Array[Vector2], requests: Array[DamageRequest], elements: Array[StringName], radius: float, interval: float, once_per_target: bool, marked_bonus: float = 0.0) -> void:
	assert(not centers.is_empty() and centers.size() == requests.size() and centers.size() == elements.size())
	if caster.world_motion != null and _world_areas.is_empty(): world_failure = &"world_anchor_required"; return
	_caster = weakref(caster)
	_centers = centers.duplicate()
	for request: DamageRequest in requests:
		_requests.append(request.copy())
	_elements = elements.duplicate()
	_radius = radius
	_interval = interval
	_once_per_target = once_per_target
	_marked_bonus = marked_bonus
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_emit_due_pulses()

func _process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	var caster := _caster.get_ref() as PlayerActor if _caster != null else null
	if caster == null or not caster.is_alive() or (not _world_areas.is_empty() and not caster.world_motion.is_current_world()):
		queue_free()
		return
	_elapsed += maxf(0.0, delta)
	_emit_due_pulses()

func _emit_due_pulses() -> void:
	while _next_pulse < _centers.size() and _elapsed + 0.000001 >= float(_next_pulse) * _interval:
		var index := _next_pulse
		_next_pulse += 1
		if not _world_areas.is_empty():
			world_pulse_requested.emit(_requests[index].skill_id,_world_areas[index],_radius,_requests[index].copy(),_elements[index],_marked_bonus,_once_per_target,_hit_ids)
		else:
			pulse_requested.emit(_requests[index].skill_id, _centers[index], _radius, _requests[index].copy(), _elements[index], _marked_bonus, _once_per_target, _hit_ids)
	if _next_pulse >= _centers.size():
		queue_free()
