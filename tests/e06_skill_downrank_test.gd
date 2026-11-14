extends SceneTree
## Ranks are cast selections, never learning mutations. Uses real cost/emission APIs.
const H = preload("res://tests/fixtures/e07/f2/confirmed_history.gd")
var checks := 0
var failures := 0
const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174335"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_layout_and_input()
	_codec()
	await _paid_cast()
	await _kit_casts()
	await _deferred_impacts()
	print("E06 downranking: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _layout_and_input() -> void:
	var slots := ActionBarLayout.assign(ActionBarLayout.empty(), &"fireball", 0)
	slots = ActionBarLayout.assign(slots, &"fireball", 12, 1)
	slots = ActionBarLayout.assign(slots, &"fireball", 23, 3)
	_check(ActionBarLayout.valid(slots, [&"fireball"]), "same skill variants coexist at original positions")
	_check(ActionBarLayout.skill_id(slots[12]) == &"fireball" and ActionBarLayout.selected_rank(slots[12]) == 1, "versioned entry extracts ID and rank")
	slots = ActionBarLayout.assign(slots, &"fireball", 7, 1)
	_check(slots[12] == null and ActionBarLayout.selected_rank(slots[7]) == 1 and slots[0] == &"fireball", "assign moves only matching variant")
	slots = ActionBarLayout.assign(slots, &"fireball", 6)
	_check(slots[0] == null and slots[6] == &"fireball", "legacy highest assign keeps unique ID move semantics")
	var invalid := slots.duplicate(true)
	invalid[2] = {"skill_id": &"fireball", "rank": 1.5}
	_check(not ActionBarLayout.valid(invalid, [&"fireball"]), "fractional payload rejected")
	invalid[2] = {"skill_id": &"fireball", "rank": 1, "forged": true}
	_check(not ActionBarLayout.valid(invalid, [&"fireball"]), "extra payload fields rejected")
	invalid[2] = {"skill_id": &"mage_mana_regeneration", "rank": 1}
	_check(not ActionBarLayout.valid(invalid, [&"mage_mana_regeneration"]), "passive explicit entry rejected")
	_check(SkillCastRank.resolve(&"fireball", 1, 5) == 1 and SkillCastRank.resolve(&"fireball", 0, 5) == 5, "explicit downrank and legacy highest resolve")
	_check(SkillCastRank.resolve(&"fireball", 6, 5) == 0 and SkillCastRank.resolve(&"fireball", -1, 5) == 0 and SkillCastRank.resolve(&"fireball", 3, 2) == 0, "invalid caps and lost access never promote")
	_check(not SkillCastRank.supports(&"mage_mana_regeneration") and SkillCastRank.resolve(&"mage_mana_regeneration", 1, 3) == 0, "passives excluded from explicit policy")
	_check(not SkillCastRank.supports(&"sentinel_explosive_shot"), "unverified deferred executor excluded explicitly")
	var prefs := ControlPreferences.new()
	var input := ActionBarInput.new()
	var event := InputEventKey.new()
	event.keycode = ControlPreferences.DEFAULT_KEYS[7]
	event.pressed = true
	_check(input.press(event, prefs, slots) == &"fireball" and input.pending_rank == 1, "key down captures variant")
	slots[7] = ActionBarLayout.entry(&"fireball", 3)
	event.pressed = false
	event.alt_pressed = true
	_check(input.release(event) == &"fireball" and input.released_rank == 1, "key release preserves rank despite layout/modifier changes")
	input.cancel()
	_check(input.pending_rank == 0, "cancel clears rank latch")

func _codec() -> void:
	var catalog := ProfileCatalog.pilot()
	var profile := ProfileState.new(PROFILE_ID)
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Ranks", &"mage")
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	for rank: int in 5:
		_check(CharacterProgression.learn_skill(character, catalog, &"fireball")["ok"], "fixture purchases legal fireball rank")
	profile.characters.append(character)
	profile.next_character_counter = 2
	profile.selected_character_id = character.character_id
	character.action_slots = ActionBarLayout.assign(ActionBarLayout.empty(), &"fireball", 0)
	character.action_slots = ActionBarLayout.assign(character.action_slots, &"fireball", 23, 1)
	var wallet := CharacterProgression.summary(character, catalog)
	var encoded := ProfileCodec.encode(profile, catalog)
	_check(encoded["ok"], "schema6 variant profile encodes")
	if not encoded["ok"]: return
	var restored := ProfileCodec.decode(encoded["text"], catalog)
	_check(restored["ok"], "schema6 variant roundtrip decodes")
	if not restored["ok"]: return
	var copy: CharacterState = restored["profile"].characters[0]
	_check(copy.action_slots == character.action_slots and CharacterProgression.summary(copy, catalog) == wallet, "roundtrip preserves positions and learning wallets")
	# Historical fixture drops the schema-8 ownership envelope; schema 1-7 needs preview + confirmed digest: E07 F2 3b15ae8a (20/10).
	var old: Dictionary = H.legacy_envelope(encoded["data"])
	old["schema_version"] = 5
	for fixture_character: Dictionary in old["characters"]: fixture_character.erase("admin_skills_unlocked")
	old["catalog_version"] = 12
	old["characters"][0]["action_slots"][23] = null
	_check(ProfileCodec.decode(JSON.stringify(old), catalog).get("error_code") == &"migration_required", "schema5 opens protected until confirmed")
	var migrated := H.decode_confirmed(JSON.stringify(old), catalog)
	_check(migrated["ok"] and migrated.get("migrated", false), "schema5 explicit migration succeeds")
	if migrated["ok"]:
		_check(migrated["profile"].characters[0].action_slots[0] == &"fireball" and CharacterProgression.summary(migrated["profile"].characters[0], catalog) == wallet, "schema5 highest ID and points unchanged")
	old["characters"][0]["action_slots"][23] = {"skill_id": "fireball", "rank": 1}
	var disguised := H.decode_confirmed(JSON.stringify(old), catalog)
	_check(not disguised["ok"] and disguised.get("error_code") != &"migration_required", "schema5 cannot disguise schema6 slot")
	var malicious: Dictionary = encoded["data"].duplicate(true)
	malicious["characters"][0]["action_slots"][23]["rank"] = 6
	_check(not ProfileCodec.decode(JSON.stringify(malicious), catalog)["ok"], "codec rejects beyond catalog cap")
	# An item reference survives losing its source, with the authored explicit rank retained.
	character.action_slots[12] = ActionBarLayout.entry(&"teleport", 1)
	var retained := ProfileCodec.encode(profile, catalog)
	_check(retained["ok"], "disabled item reference persists without inventing grant")

func _snapshot() -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "downrank-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"fireball": 5, &"fire_wall": 2, &"fire_spear": 5, &"ice_spear": 5, &"teleport": 1, &"mage_mana_regeneration": 3}
	return snapshot

func _paid_cast() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	var run := RunState.from_build("downrank-paid", _snapshot())
	var player := PlayerActor.new()
	player.configure(navigation, run)
	root.add_child(player)
	player.set_process(false)
	var requests: Array[DamageRequest] = []
	player.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int) -> void: requests.append(request))
	var learned := run.skill_levels.duplicate(true)
	var grants := run.build_snapshot.skill_ranks.duplicate(true)
	var previous := player.push_cast_rank(&"fireball", 1)
	_check(player.skill_rank(&"fireball") == 1 and player.skill_rank(&"mage_mana_regeneration") == 3, "cast context changes only chosen active")
	_check(player.skill_cost(&"fireball") == 18.0 and player.skill_cast_time(&"fireball") == StatCalculator.effective_cast_time(0.0, 0.32, player.stat_breakdown), "rank1 authored cost and cast composition")
	var starting_sp := player.current_sp
	_check(player.use_fireball(Vector2.RIGHT), "rank1 executes paid emission from learned rank5")
	player.restore_cast_rank(previous)
	_check(player.current_sp == starting_sp - 18.0 and player.skill_rank(&"fireball") == 5 and player.skill_cost(&"fireball") == 24.0, "rank1 debits once and context restores highest")
	_check(requests.size() == 1 and requests[0].magic_damage == player.stat_breakdown.value(&"magic_attack") * 1.8 and requests[0].effect_snapshot["cast_rank"] == 1, "emission freezes rank1 power and rank metadata")
	var frozen := requests[0].magic_damage if not requests.is_empty() else 0.0
	previous = player.push_cast_rank(&"fireball", 3)
	_check(not player.use_fireball(Vector2.RIGHT), "different rank shares ID cooldown")
	player.restore_cast_rank(previous)
	_check(run.skill_levels == learned and run.build_snapshot.skill_ranks == grants, "paid downrank does not mutate learning or snapshot")
	player.mage_cooldowns.clear()
	player.current_sp = 18.0
	previous = player.push_cast_rank(&"fireball", 0)
	_check(not player.use_fireball(Vector2.RIGHT), "highest rank blocks on insufficient SP")
	player.restore_cast_rank(previous)
	previous = player.push_cast_rank(&"fireball", 1)
	_check(player.begin_skill_cast(&"fireball", Vector2(700, 400)), "preparation captures selected rank")
	player.restore_cast_rank(previous)
	_check(player.active_cast_rank == 1 and player.skill_rank(&"fireball") == 5, "preparation retains rank without leaking context")
	player.skill_cast_ready.connect(func(id: StringName, _point: Vector2, _target: int) -> void: player.use_fireball(Vector2.RIGHT) if id == &"fireball" else false)
	player._advance_active_cast(1.0)
	_check(requests.size() == 2 and player.current_sp == 0.0 and requests[-1].effect_snapshot["cast_rank"] == 1, "prepared release spends and emits captured rank")
	_check(requests[0].magic_damage == frozen and player.skill_rank(&"fireball") == 5, "old request remains frozen and release restores context")
	player.mage_cooldowns.clear()
	player.current_sp = player.max_sp
	previous = player.push_cast_rank(&"fireball", 3)
	_check(player.begin_skill_cast(&"fireball", Vector2(700, 400)), "rank3 preparation starts with access")
	player.restore_cast_rank(previous)
	run.skill_levels[&"fireball"] = 2
	player._advance_active_cast(1.0)
	_check(requests.size() == 2, "lost explicit rank access cancels emission without promotion")
	previous = player.push_cast_rank(&"fireball", 3)
	_check(not player.selected_cast_rank_valid(&"fireball") and not player.use_fireball(Vector2.RIGHT), "retained inaccessible rank cannot execute")
	player.restore_cast_rank(previous)
	var composed := run.composed_build()
	var disabled_preview := SkillEffectResolver.preview_retained(&"fireball",3,composed)
	_check(disabled_preview["ok"] and disabled_preview["values"]["sp_cost"] == 22.0 and int(composed["skill_ranks"][&"fireball"]) == 2, "disabled retained rank previews its own cost without granting access")
	_check(requests[0].magic_damage == frozen, "changing effective access never changes emitted request")
	player.queue_free()
	await process_frame

