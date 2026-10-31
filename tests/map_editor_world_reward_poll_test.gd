extends SceneTree
## Reward/area polling must not pay a ground path when the straight distance already rules out a hit (checkpoint33).
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const App = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Patrols = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const PatrolFixture = preload("res://tests/map_editor_patrol_test.gd")
const EXPECTED_CHECKS := 10
var checks: Array[Dictionary] = []
var app: App
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = null) -> void:
	checks.append({"id":id,"ok":ok,"detail":detail}); print("F9_REWARD_POLL_CHECK "+id+" "+str(ok))
func full_hit(area: WorldEffectArea, actor: CombatActor, radius: float) -> bool:
	var result := area.query(actor,radius)
	return result["ok"] and result["data"]["hit"]
func run() -> void:
	var source := PatrolFixture.fixture()
	var compiled := Patrols.compile(source)
	var made := Candidate.create("patrol",compiled.package,Patrols.Document.hash_source(source)) if compiled.ok else {"ok":false}
	var created := Launcher.create_session(made.candidate) if made.ok else {"ok":false}
	var window := Launcher.create_window(created.path) if created.ok else {"ok":false}
	if not window.ok: check("fixture_window",false); finish(); return
	app = App.new(); app.quit_on_close = false; app.hold_start = true; root.add_child(app); current_scene = app
	var opened: Dictionary = await app.open_window_async(window.path)
	var started: Dictionary = await app._start_with_gate() if opened.ok else {"ok":false}
	check("fixture_campaign_held",started.ok and app.status == "held")
	if not started.ok: finish(); return
	var main = app.host; var player: PlayerActor = main.player
	var enemy: CombatActor = main.enemies[0] if not main.enemies.is_empty() else null
	check("enemy_available",enemy != null and enemy.world_motion != null)
	if enemy == null: finish(); return
	# Bind a reward exactly as the runtime does, at the player's current point.
	var placed: Dictionary = main._create_reward_pickup()
	var reward: RewardPickup = main.reward
	check("reward_bound_at_player",placed.ok and is_instance_valid(reward) and reward.world_area != null)
	if not is_instance_valid(reward): finish(); return
	var area := reward.world_area
	var gap := area.anchor().position.distance_to(enemy.world_point().position)
	check("player_at_anchor_passes_prefilter",area.may_reach(player,48.0))
	check("enemy_beyond_range_is_prefiltered",gap > 48.0 and not area.may_reach(enemy,48.0) and not full_hit(area,enemy,48.0),{"gap":gap})
	var exact := true; var radii := [gap-1.0,gap*0.5,gap+1.0,gap+80.0]
	for radius: float in radii:
		if not area.may_reach(enemy,radius) and full_hit(area,enemy,radius): exact = false
	check("prefilter_never_rejects_a_real_hit",exact,{"radii":radii})
	check("prefilter_admits_within_straight_distance",area.may_reach(enemy,gap+1.0) and not area.may_reach(enemy,gap-1.0))
	var contains_ok := true
	var body := float(enemy.world_motion.profile()["radius"])
	for radius: float in [gap-body-1.0,gap+1.0,gap+80.0]:
		if area.contains_actor(enemy,radius) != full_hit(area,enemy,radius+body): contains_ok = false
	check("contains_actor_matches_full_query",contains_ok)
	app.begin()
	check("far_actor_cannot_collect",not reward.can_collect_world(enemy,48.0))
	check("reward_is_still_placed_after_far_poll",is_instance_valid(main.reward))
	finish()

func finish() -> void:
	if is_instance_valid(app): app.free()
	paused = false
	var ok := checks.size() == EXPECTED_CHECKS and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_REWARD_POLL_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"expected_count":EXPECTED_CHECKS})); quit(0 if ok else 1)
