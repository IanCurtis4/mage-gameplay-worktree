extends SceneTree
## Actual Compatibility renderer: legal build, dense snapshots and measured frame intervals.
## No performance claim is inferred from engine-reported FPS or headless simulation.

const POINTS := [Vector2(720, 540), Vector2(1020, 460), Vector2(960, 670)]
const FRAME_SAMPLES := 240
var arena: RunController
var casting: GeometerCasting
var valid := true
var samples := PackedFloat64Array()
var max_reactions := 0
var baseline: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var build := _legal_build()
	RunController.pending_run_state = RunState.from_build("", build)
	RunController.pending_training_mode = true
	arena = load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(arena)
	current_scene = arena
	arena.set_process(false)
	arena.player.set_process(false)
	arena.player.global_position = Vector2(850, 450)
	arena.player.health.max_hp = 100000
	arena.player.health.current_hp = 100000
	arena.training_boss.set_process(false)
	arena.training_boss.global_position = Vector2(910, 560)
	arena._training_add_elapsed = -1000.0
	for child: Node in arena.player.get_children():
		if child is Camera2D: child.position_smoothing_enabled = false
	casting = arena.geometer_casting
	valid = arena.player.character_animation.actor_kind == &"geometer" and arena.player.character_animation.atlas != null and valid
	for index: int in 19:
		var enemy := arena._spawn_enemy(&"archer" if index % 4 == 0 else &"chaser", Vector2(730 + index % 5 * 60, 510 + index / 5 * 42))
		enemy.set_process(false)
		enemy.health.max_hp = 10000
		enemy.health.current_hp = 10000
	casting.targets = arena.enemies.duplicate()
	valid = arena.enemies.size() == 20 and valid
	await _shot("01_final_silhouette_dense")
	_shape([&"fire", &"ice"])
	await _shot("01b_directional_wall_ground")
	var archer := arena.enemies[1] as EnemyActor
	archer.global_position = Vector2(900, 620)
	archer._try_attack(true)
	var intercepted := false
	for child: Node in arena.get_children():
		if child is ArrowProjectile:
			child.set_process(false)
			child._process(0.5)
			intercepted = child.is_queued_for_deletion()
	valid = intercepted and not casting._wall_reactions.is_empty() and valid
	await _shot("01c_real_hostile_interception")
	_shape([&"fire", &"fire", &"fire"])
	await _shot("02_fff_closure")
	casting.advance(0.5)
	await _shot("03_fff_ground")
	_shape([&"ice", &"ice", &"ice"])
	await _shot("04_ggg_containment")
	_shape([&"lightning", &"lightning", &"lightning"])
	arena.player.target = arena.training_boss
	arena.player._try_basic_attack()
	_emit_arrows()
	await _shot("05_rrr_arrows_auto")
	_shape([&"fire", &"ice", &"lightning"], true)
	await _shot("06_fgr_mobile")
	arena.training_boss.global_position = Vector2(1400, 920)
	casting.advance(0.1)
	valid = casting.construction.suspended and valid
	await _shot("07_suspended_no_effect")
	arena.training_boss.global_position = POINTS[2]
	casting.advance(0.1)
	valid = casting.construction.has_active_figure() and valid
	await _shot("08_resumed_without_closure")
	var guide := arena.geometer_onboarding
	valid = guide != null and valid
	if guide != null:
		guide.toggle_button.pressed.emit()
		await _shot("09_help_expanded")
		valid = guide.help_label.visible and valid
		guide.toggle_button.pressed.emit()
		await _shot("10_help_collapsed")
		valid = not guide.help_label.visible and valid
	# Same rules and VFX over a controlled dark floor sample, retaining all world layers.
	var floor_sample := Polygon2D.new()
	floor_sample.name = "DarkFloorProbe"
	floor_sample.polygon = PackedVector2Array([Vector2(650, 430), Vector2(1150, 430), Vector2(1150, 720), Vector2(650, 720)])
	floor_sample.color = Color("142a34")
	floor_sample.z_index = -2
	arena.add_child(floor_sample)
	_shape([&"fire", &"ice", &"lightning"])
	await _shot("11_tricolor_dark_floor")
	floor_sample.queue_free()
	await process_frame
	root.size = Vector2i(1920, 1080)
	await process_frame
	baseline = await _measure(false)
	await _measure(true)
	await _shot("12_dense_measured_end")
	_report_performance()
	casting.clear_construction()
	casting.advance(0.5)
	valid = casting._wall_reactions.is_empty() and casting.construction.vertices.is_empty() and valid
	await _shot("13_clean")
	print("Geometer G7 renderer: ", "PASS" if valid else "FAIL")
	arena.queue_free()
	await process_frame
	quit(0 if valid else 1)

func _legal_build() -> BuildSnapshot:
	var catalog := ProfileCatalog.pilot({}, {}, {&"mg_ar": {"content_ready": true}})
	var character := CharacterState.new("geometer-g7-renderer", "Geômetra G7", &"mage")
	character.evolution_id = &"mg_ar"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	var purchases := {&"fireball": 5, &"lightning": 5, &"fire_spear": 5, &"mage_mana_regeneration": 3, &"teleport": 1, &"geometer_trace": 2, &"geometer_incidence": 3, &"geometer_triangulation": 5, &"geometer_vector_memory": 3, &"geometer_collapse": 2, &"geometer_rewrite": 5}
	for skill: StringName in purchases:
		for index: int in int(purchases[skill]):
			valid = bool(CharacterProgression.learn_skill(character, catalog, skill)["ok"]) and valid
	var summary := CharacterProgression.summary(character, catalog)
	valid = summary["base_skill_points_spent"] == 19 and summary["evolution_skill_points_spent"] == 20 and valid
	character.presets[0]["active_slots"] = [&"geometer_trace", &"geometer_triangulation", &"geometer_rewrite", &"geometer_collapse", &"fireball"]
	character.presets[0]["passive_slots"] = [&"geometer_incidence", &"geometer_vector_memory"]
	return BuildSnapshot.from_character(character, summary["base_level"], summary["job_level"], summary["effective_skill_ranks"], catalog.skill_ids_for_identity(&"mage", &"mg_ar"))