func _kit_casts() -> void:
	var groups := {
		&"defender": [[&"defender_counterstroke", "use_defender_counterstroke", "cone"], [&"defender_anchor", "use_defender_anchor", "point"], [&"defender_line_lock", "use_defender_line_lock", "cone"], [&"defender_reprisal_wave", "use_defender_reprisal_wave", "area"]],
		&"elementalist": [[&"elementalist_flame_burst", "use_elementalist_flame_burst", "point"], [&"elementalist_glacial_ring", "use_elementalist_glacial_ring", "self"], [&"elementalist_lightning_arc", "use_elementalist_lightning_arc", "target"], [&"elementalist_ember_path", "use_elementalist_ember_path", "direction"], [&"elementalist_tri_nova", "use_elementalist_tri_nova", "self"]],
		&"berserker": [[&"berserker_rupture", "use_berserker_rupture", "target"], [&"berserker_execution", "use_berserker_execution", "target"], [&"berserker_breath_steal", "use_berserker_breath_steal", "target"], [&"berserker_blood_rift", "use_berserker_blood_rift", "cone"]],
		&"spiritualist": [[&"spiritualist_echo_curse", "use_spiritualist_echo_curse", "target"], [&"spiritualist_spectral_veil", "use_spiritualist_spectral_veil", "point"], [&"spiritualist_dissipation", "use_spiritualist_dissipation", "point"]],
	}
	for evolution: StringName in groups:
		var navigation := ArenaNavigation.new()
		navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
		var snapshot := BuildSnapshot.new()
		snapshot.base_class_id = &"swordsman" if evolution in [&"defender", &"berserker"] else &"mage"
		snapshot.evolution_id = evolution
		snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
		var catalog := ProfileCatalog.pilot()
		snapshot.library_skill_ids = catalog.skill_ids_for_identity(snapshot.base_class_id, evolution)
		for id: StringName in snapshot.library_skill_ids:
			snapshot.skill_ranks[id] = int(catalog.skill_metadata(id)["free_rank"]) + int(catalog.skill_metadata(id)["max_purchased_rank"])
		var run := RunState.from_build("downrank-kits", snapshot)
		var player := PlayerActor.new()
		player.configure(navigation, run)
		root.add_child(player)
		player.position = Vector2(400, 400)
		player.set_process(false)
		var enemy := CombatActor.new()
		enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
		root.add_child(enemy)
		enemy.position = Vector2(480, 400)
		enemy.set_process(false)
		var enemies: Array[CombatActor] = [enemy]
		var requests: Array[DamageRequest] = []
		var scalars: Array[float] = []
		player.berserker_rift_hit_requested.connect(func(request: DamageRequest, _target: CombatActor, _bleed: DamageRequest) -> void: requests.append(request))
		player.berserker_breath_hit_requested.connect(func(request: DamageRequest, _target: CombatActor, fraction: float, _wounded: bool) -> void: requests.append(request); scalars.append(fraction))
		player.attack_requested.connect(func(request: DamageRequest, _target: CombatActor) -> void: requests.append(request))
		player.defender_hit_requested.connect(func(request: DamageRequest, _target: CombatActor, duration: float, _push: Vector2) -> void: requests.append(request); scalars.append(duration))
		player.elementalist_flame_burst_requested.connect(func(_center: Vector2, request: DamageRequest) -> void: requests.append(request))
		player.elementalist_area_requested.connect(func(_id: StringName, _center: Vector2, _radius: float, request: DamageRequest, _element: StringName) -> void: requests.append(request))
		player.elementalist_lightning_arc_requested.connect(func(request: DamageRequest, _target: CombatActor, _jump: float, _bonus: float) -> void: requests.append(request))
		player.elementalist_ember_path_requested.connect(func(_centers: Array[Vector2], request: DamageRequest) -> void: requests.append(request))
		player.elementalist_tri_nova_requested.connect(func(_center: Vector2, values: Array[DamageRequest], _bonus: float) -> void: requests.append_array(values))
		player.spiritualist_echo_curse_requested.connect(func(request: DamageRequest, _target: CombatActor, power: float) -> void: requests.append(request); scalars.append(power))
		player.spiritualist_veil_requested.connect(func(_center: Vector2, duration: float, fraction: float) -> void: scalars.append(duration); scalars.append(fraction))
		player.spiritualist_dissipation_requested.connect(func(_center: Vector2, request: DamageRequest, _marked: float, _focus: float) -> void: requests.append(request))
		for row: Array in groups[evolution]:
			var id: StringName = row[0]
			requests.clear()
			scalars.clear()
			player.mage_cooldowns.clear()
			player.current_sp = player.max_sp
			var previous := player.push_cast_rank(id, 1)
			var cost := player.skill_cost(id)
			var sp := player.current_sp
			var args: Array = []
			match row[2]:
				"cone": args = [Vector2.RIGHT, enemies]
				"point": args = [Vector2(480, 400)]
				"area": args = [enemies]
				"direction": args = [Vector2.RIGHT]
				"target": args = [enemy]
			var succeeded: bool = player.callv(row[1], args)
			player.restore_cast_rank(previous)
			_check(succeeded and player.current_sp == sp - cost, "%s rank1 executes and debits selected cost" % id)
			_check(player.skill_rank(id) == run.effective_skill_rank(id), "%s restores effective rank after emission" % id)
			var rank := ClassCatalog.skill_definition(id).rank_definition(1)
			if id == &"defender_anchor":
				_check(player.defender_anchor_remaining == rank.power, "anchor duration freezes selected rank")
			elif id == &"spiritualist_spectral_veil":
				_check(scalars == [rank.secondary_power, rank.power], "veil duration and fraction freeze selected rank")
			else:
				_check(not requests.is_empty() and requests[0].effect_snapshot["cast_rank"] == 1, "%s emitted request freezes rank1" % id)
				if not requests.is_empty():
					var stat := &"melee_attack" if evolution in [&"defender", &"berserker"] else &"magic_attack"
					var damage := requests[0].physical_damage if evolution in [&"defender", &"berserker"] else requests[0].magic_damage
					_check(is_equal_approx(damage, player.stat_breakdown.value(stat) * rank.power), "%s emitted primary power uses rank1" % id)
			if id == &"spiritualist_echo_curse":
				_check(scalars == [rank.secondary_power], "curse delayed echo scalar freezes selected rank")
		player.queue_free()
		enemy.queue_free()
		await process_frame

