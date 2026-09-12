extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_real_archer_pursuit()
	_test_attack_recovery()
	_test_momentum()
	_test_obstacle_routes()
	_test_arena_archers()
	print("Perseguição e inércia: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_real_archer_pursuit() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 4200, 600), [], 22.0)
	for fps: int in [30, 60, 144]:
		for enemy_first: bool in [false, true]:
			var player := _player(nav, Vector2(300, 300))
			var archer := EnemyActor.new()
			archer.configure(&"archer", nav, player)
			root.add_child(archer)
			archer.set_process(false)
			archer.position = Vector2(550, 300)
			# Keep the real AI active after contact to verify repeated attacks/escape.
			archer.health.reset(1000.0, 0.0)
			var hits := [0]
			player.attack_requested.connect(func(request: DamageRequest, victim: CombatActor) -> void:
				hits[0] += 1
				victim.health.apply(request, 0.0, 0.99)
			)
			player.pursue(archer)
			for _frame: int in range(fps * 10):
				if enemy_first:
					archer._process(1.0 / fps)
				player._process(1.0 / fps)
				if not enemy_first:
					archer._process(1.0 / fps)
			print("Arqueiro real %d Hz enemy_first=%s: %d autos, distância %.2f" % [fps, enemy_first, hits[0], player.position.distance_to(archer.position)])
			_check(hits[0] >= 2 and archer.health.current_hp < 1000.0, "one selection repeatedly attacks fleeing archer at %d Hz (enemy first %s)" % [fps, enemy_first])
			archer.free()
			player.free()

func _test_attack_recovery() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 800, 500), [], 22.0)
	var player := _player(nav, Vector2(200, 200))
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, RpgStats.derive({"vit": 1}), 17.0)
	root.add_child(enemy)
	enemy.position = Vector2(286, 200)
	var hits := [0]
	player.attack_requested.connect(func(_request: DamageRequest, _victim: CombatActor) -> void: hits[0] += 1)
	player.pursue(enemy)
	player._process(1.0 / 60.0)
	_check(hits[0] == 1, "ready auto fires as soon as selected target is in reach")
	enemy.position.x += 40.0
	var strike_position := player.position
	player._process(0.08)
	_check(player.position == strike_position and hits[0] == 1, "brief recovery allows enemy to leave reach without repeated strikes")
	player._process(0.10)
	_check(player.position.x > strike_position.x and hits[0] == 1, "pursuit resumes after recovery while attack cooldown remains active")
	player._attack_recovery = PlayerActor.BASIC_ATTACK_RECOVERY
	player.move_to(player.position + Vector2(0, 100))
	var before_click := player.position
	player._process(0.05)
	_check(player.target == null and player.position.y > before_click.y, "ground command cancels automated recovery and pursuit immediately")
	player.free()
	enemy.free()

