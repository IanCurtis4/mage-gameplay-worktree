extends SceneTree
const Pilot = preload("res://tools/content/pilot_bundle.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/pilot_texts.json"))
	_check(parsed is Dictionary, "real Luna document readable")
	if not parsed is Dictionary: quit(1); return
	var entries: Array[Dictionary] = Pilot.entries()
	var compiled := ContentAuthoring.compile_bundle(entries, parsed)
	_check(compiled["ok"], "real editorial complete and tied to pilot mechanics")
	if not compiled["ok"]: print(compiled); quit(1); return
	var catalog: BuildEffectCatalog = compiled["catalog"]
	var reloaded: Array[Dictionary] = []
	var folder := "res://.godot/content_authoring/pilot_roundtrip_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	for entry: Dictionary in compiled["entries"]:
		var definition: Resource = entry["definition"]
		_check(not definition.display_name.is_empty() and not definition.flavor_text.is_empty() and definition.description == ContentAuthoring.describe(entry["origin"], definition), "separate factual/editorial fields %s" % definition.id)
		var path := folder.path_join("%s_%s.tres" % [entry["origin"], definition.id])
		_check(ResourceSaver.save(definition, path) == OK, "save native %s" % definition.id)
		var copy: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_check(copy != null and copy.display_name == definition.display_name and copy.flavor_text == definition.flavor_text and copy.description == definition.description, "native reload %s" % definition.id)
		if copy != null: reloaded.append({"origin": entry["origin"], "definition": copy, "purpose": entry["purpose"]})
	_check(ContentAuthoring.prepare(reloaded)["mechanical_digest"] == compiled["mechanical_digest"], "all reloads preserve entire mechanical fingerprint")
	for origin: StringName in BuildEffectCatalog.ORIGINS: _projectile(origin, catalog)
	_targeted_events(catalog)
	print("E06 content pilot runtime: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _player(snapshot: BuildSnapshot, catalog: BuildEffectCatalog, effects: Dictionary) -> PlayerActor:
	var state := RunState.from_build("pilot-events", snapshot)
	state.augment_stacks.assign(effects.get("augment_stacks", {}))
	state.card_instances = effects.get("card_instances", {})
	state.card_sockets = effects.get("card_sockets", {})
	var injected := state.set_effect_catalog(catalog)
	_check(injected["ok"], "runtime catalog injects")
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(-1000, -1000, 2000, 2000), [], 0)
	var player := PlayerActor.new()
	player.configure(navigation, state)
	root.add_child(player)
	player.set_process(false)
	return player
func _victim() -> CombatActor:
	var victim := CombatActor.new()
	victim.setup("Alvo de teste", Color.WHITE, StatCalculator.calculate({}, {}, 1, [{"source_id": &"pilot_health", "flat": {&"max_hp": 5000.0}}]))
	root.add_child(victim)
	victim.set_process(false)
	victim.position = Vector2(60, 0)
	return victim
func _projectile(origin: StringName, catalog: BuildEffectCatalog) -> void:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "pilot-projectiles"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"fire_wall": 2, &"fire_spear": 1}
	snapshot.library_skill_ids = [&"fire_wall", &"fire_spear"]
	var effects := {"augment_stacks": {}, "card_instances": {}, "card_sockets": {}}
	if origin == &"augment": effects["augment_stacks"][&"extra_fire_spear"] = 1
	else:
		var item := catalog.get_definition(&"equipment", &"ember_staff" if origin == &"equipment" else &"starter_staff") as EquipmentDefinition
		var created := EquipmentInstance.from_metadata(&"pilot_weapon", item.id, item.metadata())
		snapshot.equipment_instances[&"pilot_weapon"] = created["instance"]
		snapshot.equipped[&"main_hand"] = &"pilot_weapon"
		if origin == &"card":
			effects["card_instances"][&"pilot_card"] = &"ember_card"
			effects["card_sockets"][&"pilot_weapon"] = [&"pilot_card"]
	var player := _player(snapshot, catalog, effects)
	var victim := _victim()
	var counts: Array[int] = []
	var emitted: Array[DamageRequest] = []
	player.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _victim: CombatActor, _direction: Vector2, count: int) -> void: counts.append(count); emitted.append(request.copy()))
	var capture := player.run_state.skill_effect_capture(&"fire_spear")
	_check(player.use_spear(&"fire_spear", victim), "real spear launch %s" % origin)
	_check(counts == [2] and capture["values"]["projectile_count"] == 2, "real launch and preview show transformation %s" % origin)
	if not emitted.is_empty():
		player.run_state.augment_stacks.clear()
		player.run_state.card_instances.clear()
		player.run_state.card_sockets.clear()
		player.run_state.build_snapshot.equipped = EquipmentRules.empty_layout()
		player.run_state.runtime_revision += 1
		_check(player.run_state.projectile_count(&"fire_spear") == 1 and counts[0] == 2 and capture["values"]["projectile_count"] == 2, "launched capture survives removal %s" % origin)
	player.free()
	victim.free()
func _targeted_events(catalog: BuildEffectCatalog) -> void:
	# Primary damage events are injected to test recipe filtering, not full kit rotations.
	for identity: String in Pilot.EXCLUSIVE_PROCS:
		for branch: int in 2:
			var comparison: Dictionary = Pilot.comparison(identity, branch, catalog)
			_check(comparison.get("ok",false), "comparison route has legal investments: %s/%d" % [identity,branch])
			if not comparison.get("ok",false): continue
			var effects := {"augment_stacks": {Pilot.exclusive_id(identity, branch): 1}}
			var isolated: BuildSnapshot = comparison["snapshot"].copy_snapshot()
			isolated.equipped = EquipmentRules.empty_layout()
			isolated.equipment_instances.clear()
			var player := _player(isolated, catalog, effects)
			var victim := _victim()
			var requests: Array[DamageRequest] = []
			player.status_damage_requested.connect(func(request: DamageRequest, _target: CombatActor) -> void: requests.append(request.copy()))
			var target := StringName(Pilot.EXCLUSIVE_PROCS[identity][branch])
			for skill: StringName in [target, &"basic_attack"]:
				player._begin_effect_emission()
				var request := player._make_physical_request(victim, skill, 10, DamageRequest.AccuracyMode.GEOMETRY, false)
				var result := victim.health.apply(request, 0, 1)
				player.prepare_effect_claims(result)
				player.resolve_build_effect_procs(result)
				player.resolve_build_effect_procs(result)
			_check(requests.size() == 1, "only exact skill receives one secondary despite reentry %s/%d" % [identity, branch])
			if requests.size() == 1:
				_check(requests[0].is_secondary and requests[0].context.secondary and not requests[0].can_crit, "secondary cannot become a new primary")
				_check(is_equal_approx(requests[0].physical_damage + requests[0].magic_damage, 6), "exact first-stack proc magnitude")
				var follow := victim.health.apply(requests[0], 0, 1)
				player.resolve_build_effect_procs(follow)
				_check(requests.size() == 1, "recipe cannot cascade from its own secondary")
			player.free()
			victim.free()
