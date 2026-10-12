extends SceneTree
const Fixture = preload("res://tests/e06_effects_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	_card_cap()
	_proc_child_recovery()
	print("E06 independent review boundaries: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _count_effect(id: StringName, amount: float) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = id
	effect.family_id = id
	effect.kind = EffectDefinition.Kind.SKILL_RULE
	effect.handler_id = EffectDefinition.Handler.PROJECTILE_COUNT
	effect.axis = &"projectile_count"
	effect.unit = &"count"
	effect.target_skill_ids = [&"fire_spear"]
	effect.magnitude = amount
	effect.limit = 16.0
	return effect
func _card_cap() -> void:
	var registry := BuildEffectCatalog.new()
	var item := EquipmentDefinition.new()
	item.id = &"review_staff"
	item.slot = &"main_hand"
	item.effects = [_count_effect(&"staff_count", 15.0)]
	_check(registry.register_definition(&"equipment", item)["ok"], "setup staff accepted")
	var card := CardDefinition.new()
	card.id = &"review_count_card"
	card.allowed_slots = [&"main_hand"]
	card.effects = [_count_effect(&"card_count", 1.0)]
	_check(registry.register_definition(&"card", card)["ok"], "setup card accepted")
	var state := RunState.new(&"mage")
	Fixture.equip(state.build_snapshot, item.id)
	_check(state.set_effect_catalog(registry)["ok"], "setup composition accepted")
	var controller := RunController.new()
	controller.run_state = state
	var rewards := RunRewardService.new(controller)
	var before := state.composed_build()
	var after := BuildEffectComposer.compose(state.build_snapshot, {"card_sockets": {item.id: [card.id]}, "card_instances": {card.id: card.id}}, [], registry)
	var first := SkillEffectResolver.capture(&"fire_spear", 1, before)
	var second := SkillEffectResolver.capture(&"fire_spear", 1, after)
	_check(first["values"]["projectile_count"] == 16 and first["values"] == second["values"], "both captures are already at 16 projectiles")
	var pool := rewards.eligible_cards()
	print("REPRO card cap: before=", first["values"], " after=", second["values"], " pool=", pool)
	_check(card.id not in pool, "capped card with no effective gain must not be eligible")
	controller.free()
func _proc_child_recovery() -> void:
	var build := BuildSnapshot.new()
	build.character_id = "review-proc-child"
	build.base_class_id = &"swordsman"
	build.skill_ranks = {&"blood_thirst": 1}
	var state := RunState.from_build("review-proc", build)
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 1000), [], 0.0)
	var player := PlayerActor.new()
	player.configure(nav, state)
	root.add_child(player)
	player.set_process(false)
	player.health.spend_hp_nonlethal(20.0)
	var controller := RunController.new()
	controller.player = player
	controller.run_state = state
	var victim := CombatActor.new()
	victim.setup("Revisao", Color.WHITE, StatCalculator.calculate({}))
	root.add_child(victim)
	victim.set_process(false)
	victim.health.current_hp = 1.0
	victim.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	var context := state.effect_ledger.new_root(player.get_instance_id())
	var claims := state.effect_ledger.claim_batch(context, [{"family_id": &"review_generic_proc", "source_id": &"review_item", "target_id": victim.get_instance_id()}])
	var request := DamageRequest.new()
	request.context = claims[0]["context"]
	request.source_id = player.get_instance_id()
	request.target_id = victim.get_instance_id()
	request.skill_id = &"review_generic_proc"
	request.physical_damage = 5.0
	request.is_secondary = true
	var hp_before := player.health.current_hp
	var result := victim.health.apply(request, 0.0, 1.0)
	_check(result["killed"] and request.context.proc_child, "generic secondary proc produces real lethal result")
	print("REPRO proc recovery: HP before=", hp_before, " after=", player.health.current_hp, " used=", state.effect_ledger.applications(context))
	_check(player.health.current_hp == hp_before, "generic proc child must not trigger healing via intrinsic DoT exception")
	victim.free()
	controller.free()
	player.free()
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
