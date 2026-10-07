extends SceneTree
## Presentation-only guide: real state/skill APIs, no profile files or scene mutation.

const GuideScript = preload("res://scripts/ui/geometer_onboarding.gd")
const A := Vector2(200, 200)
const B := Vector2(500, 200)
const C := Vector2(200, 500)
var checks := 0
var failures := 0
var guide: Control
var casting: GeometerCasting
var player: PlayerActor
var navigation := ArenaNavigation.new()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var viewport := SubViewport.new()
		viewport.size = viewport_size
		root.add_child(viewport)
		var fixture := Node2D.new()
		viewport.add_child(fixture)
		var build := BuildSnapshot.new()
		build.character_id = "geometer-onboarding-fixture"
		build.base_class_id = &"mage"
		build.evolution_id = &"mg_ar"
		build.job_level = 40
		build.skill_ranks = {&"geometer_trace": 1, &"geometer_triangulation": 5}
		build.library_skill_ids = [&"geometer_trace", &"geometer_triangulation"]
		build.active_slots = [&"geometer_trace", &"geometer_triangulation", null, null, null]
		navigation.configure(Rect2(0, 0, 1400, 1000), [], 18)
		player = PlayerActor.new()
		fixture.add_child(player)
		# The observer needs identity/slots only, not animation imports or combat setup.
		player.navigation = navigation
		player.run_state = RunState.from_build("", build)
		player.class_id = &"mage"
		player.class_definition = ClassCatalog.class_definition(&"mage")
		player.current_sp = 100.0
		player.max_sp = 100.0
		player.set_process(false)
		casting = GeometerCasting.new()
		fixture.add_child(casting)
		casting.configure(player)
		var ui := Control.new()
		viewport.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		guide = GuideScript.new()
		guide.configure(casting)
		ui.add_child(guide)
		await _settle()
		_check(guide.visible and not guide.help_label.visible, "guide defaults to compact in Geometer fixture")
		_check(guide.get_global_rect().size == Vector2(viewport_size), "guide root follows logical viewport %s" % viewport_size)
		_check(_informational_pass_through(guide), "every informational ancestor ignores world clicks")
		_check(guide.toggle_button.mouse_filter == Control.MOUSE_FILTER_STOP and guide.toggle_button.focus_mode == Control.FOCUS_NONE, "only help toggle captures mouse, never keyboard focus")
		await _expect(["Vazio", "Traçado cria A", "selecionado: Fogo"], viewport_size)
		casting.construction.grammar.select_element(&"lightning")
		await _expect(["Vazio", "selecionado: Raio"], viewport_size)
		_add(&"fire", A)
		await _expect(["Vértice A", "A:Fogo", "8.0 s", "Traçado cria B"], viewport_size)
		_add(&"fire", B)
		await _expect(["Preparação", "A:Fogo", "B:Fogo", "Triangulação R5 cria C"], viewport_size)
		player.run_state.skill_levels.erase(&"geometer_triangulation")
		await _expect(["Preparação", "aprender Triangulação no job 28"], viewport_size)
		player.run_state.skill_levels[&"geometer_triangulation"] = 3
		player.run_state.build_snapshot.active_slots[1] = null
		await _expect(["Preparação", "Triangulação R3 cria C"], viewport_size)
		player.run_state.build_snapshot.active_slots[1] = &"geometer_triangulation"
		await _expect(["Triangulação R3 cria C", "puros/mistos"], viewport_size)
		player.run_state.skill_levels[&"geometer_triangulation"] = 1
		await _expect(["Triangulação R1 cria C", "puros"], viewport_size)
		player.run_state.skill_levels[&"geometer_triangulation"] = 5
		casting.construction.clear()
		_add(&"fire", A)
		_add(&"ice", B)
		await _expect(["Parede", "A:Fogo", "B:Gelo", "6.0 s", "Triangulação R5 cria C"], viewport_size)
		_add(&"lightning", C, 42)
		await _expect(["Triângulo", "C:Raio↟", "Edite ou use Colapso", "F6 desfaz sem dano"], viewport_size)
		casting.construction.figure_remaining = 4.25
		casting.construction.vertices[0].remaining = 2.0
		await _expect(["Triângulo", "2.0 s"], viewport_size)
		casting.construction.suspended = true
		await _expect(["suspensa", "Sem efeitos", "O prazo continua"], viewport_size)
		casting.construction.clear()
		casting.construction.grammar.reserve(A, 0, 0)
		await _expect(["Vazio", "1 em trânsito", "Aguarde o impacto"], viewport_size)
		casting.construction.grammar.reserve(B, 0, 0)
		await _expect(["2 em trânsito"], viewport_size)
		var before := _snapshot()
		guide.toggle_button.pressed.emit()
		await _settle()
		_check(guide.help_label.visible and guide.toggle_button.text == "Guia −", "toggle expands help")
		for text: String in ["F1 Fogo", "F2 Gelo", "F3 Raio", "Traçado cria A/B", "Triangulação cria C", "R1: puros", "R3: mistos", "R5: tricolores", "corpo vincula", "Shift força chão", "Translação", "Reescrita", "Esc cancela", "F6 desfaz SEM Colapso", "Colapso consome", "expirar só desfaz"]:
			_check(text in guide.help_label.text, "expanded guide documents " + text)
		_check(_fits(guide.help_label, viewport_size) and _fits(guide.toggle_button, viewport_size), "expanded guide stays inside viewport")
		_check(guide.help_label.get_global_rect().end.y < float(viewport_size.y) - 160.0, "expanded guide leaves bottom action/aim region clear")
		_check(_fits(guide.status_label.get_parent().get_parent(), viewport_size), "expanded panel itself fits viewport, not just its labels")
		_check(before == _snapshot(), "help opening never changes construction, SP, cooldown or preview")
		paused = true
		await _expect(["pausa", "2 em trânsito"], viewport_size)
		guide.toggle_button.pressed.emit()
		await _settle()
		_check(not guide.help_label.visible and guide.toggle_button.text == "Guia +", "help can close during pause without gameplay changes")
		_check(guide.status_label.get_parent().get_parent().size.y <= 138.0, "closing help releases expanded container height")
		_check(before == _snapshot(), "refresh/toggle while paused preserve timers, queue and resources")
		_check(_informational_pass_through(guide), "pause does not create informational dead click regions")
		paused = false
		guide.configure(null)
		_check(not guide.visible, "null casting hides observer safely")
		guide.configure(casting)
		player.run_state.build_snapshot.evolution_id = &"mg_mg"
		guide.refresh()
		_check(not guide.visible, "other evolution never shows Geometer guide")
		player.run_state.build_snapshot.evolution_id = &"mg_ar"
		guide.refresh()
		_check(guide.visible, "valid Geometer restores read-only guide")
		viewport.queue_free()
		await process_frame
	print("Geometer G7 onboarding: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _add(element: StringName, point: Vector2, carrier: int = 0) -> void:
	_check(casting.construction.add_vertex(element, point, carrier, 5, navigation)["ok"], "valid observer state fixture")

func _expect(phrases: Array[String], viewport_size: Vector2i) -> void:
	var before := _snapshot()
	guide.refresh()
	await _settle()
	for phrase: String in phrases:
		_check(phrase in guide.status_label.text, "context reads " + phrase)
	_check(_fits(guide.status_label, viewport_size) and _fits(guide.toggle_button, viewport_size), "status and toggle fit %s" % viewport_size)
	_check(_fits(guide.status_label.get_parent().get_parent(), viewport_size), "whole contextual panel fits %s" % viewport_size)
	if not guide.help_label.visible:
		_check(guide.status_label.get_parent().get_parent().get_global_rect().size.y <= 138.0, "collapsed guide remains compact: %s / %s" % [guide.status_label.text, guide.status_label.get_parent().get_parent().get_global_rect()])
	_check(before == _snapshot(), "observing state never mutates gameplay")

func _snapshot() -> Dictionary:
	var anchors: Array[Dictionary] = []
	for anchor: GeometerAnchor in casting.construction.vertices:
		anchors.append({"element": anchor.element, "point": anchor.position, "last_ground": anchor.last_valid_ground, "carrier": anchor.actor_id, "remaining": anchor.remaining})
	return {"anchors": anchors, "pending": casting.construction.grammar.pending_snapshot(), "selected": casting.construction.grammar.selected_element, "id": casting.construction.construction_id, "shape": casting.construction.shape, "suspended": casting.construction.suspended, "figure": casting.construction.figure_remaining, "sp": player.current_sp, "cooldowns": player.mage_cooldowns.duplicate(), "preview": casting.preview_command}

func _informational_pass_through(node: Node) -> bool:
	if node is Control and node != guide.toggle_button and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for child: Node in node.get_children():
		if not _informational_pass_through(child):
			return false
	return true

func _settle() -> void:
	await process_frame
	await process_frame

func _fits(control: Control, viewport_size: Vector2i) -> bool:
	return Rect2(Vector2.ZERO, Vector2(viewport_size)).encloses(control.get_global_rect()) and control.size.x > 0.0 and control.size.y > 0.0

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
