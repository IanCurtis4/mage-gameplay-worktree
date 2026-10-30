extends SceneTree
## World-view enemy picking: drawn body, smart-lock assist and lock (checkpoint32).
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const App = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Patrols = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const PatrolFixture = preload("res://tests/map_editor_patrol_test.gd")
const View = preload("res://scripts/world/expedition_geometry_view.gd")
const EXPECTED_CHECKS := 16
var checks: Array[Dictionary] = []
var app: App
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = null) -> void:
	checks.append({"id":id,"ok":ok,"detail":detail}); print("F9_TARGET_CHECK "+id+" "+str(ok))
func run() -> void:
	# Patrol fixture: one real enemy bound to the authored world (same as GameplayNative).
	var source := PatrolFixture.fixture()
	var compiled := Patrols.compile(source)
	var made := Candidate.create("patrol",compiled.package,Patrols.Document.hash_source(source)) if compiled.ok else {"ok":false}
	var created := Launcher.create_session(made.candidate) if made.ok else {"ok":false}
	var window := Launcher.create_window(created.path) if created.ok else {"ok":false}
	if not window.ok: check("fixture_window",false); finish(); return
	app = App.new(); app.quit_on_close = false; app.hold_start = true; root.add_child(app); current_scene = app
	var opened: Dictionary = await app.open_window_async(window.path)
	var started: Dictionary = await app._start_with_gate() if opened.ok else {"ok":false}
	check("fixture_campaign_held",started.ok and app.status == "held" and is_instance_valid(app.host))
	if not started.ok: finish(); return
	var main = app.host; var view: ExpeditionGeometryView = main.expedition_view
	view.sync()
	var enemy: CombatActor
	for actor: CombatActor in main.enemies:
		if view._pickable(actor): enemy = actor; break
	check("live_enemy_available",enemy != null)
	if enemy == null: finish(); return
	# Only this enemy is pickable, so radii checks never depend on fixture spacing.
	var only: Array[CombatActor] = [enemy]
	for other: CombatActor in main.enemies:
		if other != enemy and is_instance_valid(other): other.visible = false
	var radius_before := enemy.collision_radius
	var body := enemy.pick_body_rect()
	var foot := enemy.global_position
	var center := foot+Vector2(0,body.position.y*0.5)
	check("body_center_is_direct_hit",view.actor_at(center,only) == enemy)
	check("sprite_head_is_direct_hit",view.actor_at(foot+Vector2(0,body.position.y-2.0),only) == enemy,{"rect":body})
	check("sprite_flank_is_direct_hit",view.actor_at(foot+Vector2(body.end.x-1.0,body.position.y*0.5),only) == enemy)
	var beside := center+Vector2(body.end.x+View.PICK_PADDING+30.0,0)
	check("near_miss_without_assist_is_empty",view.actor_at(beside,only) == null)
	check("near_miss_with_assist_binds",view.actor_at(beside,only,null,true) == enemy)
	var far := center+Vector2(View.ASSIST_RADIUS+6.0,0)
	check("outside_assist_without_lock_is_empty",view.actor_at(far,only,null,true) == null)
	check("held_lock_keeps_target_until_lock_radius",view.actor_at(far,only,enemy,true) == enemy)
	check("lock_releases_past_radius",view.actor_at(center+Vector2(View.LOCK_RADIUS+6.0,0),only,enemy,true) == null)
	check("lock_requires_assist",view.actor_at(far,only,enemy,false) == null)
	enemy.sprite_visual_scale = 1.5
	var tall := enemy.pick_body_rect()
	check("tall_species_head_is_direct_hit",tall.size.y > body.size.y and view.actor_at(foot+Vector2(0,tall.position.y-2.0),only) == enemy)
	enemy.sprite_visual_scale = 1.0
	enemy.visible = false
	check("hidden_enemy_is_not_pickable",view.actor_at(center,only,enemy,true) == null)
	enemy.visible = true
	main.control_preferences.smart_lock = false
	check("main_respects_smart_lock_off",main._world_enemy_at(beside) == null)
	main.control_preferences.smart_lock = true
	check("main_basic_click_uses_assist",main._world_enemy_at(beside) == enemy)
	check("picking_never_changes_collision",is_equal_approx(enemy.collision_radius,radius_before))
	finish()

func finish() -> void:
	if is_instance_valid(app): app.free()
	paused = false
	var ok := checks.size() == EXPECTED_CHECKS and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_TARGET_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"expected_count":EXPECTED_CHECKS})); quit(0 if ok else 1)
