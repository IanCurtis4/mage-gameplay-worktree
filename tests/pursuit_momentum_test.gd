extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_test_real_archer_pursuit()
	_test_attack_recovery()
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
