extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	_quota_and_order()
	_health_and_reentry()
	_lifetime_and_ticks()
	_echo_exception()
	_delivery_replay()
	print("E06 proc ledger: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _quota_and_order() -> void:
	var ledger := EffectProcLedger.new("fixture")
	var context := ledger.new_root(1).impact(10)
	var candidates: Array[Dictionary] = []
	for target: int in range(17, 0, -1):
		candidates.append({"family_id": &"hit", "source_id": &"a", "target_id": target})
	candidates.append({"family_id": &"hit", "source_id": &"a", "target_id": 1})
	var claims := ledger.claim_batch(context, candidates)
	_check(claims.size() == 16 and claims[0]["target_id"] == 1 and claims[15]["target_id"] == 16, "sort/dedupe before cap; seventeenth dropped")
	_check(ledger.claim_batch(context, candidates).is_empty() and ledger.applications(context) == 16, "reentry and listener replay never reclaim")
	var other := ledger.new_root(1).impact(10)
	_check(ledger.claim_batch(other, [{"family_id": &"hit", "source_id": &"b", "target_id": 1}]).size() == 1, "another root has own budget")
	_check(ledger.claim_batch(other, [{"family_id": &"hit", "source_id": &"different_origin", "target_id": 1}]).is_empty(), "family/target dedup spans all origins")
	var child: CombatEventContext = claims[0]["context"]
	_check(ledger.claim_batch(child, [{"family_id": &"cascade", "source_id": &"b", "target_id": 19}]).is_empty(), "secondary cannot produce secondary")
	_check(child.scheduled_tick() == null, "proc cannot create new timer root")
	child.event_id = 0
	_check(ledger.claim_intrinsic(child, [{"family_id": &"launder", "source_id": &"b", "target_id": 19}]).is_empty(), "reset event cannot launder proc into kit")

func _health_and_reentry() -> void:
	var ledger := EffectProcLedger.new("health")
	var context := ledger.new_root(1).impact(2)
	var template := DamageRequest.new()
	template.source_id = 1
	template.physical_damage = 10.0
	var child := template.child_request(context, &"hit", &"augment:a", 2)
	var copy := child.copy()
	copy.is_secondary = false
	copy.can_crit = true
	copy.force_critical = true
	copy.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
	var resolved := CombatMath.resolve(copy, 0.0, 0.0, 1000.0, 0.0, 0.99, 0.0)
	_check(copy.is_secondary and resolved["damage"] == 10 and not resolved["critical"] and not resolved["can_trigger_effects"], "copy preserves secondary, geometry and no critical")
	var health := HealthState.new(2, StatCalculator.calculate({}))
	var calls := [0]
	health.damage_applied.connect(func(_result: Dictionary) -> void:
		calls[0] += 1
		_check(health.apply(copy, 0.0, 0.0).is_empty(), "nested application rejected before callback"))
	var result := health.apply(child, 0.0, 0.0)
	_check(result["actual_damage"] == 10.0 and calls[0] == 1, "one canonical application")
	_check(health.apply(copy, 0.0, 0.0).is_empty(), "late duplicate event rejected")
	var wrong := template.child_request(context, &"other", &"card:a", 3)
	wrong.target_id = 2
	_check(health.apply(wrong, 0.0, 0.0).is_empty(), "claimed target cannot be redirected")
	var shield := HealthState.new(4, StatCalculator.calculate({}))
	shield.grant_shield(100.0)
	var absorbed := template.child_request(context, &"hit", &"card:a", 4)
	result = shield.apply(absorbed, 0.0, 0.0)
	_check(result["actual_damage"] == 0.0 and result["absorbed_damage"] == 10.0 and ledger.applications(context) == 3, "shield consumes claimed application with no refund/proc")
	var corpse := HealthState.new(5, StatCalculator.calculate({}))
	corpse.current_hp = 0.0
	var dead := template.child_request(context, &"hit", &"equipment:a", 5)
	_check(corpse.apply(dead, 0.0, 0.0).is_empty() and ledger.applications(context) == 4, "target invalidated after claim still costs one")
	var primary := DamageRequest.new()
	primary.source_id = 1
	primary.target_id = 6
	primary.context = ledger.new_root(1)
	primary.physical_damage = 200.0
	primary.can_crit = false
	primary.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
	var victim := HealthState.new(6, StatCalculator.calculate({}))
	_check(not victim.apply(primary, 0.99, 0.0)["can_trigger_effects"], "miss cannot trigger")
	primary.context = ledger.new_root(1)
	primary.physical_damage = 0.0
	_check(not victim.apply(primary, 0.0, 0.0)["can_trigger_effects"], "zero cannot trigger")
	primary.context = ledger.new_root(1)
	primary.physical_damage = 200.0
	result = victim.apply(primary, 0.0, 0.0)
	_check(result["killed"] and result["actual_damage"] == 100.0, "lethal is real canonical HP loss")
	_check(ledger.claim_kit_recovery(result["context"], &"blood_thirst", &"blood_thirst", 6), "legal kill recovery gets shared claim")
	_check(not ledger.claim_kit_recovery(result["context"], &"blood_thirst", &"blood_thirst", 6), "recovery never repeats")

func _lifetime_and_ticks() -> void:
	var ledger := EffectProcLedger.new("lifetime")
	var original := ledger.new_root(1)
	var late := original.copy_context()
	ledger.claim_batch(original, [{"family_id": &"a", "source_id": &"a", "target_id": 2}])
	original = null
	for index: int in 20:
		var short := ledger.new_root(1)
		short = null
	_check(ledger.live_roots() == 1 and ledger.claim_batch(late, [{"family_id": &"a", "source_id": &"a", "target_id": 2}]).is_empty(), "late reference preserves dedupe without TTL")
	var tick := late.secondary_prototype().scheduled_tick()
	_check(tick.secondary and tick.depth == 1 and tick.ancestor_root_id == late.root_event_id and tick.root_event_id != late.root_event_id, "intrinsic tick retains ancestry and separate quota")
	_check(ledger.claim_intrinsic(tick, [{"family_id": &"tick", "source_id": &"dot", "target_id": 2}]).size() == 1, "periodic secondary tick can apply once")
	var retained: Array[CombatEventContext] = [late, tick]
	while ledger.can_create_root():
		retained.append(ledger.new_root(1))
	_check(ledger.live_roots() == 512 and ledger.new_root(1) == null, "deterministic live-root saturation")
	ledger.cancel()
	_check(not late.is_active() and not tick.is_active() and ledger.claim_batch(late, []).is_empty(), "death/end cancellation invalidates late work")
	retained.clear()

func _echo_exception() -> void:
	var ledger := EffectProcLedger.new("echo")
	var context := ledger.new_root(1).impact(2)
	var quota: Array[Dictionary] = []
	for target: int in range(20, 33):
		quota.append({"family_id": &"item_proc", "source_id": &"equipment", "target_id": target})
	ledger.claim_batch(context, quota)
	var first := ledger.claim_echo_pair(context, 2, 2)
	var second := ledger.claim_echo_pair(context, 3, 2)
	_check(first != null and second != null, "approved finite carriers can hit same target")
	_check(ledger.claim_echo_pair(context, 2, 2) == null, "carrier/target pair deduplicated")
	_check(ledger.claim_echo_pair(context, 4, 2) != null and ledger.claim_echo_pair(context, 5, 2) == null and ledger.applications(context) == 16, "echo shares remaining quota with all origins")
	_check(ledger.claim_echo_pair(first, 9, 2) == null, "echo child cannot authorize another wave")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _delivery_replay() -> void:
	var ledger := EffectProcLedger.new("delivery")
	var request := DamageRequest.new()
	request.context = ledger.new_root(20)
	request.source_id = 20
	request.target_id = 30
	request.physical_damage = 2.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var health := HealthState.new(30, StatCalculator.calculate({}))
	health.apply(request, 0.0, 1.0)
	var hp := health.current_hp
	_check(health.apply(request.copy(), 0.0, 1.0).is_empty() and health.current_hp == hp, "delivered primary replay retains event and cannot damage twice")
