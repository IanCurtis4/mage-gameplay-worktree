extends ExpeditionGeometryView
## Disposable skin over the canonical gameplay world. Actors keep their owner.
const PackageView = preload("res://scripts/world/map_package_view.gd")
const CanvasOrder = preload("res://scripts/world/world_canvas_order.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_view.gd")
var skin: PackageView
## Checkpoint49 (F9-01, P6c): props faded this frame because an actor is behind them.
var occluded := 0
var ordering: Dictionary = {}
var package: Dictionary = {}

func configure_package(value: Dictionary, world: WorldGeometry) -> Dictionary:
	var proposed := PackageView.new()
	var made := proposed.configure(value,world)
	if not made.ok: proposed.free(); return made
	var snapshot := world.presentation_snapshot(world.geometry_revision)
	if not snapshot.ok: proposed.free(); return snapshot
	field_views.clear()
	if is_instance_valid(skin): skin.free()
	package = value.duplicate(true); skin = proposed; add_child(skin)
	geometry = world; _epoch = world.configuration_revision; _surfaces = snapshot.data.surfaces
	if _effects == null:
		_effects = Node2D.new(); _effects.z_index = 4090
		_effects.z_as_relative = false; add_child(_effects); _effects.draw.connect(_draw_effects)
	return made

## Reuses a skin already built for this exact prepared package. The skin is
## presentation only and its static support data is identical across the
## worlds a campaign transaction restores, so the rebuild (seconds) is skipped.
func configure_with_skin(value: Dictionary, world: WorldGeometry, reused_node: Node) -> Dictionary:
	var reused := reused_node as PackageView
	if not is_instance_valid(reused): return configure_package(value,world)
	var snapshot := world.presentation_snapshot(world.geometry_revision)
	if not snapshot.ok: return snapshot
	field_views.clear()
	if is_instance_valid(skin) and skin != reused: skin.free()
	if reused.get_parent() != null: reused.get_parent().remove_child(reused)
	package = value.duplicate(true); skin = reused; skin.geometry = world; add_child(skin)
	geometry = world; _epoch = world.configuration_revision; _surfaces = snapshot.data.surfaces
	if _effects == null:
		_effects = Node2D.new(); _effects.z_index = 4090
		_effects.z_as_relative = false; add_child(_effects); _effects.draw.connect(_draw_effects)
	return {"ok":true,"code":"","reused":true}

func configure(world: WorldGeometry) -> Dictionary:
	if package.is_empty(): return {"ok":false,"code":"package_required"}
	return configure_package(package,world)

func sync() -> void:
	if geometry == null or not is_instance_valid(skin): return
	if not current():
		var snapshot := geometry.presentation_snapshot(geometry.geometry_revision)
		if not snapshot.ok: return
		_epoch = geometry.configuration_revision; _surfaces = snapshot.data.surfaces
	var observed: Array = []; var kept: Array[WeakRef] = []
	for reference: WeakRef in _actors:
		var actor := reference.get_ref() as CombatActor
		if not is_instance_valid(actor): continue
		kept.append(reference)
		if actor.world_motion == null or actor.world_motion.geometry != geometry or not actor.world_motion.is_current_world(): continue
		actor.global_position = to_global(project(actor.world_point().position))
		actor.visible = actor.world_point().surface_id not in _hidden
		observed.append(actor)
	_actors = kept
	# Camera-occluding props fade while the player or an enemy is behind them.
	var feet: Array = []
	for actor: CombatActor in observed:
		if actor.visible: feet.append(actor.world_point().position)
	occluded = Objects.reveal_actors(skin.object_sprites,feet)
	# Never call the base height-Z assignment: it invalidates warm topology reuse.
	field_views.sync(skin,controller,geometry,_hidden)
	ordering = CanvasOrder.apply(skin,observed)
	if _effects != null: _effects.queue_redraw()
