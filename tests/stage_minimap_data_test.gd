extends SceneTree

const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const MinimapData = preload("res://scripts/ui/expedition/stage_minimap_data.gd")
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_world_map()
	_check_flat_map()
	_check_actor_markers()
	_check_camera_preference()
	print("F10 minimap data: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check_world_map() -> void:
	var vertices := PackedVector3Array([
		Vector3(-40.0, 0.0, -20.0), Vector3(80.0, 0.0, -20.0),
		Vector3(80.0, 12.0, 60.0), Vector3(-40.0, 12.0, 60.0),
	])
	var snapshot := {
		"surfaces": [{"vertices": vertices}],
		"volumes": [AABB(Vector3(100.0, 35.0, -50.0), Vector3(20.0, 30.0, 40.0))],
	}
	var before := var_to_bytes(snapshot)
	var result := MinimapData.world_map(snapshot)
	check(result["surfaces"].size() == 1 and result["surfaces"][0] == _projected(vertices), "world map projects every surface vertex with ExpeditionProjection")
	check(result["obstacles"].size() == 1 and result["obstacles"][0].size() >= 4, "elevated volume produces a projected obstacle hull")
	var all_points := PackedVector2Array()
	var volume_points := PackedVector2Array()
	for point: Vector3 in vertices:
		all_points.append(ProjectionMath.project(point))
	var volume: AABB = snapshot["volumes"][0]
	for x: float in [volume.position.x, volume.end.x]:
		for y: float in [volume.position.y, volume.end.y]:
			for z: float in [volume.position.z, volume.end.z]:
				var projected := ProjectionMath.project(Vector3(x, y, z))
				all_points.append(projected)
				volume_points.append(projected)
	check(_contains_all(result["bounds"], all_points), "world-map bounds contain every surface vertex and elevated volume corner")
	var hull_contains_volume := true
	for point: Vector2 in volume_points:
		hull_contains_volume = hull_contains_volume and Geometry2D.is_point_in_polygon(point, result["obstacles"][0])
	check(hull_contains_volume, "elevated obstacle hull contains every corner projected with ExpeditionProjection")
	check(var_to_bytes(snapshot) == before, "world-map extraction does not mutate the source snapshot")

func _projected(vertices: PackedVector3Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for vertex: Vector3 in vertices:
		points.append(ProjectionMath.project(vertex))
	return points

func _contains_all(bounds: Rect2, points: PackedVector2Array) -> bool:
	for point: Vector2 in points:
		if point.x < bounds.position.x - 0.001 or point.x > bounds.end.x + 0.001:
			return false
		if point.y < bounds.position.y - 0.001 or point.y > bounds.end.y + 0.001:
			return false
	return true

func _check_flat_map() -> void:
	var bounds := Rect2(Vector2(-10.0, 5.0), Vector2(90.0, 70.0))
	var rectangles: Array[Rect2] = [Rect2(Vector2(8.0, 14.0), Vector2(12.0, 9.0)), Rect2(Vector2(42.0, 31.0), Vector2(4.0, 22.0))]
	var result := MinimapData.flat_map(bounds, rectangles)
	check(result["surfaces"].size() == 1 and result["surfaces"][0] == _rect_points(bounds), "flat-map surface preserves the input rectangle corners")
	var obstacles: Array = result["obstacles"]
	var preserved := obstacles.size() == rectangles.size()
	for index in mini(obstacles.size(), rectangles.size()):
		preserved = preserved and obstacles[index] == _rect_points(rectangles[index])
	check(preserved, "flat-map obstacles preserve each input rectangle and its order")

func _rect_points(rectangle: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)])

