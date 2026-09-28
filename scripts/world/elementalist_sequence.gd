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

func configure(caster: PlayerActor, centers: Array[Vector2], requests: Array[DamageRequest], elements: Array[StringName], radius: float, interval: float, once_per_target: bool, marked_bonus: float = 0.0) -> void:
	assert(not centers.is_empty() and centers.size() == requests.size() and centers.size() == elements.size())
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
	if caster == null or not caster.is_alive():
		queue_free()
		return
	_elapsed += maxf(0.0, delta)
	_emit_due_pulses()

func _emit_due_pulses() -> void:
	while _next_pulse < _centers.size() and _elapsed + 0.000001 >= float(_next_pulse) * _interval:
		var index := _next_pulse
		_next_pulse += 1
		pulse_requested.emit(_requests[index].skill_id, _centers[index], _radius, _requests[index].copy(), _elements[index], _marked_bonus, _once_per_target, _hit_ids)
	if _next_pulse >= _centers.size():
		queue_free()
