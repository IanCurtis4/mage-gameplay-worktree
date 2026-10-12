extends SceneTree
## Real finite wall/echo consumers, plus adversarial admission boundaries.
var checks := 0
var failures := 0
var rng := RandomNumberGenerator.new()
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _actor(point: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Teste", Color.WHITE, StatCalculator.calculate({}, {}, 1, [{"source_id": &"hp", "flat": {&"max_hp": 10000.0}}]))
	root.add_child(actor)
	actor.global_position = point
	actor.set_process(false)
	return actor
func _request(owner: CombatActor, victim: CombatActor, context: CombatEventContext, skill: StringName) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = owner.get_instance_id()
	request.target_id = victim.get_instance_id()
	request.context = context
	request.skill_id = skill
	request.emission_id = 77
	request.magic_damage = 50.0
	request.can_crit = false
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	return request
func _run() -> void:
	var owner := _actor(Vector2(200, 200))
	var victim := _actor(Vector2(400, 200))
	var ledger := EffectProcLedger.new("late_fields")
	var context := ledger.new_root(owner.get_instance_id(), false, "", false, {"families": [&"fire_wall", &"test_proc"], "targets": [owner.get_instance_id()], "carriers": []})
	var candidate := {"family_id": &"test_proc", "source_id": &"test_source", "target_id": victim.get_instance_id()}
	_check(ledger.claim_batch(context, [candidate]).is_empty() and ledger.application_limit(context) == 2, "generic callback cannot admit a late victim")
	var wrong_owner := _request(owner, victim, context.copy_context(), &"fire_wall")
	wrong_owner.source_id += 1
	_check(victim.apply_damage(wrong_owner, rng).is_empty() and ledger.application_limit(context) == 2, "invalid source cannot admit victim before canonical validation")
	var primary := _request(owner, victim, context.copy_context(), &"fire_wall")
	_check(not victim.apply_damage(primary, rng).is_empty() and ledger.application_limit(context) == 4, "canonical primary admits real late victim before callbacks")
	var accepted := ledger.claim_batch(primary.context, [candidate])
	_check(accepted.size() == 1 and ledger.claim_batch(primary.context, [candidate]).is_empty(), "claim is recorded before a reentrant callback")
	var third := _actor(Vector2(420, 200))
	var late_candidate := {"family_id": &"test_proc", "source_id": &"test_source", "target_id": third.get_instance_id()}
	_check(ledger.claim_intrinsic(accepted[0]["context"], [late_candidate]).is_empty() and ledger.application_limit(context) == 4, "proc child cannot admit another victim through intrinsic API")
	_check(ledger.claim_batch(context.secondary_prototype(), [late_candidate]).is_empty(), "secondary callback cannot extend generic domain")
	var tick := context.scheduled_tick()
	var intrinsic := _request(owner, third, tick, &"fire_wall")
	intrinsic.is_secondary = true
	_check(not third.apply_damage(intrinsic, rng).is_empty() and ledger.application_limit(tick) == 6, "finite intrinsic tick admits a newly tracked victim without an earlier primary")
	_check(tick.ancestor_root_id == context.root_event_id and ledger.application_limit(context) == 4, "tick inherits emission snapshot without mutating ancestor domain")
	var unknown := context.scheduled_tick()
	_check(ledger.claim_intrinsic(unknown, [{"family_id": &"late_family", "source_id": &"source", "target_id": third.get_instance_id()}]).is_empty() and ledger.application_limit(unknown) == 4, "unknown family cannot use intrinsic admission")
	_wall(owner, ledger)
	_echo(owner, ledger)
	ledger.cancel()
	_check(context.impact(third.get_instance_id()) == null and ledger.claim_intrinsic(tick, [late_candidate]).is_empty(), "cancelled producer cannot admit targets or emit callbacks")
	third.free()
	victim.free()
	owner.free()
	print("E06 TX late fields: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _wall(owner: CombatActor, ledger: EffectProcLedger) -> void:
	var context := ledger.new_root(owner.get_instance_id(), false, "", false, {"families": [&"lightning_wall"], "targets": [owner.get_instance_id()], "carriers": []})
	var wall := LightningWall.new()
	var request := DamageRequest.new()
	request.source_id = owner.get_instance_id()
	request.skill_id = &"lightning_wall"
	request.context = context
	request.magic_damage = 50.0
	request.can_crit = false
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	wall.configure(owner, Vector2.RIGHT, request, [], 100.0)
	root.add_child(wall)
	wall.set_process(false)
	var victim := _actor(Vector2(350, 200))
	wall.targets.append(victim)
	var results: Array[Dictionary] = []
	wall.crossed.connect(func(hit: DamageRequest, actor: CombatActor) -> void: results.append(actor.apply_damage(hit, rng)))
	wall._process(0.01)
	victim.global_position = Vector2(250, 200)
	wall._process(0.01)
	_check(results.size() == 1 and not results[0].is_empty(), "actual wall hits a victim admitted after placement")
	_check(results[0]["context"].ancestor_root_id == context.root_event_id and int(results[0]["target_id"]) == victim.get_instance_id(), "actual wall tick preserves producer ancestry and canonical victim")
	var before := victim.health.current_hp
	wall._process(0.1)
	_check(is_equal_approx(before, victim.health.current_hp), "standing at wall does not create a repeated application")
	wall.free()
	victim.free()
func _echo(owner: CombatActor, ledger: EffectProcLedger) -> void:
	var context := ledger.new_root(owner.get_instance_id(), false, "", false, {"families": [&"soul_impact"], "targets": [owner.get_instance_id()], "carriers": []})
	var first := _actor(Vector2(400, 300))
	var carrier := _actor(Vector2(420, 300))
	_check(not ledger.bind_echo_carriers(context, [first.get_instance_id(), first.get_instance_id()]) and not context._budget.echo_bound, "malformed duplicate carrier list cannot bind or mutate the wave budget")
	var state := SpiritualistEchoState.new(owner.get_instance_id())
	state.mark(first.get_instance_id(), 0.35)
	state.mark(carrier.get_instance_id(), 0.35)
	var hit := _request(owner, first, context.copy_context(), &"soul_impact")
	var result := first.apply_damage(hit, rng)
	_check(state.record_hit(result, 100.0) and ledger.application_limit(context) == 9, "actual first hit binds marks added after emission to one finite echo snapshot")
	var wave_id := int(state.pending[0]["wave_id"])
	var late := _actor(Vector2(450, 300))
	state.mark(late.get_instance_id(), 0.35)
	var pair := ledger.claim_echo_pair(result["context"], first.get_instance_id(), late.get_instance_id())
	_check(pair != null and ledger.application_limit(context) == 12, "frozen eligible carrier can hit a later wave victim")
	_check(ledger.claim_echo_pair(result["context"], first.get_instance_id(), late.get_instance_id()) == null, "echo pair cannot reopen on reentry")
	_check(ledger.claim_echo_pair(result["context"], late.get_instance_id(), first.get_instance_id()) == null, "later marked victim cannot become carrier of existing wave")
	_check(not ledger.bind_echo_carriers(result["context"], [late.get_instance_id()]), "actual carrier snapshot cannot be replaced after first hit")
	var echo := _request(owner, late, pair, &"spiritualist_echo")
	echo.is_secondary = true
	var echo_result := late.apply_damage(echo, rng)
	_check(not echo_result.is_empty() and state.record_echo_impact(wave_id, echo_result, 0.35), "late victim receives native echo and rearm for next action")
	_check(state.pending.size() == 1 and not state.waves[wave_id]["scheduled"].has(late.get_instance_id()), "rearm cannot schedule late carrier in same wave")
	_check(not ledger.bind_echo_carriers(pair, [late.get_instance_id()]), "derived echo context cannot bind carriers")
	first.free()
	carrier.free()
	late.free()
