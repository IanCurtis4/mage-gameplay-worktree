extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
const E = preload("res://tests/e06_effects_fixture.gd")
var checks := 0
var failures := 0
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var ledger := EffectProcLedger.new("tx2")
	var families: Array[StringName] = []
	var candidates: Array[Dictionary] = []
	for i: int in 25:
		var family := StringName("family_%d" % i)
		families.append(family)
		for target: int in [10, 11]:
			candidates.append({"family_id": family, "source_id": family, "target_id": target})
	var plan := {"families": families, "targets": [1, 10, 11], "carriers": [10]}
	var context := ledger.new_root(1, false, "", false, plan)
	plan["families"].append(&"late_family")
	_check(ledger.application_limit(context) == 78, "budget derives finite family/target/carrier product and freezes input")
	var accepted := ledger.claim_batch(context, candidates)
	_check(accepted.size() == 50 and ledger.applications(context) == 50, "more than sixteen useful families and multiple targets are preserved")
	_check(ledger.claim_batch(context, candidates).is_empty(), "all pairs claimed before callbacks and replay cannot reopen")
	_check(ledger.claim_batch(accepted[0]["context"], candidates).is_empty(), "proc child cannot create cascade")
	_check(ledger.apply_once(accepted[0]["context"]) and not ledger.apply_once(accepted[0]["context"]), "one claimed application is consumed once")
	_check(ledger.claim_batch(context, [{"family_id": &"late_family", "source_id": &"late", "target_id": 10}]).is_empty(), "late build cannot add a family to emitted plan")
	_check(ledger.claim_batch(context, [{"family_id": &"family_0", "source_id": &"source", "target_id": 12}]).is_empty(), "undeclared late target cannot expand budget")
	var echo := ledger.claim_echo_pair(context, 10, 11)
	_check(echo != null and ledger.claim_echo_pair(context, 10, 11) == null and ledger.claim_echo_pair(context, 11, 10) == null, "echo finite authorized carrier pairs share root claims")
	var tick := context.scheduled_tick()
	_check(tick != null and tick.ancestor_root_id == context.root_event_id and ledger.application_limit(tick) == 78, "finite intrinsic tick inherits frozen plan and ancestry")
	_check(accepted[0]["context"].scheduled_tick() == null, "generic proc cannot schedule fresh root")
	var bad := ledger.new_root(1, false, "", false, {"families": [&"family"], "targets": [1], "carriers": [2]})
	_check(bad == null, "malformed authorization plan rejected before root allocation")
	ledger.cancel()
	_check(not context.is_active() and ledger.claim_batch(context, candidates).is_empty() and context.scheduled_tick() == null, "cancel prevents late callbacks and ticking roots")
	_live_weapon_and_large_build()
	print("E06 TX2 causality: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _live_weapon_and_large_build() -> void:
	var fixture := F.make(self, "tx2_live_causal", &"swordsman")
	var c: RunController = fixture["controller"]
	var state := c.run_state
	var registry := E.registry()
	var source := F.catalog()
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for id: StringName in source.ids(origin):
			var definition := source.get_definition(origin, id)
			if id == &"riposte_blade":
				definition.effects.assign([E.proc_effect(&"blade_proc", &"mixed_family", 7.0)])
			elif id == &"prismatic_charm":
				var grant := EffectDefinition.new()
				grant.id = &"grant"
				grant.family_id = &"grant"
				grant.unit = &"points"
				grant.kind = EffectDefinition.Kind.ACTIVE_GRANT
				grant.handler_id = EffectDefinition.Handler.ACTIVE_SKILL
				grant.granted_skill_id = &"fire_spear"
				grant.allowed_origins = [&"swordsman"]
				definition.effects.assign([grant])
			assert(registry.register_definition(origin, definition)["ok"])
	var generic := E.definition(&"augment", &"generic", [E.proc_effect(&"generic_proc", &"mixed_family", 3.0)])
	registry.register_definition(&"augment", generic)
	state.augment_stacks[&"generic"] = 1
	for index: int in 25:
		var id := StringName("large_%d" % index)
		registry.register_definition(&"augment", E.definition(&"augment", id, [E.proc_effect(id, id, 1.0)]))
		state.augment_stacks[id] = 1
	_check(state.set_effect_catalog(registry)["ok"], "many-source catalog is legal without global effect cap")
	_check(F.change(c, &"equip", {"slot": &"main_hand", "item_id": &"riposte_blade"})["ok"] and F.change(c, &"equip", {"slot": &"accessory_1", "item_id": &"prismatic_charm"})["ok"], "real weapon and active equipped transactionally")
	var victim := CombatActor.new()
	victim.setup("Teste", Color.WHITE, StatCalculator.calculate({}, {}, 1, [{"source_id": &"hp", "flat": {&"max_hp": 10000.0}}]))
	victim.global_position = c.player.global_position + Vector2(40, 0)
	root.add_child(victim)
	c.enemies.append(victim)
	victim.health.damage_applied.connect(c.player.resolve_build_effect_procs)
	var emitted: Array[DamageRequest] = []
	c.player.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int) -> void: emitted.append(request.copy()))
	_check(c.player.use_spear(&"fire_spear", victim), "paid emission captures all sources with actual live root")
	var spell := emitted[0]
	spell.can_crit = false
	spell.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var oracle := CombatMath.resolve(spell, victim.health.physical_defense, victim.health.magic_defense, 0, 0, 0, 1)
	var before := victim.health.current_hp
	victim.apply_damage(spell, c.rng)
	_check(is_equal_approx(before - victim.health.current_hp, float(oracle["damage"]) + 28.0) and state.effect_ledger.applications(spell.context) == 26, "26 useful families execute; generic spell gets augment share but no weapon share")
	c.player._begin_effect_emission()
	var arrow := c.player._make_physical_request(victim, &"basic_attack", 10, DamageRequest.AccuracyMode.GEOMETRY, false)
	before = victim.health.current_hp
	oracle = CombatMath.resolve(arrow, victim.health.physical_defense, victim.health.magic_defense, 0, 0, 0, 1)
	victim.apply_damage(arrow, c.rng)
	_check(is_equal_approx(before - victim.health.current_hp, float(oracle["damage"]) + 35.0) and arrow.weapon_instance_ids.size() == 1, "actual weapon use receives both separately conditioned shares")
	var before_offer := state.composed_build()
	var saturated_weapon := E.proc_effect(&"saturation", &"conditional_saturation", 100.0)
	var weapon_item := source.get_definition(&"equipment", &"riposte_blade") as EquipmentDefinition
	weapon_item.effects.assign([saturated_weapon])
	var gain_catalog := E.registry()
	gain_catalog.register_definition(&"equipment", weapon_item)
	for id: StringName in source.ids(&"equipment"):
		if id != weapon_item.id:
			gain_catalog.register_definition(&"equipment", source.get_definition(&"equipment", id))
	gain_catalog.register_definition(&"augment", E.definition(&"augment", &"new_generic", [E.proc_effect(&"new_generic", &"conditional_saturation", 5)]))
	var snapshot := state.build_snapshot.copy_snapshot()
	var before_conditional := BuildEffectComposer.compose(snapshot, {}, [], gain_catalog)
	var after_conditional := BuildEffectComposer.compose(snapshot, {"augment_stacks": {&"new_generic": 1}}, [], gain_catalog)
	_check(state.has_effective_gain(before_conditional, after_conditional), "saturated weapon share does not hide new generic spell gain")
	var used := state.effect_ledger.applications(arrow.context)
	victim.apply_damage(arrow.copy(), c.rng)
	_check(state.effect_ledger.applications(arrow.context) == used, "repeated impact cannot reclaim any family")
	c.enemies.erase(victim)
	victim.free()
	c.free()