func _deferred_impacts() -> void:
	for evolution: StringName in [&"defender", &"berserker"]:
		var navigation := ArenaNavigation.new()
		navigation.configure(Rect2(0,0,1200,800),[],20.0)
		var snapshot := BuildSnapshot.new()
		snapshot.base_class_id = &"swordsman"
		snapshot.evolution_id = evolution
		snapshot.job_level = 40
		var catalog := ProfileCatalog.pilot()
		snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"swordsman",evolution)
		for id: StringName in snapshot.library_skill_ids:
			var metadata := catalog.skill_metadata(id)
			snapshot.skill_ranks[id] = int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
		var player := PlayerActor.new()
		player.configure(navigation,RunState.from_build("deferred-downrank",snapshot))
		root.add_child(player)
		player.position = Vector2(400,400)
		player.set_process(false)
		var enemy := CombatActor.new()
		enemy.setup("Alvo",Color.WHITE,StatCalculator.calculate({&"vit":10}),18)
		root.add_child(enemy)
		enemy.position = Vector2(460,400)
		enemy.set_process(false)
		var enemies: Array[CombatActor] = [enemy]
		var requests: Array[DamageRequest] = []
		player.attack_requested.connect(func(request: DamageRequest,_target: CombatActor) -> void: requests.append(request))
		player.defender_hit_requested.connect(func(request: DamageRequest,_target: CombatActor,_duration: float,_push: Vector2) -> void: requests.append(request))
		var id := &"defender_wall_advance" if evolution == &"defender" else &"berserker_wound_leap"
		var previous := player.push_cast_rank(id,1)
		var expected := player.stat_breakdown.value(&"melee_attack") * ClassCatalog.skill_definition(id).rank_definition(1).power
		var success := player.use_defender_wall_advance(Vector2.RIGHT,enemies) if evolution == &"defender" else player.use_berserker_wound_leap(Vector2.RIGHT,enemies)
		player.restore_cast_rank(previous)
		_check(success and player.skill_rank(id) == 5, "%s launch restores highest rank before impact" % id)
		if evolution == &"defender": player._try_defender_advance_hit(Vector2(400,400),Vector2(500,400))
		else: player._try_berserker_leap_hit(Vector2(400,400),Vector2(500,400))
		_check(requests.size() == 1 and is_equal_approx(requests[0].physical_damage,expected) and requests[0].effect_snapshot["cast_rank"] == 1, "%s delayed impact uses launch capture rather than highest" % id)
		if evolution == &"defender": player._try_defender_advance_hit(Vector2(400,400),Vector2(500,400))
		else: player._try_berserker_leap_hit(Vector2(400,400),Vector2(500,400))
		_check(requests.size() == 1, "%s impact remains single claim" % id)
		player._stop_dash()
		player.queue_free()
		enemy.queue_free()
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
