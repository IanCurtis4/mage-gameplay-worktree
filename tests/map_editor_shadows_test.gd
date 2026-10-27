extends SceneTree
const Shadow = preload("res://scripts/world/ground_shadow.gd")
const Patch = preload("res://scripts/core/expedition/spatial/world_support_patch.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const ProjectionView = preload("res://scripts/world/expedition_geometry_view.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_SHADOW_CHECK "+id+" "+str(ok))
static func cell(id: String, x0: float, x1: float, y0: float = 0.0, y1: float = 0.0) -> Dictionary:
	return {"surface_id":id,"headroom":100.0,"vertices":[Vector3(x0,y0,0),Vector3(x1,y1,0),Vector3(x1,y1,100),Vector3(x0,y0,100)]}
static func stage() -> Dictionary:
	return {"surfaces":[cell("left",0,50),cell("right",50,100)],"connectors":[{"connector_id":"a","surface_id":"left","position":Vector3(50,0,50),"outward":Vector3.RIGHT,"width":100.0,"headroom":100.0,"kind":"walk"},{"connector_id":"b","surface_id":"right","position":Vector3(50,0,50),"outward":Vector3.LEFT,"width":100.0,"headroom":100.0,"kind":"walk"}],"connections":[{"connection_id":"join","a_connector":"a","b_connector":"b","forward":true,"backward":true}]}
static func area(data: Dictionary) -> float:
	var vertices: Array = data.world_vertices; var ids: PackedInt32Array = data.arrays[Mesh.ARRAY_INDEX]; var total := 0.0
	for k: int in range(0,ids.size(),3):
		var a: Vector3 = vertices[ids[k]]; var b: Vector3 = vertices[ids[k+1]]; var c: Vector3 = vertices[ids[k+2]]
		total += absf((float(b.x)-float(a.x))*(float(c.z)-float(a.z))-(float(b.z)-float(a.z))*(float(c.x)-float(a.x)))*0.5
	return total
func run() -> void:
	var source := stage(); var snapshot := Canonical.digest(source); var index := Patch.index(source)
	var anchor := Vector3(50,0,50); var built := Shadow.mesh_data(anchor,Vector2(20,20),index,"left",ProjectionView.project)
	check("connected_receiver_mesh_builds",built.ok)
	if not built.ok: print(built); finish(); return
	check("seam_uses_both_actual_receivers",built.receivers == ["left","right"])
	check("seam_projected_footprint_area1600",absf(area(built)-1600.0) < 0.00001)
	var projection_ok := true; var uv_ok := true
	for k: int in built.world_vertices.size():
		if built.arrays[Mesh.ARRAY_VERTEX][k] != ProjectionView.project(built.world_vertices[k])-ProjectionView.project(anchor): projection_ok = false
		var uv: Vector2 = built.arrays[Mesh.ARRAY_TEX_UV][k]
		if not uv.is_finite() or uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1: uv_ok = false
	check("world_projection_applied_once",projection_ok)
	check("radial_texture_uvs_bounded",uv_ok)
	check("source_and_index_not_mutated",Canonical.digest(source) == snapshot and Canonical.encode(index) == Canonical.encode(Patch.index(source)))
	var edge := Shadow.mesh_data(Vector3(4,0,50),Vector2(20,20),index,"left",ProjectionView.project)
	check("edge_shadow_clips_to_real_ground",edge.ok and edge.world_vertices.all(func(p: Vector3) -> bool: return p.x >= 0 and p.x <= 24))
	check("edge_shadow_area960",edge.ok and absf(area(edge)-960.0) < 0.00001)
	var ramp_stage := {"surfaces":[cell("ramp",0,100,0,20),cell("lower",0,100,-100,-100)],"connectors":[],"connections":[]}
	var ramp_index := Patch.index(ramp_stage)
	var ramp := Shadow.mesh_data(Vector3(50,10,50),Vector2(20,20),ramp_index,"ramp",ProjectionView.project)
	check("ramp_receiver_preserves_real_height",ramp.ok and ramp.world_vertices.all(func(p: Vector3) -> bool: return absf(float(p.y)-float(p.x)*0.2) < 0.00001))
	check("ramp_does_not_shadow_lower_floor",ramp.ok and ramp.receivers == ["ramp"])
	check("explicit_wrong_surface_does_not_fall_to_lower_floor",Shadow.receiver(Vector3(50,10,50),ramp_index,"lower").is_empty())
	check("automatic_receiver_uses_contact_height",Shadow.receiver(Vector3(50,10,50),ramp_index) == "ramp")
	var bridge_index := Patch.index({"surfaces":[cell("bridge",0,100,160,160),cell("floor",0,100)],"connectors":[],"connections":[]})
	var bridge := Shadow.mesh_data(Vector3(50,160,50),Vector2(20,20),bridge_index,"bridge",ProjectionView.project)
	check("bridge_shadow_stays_at160",bridge.ok and bridge.world_vertices.all(func(p: Vector3) -> bool: return p.y == 160.0) and bridge.receivers == ["bridge"])
	var gap_index := Patch.index({"surfaces":[cell("left",0,40),cell("right",60,100)],"connectors":[],"connections":[]})
	var gap := Shadow.mesh_data(Vector3(40,0,50),Vector2(30,30),gap_index,"left",ProjectionView.project)
	check("real_gap_and_unlinked_neighbor_remain_unshadowed",gap.ok and gap.receivers == ["left"] and gap.world_vertices.all(func(p: Vector3) -> bool: return p.x <= 40))
	check("missing_receiver_is_explicit",Shadow.mesh_data(anchor,Vector2.ONE,index,"absent",ProjectionView.project).code == "shadow_invalid")
	check("negative_radius_rejected",not Shadow.mesh_data(anchor,Vector2(-1,2),index,"left",ProjectionView.project).ok)
	check("nan_anchor_rejected",not Shadow.mesh_data(Vector3(NAN,0,0),Vector2.ONE,index,"left",ProjectionView.project).ok)
	check("missing_projection_rejected",not Shadow.mesh_data(anchor,Vector2.ONE,index,"left",Callable()).ok)
	check("false_support_height_rejected",Shadow.mesh_data(Vector3(50,20,50),Vector2.ONE,index,"left",ProjectionView.project).code == "shadow_receiver_missing")
	check("unbounded_radius_rejected",not Shadow.mesh_data(anchor,Vector2(1024,1024),index,"left",ProjectionView.project).ok)
	var sprite := Sprite2D.new(); sprite.scale = Vector2(0.25,0.25); sprite.z_index = 1
	var attached := Shadow.attach(sprite,anchor,Vector2(20,20),index,"left",ProjectionView.project)
	check("shadow_stays_positive_at_lowest_sprite_depth",attached.ok and attached.node.z_index == 0 and attached.node.show_behind_parent and attached.node.scale == Vector2(4,4))
	sprite.free()
	finish()
func finish() -> void:
	var ok := checks.all(func(entry: Dictionary) -> bool: return entry.ok)
	print("F9_SHADOW_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
