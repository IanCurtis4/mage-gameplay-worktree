extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"spiritualist_spectral_veil")
	var definition := ClassCatalog.skill_definition(&"spiritualist_spectral_veil")
	_check(catalog.is_valid() and metadata["rank_requirements"][1]["job_level"] == 28 and definition.is_rank_catalog_valid(), "Veil unlocks at job 28 with typed ranks")
	for index: int in range(5):
		var rank := definition.rank_definition(index + 1)
		_check(is_equal_approx(rank.power, 0.15) and is_equal_approx(rank.secondary_power, 3.0 + 0.5 * float(index)) and is_equal_approx(rank.range, 250.0), "R%d stores same-channel debuff and approved duration" % (index + 1))
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [Rect2(600, 300, 40, 100)], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.job_level = 28
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_spectral_veil": 1}
	snapshot.active_slots = [&"spiritualist_spectral_veil", &"spiritualist_echo_curse", null, null, null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("veil", snapshot))
	player.global_position = Vector2(400, 350)
	var inside := _enemy(Vector2(490, 350))
	var outside := _enemy(Vector2(750, 350))
	var controller := RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(600, 300, 40, 100)], 20.0)
	controller.enemies = [inside, outside]
	player.spiritualist_veil_requested.connect(controller._on_spiritualist_veil_requested)
	_check(player.can_place_spiritualist_veil(Vector2(480, 350)) and not player.can_place_spiritualist_veil(Vector2(700, 350)), "point placement rejects obstacle crossings")
	_check(player.spiritualist_veil_center(Vector2(1000, 350)).distance_to(player.global_position) <= 250.001, "preview and commit clamp to 250")
	var hp_inside := inside.health.current_hp
	var hp_outside := outside.health.current_hp
	var sp_before := player.current_sp
	_check(player.use_spiritualist_spectral_veil(Vector2(480, 350)) and player.current_sp == sp_before - 20.0 and player.skill_cooldown(&"spiritualist_spectral_veil") > 0.0, "commit spends SP and cooldown once")
	_check(controller.spiritualist_veil_state.active and controller.spiritualist_veil_state.center == Vector2(480, 350) and controller.spiritualist_veil_state.remaining == 3.0, "one zone starts at approved center and R1 duration")
	_check(inside.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.15 and outside.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) == 0.0, "only enemy inside exact radius receives debuff")
	_check(inside.health.current_hp == hp_inside and outside.health.current_hp == hp_outside, "zone never deals damage")
	_check(controller.battle_indicators.spiritualist_veil_center == controller.spiritualist_veil_state.center and SpiritualistVeilState.RADIUS == 110.0, "halo is cosmetic and contour matches authoritative radius")
	inside.apply_weaken(0.20, 4.0, &"another_source")
	controller._advance_spiritualist_veil(0.1)
	_check(is_equal_approx(inside.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT), 0.20), "independent sources use strongest fraction, not additive")
	inside.global_position = Vector2(700, 350)
	controller._advance_spiritualist_veil(0.1)
	_check(inside.attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_spectral_veil") == 0.0 and is_equal_approx(inside.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT), 0.20), "leaving zone removes only its own source")
	inside.global_position = Vector2(490, 350)
	controller._advance_spiritualist_veil(0.1)
	_check(inside.attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_spectral_veil") > 0.0, "re-entry refreshes debuff")
	controller._on_spiritualist_veil_requested(Vector2(350, 350), 5.0, 0.15)
	_check(controller.spiritualist_veil_state.center == Vector2(350, 350) and inside.attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_spectral_veil") == 0.0, "new zone immediately replaces and cleans old zone")
	controller._advance_spiritualist_veil(5.01)
	_check(not controller.spiritualist_veil_state.active and controller.battle_indicators.spiritualist_veil_remaining == 0.0, "expiry removes runtime and visual zone")
	var blocked_sp := player.current_sp
	player.mage_cooldowns[&"spiritualist_spectral_veil"] = 0.0
	_check(not player.use_spiritualist_spectral_veil(Vector2(700, 350)) and player.current_sp == blocked_sp, "blocked cast fails atomically")
	player.free()
	inside.free()
	outside.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Espiritualista Véu Espectral: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
