extends SceneTree
## Presentation-only invariants. Alpha/pivot checks do not approve visual taste.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var hunter := CharacterAnimation.new()
	hunter.configure(&"hunter")
	_check(hunter.actor_kind == &"hunter" and hunter.atlas != null and hunter.atlas.get_size() == Vector2(256, 512), "Hunter owns a full 32-cell atlas")
	_check(FileAccess.file_exists("res://assets/art/animation_sources/hunter_source.png"), "generated Hunter source preserved")
	if hunter.atlas == null or hunter.actor_kind != &"hunter":
		_finish()
		return
	var bitmap := hunter.atlas.get_image()
	for index: int in 32:
		var rect := Rect2i(Vector2i(index % 4 * 64, (index >> 2) * 64), Vector2i(64, 64))
		var pose := bitmap.get_region(rect)
		var bounds := pose.get_used_rect()
		_check(bounds.has_area() and bounds.position.x > 0 and bounds.end.x < 64 and bounds.end.y <= 59, "pose%d fits transparent gutters" % index)
		var clear_edges := true
		for edge: int in 64:
			clear_edges = clear_edges and pose.get_pixel(edge, 0).a == 0.0 and pose.get_pixel(edge, 63).a == 0.0 and pose.get_pixel(0, edge).a == 0.0 and pose.get_pixel(63, edge).a == 0.0
		_check(clear_edges, "pose%d borders remain transparent" % index)
		_check(hunter.source_region(index) == Rect2(rect) and is_zero_approx(hunter.destination_rect(index).position.y + bounds.end.y - 1), "pose%d integer sampling with exact ground contact" % index)
		if index < 28:
			var boots: Array[int] = []
			for y: int in range(maxi(0, bounds.end.y - 6), bounds.end.y):
				for x: int in 64:
					var pixel := pose.get_pixel(x, y)
					if pixel.a > 0.5 and pixel.r > 0.14 and pixel.r > pixel.b * 1.2:
						boots.append(x)
			boots.sort()
			_check(not boots.is_empty() and absf(float(boots[boots.size() / 2]) - CharacterAnimation.PIVOT.x) <= 5.0, "pose%d boot median stays at logical pivot" % index)
		else:
			_check(bounds.size.x > bounds.size.y, "pose%d death silhouette lies horizontally" % index)
	for base: int in [4, 12]:
		for offset: int in 3:
			_check(bitmap.get_region(Rect2i(hunter.source_region(base + offset))).get_data() != bitmap.get_region(Rect2i(hunter.source_region(base + offset + 1))).get_data(), "distinct walk step %d" % (base + offset))
	_check(bitmap.get_region(Rect2i(hunter.source_region(0))).get_data() != bitmap.get_region(Rect2i(hunter.source_region(16))).get_data(), "front and back drawings differ")
	_orientation(hunter)
	var sibling := CharacterAnimation.new()
	sibling.configure(&"hunter")
	hunter.play(&"cast", Vector2(-1, -1), 0.4)
	_check(sibling.atlas == hunter.atlas and sibling.state != hunter.state and sibling.state.action_remaining == 0.0, "immutable atlas shared but clocks independent")
	var corpse := hunter.death_copy()
	_check(corpse.state.dead and corpse.atlas == hunter.atlas and corpse.destination_rect(31) == hunter.destination_rect(31), "death copy preserves grounding and independent state")
	for kind: StringName in [&"archer", &"sentinel"]:
		var other := CharacterAnimation.new()
		other.configure(kind)
		_check(other.actor_kind == kind and other.atlas != hunter.atlas, "unchanged own atlas for " + String(kind))
	_actor_integration()
	_finish()

func _orientation(animation: CharacterAnimation) -> void:
	for rear: bool in [false, true]:
		var direction := Vector2(-1, -1) if rear else Vector2(1, 1)
		animation.state = CombatAnimationState.new()
		animation.state.face(direction)
		_check(animation.state.frame_index() == (16 if rear else 0) and animation.state.flip_h == rear, "idle orientation and horizontal mirror")
		animation.state.advance(0.02, direction.normalized() * 16.0)
		_check(animation.state.frame_index() == (13 if rear else 5), "distance-driven walking orientation")
		animation.play(&"cast", direction, 0.4)
		animation.state.advance(0.1, Vector2.ZERO)
		_check(animation.state.frame_index() == (21 if rear else 9), "presentation action selects correct atlas row")
		animation.play(&"hurt")
		_check(animation.state.frame_index() == (26 if rear else 24), "hurt preserves direction")
		animation.play(&"death")
		animation.state.advance(0.2, Vector2.ZERO)
		_check(animation.state.frame_index() == (31 if rear else 29), "death selects terminal frame without moving feet")

func _actor_integration() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 800), [], 20.0)
	for evolution: StringName in [&"", &"hunter", &"sentinel"]:
		var build := BuildSnapshot.new()
		build.character_id = "hunter-atlas-local"
		build.base_class_id = &"archer"
		build.evolution_id = evolution
		var player := PlayerActor.new()
		player.configure(nav, RunState.from_build("", build))
		var expected := &"archer" if evolution.is_empty() else evolution
		_check(player.character_animation.actor_kind == expected and player.class_id == &"archer", "identity selects presentation without rewriting origin")
		_check(player.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "runtime sprite uses nearest")
		player.free()
	_check(ProfileCatalog.pilot().evolution_is_ready(&"hunter", &"archer"), "H7 completed candidate has its own integrated atlas; publication is separate")

func _finish() -> void:
	print("Hunter H6 atlas: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
