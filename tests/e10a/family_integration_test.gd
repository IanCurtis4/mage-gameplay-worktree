extends SceneTree
## E10a T15 (A15) — the family on the production modules, with no fixture base: the Acólito base
## of the T5 under the Cultista (T7) and the Sacerdote (T6) kits, both attached by
## PlayerActor.configure from a BuildSnapshot (the RunController start path), hits delivered by the
## RunController handlers.
## - Cultista: the base's Sussurro and Selo feed the single authority that MadnessAuthority.of()
##   finds in the origin, the Cultista's Olhar adds to the same marks, the Êxtase is turned on by
##   the passive and forwarded once (cost, MATK, onus), the base's Escudo Votivo and Prece
##   compensate it.
## - Sacerdote: the barrier_received hook (A15.3) reaches the Égide through
##   CombatActor.grant_barrier, the Fé Protetora reinforces it once, its expiry still clears the
##   reinforced barrier, and the base's Prece and Escudo still give Grace.
## - Every barrier producer of scripts/ is either on grant_barrier or on an exact legacy list.
## - The review builds: no rank 0 in the Cultista file, the strict E09 reader accepts both pure
##   files, and the T10 tool reads them in place.
## Fixture profiles only; nothing is written to disk.
const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const E09Profiles = preload("res://tools/e09_review_profiles.gd")
const FamilyProfiles = preload("res://tools/e10a_review_profiles.gd")
const BASE_PATH := "res://scripts/classes/bases/acolyte/acolyte_base.gd"
const CULTIST_PATH := "res://scripts/classes/cultist/cultist_kit.gd"
const PRIEST_PATH := "res://scripts/classes/priest/priest_kit.gd"
const GAZE := &"cultist_abyss_gaze"
const ECSTASY := &"cultist_ecstasy"
## Producers that still call HealthState.grant_shield directly (T15 recibo, A17): the path
## itself (combat_actor.gd), the Espadachim's Muralha (player_actor.gd, never beside an Acólito
## module) and the T7 test stand-in of the base (never registered in production). The Égide of
## the Sacerdote, of the Paladino (sp_ac) and of the Taumaturgo (mg_ac) goes through
## SanctuaryAuthority.grant_aegis, so through the hook.
const DIRECT_GRANT_SHIELD := ["res://scripts/actors/combat_actor.gd", "res://scripts/actors/player_actor.gd", "res://scripts/classes/cultist/fixture/cultist_fixture_base.gd"]

class Controller extends RunController:
	func _ready() -> void: pass

var checks := 0
var failures := 0
var owned: Array[Node] = []
var controller: Controller
var player: PlayerActor
var navigation: ArenaNavigation
var mob_serial := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	_check(ClassBaseRegistry.ready_for_play(&"acolyte") and ClassBaseRegistry.module(&"acolyte").get_script().resource_path == BASE_PATH, "the production Acólito base is the registered module (no fixture)")
	_check_cultist_on_real_base()
	_check_ecstasy_on_real_base()
	_check_priest_barriers()
	_check_priest_grace_from_base()
	_check_barrier_producers()
	_check_review_builds()
	_cleanup()
	ClassKitRegistry.clear_fixtures()
	KitDecoy.unregister_drawer(MadnessRules.IDOL_DRAWER)
	print("E10a T15 family integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# --- Fixture --------------------------------------------------------------------------

func _cleanup() -> void:
	for node: Node in owned:
		if is_instance_valid(node):
			if node.get_parent() != null: node.get_parent().remove_child(node)
			node.free()
	owned.clear()
	paused = false

## A job-40 character of the family, built and configured as RunController._ready does.
func _setup(evolution: StringName, ranks: Dictionary) -> void:
	_cleanup()
	navigation = ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1400, 900), [], 20.0)
	controller = Controller.new()
	controller.set_process(false)
	root.add_child(controller)
	owned.append(controller)
	controller.navigation = navigation
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL
	snapshot.base_class_id = &"acolyte"
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"acolyte", evolution)
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	player = PlayerActor.new()
	player.configure(navigation, RunState.from_build("t15-%s-%d" % [evolution, checks], snapshot))
	controller.add_child(player)
	player.set_process(false)
	player.global_position = Vector2(400, 350)
	player.character_animation.state.face(Vector2.RIGHT)
	controller.player = player
	controller.run_state = player.run_state
	controller.rng.seed = 31
	controller.enemies = []
	player.attack_requested.connect(controller._on_attack_requested)
	player.status_damage_requested.connect(controller._on_attack_requested)
	# Stand-in for the flight of the magic projectile: a projectile with a target lands at once.
	player.mage_projectile_requested.connect(func(_skill: StringName, request: DamageRequest, victim: CombatActor, _direction: Vector2, _count: int) -> void:
		if is_instance_valid(victim): controller._on_attack_requested(request, victim))
	player.max_sp = 1000.0
	player.current_sp = 1000.0

