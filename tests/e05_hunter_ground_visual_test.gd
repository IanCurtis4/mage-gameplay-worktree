extends SceneTree
## Drawing grammar/state separation only; headless does not certify legibility.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var signatures: Array[int] = []
	for skill_id: StringName in HunterMath.NEW_TRAP_IDS:
		var arming := HunterGroundArt.trap_recipe(skill_id, false, 0.25, 0.0, 52.0)
		var ready := HunterGroundArt.trap_recipe(skill_id, true, 1.0, 0.0, 52.0)
		_check(not arming.is_empty() and not ready.is_empty(), "every mechanism has both presentations")
		_check(arming != ready, "arming differs in geometry and rhythm, not tint alone")
		_check(ready == HunterGroundArt.trap_recipe(skill_id, true, 1.0, 0.0, 52.0), "recipe is deterministic without a wall clock")
		_check(ready != HunterGroundArt.trap_recipe(skill_id, true, 1.0, 0.5, 52.0), "ready glint reads supplied elapsed time")
		_check(arming != HunterGroundArt.trap_recipe(skill_id, false, 0.75, 0.0, 52.0), "existing progress drives winding/shape")
		_check(arming.size() < 64 and ready.size() < 64, "bounded primitive count per mechanism")
		signatures.append(hash(ready))
		_recipe_invariants(arming, 52.0)
		_recipe_invariants(ready, 52.0)
		_lifecycle_unchanged(skill_id)
	_check(signatures[0] != signatures[1] and signatures[1] != signatures[2] and signatures[0] != signatures[2], "cold jaws, resin pot and stakes are distinct recipes")
	var field := HunterGroundArt.tar_recipe(HunterTarField.RADIUS, 0.0)
	_check(field.size() == 22, "tar texture is finite with seven resin bubbles and five moss flecks")
	_check(field[0]["radius"] == 100.0 and field[1]["radius"] == 100.0 and field[2]["radius"] == 100.0, "fill and both contrasting boundaries retain real radius100")
	_check(field[1]["color"] != field[2]["color"] and field[1]["width"] > field[2]["width"], "double boundary combines dark backing and light narrow stroke")
	_check(field != HunterGroundArt.tar_recipe(HunterTarField.RADIUS, 0.5), "field bubbles use observed elapsed lifetime")
	_check(field == HunterGroundArt.tar_recipe(HunterTarField.RADIUS, 0.0), "field has no retained mutable visual state")
	_recipe_invariants(field, HunterTarField.RADIUS)
	for invalid: float in [NAN, INF, -1.0, 0.0]:
		_check(HunterGroundArt.tar_recipe(invalid, 0.0).is_empty(), "invalid radius cannot enter drawing")
		_check(HunterGroundArt.trap_recipe(&"hunter_freezing_trap", true, 1.0, 0.0, invalid).is_empty(), "invalid trap radius rejected")
	_check(HunterGroundArt.trap_recipe(&"explosive_trap", true, 1.0, 0.0, 52.0).is_empty(), "Hunter helper does not replace base mechanism recipes")
	_check(HunterGroundArt.trap_recipe(&"hunter_tar_trap", true, NAN, 0.0, 52.0).is_empty(), "nonfinite progress rejected")
	_check(HunterGroundArt.trap_recipe(&"hunter_tar_trap", true, 1.0, INF, 52.0).is_empty() and HunterGroundArt.tar_recipe(100.0, INF).is_empty(), "nonfinite elapsed rejected")
	print("Hunter ground visuals: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _recipe_invariants(commands: Array[Dictionary], radius: float) -> void:
	for command: Dictionary in commands:
		var color: Color = command["color"]
		_check(is_finite(color.r) and is_finite(color.g) and is_finite(color.b) and color.a >= 0.0 and color.a <= 1.0, "finite color/opacity")
		_check(not command.has("request") and not command.has("target") and not command.has("callback"), "commands contain no combat payload")
		match command["kind"]:
			&"circle", &"arc":
				var center: Vector2 = command["center"]
				var extent := float(command["radius"])
				_check(center.is_finite() and extent > 0.0 and center.length() + extent <= radius + 0.001, "rings and bubbles remain inside real area")
			&"line":
				var first: Vector2 = command["from"]
				var last: Vector2 = command["to"]
				_check(first.is_finite() and last.is_finite() and maxf(first.length(), last.length()) <= radius, "lines remain inside area")
			&"polygon":
				var points: PackedVector2Array = command["points"]
				var valid := points.size() >= 3
				for point: Vector2 in points:
					valid = valid and point.is_finite() and point.length() <= radius
				_check(valid, "material silhouettes remain inside area")
			_:
				_check(false, "unknown drawing primitive")

func _lifecycle_unchanged(skill_id: StringName) -> void:
	var stats := StatCalculator.calculate({&"int": 20, &"dex": 5})
	var request := HunterMath.trap_request(1, skill_id, 1, stats, 1.0)
	var opening := HunterMath.opening_request(1, skill_id, 1, stats, 1.0)
	var trap := HunterTrap.new()
	trap.configure_hunter(Vector2(250, 250), 1, request, opening, [], 12.0)
	root.add_child(trap)
	trap.set_process(false)
	var snapshot := [trap.state, trap.arming_remaining, trap.lifetime_remaining, trap.radius, trap.effect_radius, trap.damage_request.physical_damage, trap.damage_request.magic_damage, trap.opening_request.physical_damage]
	var progress := 1.0 - trap.arming_remaining / trap.arming_duration
	for _iteration: int in range(5):
		HunterGroundArt.trap_recipe(trap.source_skill_id, trap.state == PlayerTrap.State.ARMED, progress, trap.armed_duration - trap.lifetime_remaining, trap.radius)
	_check(snapshot == [trap.state, trap.arming_remaining, trap.lifetime_remaining, trap.radius, trap.effect_radius, trap.damage_request.physical_damage, trap.damage_request.magic_damage, trap.opening_request.physical_damage], "repeated recipe observation never changes gameplay state/payloads")
	trap.free()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
