extends SceneTree

var checks := 0
var failures := 0
var root_directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_table_and_persistent_gate()
	_check_ranked_sources_and_stats()
	_check_contested_resolution()
	_check_runtime_request_capture()
	_cleanup_directory(root_directory)
	print("E04 Precisão por rank: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_table_and_persistent_gate() -> void:
	var definition := ClassCatalog.skill_definition(&"archer_precision")
	var expected_bonuses: Array[float] = [8.0, 12.0, 16.0]
	_check(definition != null and definition.display_name == "Precisão" and definition.category == SkillDefinition.Category.PASSIVE and definition.handler_id == SkillDefinition.Handler.ARCHER_PRECISION and definition.is_rank_catalog_valid(), "Precisão exposes a valid passive rank catalog and closed handler")
	for rank: int in range(1, 4):
		var values := definition.rank_definition(rank)
		_check(values.power == expected_bonuses[rank - 1] and values.effect_ids == [&"hit_rating_flat"], "Precisão R%d owns its approved flat HIT bonus" % rank)
		_check(values.sp_cost == 0.0 and values.fixed_cast_time == 0.0 and values.variable_cast_time == 0.0 and values.post_cast_time == 0.0 and values.cooldown == 0.0 and values.range == 0.0 and values.projectile_speed == 0.0, "Precisão R%d adds no active execution parameter" % rank)
		_check(values.physical_weight == 0.0 and values.precision_weight == 0.0 and values.magic_weight == 0.0, "Precisão R%d adds no damage weight" % rank)
	var copied_rank := definition.rank_definition(3)
	copied_rank.power = 99.0
	_check(definition.rank_definition(3).power == 16.0, "passive rank lookup returns an isolated catalog copy")

	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"archer_precision")
	_check(metadata.get("category") == ProfileCatalog.PASSIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 3 and catalog.base_class_is_available(&"archer"), "profile progression publishes three purchased ranks and opens the Archer gate")
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e04_archer_precision")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	var facade := ProfileFacade.new(ProfileStore.new(root_directory, catalog))
	var opened := facade.open_profile()
	var initial := facade.current_profile()
	var created := facade.create_character("precision-create", initial.revision, "Lina", &"archer")
	var profile := facade.current_profile()
	var character := profile.character_by_id(created.get("character_id", "")) if created.get("ok", false) else null
	var empty_presets := character != null and character.purchased_skill_ranks.is_empty() and character.granted_skill_ranks.is_empty()
	if character != null:
		for preset: Dictionary in character.presets:
			empty_presets = empty_presets and preset["active_slots"] == [null, null, null, null, null] and preset["passive_slots"] == [null, null]
	_check(opened.get("ok", false) and created.get("ok", false) and character != null and character.base_class_id == &"archer" and empty_presets, "persistent Archer creation succeeds at rank zero without learning or auto-equipping Precision")

func _check_ranked_sources_and_stats() -> void:
	var expected_hit: Array[float] = [131.6, 135.6, 139.6]
	var expected_bonuses: Array[float] = [8.0, 12.0, 16.0]
	for rank: int in range(1, 4):
		var snapshot := _snapshot(rank, true)
		var sources := snapshot.intrinsic_modifier_sources()
		var stats := snapshot.stat_breakdown()
		_check(sources.size() == 1 and sources[0]["source_id"] == &"passive_archer_precision" and sources[0]["flat"][&"hit_rating"] == expected_bonuses[rank - 1], "R%d emits one identified flat HIT source with its authored magnitude" % rank)
		_check(is_equal_approx(stats.value(&"hit_rating"), expected_hit[rank - 1]) and is_equal_approx(stats.value(&"precision_attack"), 32.2) and is_equal_approx(stats.value(&"flee_rating"), 112.1) and is_equal_approx(stats.value(&"attacks_per_second"), 1.155), "R%d changes only canonical HIT among adjacent Archer stats" % rank)
	var composed := _snapshot(3, true).stat_breakdown([{
		"source_id": &"test_hit",
		"flat": {&"hit_rating": 4.0},
	}])
	_check(is_equal_approx(composed.value(&"hit_rating"), 143.6), "passive rank composes additively inside StatCalculator")
	var duplicate_slots := _snapshot(3, true)
	duplicate_slots.passive_slots = [&"archer_precision", &"archer_precision"]
	_check(duplicate_slots.intrinsic_modifier_sources().size() == 1 and is_equal_approx(duplicate_slots.stat_breakdown().value(&"hit_rating"), 139.6), "duplicate passive slots cannot apply the same identified source twice")
	var unequipped := _snapshot(3, false)
	_check(unequipped.intrinsic_modifier_sources().size() == 1 and is_equal_approx(unequipped.stat_breakdown().value(&"hit_rating"), 139.6), "learned Precision is automatic despite empty legacy slots")
	var unlearned := _snapshot(3, false)
	unlearned.skill_ranks.erase(&"archer_precision")
	_check(unlearned.intrinsic_modifier_sources().is_empty() and is_equal_approx(unlearned.stat_breakdown().value(&"hit_rating"), 123.6), "unlearned Precision applies no source")
	var invalid := _snapshot(4, true)
	_check(invalid.intrinsic_modifier_sources().is_empty() and is_equal_approx(invalid.stat_breakdown().value(&"hit_rating"), 123.6), "invalid passive rank is ineligible instead of falling back to R1")