func _cultist_ranks(ecstasy_rank: int = 3) -> Dictionary:
	var ranks := {&"acolyte_punishing_light": 1, &"acolyte_prayer": 5, &"acolyte_votive_shield": 5, &"acolyte_shadow_seal": 5, &"acolyte_disturbing_whisper": 5, &"acolyte_eldritch_vision": 1, &"acolyte_protective_faith": 1}
	for skill: StringName in ClassKitRegistry.skill_ids(&"cultist"): ranks[skill] = 3 if skill in [ECSTASY, &"cultist_open_pupil"] else 5
	ranks[ECSTASY] = ecstasy_rank
	return ranks

func _priest_ranks(faith_rank: int = 3) -> Dictionary:
	var ranks := {&"acolyte_punishing_light": 2, &"acolyte_prayer": 5, &"acolyte_votive_shield": 5, &"acolyte_shadow_seal": 1, &"acolyte_devotion": 3, &"acolyte_protective_faith": faith_rank}
	for skill: StringName in ClassKitRegistry.skill_ids(&"priest"): ranks[skill] = 3 if skill in [&"priest_grace", &"priest_exorcist"] else 5
	return ranks

## A real catalog mob of the forest phase, wired to the RunController like the game does.
func _mob(mob_id: StringName, at: Vector2, category: StringName = &"normal", hp: float = 100000.0) -> EnemyActor:
	mob_serial += 1
	var hostile := EnemyActor.new()
	hostile.global_position = at
	var spawn := MobOccurrence.new()
	spawn.occurrence_id = "t15_%s_%03d" % [mob_id, mob_serial]
	spawn.mob_base_id = mob_id
	spawn.category_id = category
	spawn.origin_id = &"trial_stage_1"
	var configured := hostile.configure_occurrence(spawn, BuildContentLoader.pilot().mob_catalog(), navigation, player)
	_check(configured.get("ok", false), "real mob %s configured: %s" % [mob_id, configured])
	controller.add_child(hostile)
	hostile.set_process(false)
	hostile.health.max_hp = hp
	hostile.health.current_hp = hp
	hostile.attack_requested.connect(controller._on_enemy_attack_requested)
	hostile.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	controller.enemies.append(hostile)
	return hostile

## Gameplay clock: enemy statuses and overrides, then the player's own tick (PlayerActor._process).
func _advance(delta: float) -> void:
	for candidate: Variant in controller.enemies.duplicate():
		var hostile := candidate as EnemyActor
		if is_instance_valid(hostile) and hostile.is_alive():
			hostile.advance_statuses(delta)
			hostile._advance_target_override(delta)
	player._process(delta)

func _advance_for(seconds: float, step: float = 0.05) -> void:
	var left := seconds
	while left > 0.0001:
		_advance(minf(step, left))
		left -= step

func _cast(skill: StringName, enemy: CombatActor = null) -> bool:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp
	player.kit_time += 0.001
	var definition := ClassKitRegistry.skill_definition(skill)
	var single := definition != null and definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET
	return player.use_kit_skill(skill, enemy.global_position if enemy != null else player.global_position, enemy if single else null)

