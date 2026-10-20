extends Node2D
## Native technical sample. Explicit F0 input and run state; no profile facade, loot or campaign.
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
const Dependencies = preload("res://tests/e05_dependency_fixture.gd")
var controller: RunController
var view: ExpeditionGeometryView
var world: WorldGeometry
var profile: Dictionary
var lower: CombatActor
var upper: CombatActor
var notice: Label
func _ready() -> void:
	var build := BuildSnapshot.new(); build.character_id = "f1_visual_fixture"; build.base_class_id = &"mage"; build.base_level = 30; build.job_level = 40
	build.action_slots = ActionBarLayout.from_legacy([&"fireball",&"fire_spear",&"ice_spear",&"lightning",&"fire_wall",&"ice_wall",&"lightning_wall",&"teleport"])
	build.skill_ranks = {&"fireball":5,&"fire_spear":5,&"ice_spear":5,&"lightning":5,&"fire_wall":5,&"ice_wall":5,&"lightning_wall":5,&"teleport":5}; Dependencies.complete_snapshot(build)
	RunController.pending_run_state = RunState.from_build("f1_visual_fixture",build); RunController.pending_run_facade = null; RunController.pending_training_mode = true
	controller = load("res://scenes/main.tscn").instantiate() as RunController
	DirAccess.make_dir_recursive_absolute("res://.godot/f1_visual_fixture")
	controller.control_preferences.path = "res://.godot/f1_visual_fixture/controls.cfg"
	add_child(controller); controller.set_process(false)
	var input := Fixture.make()
	# This explicit sample scale is not production tuning. Includes traversal and solid slab.
	input.traversal.radius *= 3; input.traversal.height *= 3
	for part: ExpeditionPartDefinition in input.parts:
		for surface: ExpeditionSurfaceDefinition in part.surfaces:
			for index: int in surface.vertices.size(): surface.vertices[index] *= 3
			surface.headroom *= 3
		for connector: ExpeditionConnectorDefinition in part.connectors: connector.position *= 3; connector.width *= 3; connector.headroom *= 3
		for socket: ExpeditionSocketDefinition in part.sockets: socket.position *= 3
		for index: int in part.solid_volumes.size():
			var volume := part.solid_volumes[index]; part.solid_volumes[index] = AABB(volume.position*3,volume.size*3)
	profile = input.traversal.to_data(); world = WorldGeometry.new()
	var assembled := ExpeditionAssembler.build(input)
	assert(assembled["ok"] and world.configure(assembled["data"]["manifest"],"sample")["ok"])
	assert(controller.player.bind_world_geometry(world,Fixture.point("root",Vector3(90,0,150)),profile,"visual_player")["ok"])
	lower = controller.training_boss; lower.set_process(false)
	assert(lower.bind_world_geometry(world,Fixture.point("root",Vector3(180,0,440)),profile,"visual_lower")["ok"])
	lower.health.max_hp = 100000; lower.health.current_hp = 100000
	upper = CombatActor.new(); controller.add_child(upper); upper.setup("Alvo superior",Color("e2b876"),StatCalculator.calculate({&"vit":10})); upper.set_animation_kind(&"archer")
	upper.health.max_hp = 100000; upper.health.current_hp = 100000; upper.set_process(false)
	assert(upper.bind_world_geometry(world,Fixture.point("bridge",Vector3(180,120,440)),profile,"visual_upper")["ok"])
	upper.set_process(false); controller.enemies.append(upper)
	view = ExpeditionGeometryView.new(); controller.add_child(view); assert(view.configure(world)["ok"])
	assert(controller.attach_expedition_view(view,36)["ok"])
	controller.arena_view.hide()
	for obstacle: Node2D in controller._world_obstacle_views: obstacle.hide()
	controller.route_camera.limit_left = -2000; controller.route_camera.limit_top = -2000; controller.route_camera.limit_right = 3000; controller.route_camera.limit_bottom = 3000
	controller.route_camera.position = Vector2(120,80); controller.route_camera.reset_smoothing()
	var overlay := CanvasLayer.new(); overlay.layer = 30; add_child(overlay)
	var panel := PanelContainer.new(); panel.position = Vector2(478,18); panel.custom_minimum_size = Vector2(410,100); overlay.add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color("11222cf2"); style.content_margin_left = 12; style.content_margin_right = 12; style.content_margin_top = 8; style.content_margin_bottom = 8; panel.add_theme_stylebox_override("panel",style)
	notice = Label.new(); notice.custom_minimum_size = Vector2(386,82); notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; notice.add_theme_font_size_override("font_size",16); panel.add_child(notice)
	notice.text = "AMOSTRA F1 · seed 711 · clique para caminhar / atacar\nRampa conecta os pisos; laje bloqueia ataques entre andares."
	controller.next_button.hide(); controller.bottom_controls.hide(); controller.training_status_label.hide()
	view.indicate(Fixture.point("bridge",Vector3(120,120,440)),true)
func _process(_delta: float) -> void:
	if controller != null:
		controller._update_hud()
		controller._update_aim(controller._world_mouse_point())
		controller.bottom_controls.hide(); controller.training_status_label.hide()
