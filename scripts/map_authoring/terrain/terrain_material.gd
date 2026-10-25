@tool
extends RefCounted
const Partition = preload("res://scripts/map_authoring/compiler/terrain_partition.gd")
const ProjectionView = preload("res://scripts/world/expedition_geometry_view.gd")
const SHADER_PATH := "res://scripts/map_authoring/terrain/terrain_material.gdshader"
const GRASS_PATH := "res://assets/art/map_authoring/grass_tile.png"
const EARTH_PATH := "res://assets/art/map_authoring/earth_tile.png"
const TILE_UNITS := 128.0

static func dependencies() -> Array:
	var result: Array = []
	for path: String in [GRASS_PATH,EARTH_PATH,SHADER_PATH,GRASS_PATH+".import",EARTH_PATH+".import"]:
		if not FileAccess.file_exists(path): return []
		result.append({"definition_id":path.get_file().replace(".","_"),"revision":1,"sha256":FileAccess.get_sha256(path),"path":path})
	return result

static func material(selected: bool = true) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load(SHADER_PATH)
	result.set_shader_parameter("grass_tile",load(GRASS_PATH))
	result.set_shader_parameter("earth_tile",load(EARTH_PATH))
	result.set_shader_parameter("layer_tint",Color.WHITE if selected else Color(0.86,0.90,0.86,1))
	return result

static func arrays(layer: Dictionary, region: Dictionary = {}) -> Array:
	var ox: int = region.get("x",0); var oz: int = region.get("z",0)
	var columns: int = int(region.get("width",int(layer.columns)-1))+1
	var rows: int = int(region.get("height",int(layer.rows)-1))+1
	var count: int = columns*rows
	var positions := PackedVector2Array(); positions.resize(count)
	var uv := PackedVector2Array(); uv.resize(count)
	var colors := PackedColorArray(); colors.resize(count)
	var indices := PackedInt32Array()
	for local_z: int in rows:
		for local_x: int in columns:
			var x := ox+local_x; var z := oz+local_z
			var index: int = local_z*columns+local_x
			var source_index: int = z*int(layer.columns)+x
			var point := Partition.point(layer,x,z)
			positions[index] = ProjectionView.project(point)
			uv[index] = Vector2(point.x,point.z)/TILE_UNITS
			var left := maxi(0,x-1); var right := mini(int(layer.columns)-1,x+1)
			var top := maxi(0,z-1); var bottom := mini(int(layer.rows)-1,z+1)
			var dx: float = (float(layer.heights[z*int(layer.columns)+right])-float(layer.heights[z*int(layer.columns)+left]))/((right-left)*float(layer.sample_spacing))
			var dz: float = (float(layer.heights[bottom*int(layer.columns)+x])-float(layer.heights[top*int(layer.columns)+x]))/((bottom-top)*float(layer.sample_spacing))
			var normal := Vector3(-dx,1,-dz).normalized()
			var shade := 0.65+0.35*maxf(0,normal.dot(Vector3(-0.3,0.8,-0.5).normalized()))
			var earth: float = layer.material_masks.earth[source_index] if layer.material_masks.has("earth") and layer.material_masks.earth.size() > source_index else 0.0
			var grass: float = layer.material_masks.grass[source_index] if layer.material_masks.has("grass") and layer.material_masks.grass.size() > source_index else 1.0
			# Derived presentation, never written into the author's paint masks.
			var slope := Vector2(dx,dz).length()
			var steep := clampf((slope-0.7)/0.3,0.0,1.0)
			colors[index] = Color(earth/maxf(0.00001,earth+grass),shade,steep,1)
			if local_x < columns-1 and local_z < rows-1:
				indices.append_array(PackedInt32Array([index,index+1,index+columns+1,index,index+columns+1,index+columns]))
	var result: Array = []; result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = positions; result[Mesh.ARRAY_TEX_UV] = uv; result[Mesh.ARRAY_COLOR] = colors; result[Mesh.ARRAY_INDEX] = indices
	return result

static func mesh(layer: Dictionary, region: Dictionary = {}) -> ArrayMesh:
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays(layer,region))
	return result
