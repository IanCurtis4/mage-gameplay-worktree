@tool
extends Node2D
## Existing authored map presentation shared by editor and gameplay. No input UI.
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const WorldProjection = preload("res://scripts/world/expedition_projection.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Partition = preload("res://scripts/map_authoring/compiler/terrain_partition.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_view.gd")
const CanvasOrder = preload("res://scripts/world/world_canvas_order.gd")
const GroundShadow = preload("res://scripts/world/ground_shadow.gd")
const TerrainTopology = preload("res://scripts/map_authoring/compiler/terrain_topology.gd")
const BorderCatalog = preload("res://scripts/map_authoring/composition/border_profile_catalog.gd")
const Grid = preload("res://scripts/map_authoring/compiler/grid_piece.gd")
var package: Dictionary = {}
var geometry: WorldGeometry
var object_sprites: Array[Sprite2D] = []
var object_volumes: Array[AABB] = []
var contact_shadows_enabled := true

func clear() -> void:
	for child: Node in get_children(): child.free()
	for key: String in ["canvas_order_cache","canvas_order_bindings","canvas_order_external_scope"]:
		if has_meta(key): remove_meta(key)
	object_sprites.clear(); object_volumes.clear(); package = {}; geometry = null

func configure(value: Dictionary, world: WorldGeometry = null) -> Dictionary:
	if not Compiler.validate_package(value): return {"ok":false,"code":"package_invalid"}
	var authority := world
	if authority == null:
		authority = WorldGeometry.new()
		var configured := authority.configure(Compiler.manifest(value),"map_preview")
		if not configured.ok: return configured
	var stage: Dictionary = value.manifest.stages[0]
	for field: String in ["surfaces","volumes","solid_prisms"]:
		if authority._stage.get(field,[]) != stage.get(field,[]): return {"ok":false,"code":"renderer_world_mismatch"}
	return _configure_approved(value.duplicate(true),authority)

func _configure_approved(value: Dictionary, world: WorldGeometry) -> Dictionary:
	# Internal ownership transfer after the producer already validated this package.
	# The package remains immutable; only derived draw nodes and caches are created.
	clear(); package = value; geometry = world; geometry._ensure_support_index()
	var heights: Array = []
	for instance: Dictionary in package.render_instances:
		for layer: Dictionary in instance.layers:
			for height: float in layer.heights: heights.append(height+float(instance.translation.y))
		for visual: Dictionary in instance.visuals:
			for point: Vector3 in visual.vertices: heights.append(point.y+float(instance.translation.y))
		for object: Dictionary in instance.get("objects",[]): heights.append(object.position.y)
	for face: Dictionary in package.border_geometry.faces+package.border_geometry.water:
		for point: Vector3 in face.vertices: heights.append(point.y)
	for object: Dictionary in package.border_geometry.props: heights.append(object.position.y)
	var depth_domain := Objects.depth_domain(heights)
	for instance: Dictionary in package.render_instances:
		for layer: Dictionary in instance.layers:
			# F10 H5: a height-grid layer is drawn per stretch, exactly its support;
			# the canvas renderer culls stretches outside the camera.
			var gridded: bool = instance.get("surface_mode","") == Grid.MODE
			for region: Dictionary in (Grid.regions(layer) if gridded else Partition.build(layer)):
				var arrays := Materials.arrays(layer,region,instance.rotation_quarters,instance.translation)
				var view := MeshInstance2D.new(); view.mesh = Materials.from_arrays(arrays); view.material = Materials.material()
				if gridded: CanvasOrder.tag_height_grid(view,Grid.transformed(region.grid,int(instance.rotation_quarters),instance.translation)); view.set_meta("grid_stretch",true)
				else: CanvasOrder.tag_grid(view,int(region.width)+1,int(region.height)+1)
				self.add_child(view)
		for visual: Dictionary in instance.visuals:
			if not visual.special: continue
			_attach_face(visual.vertices,visual.material_weights,Vector3.ZERO,instance,depth_domain)
		for side: Dictionary in instance.exposed_sides: _attach_face(side.vertices,[],side.outward,instance,depth_domain)
		object_sprites.append_array(Objects.attach(self,instance.get("objects",[]),false,[],depth_domain,geometry._support_index))
		for object: Dictionary in instance.get("objects",[]):
			if object.has("body_volume"): object_volumes.append(object.body_volume)
	var border_material := Materials.material(); border_material.shader = load(BorderCatalog.BORDER_SHADER)
	for k: int in Materials.IDS.size(): border_material.set_shader_parameter(Materials.IDS[k]+"_tile",load(Materials.PATHS[k]))
	border_material.set_shader_parameter("tile_units",Materials.TILE_UNITS)
	for face: Dictionary in package.border_geometry.faces: _attach_border_face(face,border_material,depth_domain)
	if not package.border_geometry.water.is_empty():
		var water_material := ShaderMaterial.new(); water_material.shader = load(BorderCatalog.WATER_SHADER)
		water_material.set_shader_parameter("water_tile",load(BorderCatalog.WATER_PATH)); water_material.set_shader_parameter("tile_units",Materials.TILE_UNITS)
		for face: Dictionary in package.border_geometry.water: _attach_border_face(face,water_material,depth_domain)
	var border_faces: Array = []
	if not package.border_geometry.props.is_empty():
		for mass: Dictionary in package.border_geometry.solid_prisms:
			border_faces.append({"face_id":mass.volume_id,"source_id":mass.volume_id,"vertices":mass.top.duplicate(),"headroom":1.0,"walkable":TerrainTopology.is_walkable(mass.top),"special":false,"bottom_y":mass.bottom_y})
	var border_index := GroundShadow.index_from_topology(border_faces,TerrainTopology.build(border_faces)) if not border_faces.is_empty() else {}
	object_sprites.append_array(Objects.attach(self,package.border_geometry.props,false,[],depth_domain,border_index))
	for object: Dictionary in package.border_geometry.props:
		if object.has("body_volume"): object_volumes.append(object.body_volume)
	for volume: AABB in package.manifest.stages[0].volumes:
		if volume not in object_volumes: _attach_volume(volume,depth_domain)
	set_contact_shadows(contact_shadows_enabled)
	return CanvasOrder.apply(self)

func _attach_volume(box: AABB, _domain: Vector2) -> void:
	var group := Node2D.new(); self.add_child(group); CanvasOrder.tag_box(group,box)
	var p := box.position; var e := box.end; var material := Materials.material()
	var faces: Array = [
		{"vertices":[Vector3(e.x,p.y,p.z),Vector3(e.x,p.y,e.z),Vector3(e.x,e.y,e.z),Vector3(e.x,e.y,p.z)],"normal":Vector3.RIGHT},
		{"vertices":[Vector3(e.x,p.y,e.z),Vector3(p.x,p.y,e.z),Vector3(p.x,e.y,e.z),Vector3(e.x,e.y,e.z)],"normal":Vector3.BACK},
		{"vertices":[Vector3(p.x,e.y,p.z),Vector3(e.x,e.y,p.z),Vector3(e.x,e.y,e.z),Vector3(p.x,e.y,e.z)],"normal":Vector3.UP}]
	# The camera looks from positive X/Y/Z: an opaque AABB exposes these three
	# faces. Its canonical volume and legacy dimensions remain unchanged.
	for face: Dictionary in faces:
		var view := MeshInstance2D.new(); view.mesh = Materials.from_arrays(Materials.face_arrays(face.vertices,[],face.normal)); view.material = material; group.add_child(view)

func set_contact_shadows(enabled: bool) -> void:
	contact_shadows_enabled = enabled
	for sprite: Sprite2D in object_sprites:
		var shadow := sprite.get_node_or_null("ContactShadow") as CanvasItem
		if shadow != null: shadow.visible = enabled

func _attach_border_face(face: Dictionary, material: ShaderMaterial, domain: Vector2) -> void:
	var view := MeshInstance2D.new(); view.mesh = Materials.from_arrays(Materials.face_arrays(face.vertices,face.get("material_weights",[]),face.get("outward",Vector3.ZERO))); view.material = material
	var height := 0.0
	for point: Vector3 in face.vertices: height += point.y
	view.z_index = Objects.depth_order(height/face.vertices.size(),domain); view.set_meta("border_face_id",face.face_id); self.add_child(view)

func _attach_face(vertices: Array, paint: Array, normal: Vector3, instance: Dictionary, domain: Vector2) -> void:
	var view := MeshInstance2D.new(); view.mesh = Materials.from_arrays(Materials.face_arrays(vertices,paint,normal,instance.rotation_quarters,instance.translation)); view.material = Materials.material()
	var height := 0.0
	for point: Vector3 in vertices: height += point.y
	view.z_index = Objects.depth_order(height/vertices.size()+float(instance.translation.y),domain); self.add_child(view)
