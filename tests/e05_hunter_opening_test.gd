extends SceneTree
## Deterministic contract checks, not a solo AI/gameplay viability claim.

var checks := 0
var failures := 0

func _initialize() -> void:
	_claims()
	_bounds()
	_math()
	for hz: int in [30, 60, 144]:
		_timers(hz)
	print("Hunter opening: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _state() -> HunterOpeningState:
	var state := HunterOpeningState.new()
	state.configure(101)
	return state

func _snapshot() -> DamageRequest:
	return HunterMath.opening_request(101, &"snare_trap", 1, _stats(10, 5), 1.0)

func _result(emission: int = 1, victim: int = 201) -> Dictionary:
	return {"source_id": 101, "target_id": victim, "emission_id": emission, "skill_id": &"basic_attack", "actual_damage": 1.0, "can_trigger_effects": true}

func _claims() -> void:
	var state := _state()
	var snapshot := _snapshot()
	_check(state.activate(1, 201, snapshot), "valid activation opens one victim")
	snapshot.physical_damage = 9000.0
	var view := state.opening(201)
	_check(is_equal_approx(view["request"].physical_damage, 22.0), "placement request copied, caller mutation cannot change payload")
	view["request"].physical_damage = 9999.0
	view["remaining"] = 9999.0
	_check(state.opening(201)["remaining"] == 4.0 and state.opening(201)["request"].physical_damage == 22.0, "read-only views return copied snapshots")
	state.advance(0.5)
	_check(not state.activate(1, 201, _snapshot()) and state.opening(201)["remaining"] == 3.5, "duplicate trap/victim never refreshes")
	_check(state.activate(2, 201, _snapshot()) and state._openings.size() == 1 and state.opening(201)["remaining"] == 4.0, "new trap replaces instead of stacking")
	for reason: String in ["foreign", "secondary", "zero", "shield", "trap", "missing_emission", "missing_target", "nan", "infinite"]:
		var result := _result()
		match reason:
			"foreign": result["source_id"] = 999
			"secondary": result["can_trigger_effects"] = false
			"zero", "shield": result["actual_damage"] = 0.0
			"trap": result["skill_id"] = &"explosive_trap"
			"missing_emission": result["emission_id"] = 0
			"missing_target": result["target_id"] = 0
			"nan": result["actual_damage"] = NAN
			"infinite": result["actual_damage"] = INF
		_check(state.consume(result).is_empty() and not state.opening(201).is_empty(), reason + " preserves opening")
	var payload := state.consume(_result())
	_check(not payload.is_empty() and state.opening(201).is_empty(), "direct positive own bow consumes before external callback")
	var extra: DamageRequest = payload["request"]
	_check(extra.is_secondary and not extra.can_crit and extra.skill_id == &"hunter_exploit" and extra.target_id == 201 and extra.emission_id == 1, "extra is canonical secondary geometry physical payload")
	_check(bool(payload["granted_step"]) and state.step_remaining == 1.5 and state.step_cooldown == 3.0, "intrinsic step does not require passive")
	_check(state.consume(_result()).is_empty(), "reentrant duplicate claim finds no opening")
	_check(state.activate(3, 201, _snapshot()), "new trap can reapply after consume")
	_check(state.consume(_result()).is_empty() and not state.opening(201).is_empty(), "same arrow action cannot consume replacement on same victim")
	_check(not state.consume(_result(2)).is_empty() and state.step_remaining == 1.5, "new action explores during shared ICD without extending step")
	state.advance(3.0)
	_check(state.activate(4, 202, _snapshot()), "another prey opens after timer advance")
	_check(not bool(state.consume(_result(2, 202))["granted_step"]), "late victim of ICD-rejected emission cannot pay step later")
	for victim: int in range(203, 213):
		_check(state.activate(5, victim, _snapshot()), "area trap opens distinct prey once")
		var area_payload := state.consume(_result(3, victim))
		_check(not area_payload.is_empty() and bool(area_payload["granted_step"]) == (victim == 203), "area arrow claims each prey but step only once")
	_check(state.step_remaining == 1.5, "ten victims never multiply movement duration")
	state.clear()
	_check(state._openings.is_empty() and state._activations.is_empty() and state._emissions.is_empty() and state.step_remaining == 0.0 and state.step_cooldown == 0.0, "run end/reset cleans all ephemeral state")

func _bounds() -> void:
	var state := _state()
	for victim: int in range(201, 201 + HunterTuning.OPENING_CAP):
		_check(state.activate(1, victim, _snapshot()), "bounded valid opening admitted")
	_check(not state.activate(1, 999, _snapshot()) and state._openings.size() == HunterTuning.OPENING_CAP, "opening saturation fails closed")
	state.clear()
	for activation: int in range(1, HunterTuning.ACTIVATION_CAP + 1):
		_check(state.activate(activation, 201, _snapshot()), "activation ledger admits bounded unique trap")
	_check(not state.activate(999, 201, _snapshot()), "activation saturation does not evict live identities")
	state.advance(HunterTuning.ACTIVATION_LIFETIME)
	_check(state.activate(999, 201, _snapshot()), "expired activation identities release capacity")
	state.clear()
	_check(state.activate(1, 201, _snapshot()), "start bounded emission test")
	for emission: int in range(1, HunterTuning.EMISSION_CAP + 1):
		if emission > 1:
			state.discard_target(201)
			# Test consumer capacity independently of the equally sized activation cap.
			state._openings[201] = {"remaining": 4.0, "request": _snapshot(), "activation_id": 1}
		_check(not state.consume(_result(emission)).is_empty(), "bounded emission admitted")
	state._openings[201] = {"remaining": 4.0, "request": _snapshot(), "activation_id": 1}
	_check(state.consume(_result(999)).is_empty() and not state.opening(201).is_empty(), "emission saturation preserves opening and fails closed")
	state.advance(HunterTuning.EMISSION_LIFETIME)
	_check(state.activate(2, 201, _snapshot()) and not state.consume(_result(999)).is_empty(), "expired claims release capacity")
	for invalid: float in [NAN, INF, -1.0, 0.0, 6.01]:
		_check(not state.activate(99, 299, _snapshot(), invalid), "invalid window rejected")
	for field: String in ["source_id", "physical_damage", "magic_damage", "is_secondary", "can_crit", "damage_dealt_multiplier"]:
		var request := _snapshot()
		match field:
			"source_id": request.source_id = 900
			"physical_damage": request.physical_damage = NAN
			"magic_damage": request.magic_damage = 1.0
			"is_secondary": request.is_secondary = false
			"can_crit": request.can_crit = true
			"damage_dealt_multiplier": request.damage_dealt_multiplier = INF
		_check(not state.activate(100, 300, request), "invalid " + field + " snapshot rejected")

func _math() -> void:
	var low := _stats(5, 5)
	var dexterity := _stats(5, 60)
	var intelligence := _stats(60, 5)
	for rank: int in range(1, 6):
		for id: StringName in HunterMath.TRAP_IDS:
			var first := HunterMath.opening_request(101, id, rank, low, 1.0)
			_check(first.physical_damage == HunterMath.opening_request(101, id, rank, dexterity, 1.0).physical_damage, "trap reward excludes DES/precision/MATK leakage")
			_check(first.physical_damage < HunterMath.opening_request(101, id, rank, intelligence, 1.0).physical_damage, "INT improves intrinsic trap reward")
		_check(HunterMath.explosive_raw(rank, low) == HunterMath.explosive_raw(rank, dexterity), "specialized Explosive excludes DES")
		_check(HunterMath.explosive_raw(rank, low) < HunterMath.explosive_raw(rank, intelligence), "specialized Explosive scales INT")
	var extra := _snapshot()
	extra.damage_dealt_multiplier = 1.25
	var result := CombatMath.resolve(extra, 100.0, 0.0, 999.0, 0.0, 0.9, 0.0)
	_check(result["landed"] and not result["critical"] and result["damage"] == 14 and not result["can_trigger_effects"], "canonical resolver applies physical defense and snapshot multiplier once without crit/procs")
	_check(HunterMath.opening_request(101, &"unknown", 1, low, 1.0) == null and HunterMath.opening_request(101, &"snare_trap", 0, low, 1.0) == null, "invalid identity/rank cannot grant reward")

func _timers(hz: int) -> void:
	var state := _state()
	state.activate(1, 201, _snapshot())
	state.consume(_result())
	state.activate(2, 202, _snapshot())
	state.advance(99.0, true)
	_check(state.step_remaining == 1.5 and state.opening(202)["remaining"] == 4.0, "pause freezes timers at %dHz" % hz)
	for _frame: int in range(hz * 4):
		state.advance(1.0 / hz)
	_check(state.step_remaining == 0.0 and state.step_cooldown == 0.0 and state.opening(202).is_empty(), "timer boundaries independent of %dHz" % hz)

func _stats(intelligence: int, dexterity: int) -> StatBreakdown:
	return StatCalculator.calculate({&"str": 5, &"agi": 5, &"vit": 5, &"int": intelligence, &"dex": dexterity, &"luk": 5})

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