func _shape(elements: Array[StringName], mobile: bool = false) -> void:
	casting.clear_construction()
	for index: int in elements.size():
		if mobile and index == 2: arena.training_boss.global_position = POINTS[index]
		valid = bool(casting.construction.add_vertex(elements[index], POINTS[index], arena.training_boss.get_instance_id() if mobile and index == 2 else 0, arena.player.skill_rank(&"geometer_triangulation"), arena.navigation, 12, 9)["ok"]) and valid
	casting.wall_field.capture_construction()
	if elements.size() == 3: casting.triangle_field.form()

func _emit_arrows() -> void:
	for enemy: CombatActor in arena.enemies:
		if enemy is EnemyActor and (enemy as EnemyActor).archetype == &"archer":
			(enemy as EnemyActor).attack_cooldown = 0
			(enemy as EnemyActor)._try_attack(true)

func _measure(with_field: bool) -> Dictionary:
	casting.clear_construction()
	arena.player.global_position = Vector2(850, 450)
	arena.player.attack_cooldown = 0
	for index: int in arena.enemies.size():
		var enemy := arena.enemies[index] as EnemyActor
		enemy.clear_statuses()
		enemy.attack_cooldown = 0
		enemy._path.clear()
		enemy._repath_time = 0
		enemy.global_position = Vector2(910, 560) if index == 0 else Vector2(730 + (index - 1) % 5 * 60, 510 + (index - 1) / 5 * 42)
	for child: Node in arena.get_children():
		if child is PlayerProjectile or child is ArrowProjectile: child.queue_free()
	await process_frame
	if with_field: _shape([&"lightning", &"lightning", &"lightning"])
	for index: int in 60:
		_benchmark_step(1.0 / 60.0, index, with_field)
		await process_frame
	samples.clear()
	var previous := Time.get_ticks_usec()
	for index: int in FRAME_SAMPLES:
		_benchmark_step(1.0 / 60.0, index, with_field)
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - previous) / 1000.0)
		previous = now
	return _statistics()

func _benchmark_step(delta: float, index: int, with_field: bool = true) -> void:
	# Manual advancement uses the same runtime APIs; simulated delta is explicit and
	# separate from real wall time measured between rendered frame boundaries.
	if with_field and casting.construction.vertices.is_empty(): _shape([&"lightning", &"lightning", &"lightning"])
	casting.advance(delta)
	arena.player.target = arena.training_boss
	arena.player._process(delta)
	for enemy: CombatActor in arena.enemies:
		if enemy is EnemyActor: enemy._process(delta)
	if index % 30 == 0: _emit_arrows()
	if index % 60 == 0:
		var request := DamageRequest.new()
		request.source_id = arena.player.get_instance_id()
		request.skill_id = &"fireball"
		request.magic_damage = arena.player.stat_breakdown.value(&"magic_attack")
		arena._on_mage_projectile_requested(&"fireball", request, arena.training_boss, Vector2.RIGHT, 1)
	arena._update_hud()
	max_reactions = maxi(max_reactions, casting._wall_reactions.size())
	valid = max_reactions <= 12 and valid

func _report_performance() -> void:
	var statistics := _statistics()
	var report := {
		"engine": Engine.get_version_info()["string"], "os": OS.get_name(), "cpu": OS.get_processor_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"window": root.size, "logical_viewport": arena.get_viewport_rect().size,
		"samples_per_phase": samples.size(), "warmup_frames_per_phase": 60, "enemies_including_boss": arena.enemies.size(),
		"baseline_without_field": baseline, "active_rrr_field": statistics,
		"mean_interval_difference_ms": statistics["mean_interval_ms"] - baseline["mean_interval_ms"],
		"max_reactions": max_reactions, "simulation_delta": 1.0 / 60.0,
		"limitation": "1920x1080 window, logical1280x720 Compatibility automated renderer probe, not independent human playtest or performance acceptance; frame intervals include pacing/vsync and CPU/GPU work, not GPU-only timing. Sequential baseline comparison is observational, not an isolated benchmark.",
	}
	print("Geometer G7 measured frame intervals: ", JSON.stringify(report))
	var path := ProjectSettings.globalize_path("res://.godot/verification/geometer_g7_performance.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	else: valid = false

func _statistics() -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample: float in samples: total += sample
	return {
		"mean_interval_ms": total / samples.size(), "p95_interval_ms": sorted[ceili(sorted.size() * 0.95) - 1],
		"worst_interval_ms": sorted[-1],
	}

func _shot(stage: String) -> void:
	arena._update_hud()
	arena.training_status_label.text = "VALIDAÇÃO DENSA · Guardião %d HP · 20 atores" % arena.training_boss.health.current_hp
	await process_frame
	await process_frame
	var viewport_rect := arena.get_viewport_rect()
	for button: Button in arena.battle_controls.skill_buttons.values():
		valid = viewport_rect.encloses(button.get_global_rect()) and valid
	var screenshot := root.get_texture().get_image()
	var folder := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("geometer_g7_" + stage + ".png")
	valid = screenshot != null and screenshot.save_png(path) == OK and valid
	print(stage, " ", path)
