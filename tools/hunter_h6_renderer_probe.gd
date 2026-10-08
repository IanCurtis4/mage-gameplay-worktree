extends Node2D
## Run ONLY as the explicit positional scene hunter_h6_probe.tscn, with a renderer.
## No SceneTree --script, CharacterMenu, ProfileStore, facade or personal save.
## Controlled snapshots; AI is disabled and no FPS/DPS/fun claim is made.

const OUTPUT := "res://docs/art/hunter_h6"
const POINTS: Array[Vector2] = [Vector2(830, 550), Vector2(970, 550), Vector2(1090, 575)]
const TRAP_IDS: Array[StringName] = [&"hunter_freezing_trap", &"hunter_tar_trap", &"hunter_thorn_trap"]
var arena: RunController
var checks := 0
var failures := 0
var captures := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "native probe requires an actual renderer")
		_finish()
		return
	get_tree().root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	await _atlas_contact()
	for ambusher: bool in [false, true]:
		for dark: bool in [false, true]:
			await _show_build(ambusher, dark)
	_finish()

func _finish() -> void:
	print("Hunter H6 native renderer: %s (%d checks, %d captures, %d failures; controlled AI-off snapshots)" % ["PASS" if failures == 0 else "FAIL", checks, captures, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _build(ambusher: bool) -> BuildSnapshot:
	var catalog := ProfileCatalog.pilot({}, {}, {&"hunter": {"content_ready": true}})
	var character := CharacterState.new("hunter-h6-native", "Caçadora H6", &"archer")
	character.evolution_id = &"hunter"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	var purchases: Dictionary = {
		&"double_shot": 5, &"piercing_arrow": 5, &"arrow_rain": 5,
		&"archer_precision": 3, &"archer_cadence": 1,
	}
	if ambusher:
		purchases.merge({&"hunter_tar_trap": 1, &"hunter_mark": 4, &"hunter_shooting_discipline": 3, &"hunter_covering_shot": 5, &"hunter_easy_prey": 3, &"hunter_total_cover": 4})
	else:
		purchases.merge({&"hunter_freezing_trap": 4, &"hunter_tar_trap": 4, &"hunter_thorn_trap": 4, &"hunter_mark": 2, &"hunter_shooting_discipline": 2, &"hunter_easy_prey": 2, &"hunter_covering_shot": 1, &"hunter_total_cover": 1})
	for skill: StringName in purchases:
		for _purchase: int in int(purchases[skill]):
			_check(bool(CharacterProgression.learn_skill(character, catalog, skill)["ok"]), "legal purchase " + String(skill))
	_check(bool(CharacterProgression.allocate_attributes(character, {&"dex": 40, &"agi": 35, &"luk": 25} if ambusher else {&"int": 35, &"dex": 30, &"vit": 25})["ok"]), "legal attribute purchase")
	var summary := CharacterProgression.summary(character, catalog)
	_check(summary["base_skill_points_spent"] == 19 and summary["evolution_skill_points_spent"] == 20, "legal wallets 19/20")
	character.action_slots = ActionBarLayout.empty()
	var slot := 0
	for skill: StringName in catalog.skill_ids_for_identity(&"archer", &"hunter"):
		if int(summary["effective_skill_ranks"].get(skill, 0)) > 0 and catalog.skill_metadata(skill).get("category") == ProfileCatalog.ACTIVE:
			character.action_slots[slot] = skill
			slot += 1
	return BuildSnapshot.from_character(character, int(summary["base_level"]), int(summary["job_level"]), summary["effective_skill_ranks"], catalog.skill_ids_for_identity(&"archer", &"hunter"), catalog)

func _show_build(ambusher: bool, dark: bool) -> void:
	var prefix := ("emboscadora" if ambusher else "preparadora") + ("_dark" if dark else "_light")
	RunController.pending_run_state = RunState.from_build("", _build(ambusher))
	RunController.pending_run_facade = null
	RunController.pending_training_mode = true
	arena = (load("res://scenes/main.tscn") as PackedScene).instantiate() as RunController
	arena.control_preferences.path = "res://.godot/verification/hunter_h6_probe_controls.cfg"
	add_child(arena)
	_freeze(arena)
	arena.combat_numbers_visible = false
	arena._training_add_elapsed = -1000.0
	arena.navigation.configure(Rect2(80, 80, 1640, 920), [], 20.0)
	arena.player.global_position = Vector2(850, 450)
	arena.training_boss.global_position = Vector2(1280, 740)
	arena.training_boss.health.max_hp = 100000.0
	arena.training_boss.health.current_hp = 100000.0
	for child: Node in arena.player.get_children():
		if child is Camera2D:
			(child as Camera2D).enabled = false
	# Dedicated presentation stage: navigation above has no obstacles. Remove
	# matching obstacle artwork, rather than let fake scenery occlude the proof.
	for child: Node in arena.get_children():
		if child is ArenaObstacleView:
			child.queue_free()
	var camera := Camera2D.new()
	arena.add_child(camera)
	camera.global_position = Vector2(960, 550)
	camera.force_update_scroll()
	arena.ui_root.hide()
	var proof_canvas := CanvasLayer.new()
	proof_canvas.layer = 20
	arena.add_child(proof_canvas)
	var notice := Label.new()
	notice.name = "ProofNotice"
	notice.position = Vector2(24, 18)
	notice.add_theme_color_override("font_color", Color("eee2bd") if dark else Color("18231d"))
	notice.add_theme_font_size_override("font_size", 18)
	proof_canvas.add_child(notice)
	arena.help_panel.hide()
	var floor_sample := Polygon2D.new()
	floor_sample.polygon = PackedVector2Array([Vector2(80, 80), Vector2(1720, 80), Vector2(1720, 1000), Vector2(80, 1000)])
	floor_sample.color = Color("142a34") if dark else Color("cdd3aa")
	floor_sample.z_index = -2
	arena.add_child(floor_sample)
	_check(arena.persistent_facade == null and arena.player.is_hunter(), "isolated legal Hunter run without persistence")
	_check(arena.player.character_animation.actor_kind == &"hunter", "own Hunter atlas selected by real actor")
	_check(arena.player.get_node_or_null("HunterPresentation") != null, "presentation observer attached")
	_check(not is_instance_valid(arena.persistent_facade) and arena.control_preferences.path.begins_with("res://.godot/"), "neither personal profile nor control preferences are opened")
	await _capture(prefix + "_01_solo_boss", "Silhueta própria / boss isolado")
	for index: int in 11:
		var enemy := arena._spawn_enemy(&"archer" if index % 4 == 0 else &"chaser", Vector2(1250 + index % 4 * 42, 720 + index / 4 * 42))
		enemy.health.max_hp = 10000.0
		enemy.health.current_hp = 10000.0
		_freeze(enemy)
	_check(arena.enemies.size() == 12, "boss +11 actors within 20-actor limit")
	var traps: Array[PlayerTrap] = []
	for index: int in TRAP_IDS.size():
		var skill := TRAP_IDS[index]
		if arena.player.skill_rank(skill) == 0:
			continue # Ambusher deliberately does not learn the complete kit.
		_prepare_resources(skill)
		_check(arena.player.use_hunter_trap(skill, POINTS[index]), "real paid placement " + String(skill))
		var current := arena.trap_registry.active_traps(arena.player.get_instance_id())
		if not current.is_empty():
			var trap := current.back() as PlayerTrap
			_freeze(trap)
			traps.append(trap)
	await _capture(prefix + "_02_preparing", "Grupo / mecanismos preparando")
	for trap: PlayerTrap in traps:
		trap._process(0.61)
		_check(trap.state == PlayerTrap.State.ARMED, "mechanism armed without a stationary occupant")
	await _capture(prefix + "_03_armed", "Grupo / mecanismos armados")
	arena.training_boss.global_position = POINTS[0]
	_prepare_resources(&"hunter_mark")
	_check(arena.player.use_hunter_mark(arena.training_boss), "real Mark on boss")
	for trap: PlayerTrap in traps:
		if trap.source_skill_id == &"hunter_freezing_trap":
			trap._process(0.01)
			_check(not arena.player.hunter_state.opening(arena.training_boss.get_instance_id()).is_empty(), "boss opening from real freezing activation")
	await _capture(prefix + "_04_mark_opening", "Marca / abertura entalhada no boss")
	for index: int in range(1, arena.enemies.size()):
		arena.enemies[index].global_position = POINTS[1] + Vector2(index % 4 * 44 - 65, index / 4 * 42 - 42)
	for trap: PlayerTrap in traps:
		if is_instance_valid(trap) and trap.source_skill_id == &"hunter_tar_trap":
			trap._process(0.01)
	_check(is_instance_valid(arena.hunter_tar_field) and arena.hunter_tar_field.active, "real triggered Tar field")
	await _capture(prefix + "_05_tar_overlap", "Campo de Piche / aberturas sobrepostas")
	for trap: PlayerTrap in traps:
		if is_instance_valid(trap) and trap.source_skill_id == &"hunter_thorn_trap":
			arena.enemies[1].global_position = POINTS[2]
			trap._process(0.01)
	# A real directional shot, collision and canonical callback consume an opening.
	var prey := arena.enemies[2]
	prey.global_position = Vector2(970, 530)
	_prepare_resources(&"hunter_covering_shot")
	_check(arena.player.use_hunter_covering_shot(arena.player.global_position.direction_to(prey.global_position + PlayerProjectile.BODY_OFFSET)), "real Covering Shot emission")
	for projectile: Node in get_tree().get_nodes_in_group("player_projectiles"):
		_freeze(projectile)
		if projectile is PlayerProjectile:
			(projectile as PlayerProjectile)._process(0.35)
	_check(arena.player.hunter_state.step_remaining > 0.0, "real positive shot grants Hunt Step")
	for index: int in 4:
		arena.player.global_position += Vector2(-12, 0)
		arena.player.hunter_presentation._process(0.02)
	_check(not arena.player.hunter_presentation.trails.is_empty(), "real Step state supports a short bounded foot trail")
	await _capture(prefix + "_06_consumed_step", "Consumo / impacto breve / rastro nos pés")
	_prepare_resources(&"hunter_total_cover")
	_check(arena.player.use_hunter_total_cover(arena.player.global_position + Vector2(-40, 0)), "real paid Total Cover")
	arena.player.hunter_cover.advance(1.3, arena.player.global_position)
	_check(arena.player.is_concealed(), "actual shared-cover state is hidden after reveal ends")
	await _capture(prefix + "_07_cover", "Cobertura territorial / sobreposição de grupo")
	# Real terminal path clears zones as well as player dictionaries/markers.
	arena._show_result(false)
	get_tree().paused = false # snapshot coroutine, not a continued gameplay run
	await _capture(prefix + "_08_cleanup", "Limpeza sem marcadores órfãos")
	arena.queue_free()
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("player_traps").is_empty() and get_tree().get_nodes_in_group("foliage_shelters").is_empty(), "owned mechanisms and cover disappear with scene")
	arena = null

func _prepare_resources(skill: StringName) -> void:
	# Probe setup only: makes independent snapshots, never a balance measurement.
	arena.player.current_sp = arena.player.max_sp
	arena.player.mage_cooldowns[skill] = 0.0

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	for child: Node in node.get_children():
		_freeze(child)

func _capture(filename: String, description: String) -> void:
	_freeze(arena)
	var presentation := arena.player.get_node_or_null("HunterPresentation")
	if presentation != null:
		presentation.call("_process", 0.04)
	arena._update_hud()
	arena.training_status_label.text = "PROVA VISUAL · %d atores · build legal · IA desligada" % arena.enemies.size()
	arena.status_label.text = description + " · sem medida de DPS/FPS"
	for canvas: Node in arena.get_children():
		var notice := canvas.get_node_or_null("ProofNotice") as Label
		if notice != null:
			notice.text = description + "\n" + filename + " · %d atores · build legal · IA desligada · piso de avaliação\nHUD oculto apenas neste probe · sem medida de DPS/FPS" % arena.enemies.size()
	_redraw(arena)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var bitmap := get_viewport().get_texture().get_image()
	_check(bitmap != null and bitmap.save_png(OUTPUT.path_join(filename + ".png")) == OK, "native capture " + filename)
	captures += 1

func _redraw(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).queue_redraw()
	for child: Node in node.get_children():
		_redraw(child)

func _atlas_contact() -> void:
	var floor_view := AtlasFloor.new()
	add_child(floor_view)
	var animation := CharacterAnimation.new()
	animation.configure(&"hunter")
	_check(animation.actor_kind == &"hunter" and animation.atlas != null, "full contact sheet uses imported Hunter texture")
	var icons := IconStrip.new()
	for skill: StringName in HunterTuning.SKILL_IDS:
		var icon := load("res://assets/art/icons/hunter/%s.svg" % skill) as Texture2D
		_check(icon != null, "exclusive native icon " + String(skill))
		icons.icons.append(icon)
	floor_view.add_child(icons)
	for index: int in 32:
		for side: int in 2:
			var pose := AtlasPose.new()
			pose.animation = animation
			pose.frame = index
			pose.mirrored = side == 1
			pose.position = Vector2(70 + index % 4 * 125 + side * 640, 106 + index / 4 * 74)
			floor_view.add_child(pose)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var bitmap := get_viewport().get_texture().get_image()
	_check(bitmap.save_png(OUTPUT.path_join("00_atlas_native.png")) == OK, "32 cells, nearest, native + mirrored on both floors")
	captures += 1
	floor_view.queue_free()
	await get_tree().process_frame

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

class AtlasFloor extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 640, 720), Color("cdd3aa"))
		draw_rect(Rect2(640, 0, 640, 720), Color("142a34"))
		draw_string(ThemeDB.fallback_font, Vector2(20, 28), "Caçadora · atlas 32 células · tamanho real / espelhado · renderer nativo", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f3d9ad"))
		for index: int in 8:
			draw_string(ThemeDB.fallback_font, Vector2(20, 55 + index * 74), ["Frente idle", "Frente walk", "Frente ataque", "Costas walk", "Costas idle", "Costas ataque", "Hurt frente / costas", "Morte frente / costas"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("805737"))

class AtlasPose extends Node2D:
	var animation: CharacterAnimation
	var frame := 0
	var mirrored := false
	func _draw() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		draw_line(Vector2(-25, 0), Vector2(25, 0), Color("d69d5d"), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1) if mirrored else Vector2.ONE)
		draw_texture_rect_region(animation.atlas, animation.destination_rect(frame), animation.source_region(frame))

class IconStrip extends Node2D:
	var icons: Array[Texture2D] = []
	func _draw() -> void:
		for index: int in icons.size():
			if icons[index] == null:
				continue
			var x := 55.0 + index * 154.0
			draw_texture_rect(icons[index], Rect2(x, 650, 48, 48), false)
			draw_string(ThemeDB.fallback_font, Vector2(x - 10, 715), ["Congelante", "Piche", "Espinhos", "Marca", "Disciplina", "Tiro", "Presa", "Cobertura"][index], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("805737") if index < 4 else Color("eee2bd"))