func _check_actor_markers() -> void:
	var input := Fixture.make()
	var built := ExpeditionAssembler.build(input)
	if not built.get("ok", false):
		check(false, "canonical F1 fixture assembles for marker test")
		return
	var manifest: ExpeditionManifest = built["data"]["manifest"]
	var first_world := WorldGeometry.new()
	var second_world := WorldGeometry.new()
	first_world.configure(manifest, "sample")
	second_world.configure(manifest, "sample")
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 800), [], 0)
	var player := PlayerActor.new()
	player.configure(nav, RunState.new(&"mage"))
	root.add_child(player)
	player.set_animation_kind(&"mage")
	player.character_animation.state.facing = Vector2(-1.0, 0.0)
	var profile: Dictionary = input.traversal.to_data()
	var player_point := Fixture.point("root", Vector3(50.0, 0.0, 50.0))
	check(player.bind_world_geometry(first_world, player_point, profile, "minimap_player").get("ok", false), "player binds to the current F1 world")
	var visible_enemy := _marker_actor(player, "Visible", first_world, Fixture.point("slope", Vector3(150.0, 20.0, 50.0)), profile, "minimap_visible")
	var distant_hidden_enemy := _marker_actor(player, "Hidden", first_world, Fixture.point("bridge", Vector3(50.0, 40.0, 150.0)), profile, "minimap_hidden")
	distant_hidden_enemy.visible = false
	var dead_enemy := _marker_actor(player, "Dead", first_world, Fixture.point("slope", Vector3(150.0, 20.0, 80.0)), profile, "minimap_dead")
	dead_enemy.health.current_hp = 0.0
	var queued_enemy := _marker_actor(player, "Queued", first_world, Fixture.point("landing", Vector3(250.0, 40.0, 80.0)), profile, "minimap_queued")
	queued_enemy.queue_free()
	var foreign_enemy := _marker_actor(player, "Foreign", second_world, Fixture.point("bridge", Vector3(100.0, 40.0, 150.0)), profile, "minimap_foreign")
	var candidates: Array[CombatActor] = [visible_enemy, distant_hidden_enemy, dead_enemy, queued_enemy, foreign_enemy]
	var markers := MinimapData.actor_markers(player, candidates)
	check(markers.get("ok", false), "current player world yields marker data")
	check(markers["player"].is_equal_approx(ProjectionMath.project(player_point.position)), "player marker uses the shared expedition projection")
	check(markers["heading"] == Vector2(-1.0, 0.0), "player marker preserves CharacterAnimation facing")
	var enemy_points: PackedVector2Array = markers["enemies"]
	check(enemy_points.size() == 2, "live same-world enemies remain marked outside camera and when invisible; dead, queued, and foreign-world actors are omitted")
	check(enemy_points.has(ProjectionMath.project(visible_enemy.world_point().position)) and enemy_points.has(ProjectionMath.project(distant_hidden_enemy.world_point().position)), "enemy marker positions match the projected world positions")
	for actor: Node in [player, visible_enemy, distant_hidden_enemy, dead_enemy, queued_enemy, foreign_enemy]:
		if is_instance_valid(actor):
			actor.free()

func _marker_actor(player: PlayerActor, label: String, world: WorldGeometry, point: ExpeditionWorldPoint, profile: Dictionary, occupant_id: String) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup(label, Color.RED, player.stat_breakdown)
	actor.set_animation_kind(&"mage")
	root.add_child(actor)
	actor.set_process(false)
	check(actor.bind_world_geometry(world, point, profile, occupant_id).get("ok", false), "%s actor binds to its intended world" % label)
	return actor

func _check_camera_preference() -> void:
	var profile_dir := "res://.godot/verification/minimap_data_%d" % Time.get_ticks_usec()
	var absolute_dir := ProjectSettings.globalize_path(profile_dir)
	check(DirAccess.make_dir_recursive_absolute(absolute_dir) == OK, "isolated minimap preference directory is created under res://.godot/verification")
	var config_path := profile_dir.path_join("controls.cfg")
	var preferences := ControlPreferences.new()
	preferences.path = config_path
	preferences.camera_zoom = 1.5
	preferences.bindings[0] = {"keycode": KEY_Z, "physical": false, "alt": false, "ctrl": false, "shift": false, "meta": false}
	var bindings_before: Array = preferences.bindings.duplicate(true)
	preferences.load_camera_zoom()
	check(preferences.camera_zoom == 1.0 and not FileAccess.file_exists(config_path), "missing preference file selects default zoom without creating user data")
	check(preferences.bindings == bindings_before, "loading a missing camera preference leaves battle bindings unchanged")
	preferences.camera_zoom = 99.0
	check(preferences.save_settings() == OK, "camera preference saves to the isolated profile")
	var maximum := ControlPreferences.new()
	maximum.path = config_path
	maximum.load_camera_zoom()
	check(is_equal_approx(maximum.camera_zoom, ControlPreferences.CAMERA_ZOOM_MAX), "saved zoom above range clamps to 160 percent")
	preferences.camera_zoom = -99.0
	check(preferences.save_settings() == OK, "lower camera preference saves to the isolated profile")
	var minimum := ControlPreferences.new()
	minimum.path = config_path
	minimum.load_camera_zoom()
	check(is_equal_approx(minimum.camera_zoom, ControlPreferences.CAMERA_ZOOM_MIN), "saved zoom below range clamps to 50 percent")
	var invalid_config := ConfigFile.new()
	invalid_config.set_value("interface", "camera_zoom", "not-a-number")
	check(invalid_config.save(config_path) == OK, "invalid zoom fixture is written to the isolated profile")
	preferences.camera_zoom = 1.4
	bindings_before = preferences.bindings.duplicate(true)
	preferences.load_camera_zoom()
	check(preferences.camera_zoom == 1.0, "invalid saved zoom falls back to default")
	check(preferences.bindings == bindings_before, "loading invalid camera zoom does not alter battle bindings")
	var nan_config := ConfigFile.new()
	nan_config.set_value("interface", "camera_zoom", NAN)
	check(nan_config.save(config_path) == OK, "NaN zoom fixture is written to the isolated profile")
	preferences.camera_zoom = 1.4
	preferences.load_camera_zoom()
	check(preferences.camera_zoom == 1.0, "non-finite saved zoom falls back to default")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(config_path))
	DirAccess.remove_absolute(absolute_dir)
