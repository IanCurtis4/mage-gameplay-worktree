class_name HunterOpeningState
extends RefCounted
## Run-only claims. No nodes, wall-clock time, catalog mutation or damage resolver.

const BOW_SKILLS: Array[StringName] = [
	&"basic_attack", &"double_shot", &"piercing_arrow", &"arrow_rain",
	&"slowing_arrow", &"hunter_covering_shot",
]

var owner_id := 0
var step_remaining := 0.0
var step_cooldown := 0.0
var marked_target_id := 0
var mark_rank := 0
var mark_remaining := 0.0
var _openings: Dictionary[int, Dictionary] = {}
var _activations: Dictionary[int, Dictionary] = {}
var _emissions: Dictionary[int, Dictionary] = {}

func configure(runtime_owner_id: int) -> void:
	assert(runtime_owner_id > 0)
	clear()
	owner_id = runtime_owner_id

func mark(target_id: int, rank: int) -> bool:
	var tuning := HunterTuning.values(&"hunter_mark", rank)
	if owner_id <= 0 or target_id <= 0 or target_id == owner_id or tuning.is_empty():
		return false
	marked_target_id = target_id
	mark_rank = rank
	mark_remaining = float(tuning["duration"])
	return true

func is_marked(target_id: int) -> bool:
	return target_id > 0 and target_id == marked_target_id and mark_remaining > 0.0

func activate(activation_id: int, target_id: int, snapshot: DamageRequest, duration: float = HunterTuning.OPENING_DURATION) -> bool:
	if owner_id <= 0 or activation_id <= 0 or target_id <= 0 or target_id == owner_id or not _valid_snapshot(snapshot) or not is_finite(duration) or duration <= 0.0 or duration > 6.0:
		return false
	var activation: Dictionary = _activations.get(activation_id, {})
	if activation.is_empty():
		if _activations.size() >= HunterTuning.ACTIVATION_CAP:
			return false
		activation = {"remaining": HunterTuning.ACTIVATION_LIFETIME, "targets": {}}
	var targets: Dictionary = activation["targets"]
	if targets.has(target_id) or (not _openings.has(target_id) and _openings.size() >= HunterTuning.OPENING_CAP) or targets.size() >= HunterTuning.OPENING_CAP:
		return false
	# Mark is sampled at activation, never retroactively on a live opening.
	var request := snapshot.copy()
	if is_marked(target_id):
		var tuning := HunterTuning.values(&"hunter_mark", mark_rank)
		duration = minf(6.0, duration + float(tuning["opening_extension"]))
		request.physical_damage *= 1.0 + float(tuning["reward_bonus"])
	if not _valid_snapshot(request):
		return false
	# Commit both ledgers before any caller applies effects/calls external signals.
	targets[target_id] = true
	_activations[activation_id] = activation
	request.target_id = target_id
	_openings[target_id] = {"remaining": duration, "request": request, "activation_id": activation_id}
	return true

func consume(result: Dictionary, controlled_or_boss: bool = false) -> Dictionary:
	var target_id := int(result.get("target_id", 0))
	var emission_id := int(result.get("emission_id", 0))
	var actual_damage := float(result.get("actual_damage", 0.0))
	if owner_id <= 0 or int(result.get("source_id", 0)) != owner_id or target_id <= 0 or emission_id <= 0 or not bool(result.get("can_trigger_effects", false)) or not is_finite(actual_damage) or actual_damage <= 0.0 or StringName(result.get("skill_id", &"")) not in BOW_SKILLS or not _openings.has(target_id):
		return {}
	var precision := float(result.get("hunter_precision_damage", 0.0))
	var easy_bonus := float(result.get("hunter_easy_prey_bonus", 0.0))
	if not is_finite(precision) or precision < 0.0 or not is_finite(easy_bonus) or easy_bonus < 0.0 or easy_bonus > 0.16:
		return {}
	var emission: Dictionary = _emissions.get(emission_id, {})
	if emission.is_empty():
		if _emissions.size() >= HunterTuning.EMISSION_CAP:
			return {}
		emission = {"remaining": HunterTuning.EMISSION_LIFETIME, "targets": {}, "step_considered": false}
	var targets: Dictionary = emission["targets"]
	if targets.has(target_id) or targets.size() >= HunterTuning.OPENING_CAP:
		return {}
	var opening: Dictionary = _openings[target_id]
	var request: DamageRequest = opening["request"]
	request = request.copy()
	request.emission_id = emission_id
	# Mark was already captured on activation. Easy Prey scales only that INT
	# portion; Discipline is added afterwards. One canonical secondary request
	# retains the placement multiplier, current defenses and no critical roll.
	if is_marked(target_id) or controlled_or_boss:
		request.physical_damage *= 1.0 + easy_bonus
	request.physical_damage += precision
	if not _valid_snapshot(request):
		return {}
	# Claim/erase before returning a payload. Nested secondary/death callbacks
	# cannot find the same opening, or exploit a replacement with the same action.
	_openings.erase(target_id)
	targets[target_id] = true
	var granted_step := false
	if not bool(emission["step_considered"]):
		emission["step_considered"] = true
		if step_cooldown <= 0.0:
			step_cooldown = HunterTuning.STEP_COOLDOWN
			step_remaining = HunterTuning.STEP_DURATION
			granted_step = true
	_emissions[emission_id] = emission
	return {"request": request, "granted_step": granted_step, "activation_id": opening["activation_id"]}

func opening(target_id: int) -> Dictionary:
	if not _openings.has(target_id):
		return {}
	var result: Dictionary = _openings[target_id].duplicate()
	var request: DamageRequest = result["request"]
	result["request"] = request.copy()
	return result

func discard_target(target_id: int) -> void:
	_openings.erase(target_id)
	if target_id == marked_target_id:
		marked_target_id = 0
		mark_rank = 0
		mark_remaining = 0.0
	# Keep claims until TTL: death/removal must not release a live emission.

func advance(delta: float, paused: bool = false) -> void:
	if paused or not is_finite(delta) or delta <= 0.0:
		return
	step_remaining = _remaining(step_remaining, delta)
	step_cooldown = _remaining(step_cooldown, delta)
	mark_remaining = _remaining(mark_remaining, delta)
	if mark_remaining <= 0.0:
		marked_target_id = 0
		mark_rank = 0
	for ledger: Dictionary in [_openings, _activations, _emissions]:
		for id: int in ledger.keys():
			var entry: Dictionary = ledger[id]
			entry["remaining"] = _remaining(float(entry["remaining"]), delta)
			if float(entry["remaining"]) <= 0.0:
				ledger.erase(id)

func clear() -> void:
	_openings.clear()
	_activations.clear()
	_emissions.clear()
	step_remaining = 0.0
	step_cooldown = 0.0
	marked_target_id = 0
	mark_rank = 0
	mark_remaining = 0.0

func _valid_snapshot(snapshot: DamageRequest) -> bool:
	return snapshot != null and snapshot.source_id == owner_id and snapshot.is_secondary and not snapshot.can_crit and snapshot.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and is_finite(snapshot.physical_damage) and snapshot.physical_damage > 0.0 and snapshot.magic_damage == 0.0 and is_finite(snapshot.damage_dealt_multiplier) and snapshot.damage_dealt_multiplier >= 0.0

static func _remaining(value: float, delta: float) -> float:
	var remaining := maxf(0.0, value - delta)
	return 0.0 if remaining < 0.000001 else remaining
