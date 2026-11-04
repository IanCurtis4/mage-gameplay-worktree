extends SceneTree
const Release = preload("res://scripts/map_authoring/release/map_release.gd")
const Phase = preload("res://scripts/map_authoring/release/phase_release.gd")
const PackageView = preload("res://scripts/world/map_package_view.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void: checks.append({"id":id,"ok":ok})
func run() -> void:
	var map := Release.prepare("sanctuary_woods")
	check("published_map_prepares",map.ok)
	if not map.ok: finish(); return
	var definition := {"registry_version":1,"phase_id":"presentation_test","title":"Prova visual","maps":[{"package_id":"sanctuary_woods","exit":"shrine_completion"},{"package_id":"sanctuary_woods"}]}
	var composed := Phase.compose(definition,[map,map])
	check("phase_composes",composed.ok)
	if not composed.ok: finish(); return
	var data: Dictionary = composed.manifest.to_data()
	check("every_stage_pins_original_revision",data.input.authored_presentations.size() == 2 and data.input.authored_presentations.presentation_test_1 == map.release and data.input.authored_presentations.presentation_test_2 == map.release)
	var pinned := Release.load_reference(map.release)
	check("pinned_reference_loads_without_registry_lookup",pinned.ok and pinned.package == map.package)
	var bad: Dictionary = map.release.duplicate(true); bad.path = "res://data/map_authoring/../outside.rpp"
	check("unsafe_reference_refused",not Release.load_reference(bad).ok)
	bad = map.release.duplicate(true); bad.package_hash = "0".repeat(64)
	check("changed_pin_refused",not Release.load_reference(bad).ok)
	var world := WorldGeometry.new()
	var configured := world.configure(composed.manifest,"presentation_test_1")
	check("renamed_stage_configures",configured.ok)
	var package: Dictionary = map.map_package
	var before := var_to_bytes(package)
	var view := PackageView.new(); root.add_child(view)
	var rendered := view.configure(package,world)
	check("original_package_binds_to_renamed_geometry",rendered.ok and view.geometry == world and not view.object_sprites.is_empty())
	check("presentation_does_not_rewrite_package",var_to_bytes(package) == before)
	world._stage.surfaces[0].vertices[0].y += 2.0
	var mismatch := view.configure(package,world)
	check("changed_geometry_still_refused",not mismatch.ok and mismatch.code == "renderer_world_mismatch")
	view.queue_free()
	await process_frame
	finish()
func finish() -> void:
	var ok := checks.size() == 10 and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_PHASE_PRESENTATION_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	quit(0 if ok else 1)
