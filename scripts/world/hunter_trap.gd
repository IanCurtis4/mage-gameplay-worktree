class_name HunterTrap
extends PlayerTrap
## One primary activation with a captured, deterministic area victim list.
## Application and opening claims belong to the controller, never to drawing.

signal sprung(trap: HunterTrap, victims: Array[CombatActor])

var tuning: Dictionary = {}
var damage_request: DamageRequest
var opening_request: DamageRequest
var effect_radius := 0.0
var _targets: Array[CombatActor] = []

func configure_hunter(placement: Vector2, rank: int, request: DamageRequest, opening: DamageRequest, targets: Array[CombatActor], lifetime: float) -> void:
	assert(request != null and request.skill_id in HunterMath.NEW_TRAP_IDS and opening != null)
	tuning = HunterTuning.values(request.skill_id, rank)
	assert(not tuning.is_empty())
	damage_request = request.copy()
	opening_request = opening.copy()
	_targets.clear()
	for victim: CombatActor in targets:
		if victim != null and is_instance_valid(victim) and victim.get_instance_id() != request.source_id and victim not in _targets and _targets.size() < HunterTuning.OPENING_CAP:
			_targets.append(victim)
	effect_radius = float(tuning.get("field_radius", tuning.get("radius", 52.0)))
	triggered.connect(_on_triggered)
	configure(request.source_id, request.skill_id, placement, float(tuning.get("trigger_radius", tuning.get("radius", 52.0))), float(tuning["arming_time"]), lifetime)

func track_target(victim: CombatActor) -> void:
	for index: int in range(_targets.size() - 1, -1, -1):
		if not is_instance_valid(_targets[index]):
			_targets.remove_at(index)
	if is_active() and victim != null and is_instance_valid(victim) and victim.get_instance_id() != owner_id and victim not in _targets and _targets.size() < HunterTuning.OPENING_CAP:
		_targets.append(victim)

func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or (is_inside_tree() and get_tree().paused):
		return
	super._process(delta)
	if state == State.ARMED:
		var victim := first_trigger_target(_targets)
		if victim != null:
			try_trigger(victim)

func _on_triggered(_trap: PlayerTrap, primary: CombatActor) -> void:
	var victims: Array[CombatActor] = []
	# Freezing is a single-prey control trap. Thorn/Tar open initial occupants
	# only; future Tar occupants receive slow but never a new opening.
	if source_skill_id == &"hunter_freezing_trap":
		victims.append(primary)
	else:
		for victim: CombatActor in _targets:
			if victim == null or not is_instance_valid(victim) or not victim.is_alive() or victim.get_instance_id() == owner_id:
				continue
			if global_position.distance_to(victim.global_position) <= effect_radius + victim.collision_radius and (not target_filter.is_valid() or bool(target_filter.call(victim))):
				victims.append(victim)
		victims.sort_custom(func(first: CombatActor, second: CombatActor) -> bool: return first.get_instance_id() < second.get_instance_id())
	sprung.emit(self, victims)

func _draw() -> void:
	super._draw()
	if not is_active():
		return
	var color := Color("b6d9d7") if source_skill_id == &"hunter_freezing_trap" else Color("cab58a")
	if source_skill_id == &"hunter_tar_trap":
		draw_circle(Vector2.ZERO, 13.0, Color("343b2b"))
		draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 20, color, 2.0, true)
	elif source_skill_id == &"hunter_freezing_trap":
		for index: int in range(3):
			var x := float(index - 1) * 12.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 5, 5), Vector2(x, -15), Vector2(x + 5, 5)]), Color(color, 0.75))
	else:
		for index: int in range(6):
			var axis := Vector2.from_angle(TAU * index / 6.0)
			draw_line(axis * 7.0, axis * 25.0, color, 3.0, true)
