@tool
extends RefCounted
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const GroundShadow = preload("res://scripts/world/ground_shadow.gd")
const Metadata = preload("res://scripts/map_authoring/objects/object_schema.gd")
const ProjectionView = preload("res://scripts/world/expedition_geometry_view.gd")

static func depth_domain(heights: Array) -> Vector2:
	if heights.is_empty(): return Vector2.ZERO
	var low := float(heights[0]); var high := low
	for value: float in heights: low = minf(low,value); high = maxf(high,value)
	return Vector2(low,high)

static func depth_order(height: float, domain: Vector2, offset: int = 0) -> int:
	# Editor backgrounds stay at zero and interaction overlays at4090. Normalize
	# display depth only; negative world heights and physical geometry are intact.
	var scale := minf(4.0,3984.0/maxf(1.0,float(domain.y)-float(domain.x)))
	return clampi(8+floori((height-float(domain.x))*scale)+offset,1,4000)

static func source_records(source: Dictionary) -> Array:
	var catalog := Catalog.load_catalog(); var records: Array = []
	if not catalog.ok: return records
	for placement: Dictionary in source.get("placements",[]):
		var found := Catalog.definition(placement.definition_id,catalog)
		if not found.ok: continue
		var p: Array = placement.position_xyz
		records.append({"placement_id":placement.placement_id,"definition_id":placement.definition_id,"position":Vector3(p[0],p[1],p[2]),"source_surface_id":placement.surface_id,"rotation_y":placement.rotation_y,"definition":found.definition,"editor_state":Metadata.state(source,placement.placement_id)})
	return records

static func attach(root: Node2D, records: Array, authoring: bool = false, hidden_surfaces: Array[String] = [], domain: Vector2 = Vector2.ZERO, shadow_index: Dictionary = {}) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	if records.is_empty(): return result
	var catalog := Catalog.load_catalog()
	if not catalog.ok: return result
	var ordered: Array = records.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var ay := ProjectionView.project(a.position).y; var by := ProjectionView.project(b.position).y
		return ay < by if ay != by else str(a.placement_id) < str(b.placement_id))
	for object: Dictionary in ordered:
		if authoring and (object.get("editor_state",{}).get("hidden",false) or object.get("source_surface_id","") in hidden_surfaces): continue
		var current := Catalog.definition(str(object.get("definition_id","")),catalog)
		if not current.ok or not object.get("position") is Vector3 or not object.position.is_finite(): continue
		# Renderer paths always come from the local passive catalog, including when
		# a caller supplied a compiled record. Never load a sender's resource path.
		var definition: Dictionary = current.definition
		var texture := load(definition.sprite_path) as Texture2D
		if texture == null: continue
		var sprite := Sprite2D.new(); sprite.texture = texture
		sprite.name = "Prop_"+str(object.placement_id).replace("/","_").replace(":","_").replace(".","_")
		sprite.centered = false
		sprite.offset = -Vector2(definition.pivot_uv[0]*texture.get_width(),definition.pivot_uv[1]*texture.get_height())
		sprite.scale = Vector2.ONE*float(definition.world_height)/float(texture.get_height())
		sprite.position = ProjectionView.project(object.position)
		sprite.z_index = depth_order(object.position.y,domain,1)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.flip_h = int(round(float(object.rotation_y)/90.0)) in [1,2]
		if sprite.flip_h: sprite.offset.x = -(1.0-float(definition.pivot_uv[0]))*texture.get_width()
		sprite.set_meta("placement_id",object.placement_id)
		sprite.set_meta("world_position",object.position)
		sprite.set_meta("footprint_radius",float(definition.footprint_radius)); sprite.set_meta("world_height",float(definition.world_height))
		sprite.set_meta("camera_occlusion",definition.capabilities.camera_occlusion)
		root.add_child(sprite); result.append(sprite)
		if not shadow_index.is_empty():
			var receiver_id := GroundShadow.receiver(object.position,shadow_index,str(object.get("surface_id","")))
			if not receiver_id.is_empty(): GroundShadow.attach(sprite,object.position,Vector2.ONE*maxf(3.0,float(definition.footprint_radius)*0.85),shadow_index,receiver_id,ProjectionView.project)
	return result

static func pick(records: Array, local: Vector2, project: Callable, scale: float) -> String:
	var nearest := INF; var selected := ""
	var images := {}
	for object: Dictionary in records:
		if object.get("editor_state",{}).get("hidden",false): continue
		var definition: Dictionary = object.definition
		var texture := load(definition.sprite_path) as Texture2D
		if texture == null: continue
		var anchor: Vector2 = project.call(object.position)
		var ratio := float(definition.world_height)*scale/float(texture.get_height())
		var mirrored := int(round(float(object.rotation_y)/90.0)) in [1,2]
		var pivot_x: float = 1.0-float(definition.pivot_uv[0]) if mirrored else float(definition.pivot_uv[0])
		var corner := anchor-Vector2(pivot_x*texture.get_width(),definition.pivot_uv[1]*texture.get_height())*ratio
		var rectangle := Rect2(corner,texture.get_size()*ratio)
		if not rectangle.has_point(local): continue
		# Texture alpha, rather than a giant invisible canopy rectangle, owns picking.
		var pixel := (local-corner)/ratio
		if mirrored: pixel.x = texture.get_width()-1-pixel.x
		if not images.has(definition.sprite_path): images[definition.sprite_path] = texture.get_image()
		var image: Image = images[definition.sprite_path]
		if image != null and image.get_pixel(clampi(int(pixel.x),0,image.get_width()-1),clampi(int(pixel.y),0,image.get_height()-1)).a < 0.1: continue
		var distance := local.distance_to(anchor)
		if distance < nearest: nearest = distance; selected = object.placement_id
	return selected

static func reveal_actor(sprites: Array[Sprite2D], actor_position: Vector3) -> void:
	var screen := ProjectionView.project(actor_position)+Vector2(0,-20)
	for sprite: Sprite2D in sprites:
		if not sprite.get_meta("camera_occlusion",false): continue
		var rect := sprite.get_rect()
		var parent := sprite.get_parent() as Node2D
		var obscures := rect.has_point(sprite.to_local(parent.to_global(screen))) and float(sprite.get_meta("world_position").y) <= actor_position.y+32.0
		sprite.modulate.a = 0.38 if obscures else 1.0
