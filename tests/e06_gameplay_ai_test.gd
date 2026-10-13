extends SceneTree
## Author checks for bounded engagement using real actors, navigation and damage.
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_acquisition_and_damage()
	_visibility_and_return()
	_hunter_and_taunt()
	_controls_and_summoning()
	_legacy_and_occurrence_stats()
	print("E06 gameplay AI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _fixture(summoned: bool = false, hunter: bool = false, legacy: bool = false) -> Dictionary:
	var owner := Node2D.new()
	root.add_child(owner)
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 2600, 1700), [], 20.0)
	var target := PlayerActor.new()
	owner.add_child(target)
	target.set_process(false)
	target.global_position = Vector2(1100, 800)
	var state := RunState.new()
	if hunter:
		var build := BuildSnapshot.new()
		build.character_id = "e06-ai-hunter"
		build.base_class_id = &"archer"
		build.evolution_id = &"hunter"
		build.base_level = 30
		build.job_level = 40
		build.skill_ranks = {&"hunter_total_cover": 1}
		state = RunState.from_build("", build)
	target.configure(nav, state)
	var catalog := MobCatalog.new()
	var definition := BuildContentLoader.pilot().mob_catalog().get_definition(&"demo_chaser")
	definition.id = &"ai_master"
	definition.allowed_occurrence_categories = [&"rare", &"elite", &"boss"]
	definition.origin_levels = {&"ai_origin": 6}
	definition.encounter_tiers = not legacy
	definition.aggro_radius = 0.0 if legacy else 420.0
	definition.leash_radius = 0.0 if legacy else 850.0
	definition.sight_timeout = 4.0
	definition.summons_companion = not legacy
	_check(catalog.register_definition(definition)["ok"], "fixture definition accepted")
	var spawn := MobOccurrence.new()
	spawn.occurrence_id = "ai_fixture"
	spawn.mob_base_id = &"ai_master"
	spawn.category_id = &"rare"
	spawn.origin_id = &"ai_origin"
	var enemy := EnemyActor.new()
	owner.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position = Vector2(500, 800)
	enemy.is_summoned = summoned
	var summons := [0]
	var attacks := [0]
	enemy.companion_requested.connect(func(_master: EnemyActor) -> void: summons[0] += 1)
	enemy.attack_requested.connect(func(_request: DamageRequest, _victim: CombatActor, _ranged: bool) -> void: attacks[0] += 1)
	_check(enemy.configure_occurrence(spawn, catalog, nav, target)["ok"], "actor configured with occurrence stats")
	return {"owner": owner, "enemy": enemy, "player": target, "nav": nav, "catalog": catalog, "spawn": spawn, "summons": summons, "attacks": attacks}

func _damage(enemy: EnemyActor, source_id: int, power: float) -> Dictionary:
	var request := DamageRequest.new()
	request.source_id = source_id
	request.target_id = enemy.get_instance_id()
	request.skill_id = &"ai_damage_fixture"
	request.physical_damage = power
	request.can_crit = false
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	return enemy.apply_damage(request, RandomNumberGenerator.new())

func _advance(enemy: EnemyActor, duration: float, hz: int = 60) -> void:
	for _step: int in range(roundi(duration * hz)):
		enemy._process(1.0 / float(hz))

func _acquisition_and_damage() -> void:
	var f := _fixture()
	var enemy: EnemyActor = f["enemy"]
	var target: PlayerActor = f["player"]
	_check(enemy.spawn_home == Vector2(500, 800) and enemy.engagement_mode == &"idle" and f["summons"][0] == 0, "placement defines home; player at 600 does not acquire")
	target.global_position = Vector2(921, 800)
	enemy._process(0.0)
	_check(enemy.engagement_mode == &"idle", "421px remains outside acquisition")
	target.global_position = Vector2(920, 800)
	enemy._process(0.0)
	_check(enemy.engagement_mode == &"engaged" and enemy.player_target_acquired and f["summons"][0] == 1, "420px visible target acquires and summons once")
	(f["owner"] as Node).free()
	f = _fixture()
	enemy = f["enemy"]
	target = f["player"]
	_damage(enemy, target.get_instance_id(), 0.0)
	_check(enemy.engagement_mode == &"idle" and f["summons"][0] == 0, "zero damage cannot provoke")
	enemy.health.grant_shield(100.0)
	var absorbed := _damage(enemy, target.get_instance_id(), 10.0)
	_check(absorbed["actual_damage"] == 0.0 and enemy.engagement_mode == &"idle" and f["summons"][0] == 0, "fully absorbed damage cannot provoke or summon")
	enemy.health.clear_shield()
	_damage(enemy, 12345, 1.0)
	_check(enemy.engagement_mode == &"idle", "foreign positive damage cannot acquire the player")
	var hp := enemy.health.current_hp
	var hit := _damage(enemy, target.get_instance_id(), 10.0)
	_check(hit["actual_damage"] > 0.0 and enemy.health.current_hp < hp and enemy.engagement_mode == &"engaged" and f["summons"][0] == 1, "positive player damage provokes outside aggro inside leash")
	(f["owner"] as Node).free()
	f = _fixture()
	enemy = f["enemy"]
	target = f["player"]
	target.health.current_hp = 0.0
	_damage(enemy, target.get_instance_id(), 1.0)
	_check(enemy.engagement_mode == &"idle" and f["summons"][0] == 0, "damage owned by dead player cannot acquire a living target")
	target.health.current_hp = target.health.max_hp
	_damage(enemy, target.get_instance_id(), 1000000.0)
	_check(not enemy.is_alive() and f["summons"][0] == 0, "lethal damage cannot request a companion from a dead master")
	(f["owner"] as Node).free()