func _test_momentum() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1800, 1000), [], 22.0)
	var player := _player(nav, Vector2(600, 500))
	player.move_to(Vector2(1500, 500))
	player._process(0.05)
	_check(player.velocity.x > 0.0 and player.velocity.x < 100.0 and player.position.x < 605.0, "walking accelerates instead of starting at full speed")
	player._process(0.25)
	_check(absf(player.velocity.length() - 220.0) < 0.1, "light acceleration reaches normal movement speed promptly")
	var turn_origin := player.position
	player.move_to(turn_origin + Vector2(0, 300))
	player._process(0.05)
	_check(player.velocity.x > 0.0 and player.velocity.y > 0.0 and player.position.x > turn_origin.x, "a turn preserves momentum and curves toward the new command")
	player._process(2.0)
	_check(player.position.distance_to(turn_origin + Vector2(0, 300)) < 0.1 and player.velocity.is_zero_approx(), "curved movement settles at the exact commanded destination")
	player.move_to(player.position + Vector2(400, 0))
	player._process(0.4)
	var reversal_origin := player.position
	player.move_to(player.position - Vector2(400, 0))
	player._process(1.0 / 120.0)
	_check(player.velocity.x > 0.0 and player.position.x > reversal_origin.x, "reversal brakes the current direction instead of instantly flipping velocity")
	player._process(0.5)
	_check(player.velocity.x < -200.0, "reversal responds and accelerates in the new direction")
	var stop_origin := player.position
	player.move_to(stop_origin)
	player._process(0.04)
	_check(player.velocity.length() > 0.0 and player.velocity.length() < 220.0, "friction reduces speed over time on a stop command")
	player._process(0.3)
	_check(player.velocity.is_zero_approx() and player.position.distance_to(stop_origin) < 20.0, "friction stops the actor within a short bounded glide")
	for distance: float in [1.0, 5.0, 10.0]:
		var destination := player.position + Vector2(distance, 0)
		player.move_to(destination)
		player._process(1.0)
		_check(player.position.distance_to(destination) < 0.1 and player.velocity.is_zero_approx(), "short %.0f px clicks arrive without orbiting" % distance)
	player.move_to(player.position + Vector2(0, -200))
	player._process(0.2)
	var paused_position := player.position
	var paused_velocity := player.velocity
	paused = true
	player._process(0.5)
	_check(player.position == paused_position and player.velocity == paused_velocity, "pause freezes both position and momentum")
	paused = false
	player._process(0.05)
	_check(player.position != paused_position, "unpause resumes existing movement intent")
	player.use_dash(Vector2.RIGHT)
	var dash_position := player.position
	player._process(0.2)
	_check(player.velocity.is_zero_approx() and player.position == dash_position, "dash clears walking momentum and stale destination")
	player.move_to(player.position + Vector2(100, 0))
	player._process(0.1)
	var lethal := DamageRequest.new()
	lethal.base_damage = 9999.0
	lethal.hit_chance = 1.0
	lethal.target_id = player.get_instance_id()
	player.health.apply(lethal, 0.0, 0.99)
	_check(not player.is_alive() and player.velocity.is_zero_approx() and player._path.is_empty(), "death discards momentum synchronously before death pause")
	player.free()
	var positions: Array[Vector2] = []
	for fps: int in [30, 60, 144]:
		var paced := _player(nav, Vector2(512, 300))
		paced.move_to(Vector2(1600, 300))
		for _frame: int in range(fps):
			paced._process(1.0 / fps)
		positions.append(paced.position)
		_check(absf(paced.position.x - 710.0) < 0.2, "acceleration covers a stable distance in 1 s at %d Hz" % fps)
		paced.free()
	_check(positions[0].distance_to(positions[2]) < 0.2, "render rate does not materially change movement weight")

func _test_obstacle_routes() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(RunController.ARENA_BOUNDS, RunController.ARENA_OBSTACLES, 22.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 914
	var player := _player(nav, Vector2(300, 520))
	var all_safe := true
	var all_arrived := true
	for route: int in range(40):
		var destination := Vector2(rng.randf_range(110, 1690), rng.randf_range(110, 970))
		while not nav.is_walkable(destination):
			destination = Vector2(rng.randf_range(110, 1690), rng.randf_range(110, 970))
		player.move_to(destination)
		# Redirect while moving on alternate routes to exercise inertia off the path.
		if route % 2 == 0:
			player._process(0.35)
			player.move_to(Vector2(300, 520))
			destination = Vector2(300, 520)
		for _frame: int in range(30 * 15):
			var previous := player.position
			player._process(1.0 / 30.0)
			all_safe = all_safe and nav.is_segment_walkable(previous, player.position)
			if player.position.distance_to(destination) < 0.1 and player.velocity.is_zero_approx():
				break
		if player.position.distance_to(destination) >= 0.1:
			print("Unfinished route %d: %s -> %s" % [route, player.position, destination])
			all_arrived = false
	_check(all_safe, "momentum and redirects never cross inflated obstacles or bounds on 40 seeded routes")
	_check(all_arrived, "40 seeded routes arrive without getting stuck on obstacle corners")
	player.free()

func _test_arena_archers() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(RunController.ARENA_BOUNDS, RunController.ARENA_OBSTACLES, 22.0)
	for spawn: Vector2 in [Vector2(1500, 350), Vector2(960, 850)]:
		var player := _player(nav, Vector2(300, 520))
		var archer := EnemyActor.new()
		archer.configure(&"archer", nav, player)
		root.add_child(archer)
		archer.set_process(false)
		archer.position = spawn
		player.attack_requested.connect(func(request: DamageRequest, victim: CombatActor) -> void: victim.health.apply(request, 0.0, 0.99))
		player.pursue(archer)
		var safe := true
		for _frame: int in range(60 * 20):
			var previous := player.position
			player._process(1.0 / 60.0)
			archer._process(1.0 / 60.0)
			safe = safe and nav.is_segment_walkable(previous, player.position)
			if not archer.is_alive():
				break
		_check(not archer.is_alive() and safe, "one pursuit kills real arena archer at %s with safe obstacle movement" % spawn)
		player.free()
		archer.free()

func _player(nav: ArenaNavigation, point: Vector2) -> PlayerActor:
	var player := PlayerActor.new()
	player.configure(nav, RunState.new())
	root.add_child(player)
	player.set_process(false)
	player.position = point
	return player

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
