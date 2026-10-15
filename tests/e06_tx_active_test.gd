extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
const Effects = preload("res://tests/e06_effects_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _catalog() -> BuildEffectCatalog:
	var source := F.catalog()
	var registry := Effects.registry()
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for id: StringName in source.ids(origin):
			var definition := source.get_definition(origin, id)
			if id == &"prismatic_charm":
				var effect := EffectDefinition.new()
				effect.id = &"fixture_active"
				effect.family_id = &"fixture_active"
				effect.kind = EffectDefinition.Kind.ACTIVE_GRANT
				effect.handler_id = EffectDefinition.Handler.ACTIVE_SKILL
				effect.granted_skill_id = &"fire_spear"
				effect.granted_rank = 3
				effect.allowed_origins = [&"swordsman", &"mage", &"archer"]
				effect.unit = &"points"
				var ice := effect.duplicate(true) as EffectDefinition
				ice.id = &"fixture_ice"
				ice.family_id = &"fixture_ice"
				ice.granted_skill_id = &"ice_spear"
				ice.granted_rank = 2
				var teleport := effect.duplicate(true) as EffectDefinition
				teleport.id = &"fixture_teleport"
				teleport.family_id = &"fixture_teleport"
				teleport.granted_skill_id = &"teleport"
				teleport.granted_rank = 1
				definition.effects.assign([effect, ice, teleport])
			assert(registry.register_definition(origin, definition)["ok"])
	return registry
func _run() -> void:
	for origin: StringName in [&"swordsman", &"mage", &"archer"]:
		var fixture := F.make(self, "tx2_active_" + String(origin), origin)
		var c: RunController = fixture["controller"]
		var player := c.player
		_check(c.run_state.set_effect_catalog(_catalog())["ok"], "item recipe catalog accepted")
		var learned := player.skill_rank(&"fire_spear")
		_check(F.change(c, &"equip", {"slot": &"accessory_1", "item_id": &"prismatic_charm"})["ok"], "equip grants source")
		_check(player.skill_rank(&"fire_spear") == 3 and &"fire_spear" in player.available_skill_ids() and int(c.run_state.skill_levels.get(&"fire_spear", 0)) == learned, "max rank without writing learned ranks")
		_check(c.action_slots.find(&"fire_spear") == (-1 if origin != &"mage" else 0), "item never auto-assigns shortcut")
		var slots := c.action_slots.duplicate()
		for index: int in slots.size():
			if slots[index] == &"fire_spear": slots[index] = null
		slots[8] = &"fire_spear"
		slots[9] = &"teleport"
		c._change_action_slots(slots)
		_check(c.action_slots[8] == &"fire_spear", "manual shortcut persists through durable facade")
		var victim := CombatActor.new()
		victim.setup("Teste", Color.WHITE, StatCalculator.calculate({}, {}, 1, [{"source_id": &"fixture", "flat": {&"max_hp": 10000.0}}]))
		victim.global_position = player.global_position + Vector2(50, 0)
		root.add_child(victim)
		c.enemies.append(victim)
		var emitted: Array[DamageRequest] = []
		player.mage_projectile_requested.connect(func(_id: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int) -> void: emitted.append(request.copy()))
		_check(player.use_spear(&"fire_spear", victim), "concrete cross-class emission uses canonical executor")
		player.recover_sp(player.max_sp)
		_check(player.use_spear(&"ice_spear", victim) and player.skill_rank(&"ice_spear") == 2, "ice item adapter executes canonical emission on every base")
		player.recover_sp(player.max_sp)
		var old_position := player.global_position
		var destination := player.navigation.move_until_blocked(old_position, old_position + Vector2(25, 0))
		_check(player.use_teleport(destination) and player.global_position == destination and player.global_position != old_position, "teleport item adapter executes canonical movement on every base")
		var cooldown := player.skill_cooldown(&"fire_spear")
		var captured := emitted[0]
		_check(captured.context != null and c.run_state.effect_ledger.application_limit(captured.context) > 16 and captured.weapon_instance_ids.is_empty(), "live producer uses frozen derived plan and generic magic does not use weapon")
		_check(F.change(c, &"unequip", {"slot": &"accessory_1"})["ok"], "remove source transaction succeeds")
		_check(player.skill_rank(&"fire_spear") == learned and player.skill_cooldown(&"fire_spear") == cooldown and c.action_slots[8] == &"fire_spear" and captured.context.is_active(), "removal keeps cooldown, shortcut, learned rank and already emitted context")
		if origin != &"mage":
			_check(&"fire_spear" not in player.available_skill_ids() and not player.use_spear(&"fire_spear", victim), "no final source means disabled action")
		_check(F.change(c, &"equip", {"slot": &"accessory_1", "item_id": &"prismatic_charm"})["ok"] and player.skill_cooldown(&"fire_spear") == cooldown, "reequip restores rank/access without cooldown reset")
		player._advance_player(0.25)
		_check(player.skill_cooldown(&"fire_spear") < cooldown, "shared cooldown continues normally")
		player.mage_cooldowns[&"fire_spear"] = 0.0
		_check(player.begin_skill_cast(&"fire_spear", victim.global_position, victim), "prepare before removing source")
		F.change(c, &"unequip", {"slot": &"accessory_1"})
		_check(not player.has_active_cast(), "removing item cancels captured R3 preparation when that rank loses access")
		if origin == &"mage":
			var previous := player.push_cast_rank(&"fire_spear",1)
			_check(player.begin_skill_cast(&"fire_spear",victim.global_position,victim), "learned R1 can prepare after boosted rank is lost")
			player.restore_cast_rank(previous)
			_check(player.active_cast_rank == 1, "surviving preparation uses learned R1 without retaining item R3")
			c.control_preferences.restore_bindings()
			c.get_viewport().gui_release_focus()
			var disabled_key := InputEventKey.new()
			disabled_key.keycode = KEY_V
			disabled_key.pressed = true
			c._unhandled_input(disabled_key)
			_check(player.has_active_cast() and player.active_cast_skill == &"fire_spear", "disabled shortcut cannot cancel another valid preparation")
		var decoded := ProfileCodec.decode(F.disk(fixture))
		_check(decoded["ok"] and decoded["profile"].characters[0].action_slots[8] == &"fire_spear" and int(decoded["profile"].characters[0].purchased_skill_ranks.get(&"fire_spear", 0)) == learned, "inactive known adapter reference reopens without granting learning")
		_check(player.weapon_ids_for_skill(&"basic_attack").size() == 1 and player.weapon_ids_for_skill(&"sentinel_piercing_shot").size() == 1 and player.weapon_ids_for_skill(&"sentinel_net_shot").is_empty(), "autos and explicit paid shot adapters capture weapon; INT net does not")
		c.enemies.erase(victim)
		victim.free()
		c.free()
	_snapshot_null_guard()
	print("E06 TX2 active: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _snapshot_null_guard() -> void:
	var fixture := F.make(self, "tx_active_null_guard", &"mage")
	var controller: RunController = fixture["controller"]
	var state := controller.run_state
	assert(state.set_effect_catalog(_catalog())["ok"])
	assert(F.change(controller, &"equip", {"slot": &"accessory_1", "item_id": &"prismatic_charm"})["ok"])
	var original_ids := state.available_active_ids()
	var saved_snapshot := state.build_snapshot
	state.build_snapshot = null
	_check(state.available_active_ids().is_empty() and not state.has_item_active(&"fire_spear") and state.effective_skill_rank(&"fire_spear") == 0, "temporarily absent snapshot clears learned/item access instead of leaking cached grants")
	_check(controller.player.available_skill_ids().is_empty(), "persistent player library is safe while snapshot is absent")
	state.build_snapshot = saved_snapshot
	_check(state.available_active_ids() == original_ids and state.has_item_active(&"fire_spear") and state.effective_skill_rank(&"fire_spear") == 3, "restoring snapshot rebuilds item and learned access without losing original order")
	var pilot := RunState.new(&"mage")
	pilot.build_snapshot = null
	_check(not pilot.uses_persistent_build() and pilot.available_active_ids().is_empty(), "pilot item lookup tolerates absent snapshot; actor retains its existing class fallback")
	controller.free()
