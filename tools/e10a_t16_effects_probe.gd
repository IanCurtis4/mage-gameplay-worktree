extends SceneTree
## E10a T16 native evidence (windowed, real renderer, 1280x720): the code effects of the Acólito base (T5), the
## Sacerdote (T6) and the Cultista (T7), which never had a native capture, plus the T16 additions.
##   effects_<module>_<n>      one sheet per four effects: the module's own drawer (`ClassKitRegistry.draw_vfx`, the
##                             call FeedbackVfxLayer makes for a pulse) at t = 0.12, 0.35, 0.6, 0.85, scale 0.6 (1.4 up to 100 px)
##   cultist_figures_<phase>   a real Cultista (production base and kit) after casting the Geometria Impossível and the
##                             Revelação: the persistent nodes at 0.6 s, 2.5 s and 3.7 s of the figure
##   priest_exorcist_<phase>   a real Sacerdote: the Exposto drawing on an enemy and the shield-stripped burst
## Args: <output folder>. Run without --headless:
##   Godot --path . --script res://tools/e10a_t16_effects_probe.gd -- <folder>

const E05DependencyFixture = preload("res://tests/e05_dependency_fixture.gd")
const T_VALUES: Array[float] = [0.12, 0.35, 0.6, 0.85]
const ROWS_PER_SHEET := 4

class Controller extends RunController:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass

class EffectCell extends Node2D:
	var owner_id: StringName = &""
	var effect_id: StringName = &""
	var t := 0.5
	var drawn := false
	func _draw() -> void:
		drawn = ClassKitRegistry.draw_vfx(owner_id, effect_id, self, {"dir": Vector2.RIGHT}, Vector2.ZERO, t)

var folder := ""
var checks := 0
var failures := 0
var captures: Array[String] = []
var page: Node2D
var controller: Controller
var player: PlayerActor
var enemies: Array[CombatActor] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "capture " + name)
	captures.append(name + ".png")

func clear_page() -> void:
	if page != null and is_instance_valid(page): page.free()
	page = Node2D.new()
	page.z_index = -2 # the arena view sits at z -2; the figure (z -1) and the actors stay above it
	root.add_child(page)
	var bg := Polygon2D.new()
	bg.color = Color("33423a")
	bg.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)])
	page.add_child(bg)

func label(text: String, at: Vector2, size: int = 15) -> void:
	var node := Label.new()
	node.text = text
	node.position = at
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", Color.WHITE)
	node.add_theme_color_override("font_outline_color", Color.BLACK)
	node.add_theme_constant_override("outline_size", 4)
	page.add_child(node)

func sheets(module_id: StringName, title: String) -> void:
	var module := ClassKitRegistry.seam_module(module_id)
	check(module != null, "module " + String(module_id))
	if module == null: return
	var effects: Dictionary = module.vfx_effects()
	var ids: Array = effects.keys()
	ids.sort()
	var sheet_count := ceili(float(ids.size()) / ROWS_PER_SHEET)
	for sheet: int in sheet_count:
		clear_page()
		label("%s · efeitos de código · desenho do próprio módulo · escala 0,6 (1,4 nos de até 100 px) · t = 0,12 / 0,35 / 0,60 / 0,85 · %d/%d" % [title, sheet + 1, sheet_count], Vector2(12, 6))
		for row: int in ROWS_PER_SHEET:
			var index := sheet * ROWS_PER_SHEET + row
			if index >= ids.size(): break
			var effect_id: StringName = ids[index]
			var spec: Dictionary = effects[effect_id]
			var top := 40 + row * 170
			label("%s\n%s · %s" % [effect_id, spec["skill_id"], ",".join(PackedStringArray((spec["kinds"] as Array).map(func(kind: Variant) -> String: return String(kind))))], Vector2(12, top + 60), 14)
			for column: int in T_VALUES.size():
				var cell := EffectCell.new()
				cell.owner_id = module_id
				cell.effect_id = effect_id
				cell.t = T_VALUES[column]
				cell.position = Vector2(400 + column * 230, top + 110)
				cell.scale = Vector2.ONE * (1.4 if float(spec["size"]) <= 100.0 else 0.6)
				page.add_child(cell)
		await shot("effects_%s_%d" % [module_id, sheet + 1])
		for cell: Node in page.get_children():
			if cell is EffectCell: check((cell as EffectCell).drawn, "drawn: " + String((cell as EffectCell).effect_id))

# --- Live scenes ------------------------------------------------------------------------------

func make_player(navigation: ArenaNavigation, evolution: StringName, ranks: Dictionary, slots: Array[StringName]) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.job_level = ProgressionRules.MAX_JOB_LEVEL if evolution != &"" else ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL
	snapshot.base_class_id = &"acolyte"
	snapshot.evolution_id = evolution
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"acolyte", evolution)
	snapshot.skill_ranks = {}
	for skill: Variant in ranks:
		if int(ranks[skill]) > 0: snapshot.skill_ranks[StringName(skill)] = int(ranks[skill])
	E05DependencyFixture.complete_snapshot(snapshot)
	snapshot.active_slots = slots
	var actor := PlayerActor.new()
	actor.configure(navigation, RunState.from_build("t16-" + String(evolution), snapshot))
	return actor