func _visibility_and_return() -> void:
	for hz: int in [30, 60, 144]:
		var f := _fixture()
		var enemy: EnemyActor = f["enemy"]
		var target: PlayerActor = f["player"]
		var nav: ArenaNavigation = f["nav"]
		target.global_position = Vector2(800, 800)
		nav.configure(Rect2(0, 0, 2600, 1700), [Rect2(650, 700, 40, 200)], 20.0)
		enemy._process(0.0)
		_check(enemy.engagement_mode == &"idle", "blocked line of sight prevents initial acquisition at %dHz" % hz)
		nav.configure(Rect2(0, 0, 2600, 1700), [], 20.0)
		enemy._process(0.0)
		_damage(enemy, target.get_instance_id(), 20.0)
		var hp := enemy.health.current_hp
		var seen := enemy.hunter_last_seen_position
		nav.configure(Rect2(0, 0, 2600, 1700), [Rect2(850, 700, 40, 200)], 20.0)
		target.global_position = Vector2(1000, 800)
		_advance(enemy, 3.5, hz)
		_check(enemy.engagement_mode == &"engaged" and not enemy.player_target_acquired and enemy.hunter_last_seen_position == seen and enemy.global_position.distance_to(seen) < 2.0 and f["attacks"][0] == 0, "unseen target only pursues last seen before timeout at %dHz" % hz)
		_damage(enemy, target.get_instance_id(), 1.0)
		_check(enemy.hunter_last_seen_position == seen, "further damage cannot track hidden position at %dHz" % hz)
		_advance(enemy, 0.6, hz)
		_check(enemy.engagement_mode == &"returning" and f["attacks"][0] == 0, "four seconds without sight forces return at %dHz" % hz)
		target.global_position = Vector2(810, 800)
		enemy.apply_taunt(10.0)
		_damage(enemy, target.get_instance_id(), 5.0)
		hp = enemy.health.current_hp
		enemy._try_attack(false)
		_check(enemy.engagement_mode == &"returning" and not enemy.player_target_acquired and f["attacks"][0] == 0, "taunt, vision and damage cannot cancel mandatory return at %dHz" % hz)
		target.global_position = Vector2(1400, 800)
		_advance(enemy, 3.0, hz)
		_check(enemy.global_position.distance_to(enemy.spawn_home) < 2.0 and enemy.health.current_hp == hp and f["summons"][0] == 1 and enemy.summon_used, "return preserves damage and cannot replenish summon at %dHz" % hz)
		(f["owner"] as Node).free()

func _hunter_and_taunt() -> void:
	var f := _fixture(false, true)
	var enemy: EnemyActor = f["enemy"]
	var target: PlayerActor = f["player"]
	target.global_position = Vector2(800, 800)
	enemy._process(0.0)
	var seen := enemy.hunter_last_seen_position
	target.hunter_cover.begin_cycle()
	_check(target.register_foliage_shelter(999, target.global_position, 50.0), "real Hunter cover fixture binds")
	target.global_position = Vector2(820, 800)
	_check(target.is_concealed() and not target.can_be_acquired_by(enemy.global_position), "Hunter is hidden from outside observer")
	enemy._process(0.2)
	_check(not enemy.player_target_acquired and enemy.hunter_last_seen_position == seen and f["attacks"][0] == 0, "engaged Hunter is tracked at last seen without hidden attacks")
	enemy.apply_taunt(3.0)
	enemy._process(0.0)
	_check(enemy.player_target_acquired and enemy.hunter_last_seen_position == target.global_position, "taunt retains existing Hunter override within leash")
	target.global_position = Vector2(1400, 800)
	enemy._process(0.0)
	_check(enemy.engagement_mode == &"returning" and not enemy.player_target_acquired, "player beyond850 forces return despite taunt")
	_damage(enemy, target.get_instance_id(), 10.0)
	enemy._try_attack(false)
	_check(enemy.engagement_mode == &"returning" and f["attacks"][0] == 0, "damage beyond leash cannot reopen pursuit")
	(f["owner"] as Node).free()
	f = _fixture()
	enemy = f["enemy"]
	target = f["player"]
	target.global_position = Vector2(800, 800)
	enemy._process(0.0)
	enemy.global_position = Vector2(1351, 800)
	enemy._process(0.0)
	_check(enemy.engagement_mode == &"returning", "actor beyond850 forces return even if player remains inside")
	(f["owner"] as Node).free()

