extends SceneTree
const Tools = preload("res://scripts/map_authoring/preview/viewport_tools.gd")
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_VIEWPORT_CHECK "+id+" "+str(ok))
static func source(with_port: bool = false) -> Dictionary:
	var data := TerrainPanel.sample_source(Piece.empty("viewport_bridge"))
	if with_port: data.connectors = [{"connector_id":"west","surface_id":"lower","position_xyz":[0,0,50],"normal_xyz":[-1,0,0],"width":40,"headroom":100,"kind":"walk","tags":["map_editor"],"direction":"out"}]
	return data
static func at(world: WorldGeometry, position: Vector3) -> ExpeditionWorldPoint:
	for cell: Dictionary in world._stage.surfaces:
		if Tools.Kernel.contains(cell,position): return ExpeditionWorldPoint.create(world._stage.stage_id,cell.surface_id,position)
	return null
func run() -> void:
	var data := source(true); var before := Schema.semantic_hash(data)
	var built := Terrain.compile(data); check("real_ramp_bridge_and_port_compile",built.ok)
	if not built.ok: print(built); finish(); return
	var world := WorldGeometry.new(); world.configure(Terrain.preview_manifest(built.package),"terrain_preview")
	var upper := at(world,Vector3(50,40,150)); var lower := at(world,Vector3(50,0,150))
	check("canonical_world_point_decodes_exactly",Tools.decode_point(upper.to_data(),"terrain_preview").to_data() == upper.to_data())
	check("passive_world_point_decodes_exactly",Tools.decode_point({"surface_id":upper.surface_id,"position_xyz":[50,40,150]},"terrain_preview").to_data() == upper.to_data())
	check("foreign_stage_rejected",Tools.decode_point(upper.to_data(),"another_stage") == null)
	check("unknown_point_field_rejected",Tools.decode_point({"surface_id":upper.surface_id,"position_xyz":[50,40,150],"script":"bad"},"terrain_preview") == null)
	check("nonfinite_point_rejected",Tools.decode_point({"surface_id":upper.surface_id,"position_xyz":[NAN,40,150]},"terrain_preview") == null)
	check("boolean_coordinate_rejected",not Tools.vector_valid([true,0,0]))
	check("wrong_vector_length_rejected",not Tools.vector_valid([0,0]))
	var shape := Terrain.preview_geometry(data)
	var draft := Tools.terrain_model(data,shape,[],[],{})
	check("draft_does_not_claim_compiled_body_support",not draft.compiled)
	check("ramp_model_keeps_vertex_heights",draft.faces.any(func(face: Dictionary) -> bool: return face.source_id == "ramp" and face.vertices.any(func(p: Vector3) -> bool: return p.y == 0) and face.vertices.any(func(p: Vector3) -> bool: return p.y == 40)))
	var model := Tools.terrain_model(data,shape,[],[],built.package)
	check("compiled_model_includes_actual_supports",model.compiled and model.faces.size() == built.package.part.surfaces.size())
	check("upper_and_lower_remain_distinct",upper != null and lower != null and upper.surface_id != lower.surface_id and model.faces.any(func(face: Dictionary) -> bool: return face.source_id == "bridge"))
	var hidden := Tools.terrain_model(data,shape,[],["lower"],built.package)
	check("hidden_lower_layer_removed_from_visual_targets",not hidden.faces.any(func(face: Dictionary) -> bool: return face.source_id == "lower") and not hidden.entities.any(func(entity: Dictionary) -> bool: return entity.key == "layer/lower"))
	hidden = Tools.terrain_model(data,shape,[],["plateau"],built.package)
	check("hiding_owner_layer_hides_its_bridge",not hidden.faces.any(func(face: Dictionary) -> bool: return face.source_id in ["plateau","bridge"]))
	check("hidden_bridge_retains_physical_underside",world.position_query(lower,built.package.profile,world.geometry_revision).ok and not world.position_query(lower,{"radius":2.0,"height":40.0,"connector_kinds":["walk"]},world.geometry_revision).ok)
	check("full_width_port_not_replaced_by_center_dot",model.connectors.size() == 1 and model.connectors[0].width == 40 and model.connectors[0].outward == Vector3.LEFT)
	check("port_direction_and_headroom_preserved",model.connectors[0].direction == "out" and model.connectors[0].headroom == 100)
	var parent: Dictionary = model.entities.filter(func(entity: Dictionary) -> bool: return entity.key == "layer/plateau")[0]
	check("layer_focus_includes_attached_bridge",parent.bounds.position.x == 0 and parent.bounds.end.x == 300)
	check("source_unchanged_by_all_view_models",Schema.semantic_hash(data) == before)
	check("geometry_unchanged_by_all_view_models",world.geometry_revision == 1 and world.position_query(upper,built.package.profile,world.geometry_revision).ok)
	finish()
func finish() -> void:
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_VIEWPORT_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
