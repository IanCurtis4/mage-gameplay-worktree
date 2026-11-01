@tool
extends RefCounted
## Four paint weights and canonical world geometry for the shared canvas renderer.
const REVISION := "terrain_material_v2"
const Partition = preload("res://scripts/map_authoring/compiler/terrain_partition.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const ProjectionView = preload("res://scripts/world/expedition_geometry_view.gd")
const Assets = preload("res://scripts/map_authoring/assets/asset_manifest.gd")
const SHADER_PATH := "res://scripts/map_authoring/terrain/terrain_material.gdshader"
const GRASS_PATH := "res://assets/art/map_authoring/grass_tile.png"
const EARTH_PATH := "res://assets/art/map_authoring/earth_tile.png"
const SAND_PATH := "res://assets/art/map_authoring/sand_tile.png"
const STONE_PATH := "res://assets/art/map_authoring/cliff_tile.png"
const IDS := ["grass","earth","sand","stone"]
const PATHS := [GRASS_PATH,EARTH_PATH,SAND_PATH,STONE_PATH]
const TILE_UNITS := 128.0
const MESH_FLAGS := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

static func dependencies() -> Array:
	var paths: Array = [SHADER_PATH]
	for path: String in PATHS: paths.append(path); paths.append(path+".import")
	paths.sort()
	var result: Array = []
	for path: String in paths:
		var digest := Assets.sha256(path)
		if digest.is_empty(): return []
		result.append({"definition_id":path.get_file().replace(".","_"),"revision":2 if path == SHADER_PATH else 1,"sha256":digest,"path":path})
	return result

static func material(selected: bool = true) -> ShaderMaterial:
	var result := ShaderMaterial.new(); result.shader = load(SHADER_PATH)
	for k: int in IDS.size(): result.set_shader_parameter(IDS[k]+"_tile",load(PATHS[k]))
	result.set_shader_parameter("tile_units",TILE_UNITS)
	result.set_shader_parameter("layer_tint",Color.WHITE if selected else Color(0.86,0.90,0.86,1))
	return result

static func weights(layer: Dictionary, index: int) -> Array[float]:
	var values: Array[float] = []
	for id: String in IDS:
		var fallback := 1.0 if id == "grass" else 0.0
		values.append(float(layer.material_masks.get(id,[])[index]) if layer.material_masks.has(id) else fallback)
	var total := values[0]+values[1]+values[2]+values[3]
	if total <= 0.0: return [1.0,0.0,0.0,0.0]
	for k: int in values.size(): values[k] /= total
	return values

static func weights_at(layer: Dictionary, index: int) -> Color:
	var values := weights(layer,index)
	return Color(values[0],values[1],values[2],values[3])

static func normal_at(layer: Dictionary, x: int, z: int) -> Vector3:
	var columns: int = layer.columns
	var left := maxi(0,x-1); var right := mini(columns-1,x+1)
	var top := maxi(0,z-1); var bottom := mini(int(layer.rows)-1,z+1)
	var dx := (float(layer.heights[z*columns+right])-float(layer.heights[z*columns+left]))/((right-left)*float(layer.sample_spacing))
	var dz := (float(layer.heights[bottom*columns+x])-float(layer.heights[top*columns+x]))/((bottom-top)*float(layer.sample_spacing))
	return Vector3(-dx,1,-dz).normalized()

static func arrays(layer: Dictionary, region: Dictionary = {}, quarter: int = 0, offset: Vector3 = Vector3.ZERO) -> Array:
	var ox: int = region.get("x",0); var oz: int = region.get("z",0)
	var columns: int = int(region.get("width",int(layer.columns)-1))+1
	var rows: int = int(region.get("height",int(layer.rows)-1))+1
	var positions := PackedVector2Array(); var uv := PackedVector2Array(); var colors := PackedColorArray()
	var world_values := PackedFloat32Array(); var normals := PackedFloat32Array(); var indices := PackedInt32Array()
	for local_z: int in rows:
		for local_x: int in columns:
			var x := ox+local_x; var z := oz+local_z
			var index := local_z*columns+local_x
			var point := Kernel.rotate(Partition.point(layer,x,z),quarter)+offset
			var normal := Kernel.rotate(normal_at(layer,x,z),quarter)
			positions.append(ProjectionView.project(point)); uv.append(Vector2(point.x,point.z)/TILE_UNITS)
			colors.append(weights_at(layer,z*int(layer.columns)+x))
			world_values.append_array(PackedFloat32Array([point.x,point.y,point.z,1.0]))
			normals.append_array(PackedFloat32Array([normal.x,normal.y,normal.z,1.0]))
			if local_x < columns-1 and local_z < rows-1: indices.append_array(PackedInt32Array([index,index+1,index+columns+1,index,index+columns+1,index+columns]))
	var result: Array = []; result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = positions; result[Mesh.ARRAY_TEX_UV] = uv; result[Mesh.ARRAY_COLOR] = colors
	result[Mesh.ARRAY_CUSTOM0] = world_values; result[Mesh.ARRAY_CUSTOM1] = normals; result[Mesh.ARRAY_INDEX] = indices
	return result

static func from_arrays(values: Array) -> ArrayMesh:
	var result := ArrayMesh.new(); result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,values,[],{},MESH_FLAGS)
	return result

static func mesh(layer: Dictionary, region: Dictionary = {}, quarter: int = 0, offset: Vector3 = Vector3.ZERO) -> ArrayMesh:
	return from_arrays(arrays(layer,region,quarter,offset))

static func face_arrays(vertices: Array, paint: Array = [], normal: Vector3 = Vector3.ZERO, quarter: int = 0, offset: Vector3 = Vector3.ZERO) -> Array:
	var positions := PackedVector2Array(); var uv := PackedVector2Array(); var colors := PackedColorArray()
	var world_values := PackedFloat32Array(); var normals := PackedFloat32Array(); var indices := PackedInt32Array()
	if normal == Vector3.ZERO:
		normal = Kernel.plane_normal(vertices)
		if normal.y < 0: normal = -normal
	normal = Kernel.rotate(normal,quarter)
	for k: int in vertices.size():
		var point := Kernel.rotate(vertices[k],quarter)+offset
		positions.append(ProjectionView.project(point)); uv.append(Vector2(point.x,point.z)/TILE_UNITS)
		var weights: Array = paint[k] if paint.size() == vertices.size() else [0.0,0.0,0.0,1.0]
		colors.append(Color(weights[0],weights[1],weights[2],weights[3]))
		world_values.append_array(PackedFloat32Array([point.x,point.y,point.z,1.0]))
		normals.append_array(PackedFloat32Array([normal.x,normal.y,normal.z,1.0]))
		if k >= 2: indices.append_array(PackedInt32Array([0,k-1,k]))
	var result: Array = []; result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = positions; result[Mesh.ARRAY_TEX_UV] = uv; result[Mesh.ARRAY_COLOR] = colors
	result[Mesh.ARRAY_CUSTOM0] = world_values; result[Mesh.ARRAY_CUSTOM1] = normals; result[Mesh.ARRAY_INDEX] = indices
	return result
