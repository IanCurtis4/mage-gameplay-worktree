extends SceneTree
const Fixture = preload("res://tests/map_editor_population_test.gd")
const Map = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	print("REPRO closest_point_roundoff "+str(Geometry2D.get_closest_point_to_segment(Vector2(400,188),Vector2(400,0),Vector2(400,400)).distance_to(Vector2(400,188))))
	var source := Fixture.fixture(); var map: Dictionary = source.map[0]; var replacements := {}
	for piece: Dictionary in map.pieces:
		var old: String = piece.piece_hash
		for port: Dictionary in piece.source.connectors: port.width = 24
		piece.piece_hash = Schema.semantic_hash(piece.source); replacements[old] = piece.piece_hash
	for instance: Dictionary in map.instances: instance.piece_hash = replacements[instance.piece_hash]
	var built := Map.compile(map)
	print("REPRO compile "+str(built.ok))
	if not built.ok: print(built); quit(1); return
	var p: Dictionary = built.package
	print("REPRO package "+str(Map.validate_package(p))+" logical "+str(Map._logical_metadata_valid(p))+" terrain "+str(Map._terrain_metadata_valid(p)))
	var file := FileAccess.open("res://.godot/cliff_map_repro.var",FileAccess.WRITE); file.store_var(p); file.close()
	var parts := {}
	for part: Dictionary in p.manifest.input.parts: parts[part.part_id] = part
	for render: Dictionary in p.render_instances:
		var local := render.duplicate(true)
		for instance: Dictionary in p.manifest.stages[0].part_instances:
			if instance.instance_id == render.instance_id: local["part"] = parts[instance.part_id]
		local["render_layers"] = render.layers
		for boundary: Dictionary in local.boundaries:
			for endpoint: Dictionary in local.part.connectors:
				if endpoint.connector_id not in boundary.openings: continue
				var a := Vector2(boundary.a.x,boundary.a.z); var b := Vector2(boundary.b.x,boundary.b.z)
				var c := Vector2(endpoint.position.x,endpoint.position.z); var t := Vector2(-endpoint.outward.z,endpoint.outward.x)*float(endpoint.width)*0.5
				print("REPRO opening "+str(Terrain._opening_fits(endpoint,boundary))+" bounds "+str([a,b])+" ends "+str([c-t,c+t])+" errors "+str([Geometry2D.get_closest_point_to_segment(c-t,a,b).distance_to(c-t),Geometry2D.get_closest_point_to_segment(c+t,a,b).distance_to(c+t)]))
		print("REPRO local "+render.instance_id+" geometry "+str(Terrain._geometry_metadata_valid(local))+" ports "+str(Terrain._ports_metadata_valid(local)))
	quit()