func _enemy_request(source: CombatActor, amount: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_claw"
	request.physical_damage = amount
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.context = player.run_state.effect_ledger.new_root(source.get_instance_id(), false, "", false, {})
	return request

func _taken(source: CombatActor, amount: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return player.apply_damage(_enemy_request(source, amount), rng)

func _near(a: float, b: float, tolerance: float = 0.01) -> bool:
	return absf(a - b) < tolerance

# --- Cultista over the production base ------------------------------------------------

func _check_cultist_on_real_base() -> void:
	_setup(&"cultist", _cultist_ranks())
	var origin := player.origin_kit
	var kit := player.kit
	_check(origin != null and origin.get_script().resource_path == BASE_PATH, "Cultista: the origin is the production Acólito base")
	_check(kit != null and kit.get_script().resource_path == CULTIST_PATH, "Cultista: the evolution is the production Cultista kit")
	var authority := MadnessAuthority.of(player) as MadnessAuthority
	_check(authority != null and authority == origin.get(&"madness") and kit.get(&"madness") == null, "one Madness authority, the base's field; the Cultista keeps none")
	_check(authority != null and authority.owner_id == player.get_instance_id() and authority.stat_source_id == &"cultist_ecstasy", "the Cultista reconfigured the base's authority for its Êxtase")
	if authority == null: return
	_check(authority.ecstasy.enabled, "the Êxtase passive (R3) turns the charges on")
	# Sussurro, Selo (base) and Olhar (Cultista) add to the same marks.
	var wolf := _mob(&"forest_wolf", Vector2(520, 350))
	var boar := _mob(&"forest_boar", Vector2(300, 350)) # behind the Cultista: outside every cone
	_check(_cast(&"acolyte_disturbing_whisper", wolf), "the base's Sussurro commits under the Cultista")
	_check(is_equal_approx(MadnessAuthority.madness_of(wolf), 40.0) and wolf.marks.owner_of(MadnessRules.MARK_MADNESS) == player.get_instance_id(), "Sussurro R5: 40 Madness on the shared marks (%.1f)" % MadnessAuthority.madness_of(wolf))
	var gained := authority.gained_total
	_check(_cast(&"acolyte_shadow_seal", wolf), "the base's Selo commits under the Cultista")
	_check(is_equal_approx(MadnessAuthority.madness_of(wolf), 66.0) and is_equal_approx(authority.gained_total, gained + 26.0), "Selo R5 adds 26 through the same authority (66)")
	wolf.global_position = Vector2(500, 350) # back inside the Olhar's 200 reach after the push
	_check(_cast(GAZE, wolf), "the Cultista's Olhar do Abismo commits")
	var after_gaze := MadnessAuthority.madness_of(wolf)
	_check(after_gaze > 66.0 or MadnessAuthority.state_of(wolf) == MadnessRules.STATE_DELIRIUM, "the Olhar's first tick sums with the base's Madness (%.1f)" % after_gaze)
	_advance_for(2.1)
	_check(MadnessAuthority.state_of(wolf) == MadnessRules.STATE_DELIRIUM, "Sussurro + Selo + Olhar reach the threshold: Delírio")
	_check(authority.ecstasy.charges == 1, "the Delírio entry gives one Êxtase charge (%d)" % authority.ecstasy.charges)
	_check(wolf.combat_target() == boar, "the delirious wolf aims at the other enemy, never at the Cultista")
	_check(authority.delirium_count(player) == 1, "one delirious enemy counted by the shared authority")
	# The base Whisper on a boss: Disorientation path untouched by the kit.
	var warden := _mob(&"forest_ancient_warden", Vector2(520, 300), &"boss")
	var boss_start := warden.global_position
	_cast(&"acolyte_disturbing_whisper", warden)
	_check(warden.global_position.distance_to(boss_start) < 0.5 and not warden.has_target_override(), "the boss is never pushed nor retargeted by the base under the Cultista")

func _check_ecstasy_on_real_base() -> void:
	_setup(&"cultist", _cultist_ranks(0))
	var authority := MadnessAuthority.of(player) as MadnessAuthority
	_check(authority != null and not authority.ecstasy.enabled, "without the passive the Êxtase stays off on the real base")
	if authority == null: return
	authority.add(_mob(&"forest_wolf", Vector2(520, 350)), 100.0, "cast:t15_e0", player)
	_check(authority.ecstasy.charges == 0, "no charge without the passive")
	_setup(&"cultist", _cultist_ranks(3))
	authority = MadnessAuthority.of(player) as MadnessAuthority
	var mobs: Array[EnemyActor] = []
	for index: int in 3: mobs.append(_mob(&"forest_wolf", Vector2(500 + 30 * index, 520)))
	for index: int in 3: authority.add(mobs[index], 100.0, "cast:t15_e%d" % index, player)
	_check(authority.ecstasy.charges == 3 and authority.ecstasy.has_onus(), "three Delírio entries give three charges and the onus")
	for skill: StringName in [&"acolyte_prayer", &"acolyte_votive_shield", GAZE]:
		_check(_near(player.skill_cost(skill), player.base_skill_cost(skill) * (1.0 - 0.15), 0.001), "%s: SP cost −15%% once across the two modules (%.3f of %.3f)" % [skill, player.skill_cost(skill), player.base_skill_cost(skill)])
	var sources := player.temporary_stat_sources().filter(func(source: Dictionary) -> bool: return source.get("source_id") == &"cultist_ecstasy")
	_check(sources.size() == 1 and is_equal_approx(float(sources[0]["increased"][&"magic_attack"]), 0.15), "one Êxtase MATK source of +15%, published once")
	var attacker := _mob(&"forest_boar", Vector2(450, 350))
	var hit := _taken(attacker, 100.0)
	_check(is_equal_approx(float(hit.get("kit_damage_multiplier", 1.0)), 1.08), "the onus multiplies damage taken by 1.08 once (the base does not forward it): %.3f" % float(hit.get("kit_damage_multiplier", 1.0)))
	# Compensation by the real base: Escudo Votivo (with the Fé) absorbs, Prece heals.
	player.health.current_hp = player.health.max_hp
	_check(_cast(&"acolyte_votive_shield"), "Escudo Votivo commits under the onus")
	var plain := StatCalculator.personal_shield_capacity(78.0, player.stat_breakdown)
	_check(_near(player.health.shield_hp, plain * 1.10), "the Votive barrier carries the Fé R1 once (%.2f of %.2f)" % [player.health.shield_hp, plain])
	var shielded := _taken(attacker, 50.0)
	_check(float(shielded.get("absorbed_damage", 0.0)) > 0.0, "the Votive absorbs the multiplied hit")
	player.health.current_hp = player.health.max_hp * 0.5
	var hp := player.health.current_hp
	_check(_cast(&"acolyte_prayer"), "Prece commits under the onus")
	_advance_for(1.1)
	_check(player.health.current_hp > hp, "Prece restores HP the onus took (%.1f → %.1f)" % [hp, player.health.current_hp])

# --- Sacerdote: barriers --------------------------------------------------------------

func _check_priest_barriers() -> void:
	for faith: int in [0, 3]:
		_setup(&"priest", _priest_ranks(faith))
		var kit := player.kit
		_check(kit != null and kit.get_script().resource_path == PRIEST_PATH and player.origin_kit.get_script().resource_path == BASE_PATH, "Sacerdote on the production base (Fé R%d)" % faith)
		var sanctuary: Variant = kit.get(&"sanctuary") if kit != null else null
		if sanctuary == null: continue
		var rank := player.skill_rank(&"priest_aegis")
		var values := ClassKitRegistry.skill_definition(&"priest_aegis").rank_definition(rank)
		var plain := StatCalculator.personal_shield_capacity(values.power, player.stat_breakdown)
		var factor: float = [1.0, 1.10, 1.15, 1.20][faith]
		_check(_cast(&"priest_aegis"), "Égide commits (Fé R%d)" % faith)
		_check(_near(player.health.shield_hp, plain * factor) and _near(float(sanctuary.aegis_capacity), player.health.shield_hp, 0.001), "Fé R%d: the Égide is the plain capacity × %.2f, once, and the authority keeps the granted value (%.2f of %.2f)" % [faith, factor, player.health.shield_hp, plain])
		_advance_for(float(sanctuary.aegis_remaining) + 0.2)
		_check(is_zero_approx(player.health.shield_hp) and not sanctuary.aegis_active(), "Fé R%d: the reinforced Égide still ends with its duration" % faith)
	# Votive then Égide: each barrier reinforced once, never on top of the other.
	_setup(&"priest", _priest_ranks(3))
	var votive_plain := StatCalculator.personal_shield_capacity(78.0, player.stat_breakdown)
	_cast(&"acolyte_votive_shield")
	_check(_near(player.health.shield_hp, votive_plain * 1.20), "Votive under the Sacerdote: × 1.20 once (%.2f)" % player.health.shield_hp)
	var before := player.health.shield_hp
	_cast(&"priest_aegis")
	var aegis_plain := StatCalculator.personal_shield_capacity(ClassKitRegistry.skill_definition(&"priest_aegis").rank_definition(player.skill_rank(&"priest_aegis")).power, player.stat_breakdown)
	_check(_near(player.health.shield_hp, maxf(before, aegis_plain * 1.20)), "the Égide over the Votive keeps the larger barrier, never the sum (%.2f)" % player.health.shield_hp)

func _check_priest_grace_from_base() -> void:
	_setup(&"priest", _priest_ranks(3))
	var kit := player.kit
	var charges := int(kit.call(&"grace_charges"))
	_cast(&"acolyte_votive_shield")
	_check(int(kit.call(&"grace_charges")) == charges + 1, "the base's Escudo Votivo gives one Grace to the Sacerdote")
	_cast(&"acolyte_prayer")
	_check(int(kit.call(&"grace_charges")) == charges + 2, "the base's Prece gives one Grace to the Sacerdote")

# --- Barrier producers ------------------------------------------------------------------

func _check_barrier_producers() -> void:
	var direct: Array[String] = []
	var through_hook: Array[String] = []
	for path: String in _scripts("res://scripts"):
		var text := FileAccess.get_file_as_string(path)
		if text.contains(".grant_shield("): direct.append(path)
		if text.contains("grant_barrier("): through_hook.append(path)
	direct.sort()
	var expected := DIRECT_GRANT_SHIELD.duplicate()
	expected.sort()
	_check(direct == expected, "direct HealthState.grant_shield calls are exactly the legacy list: %s" % [direct])
	for wanted: String in ["res://scripts/classes/bases/acolyte/acolyte_base.gd", "res://scripts/systems/sanctuary/sanctuary_authority.gd"]:
		_check(wanted in through_hook, "%s grants its barrier through grant_barrier" % wanted.get_file())

func _scripts(directory: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null: return found
	for file: String in dir.get_files():
		if file.ends_with(".gd"): found.append(directory.path_join(file))
	for sub: String in dir.get_directories():
		found.append_array(_scripts(directory.path_join(sub)))
	return found

# --- Review builds ----------------------------------------------------------------------

func _check_review_builds() -> void:
	var text := FileAccess.get_file_as_string("res://scripts/classes/cultist/review_builds.json")
	var document: Variant = JSON.parse_string(text)
	var zero := 0
	if document is Dictionary:
		for build: Variant in document.get("builds", []):
			for key: String in ["base_ranks", "evolution_ranks"]:
				for skill: Variant in build.get(key, {}):
					if int(build[key][skill]) < 1: zero += 1
	_check(document is Dictionary and zero == 0, "the Cultista review file has no rank 0")
	for identity: StringName in [&"priest", &"cultist"]:
		var strict := E09Profiles.read_builds(identity)
		_check(strict["status"] == E09Profiles.READY and strict["builds"].size() == 2, "%s: the strict E09 reader accepts the file (%s %s)" % [identity, strict["error_code"], strict["detail"]])
		_check(FamilyProfiles._tolerant_root(identity, E09Profiles.DEFAULT_ROOT) == E09Profiles.DEFAULT_ROOT, "%s: the T10 tool reads the file in place (no sanitized copy)" % identity)
		var family := FamilyProfiles.read_builds(identity)
		_check(family["status"] == E09Profiles.READY and family["builds"] == strict["builds"], "%s: the T10 tool sees the same two legal builds" % identity)