func _controls_and_summoning() -> void:
	var f := _fixture()
	var enemy: EnemyActor = f["enemy"]
	var target: PlayerActor = f["player"]
	enemy.apply_stun(2.0)
	target.global_position = Vector2(800, 800)
	enemy._process(0.1)
	_check(enemy.engagement_mode == &"engaged" and f["summons"][0] == 0 and enemy.global_position == enemy.spawn_home, "stun suppresses summon and walking after acquisition")
	enemy.clear_statuses()
	enemy.apply_fear(2.0)
	enemy._process(0.1)
	_check(f["summons"][0] == 0 and f["attacks"][0] == 0 and enemy.global_position.x < enemy.spawn_home.x, "fear retains flee and suppresses summon/attacks")
	enemy.clear_statuses()
	enemy.apply_root(2.0)
	var before := enemy.global_position
	enemy._process(0.1)
	_check(enemy.global_position == before and f["summons"][0] == 1, "root blocks walking but retains acquisition and one summon")
	target.global_position = Vector2(1400, 800)
	enemy._process(0.1)
	_check(enemy.engagement_mode == &"returning" and enemy.global_position == before, "root holds mandatory return without cancelling it")
	enemy.clear_statuses()
	_advance(enemy, 1.0)
	_check(enemy.engagement_mode == &"idle" and enemy.global_position.distance_to(enemy.spawn_home) < 0.1, "unrooted return reaches home then idles")
	target.global_position = Vector2(700, 800)
	enemy._process(0.0)
	_check(f["summons"][0] == 1 and enemy.summon_used, "reacquisition never summons a replacement")
	(f["owner"] as Node).free()
	f = _fixture(true)
	enemy = f["enemy"]
	target = f["player"]
	target.global_position = Vector2(530, 800)
	enemy._process(0.0)
	enemy._try_attack(false)
	_check(f["summons"][0] == 0 and not enemy.summon_used and f["attacks"][0] == 1, "summoned actor can attack but cannot summon recursively")
	(f["owner"] as Node).free()
	f = _fixture()
	enemy = f["enemy"]
	target = f["player"]
	target.global_position = Vector2(800, 800)
	paused = true
	enemy._process(5.0)
	_check(enemy.engagement_mode == &"idle" and f["summons"][0] == 0 and enemy.global_position == enemy.spawn_home, "pause freezes acquisition, movement and summon")
	paused = false
	enemy._process(0.0)
	target.global_position = Vector2(1400, 800)
	enemy._process(0.0)
	var mode := enemy.engagement_mode
	before = enemy.global_position
	paused = true
	enemy._process(5.0)
	_check(enemy.engagement_mode == mode and enemy.global_position == before, "pause also freezes mandatory return")
	paused = false
	(f["owner"] as Node).free()

func _legacy_and_occurrence_stats() -> void:
	var f := _fixture(false, false, true)
	var enemy: EnemyActor = f["enemy"]
	var target: PlayerActor = f["player"]
	var start := enemy.global_position
	_check(enemy.player_target_acquired, "aggro0 legacy immediately acquires outside new radius")
	target.global_position = Vector2(1500, 800)
	enemy._process(0.2)
	_check(enemy.player_target_acquired and enemy.global_position.x > start.x and enemy.engagement_mode == &"idle", "legacy follows beyond new leash without state-machine behavior")
	(f["owner"] as Node).free()
	f = _fixture()
	enemy = f["enemy"]
	var spawn: MobOccurrence = f["spawn"]
	var catalog: MobCatalog = f["catalog"]
	var expected := catalog.stats_for_occurrence(spawn)
	_check(expected["level"] == 6 and enemy.health.max_hp == expected["breakdown"].value(&"max_hp") and enemy.stat_breakdown.value(&"melee_attack") == expected["breakdown"].value(&"melee_attack"), "actor receives central fixed-origin and tier stats exactly once")
	spawn.category_id = &"elite"
	_check(enemy.occurrence.category_id == &"rare" and catalog.get_definition(&"ai_master").allowed_occurrence_categories == [&"rare", &"elite", &"boss"], "actor owns occurrence copy and cannot mutate catalog")
	(f["owner"] as Node).free()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