func _check_contested_resolution() -> void:
	var expected_landed: Array[bool] = [false, true, true, true]
	for rank: int in range(0, 4):
		var stats := _snapshot(rank, rank > 0).stat_breakdown()
		var request := DamageRequest.new()
		request.physical_damage = 10.0
		request.hit_rating = stats.value(&"hit_rating")
		request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
		request.can_crit = false
		var result := CombatMath.resolve(request, 0.0, 0.0, 160.0, 0.0, 0.75, 1.0)
		_check(result["landed"] == expected_landed[rank], "contested roll 0.75 resolves from canonical HIT at passive rank %d" % rank)
	var geometry := DamageRequest.new()
	geometry.physical_damage = 10.0
	geometry.hit_rating = _snapshot(3, true).stat_breakdown().value(&"hit_rating")
	geometry.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	geometry.can_crit = false
	var geometry_result := CombatMath.resolve(geometry, 0.0, 0.0, 999.0, 0.0, 0.99, 1.0)
	_check(geometry_result["landed"] and geometry_result["hit_chance"] == 1.0, "geometry-confirmed skills remain independent from HIT and FLEE")

func _check_runtime_request_capture() -> void:
	var source_snapshot := _snapshot(3, true)
	source_snapshot.skill_ranks.merge({
		&"double_shot": 1,
		&"piercing_arrow": 1,
		&"arrow_rain": 1,
		&"slowing_arrow": 1,
	}, true)
	source_snapshot.active_slots = [&"double_shot", &"piercing_arrow", &"arrow_rain", &"slowing_arrow", null]
	var state := RunState.from_build("archer-precision-r3", source_snapshot)
	source_snapshot.skill_ranks[&"archer_precision"] = 1
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 800), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, state)
	root.add_child(player)
	player.set_process(false)
	var contested_requests: Array[DamageRequest] = []
	var geometry_requests: Array[DamageRequest] = []
	player.precision_projectile_requested.connect(func(_skill_id: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, _count: int, _hit_limit: int) -> void: contested_requests.append(request))
	player.slowing_arrow_requested.connect(func(request: DamageRequest, _direction: Vector2, _fraction: float, _duration: float) -> void: contested_requests.append(request))
	player.arrow_rain_requested.connect(func(_center: Vector2, request: DamageRequest) -> void: geometry_requests.append(request))
	var preview := state.build_snapshot.stat_breakdown()
	_check(is_equal_approx(preview.value(&"hit_rating"), 139.6) and is_equal_approx(player.stat_breakdown.value(&"hit_rating"), 139.6), "preview, copied run snapshot and runtime actor consume the same R3 HIT")
	_check(player.use_double_shot(Vector2.RIGHT) and player.use_piercing_arrow(Vector2.RIGHT) and player.use_slowing_arrow(Vector2.RIGHT), "all contested Archer skill families emit from the R3 runtime build")
	var contested_capture_is_canonical := contested_requests.size() == 3
	for request: DamageRequest in contested_requests:
		contested_capture_is_canonical = contested_capture_is_canonical and request.accuracy_mode == DamageRequest.AccuracyMode.CONTESTED and is_equal_approx(request.hit_rating, 139.6)
	_check(contested_capture_is_canonical, "Double Shot, Piercing Arrow and Slowing Arrow capture enhanced HIT in their DamageRequest")
	player.current_sp = player.max_sp
	_check(player.use_arrow_rain(player.global_position + Vector2(100, 0)) and geometry_requests.size() == 1 and geometry_requests[0].accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and is_equal_approx(geometry_requests[0].hit_rating, 139.6), "geometry skill may capture the shared snapshot but retains geometry accuracy semantics")
	_check(is_equal_approx(player.stat_breakdown.value(&"precision_attack"), 32.2) and is_equal_approx(player.stat_breakdown.value(&"crit_chance"), 0.064) and is_equal_approx(player.stat_breakdown.value(&"attacks_per_second"), 1.155), "runtime Precision changes no damage, critical or cadence stat")
	player.queue_free()

func _snapshot(rank: int, equipped: bool) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "archer-precision-test"
	snapshot.base_class_id = &"archer"
	snapshot.job_level = 20
	snapshot.skill_ranks = {&"archer_precision": rank}
	snapshot.passive_slots = [&"archer_precision", null] if equipped else [null, null]
	return snapshot

func _cleanup_directory(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	for child: String in directory.get_directories():
		_cleanup_directory(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
