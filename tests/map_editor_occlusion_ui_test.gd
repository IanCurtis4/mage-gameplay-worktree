extends SceneTree
## Checkpoint49 (F9-01, P6c): occlusion in the real game view of the Bosque. The
## released package is drawn by the gameplay skin (AuthoredExpeditionView over
## MapPackageView) with the real player and enemies. A camera-occluding tree fades
## while the player or an enemy is behind it and comes back when they leave; a
## tree behind the actor and a prop without camera occlusion never fade; the
## walk uses the real body and the game's world authority.
const Release = preload("res://scripts/map_authoring/release/map_release.gd")
const Preview = preload("res://scripts/map_authoring/patrol/patrol_preview.gd")
const AuthoredView = preload("res://scripts/world/authored_expedition_view.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_view.gd")
var checks: Array[Dictionary] = []
var view: Node2D
var host: PlayerActor
var actors: Array[EnemyActor] = []
var camera: Camera2D
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_OCCLUSION_CHECK "+id+" "+str(ok))
func frames(count: int = 2) -> void:
	for i: int in count: await process_frame
func capture(id: String) -> void:
	await frames(); RenderingServer.force_draw(false); await frames()
	var image := root.get_texture().get_image()
	check("capture_"+id,image != null and image.save_png(OS.get_environment("F9_EVIDENCE").path_join(id+".png")) == OK)
## A supported point of the stage under (x, z), on the highest surface there.
func support(world: WorldGeometry, x: float, z: float) -> ExpeditionWorldPoint:
	var best: ExpeditionWorldPoint
	for cell: Dictionary in world._stage.surfaces:
		var at := ExpeditionFixtureGeometry.support_y(cell,Vector3(x,0,z))
		if not ExpeditionFixtureGeometry.contains(cell,at): continue
		if best == null or at.y > best.position.y: best = ExpeditionWorldPoint.create("map_preview",cell.surface_id,at)
	return best
func walk(actor: CombatActor, point: ExpeditionWorldPoint) -> bool:
	if point == null: return false
	var planned := actor.world_motion.plan(point,actor.world_motion.geometry.geometry_revision)
	var steps := 0
	while planned.ok and actor.world_motion.has_route() and steps < 8000:
		actor.world_motion.advance(6); steps += 1
	view.sync()
	return planned.ok and actor.world_point().position.distance_to(point.position) < 0.1
func sprites(occluding: bool) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for sprite: Sprite2D in view.skin.object_sprites:
		if bool(sprite.get_meta("camera_occlusion",false)) == occluding: result.append(sprite)
	return result
## Walks the actor to a point just behind the prop (smaller x+z, same screen
## column) where the prop covers it; returns the point or null.
func behind(actor: CombatActor, sprite: Sprite2D, sign_depth: float) -> ExpeditionWorldPoint:
	var base: Vector3 = sprite.get_meta("world_position")
	for d: float in [18.0,28.0,40.0,56.0,72.0,96.0]:
		var point := support(actor.world_motion.geometry,base.x+sign_depth*d,base.z+sign_depth*d)
		if point == null or absf(point.position.y-base.y) > 24.0: continue
		var screen := AuthoredView.project(point.position)+Vector2(0,-20)
		if not sprite.get_rect().has_point(sprite.to_local(view.skin.to_global(screen))): continue
		if walk(actor,point): return point
	return null
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var loaded := Release.load_package("sanctuary_woods")
	check("bosque_release_loads",loaded.ok)
	if not loaded.ok: finish(); return
	var package: Dictionary = loaded.package
	var made := Preview.make_actors(package)
	check("real_actors_are_bound",made.ok and made.actors.size() == package.manifest.population.slots.size())
	if not made.ok: finish(); return
	host = made.player; actors.assign(made.actors)
	view = AuthoredView.new(); root.add_child(view)
	var configured: Dictionary = view.configure_package(package.population_package.map_package,host.world_motion.geometry)
	check("game_skin_draws_the_bosque",configured.ok and view.skin.object_sprites.size() > 0 and not sprites(true).is_empty() and not sprites(false).is_empty())
	if not configured.ok: finish(); return
	view.add_child(host); host.set_process(false); host.set_physics_process(false)
	view.observe(host)
	for actor: EnemyActor in actors: actor.set_process(false); actor.set_physics_process(false); view.observe(actor)
	camera = Camera2D.new(); camera.zoom = Vector2.ONE*1.4; view.add_child(camera); camera.make_current()
	root.size = Vector2i(1280,800)
	view.sync(); await frames()
	# 1. The player behind a tree: only that tree fades.
	var tree: Sprite2D; var spot: ExpeditionWorldPoint
	for candidate: Sprite2D in sprites(true):
		spot = behind(host,candidate,-1.0)
		if spot != null: tree = candidate; break
	check("player_reaches_a_spot_behind_a_tree",tree != null)
	if tree == null: finish(); return
	camera.position = AuthoredView.project(spot.position); view.sync(); await frames()
	var others_clear := sprites(true).all(func(sprite: Sprite2D) -> bool: return sprite == tree or is_equal_approx(sprite.modulate.a,1.0) or _covers(sprite))
	check("tree_in_front_of_the_player_fades",is_equal_approx(tree.modulate.a,0.38) and host.visible and others_clear and view.occluded >= 1)
	await capture("occlusion_player_behind_tree")
	# 2. The player in front of the same tree: no fade (it is drawn behind him).
	var front := behind(host,tree,1.0)
	check("tree_behind_the_player_stays_opaque",front == null or is_equal_approx(tree.modulate.a,1.0))
	# 3. Leaving restores the tree.
	var away := support(host.world_motion.geometry,160.0,640.0)
	walk(host,away)
	check("tree_returns_when_the_player_leaves",is_equal_approx(tree.modulate.a,1.0))
	# 4. An enemy behind a tree fades it too.
	var enemy_tree: Sprite2D; var enemy_spot: ExpeditionWorldPoint; var walker: EnemyActor
	for actor: EnemyActor in actors:
		for candidate: Sprite2D in sprites(true):
			enemy_spot = behind(actor,candidate,-1.0)
			if enemy_spot != null: enemy_tree = candidate; walker = actor; break
		if walker != null: break
	check("enemy_behind_a_tree_fades_it",walker != null and is_equal_approx(enemy_tree.modulate.a,0.38))
	if walker != null:
		camera.position = AuthoredView.project(enemy_spot.position); view.sync(); await capture("occlusion_enemy_behind_tree")
	# 5. A prop without camera occlusion never fades, even with the player behind it.
	var rock: Sprite2D; var rock_spot: ExpeditionWorldPoint
	for candidate: Sprite2D in sprites(false):
		rock_spot = behind(host,candidate,-1.0)
		if rock_spot != null: rock = candidate; break
	check("non_occluding_prop_never_fades",rock != null and is_equal_approx(rock.modulate.a,1.0))
	# 6. The same rule in the editor preview (one function for both).
	var probe: Array[Sprite2D] = [tree]
	Objects.reveal_actor(probe,spot.position)
	var editor_fades: bool = is_equal_approx(tree.modulate.a,0.38)
	Objects.reveal_actor(probe,Vector3(spot.position.x+400,spot.position.y,spot.position.z+400))
	check("editor_preview_uses_the_same_rule",editor_fades and is_equal_approx(tree.modulate.a,1.0))
	finish()
## Another occluding prop may legitimately cover the same spot.
func _covers(sprite: Sprite2D) -> bool:
	var base: Vector3 = sprite.get_meta("world_position")
	var foot := host.world_point().position
	return base.x+base.z >= foot.x+foot.z-1.0
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_OCCLUSION_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