func live_arena(evolution: StringName, slots: Array[StringName], at: Vector2) -> void:
	if controller != null and is_instance_valid(controller):
		root.remove_child(controller)
		controller.free()
	clear_page()
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1280, 720), [], 20.0)
	controller = Controller.new()
	controller.set_process(false)
	controller.set_physics_process(false)
	root.add_child(controller)
	controller.navigation = navigation
	var ranks := {&"acolyte_punishing_light": 1, &"acolyte_prayer": 1, &"acolyte_votive_shield": 1, &"acolyte_shadow_seal": 1, &"acolyte_disturbing_whisper": 1, &"acolyte_protective_faith": 1}
	for skill: StringName in (ClassKitRegistry.skill_ids(evolution) if evolution != &"" else [] as Array[StringName]): ranks[skill] = 3 if skill in [&"cultist_ecstasy", &"cultist_open_pupil", &"priest_grace", &"priest_exorcist"] else 5
	player = make_player(navigation, evolution, ranks, slots)
	controller.add_child(player)
	player.global_position = at
	player.character_animation.state.face(Vector2.RIGHT)
	controller.player = player
	controller.run_state = player.run_state
	controller.enemies = []
	player.max_sp = 1000.0
	player.current_sp = 1000.0

func dummy(at: Vector2, name: String = "Alvo") -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup(name, Color("c9a27a"), StatCalculator.calculate({&"vit": 10}), 20.0)
	controller.add_child(enemy)
	enemy.global_position = at
	enemy.health.max_hp = 100000.0
	enemy.health.current_hp = 100000.0
	controller.enemies.append(enemy)
	enemies.append(enemy)
	return enemy

func cast(skill: StringName, at: Vector2) -> bool:
	player.mage_cooldowns[skill] = 0.0
	player.current_sp = player.max_sp
	player.kit_time += 0.001
	return player.use_kit_skill(skill, at, null)

func wait_seconds(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end: await process_frame

func figure_state() -> String:
	var parts: Array[String] = []
	for kind: StringName in [&"geometry", &"revelation"]:
		var node := controller.get_node_or_null(NodePath("CultistFigure_%s_%d" % [kind, player.get_instance_id()]))
		parts.append("%s=%s" % [kind, "%d draws" % int(node.get("draw_count")) if node != null else "none"])
	return " ".join(parts)

func cultist_figures() -> void:
	live_arena(&"cultist", [&"cultist_abyss_gaze", &"cultist_impossible_idol", &"cultist_impossible_geometry", &"cultist_revelation", &"cultist_shared_delirium"], Vector2(380, 430))
	await process_frame
	check(cast(&"cultist_impossible_geometry", Vector2(760, 470)) and cast(&"cultist_revelation", player.global_position), "the figure and the eye are cast")
	var started := Time.get_ticks_msec()
	for phase: Array in [["early", 0.6], ["mid", 2.5], ["late", 3.7]]:
		var wait := float(phase[1]) - float(Time.get_ticks_msec() - started) / 1000.0
		if wait > 0.0: await wait_seconds(wait)
		clear_labels()
		var state := figure_state()
		label("Cultista · figura da Geometria e olho da Revelação · nós persistentes · %s (%.1f s)\n%s" % [phase[0], float(Time.get_ticks_msec() - started) / 1000.0, state], Vector2(12, 6))
		check(state.contains("geometry=") and not state.contains("geometry=none") and not state.contains("revelation=none"), "both persistent nodes exist at %s: %s" % [phase[0], state])
		await shot("cultist_figures_" + String(phase[0]))
	await wait_seconds(1.2)
	var after := figure_state()
	check(after.contains("geometry=none"), "the Geometria node is gone after 4 s: " + after)
	await wait_seconds(3.3)
	after = figure_state()
	check(after.contains("revelation=none"), "the eye node is gone after the duration: " + after)

func clear_labels() -> void:
	for node: Node in page.get_children():
		if node is Label: node.free()

func priest_exorcist() -> void:
	live_arena(&"priest", [&"priest_sanctuary", &"priest_judgment", &"priest_aegis", &"priest_light_seal", &"priest_holy_hour"], Vector2(380, 430))
	await process_frame
	var plain := dummy(Vector2(640, 420), "Exposto")
	var shielded := dummy(Vector2(860, 470), "Com escudo")
	shielded.health.grant_shield(500.0)
	var kit := player.kit
	check(String(kit.call(&"exorcise", player, plain, 3)) == "exposed", "the enemy is left Exposto")
	check(String(kit.call(&"exorcise", player, shielded, 3)) == "shield", "the shield is stripped")
	await wait_seconds(0.2)
	label("Sacerdote · Exorcista · golpe de luz sem escudo ou buff (Exposto: aro e selo) e escudo arrancado (rajada) · 0,2 s", Vector2(12, 6))
	await shot("priest_exorcist_burst")
	await wait_seconds(1.8)
	clear_labels()
	label("Sacerdote · Exorcista · o desenho do Exposto dura enquanto o alvo está Exposto (6 s) · 2,0 s", Vector2(12, 6))
	await shot("priest_exorcist_exposed")
	check(plain.get_node_or_null(NodePath("PriestExorcist_exposed")) != null and shielded.get_node_or_null(NodePath("PriestExorcist_stripped")) == null, "the Exposto drawing lasts; the burst ended")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	folder = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	await sheets(&"acolyte", "Acólito (base, T5)")
	await sheets(&"priest", "Sacerdote (T6, T16)")
	await sheets(&"cultist", "Cultista (T7)")
	await cultist_figures()
	await priest_exorcist()
	var file := FileAccess.open(folder.path_join("result_effects.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "captures": captures}, "  ") + "\n")
	file.close()
	print("E10a T16 effects: %d checks, %d captures, %d failures" % [checks, captures.size(), failures])
	quit(1 if failures > 0 else 0)
