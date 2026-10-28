extends SceneTree
## Real editor producers, shared session, and independent pre/post-state oracles.
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Metadata = preload("res://scripts/map_authoring/objects/object_schema.gd")
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
var checks: Array[Dictionary] = []
var gui_shell: Control
var ax_shell: Control
var gui_panel: Control
var ax_panel: Control
var piece: Control
var objects: Control
var terrain: Control

func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = {}) -> void:
	checks.append({"id":id,"ok":ok,"detail":detail})
	print("F9_AX_CONTENT_CHECK "+id+" "+str(ok))
	if not ok: print("F9_AX_CONTENT_DETAIL "+JSON.stringify(detail))
func frames(count: int = 2) -> void:
	for _i: int in count: await process_frame
func source() -> Dictionary: return ax_shell.session.document().to_data()
func hash_value() -> String: return ax_shell.session.document().semantic_hash()
func depth() -> int: return ax_shell.session._undo.size()
func invoke(id: String, params: Dictionary = {}) -> Dictionary:
	return objects.ax_invoke(id,params) if id.begins_with("objects/") else (terrain.ax_invoke(id,params) if id.begins_with("terrain/") else piece.ax_invoke(id,params))
func reset_pair(data: Dictionary) -> void:
	gui_shell.session.replace(data); ax_shell.session.replace(data)
func placement(id: String) -> Dictionary:
	for value: Dictionary in source().placements:
		if value.placement_id == id: return value
	return {}
func same_sources() -> bool: return gui_shell.session.document().semantic_hash() == hash_value()
func expected_count() -> int: return 28
func marker() -> String: return "F9_AX_CONTENT_RESULT"

func run() -> void:
	root.content_scale_size = Vector2i.ZERO; root.content_scale_factor = 1.0; root.size = Vector2i(1440,1000)
	Presentation.active_mode = "ux"
	gui_shell = Shell.new(); root.add_child(gui_shell)
	ax_shell = Shell.new(); root.add_child(ax_shell)
	await frames()
	piece = ax_shell.get_node("AuthoringPresentation")
	terrain = ax_shell.terrain.get_node("AuthoringPresentation")
	var data: Dictionary = TerrainPanel.sample_source(Document.empty("ax_content_fixture"))
	data.regions = [{"region_id":"protected_plot","layer_id":"lower","polygon_xz":[[20,20],[80,20],[80,80],[20,80]],"purpose":"protected"}]
	reset_pair(data)
	var rejected: Dictionary = piece.ax_invoke("piece/open_objects",{})
	check("ux_mode_refuses_agent_mutation",not rejected.ok and rejected.code == "ax_mode_required" and depth() == 0,rejected)
	piece.set_mode("ax")
	var opened: Dictionary = piece.ax_invoke("piece/open_objects",{})
	var gui_open: Dictionary = gui_shell.get_node("AuthoringPresentation").ax_invoke("piece/open_objects",{})
	await frames(3)
	ax_panel = ax_shell.objects_window.get_child(0); gui_panel = gui_shell.objects_window.get_child(0)
	objects = ax_panel.get_node("AuthoringPresentation")
	var ids: Array = []
	for command: Dictionary in objects.ax_snapshot().commands: ids.append(command.id)
	check("real_objects_window_and_semantic_commands",opened.ok and gui_open.ok and "objects/place" in ids and "objects/scatter/apply" in ids and ax_panel.session == ax_shell.session)
	var before := hash_value(); var rev: int = source().revision
	var catalog: Dictionary = invoke("objects/library/query")
	var selected: Dictionary = invoke("objects/select",{"ids":[]})
	var surface: Dictionary = invoke("objects/surface/select",{"surface_id":"lower"})
	check("catalog_and_selection_are_editor_state",catalog.ok and catalog.entries.size() >= 6 and selected.ok and surface.ok and hash_value() == before and source().revision == rev)
	var params := {"placement_id":"tree","definition_id":"oak_tree","surface_id":"lower","position_xz":[50,50],"snap":0}
	var a: Dictionary = gui_panel.apply_operation("place",params); var b: Dictionary = invoke("objects/place",params)
	check("gui_ax_place_same_identity_and_source",a.ok and b.ok and b.added_ids == ["tree"] and same_sources(),{"gui":a.get("code"),"ax":b.get("code")})
	params = {"ids":["tree"],"surface_id":"bridge","position_xz":[100,150],"snap":0}
	a = gui_panel.apply_operation("move",params); b = invoke("objects/move",params)
	check("move_settles_on_explicit_upper_surface",a.ok and b.ok and same_sources() and placement("tree").surface_id == "bridge" and placement("tree").position_xyz[1] == 40,{"ax":b.get("code")})
	params = {"placement_id":"rock","definition_id":"moss_boulder","surface_id":"plateau","position_xz":[250,50],"snap":0}
	a = gui_panel.apply_operation("place",params); b = invoke("objects/place",params)
	var translated: Dictionary = invoke("objects/translate",{"ids":["rock"],"delta_xz":[0,40],"snap":0})
	gui_panel.apply_operation("translate",{"ids":["rock"],"delta_xz":[0,40],"snap":0})
	var rotated: Dictionary = invoke("objects/rotate",{"ids":["rock"],"degrees":90})
	gui_panel.apply_operation("rotate",{"ids":["rock"],"degrees":90})
	check("translate_rotate_share_gui_producer",a.ok and b.ok and translated.ok and rotated.ok and same_sources() and placement("rock").position_xyz[2] == 90 and placement("rock").rotation_y == 90,{"translate":translated.get("code"),"rotate":rotated.get("code")})
	var copied: Dictionary = invoke("objects/duplicate",{"ids":["rock"],"delta_xz":[0,80],"snap":0})
	var duplicate_id := str(copied.get("added_ids",[""])[0]) if copied.ok else ""
	check("duplicate_returns_new_identity",copied.ok and not duplicate_id.is_empty() and duplicate_id != "rock" and not placement(duplicate_id).is_empty(),copied.get("diagnostics",{}))
	var group: Dictionary = invoke("objects/group",{"ids":["rock",duplicate_id],"group_id":"landmarks","name":"Marcos"})
	var group_lock: Dictionary = invoke("objects/group/state",{"group_id":"landmarks","locked":true,"hidden":true})
	before = hash_value(); var history := depth()
	var blocked: Dictionary = invoke("objects/rotate",{"ids":["rock"],"degrees":90})
	check("group_lock_and_hide_apply_to_members",group.ok and group_lock.ok and Metadata.state(source(),"rock").locked and Metadata.state(source(),"rock").hidden and not blocked.ok and hash_value() == before and depth() == history)
	var unlock_group: Dictionary = invoke("objects/group/state",{"group_id":"landmarks","locked":false,"hidden":false})
	var ungroup: Dictionary = invoke("objects/ungroup",{"ids":["rock",duplicate_id]})
	check("explicit_group_unlock_and_ungroup",unlock_group.ok and ungroup.ok and Metadata.state(source(),"rock").group_id == "")
	var locked: Dictionary = invoke("objects/lock",{"ids":["tree"],"value":true})
	before = hash_value(); history = depth()
	var denied: Dictionary = invoke("objects/remove",{"ids":["tree"]})
	check("individual_lock_rejects_without_partial_history",locked.ok and not denied.ok and denied.code == "object_locked" and hash_value() == before and depth() == history)
	invoke("objects/lock",{"ids":["tree"],"value":false})
	invoke("objects/hide",{"ids":["tree"],"value":true})
	var compiled: Dictionary = Terrain.compile(source())
	check("hidden_editor_object_remains_in_publication",compiled.ok and compiled.package.objects.size() == 3 and Metadata.state(source(),"tree").hidden,compiled.get("diagnostics",{}))
	history = depth(); var no_op: Dictionary = invoke("objects/lock",{"ids":["tree"],"value":false})
	var stable: bool = no_op.ok and no_op.no_op and depth() == history
	var removed: Dictionary = invoke("objects/remove",{"ids":[duplicate_id]})
	var gone: bool = placement(duplicate_id).is_empty()
	var undone: Dictionary = invoke("piece/history/undo")
	var restored: bool = not placement(duplicate_id).is_empty()
	var redone: Dictionary = invoke("piece/history/redo")
	check("no_op_and_remove_undo_redo_are_atomic",stable and removed.ok and removed.removed_ids == [duplicate_id] and gone and undone.ok and restored and redone.ok and placement(duplicate_id).is_empty())
	before = hash_value(); history = depth()
	var unknown: Dictionary = invoke("objects/place",{"definition_id":"oak_tree","surface_id":"lower","position_xz":[50,50],"unknown":true})
	var dup: Dictionary = invoke("objects/place",params)
	var bad_selection: Dictionary = invoke("objects/select",{"ids":["absent"]})
	check("unknown_fields_duplicate_ids_and_selection_are_rejected",not unknown.ok and not dup.ok and not bad_selection.ok and hash_value() == before and depth() == history)
	invoke("terrain/layer/lock",{"layer_id":"plateau","locked":true})
	before = hash_value(); history = depth()
	var transfer: Dictionary = invoke("objects/move",{"ids":["tree"],"surface_id":"lower","position_xz":[50,50]})
	check("source_layer_lock_blocks_transfer_from_special_surface",not transfer.ok and transfer.code == "object_locked" and hash_value() == before and depth() == history)
	invoke("terrain/layer/lock",{"layer_id":"plateau","locked":false})
	invoke("terrain/layer/protection",{"layer_id":"lower","region_ids":["protected_plot"]})
	before = hash_value(); history = depth()
	var protected_place: Dictionary = invoke("objects/place",{"definition_id":"woodland_shrub","surface_id":"lower","position_xz":[50,50]})
	check("region_protection_blocks_prop_footprint",not protected_place.ok and protected_place.code == "object_protected" and hash_value() == before and depth() == history)
	# Reset both branches to the same snapshot before testing context equivalence.
	reset_pair(source())
	var options: Dictionary = invoke("piece/context/options")
	var chosen: Dictionary = options.options[0].duplicate(true) if options.ok and not options.options.is_empty() else {}
	check("passive_catalog_options_use_registered_occurrences",options.ok and chosen.has_all(["species_id","category","origin_id"]))
	var rules := {"biome_ids":["forest"],"allowed_species":[chosen.get("species_id","")],"allow_rare":false}
	gui_shell.context_panel.biomes.text = "forest"; gui_shell.context_panel.set_selected(gui_shell.context_panel.species,rules.allowed_species); gui_shell.context_panel.rare.button_pressed = false
	gui_shell.context_panel.save_piece(); var rules_result: Dictionary = invoke("piece/context/rules/set",rules)
	check("context_gui_form_and_ax_share_rules_producer",rules_result.ok and same_sources() and source().context.biome_ids == ["forest"],rules_result.get("diagnostics",{}))
	chosen.erase("label"); chosen.erase("weight"); chosen.encounter_id = "guardian"; chosen.quest_id = ""
	var area := {"region_id":"arena","layer_id":"lower","min_xz":[8,8],"max_xz":[92,92],"allowed_species":[],"allow_rare":false,"reserved":[chosen]}
	a = gui_shell.context_panel.apply_operation("area/upsert",area); b = invoke("piece/context/area/upsert",area)
	check("area_and_catalog_reservation_match_between_gui_ax",a.ok and b.ok and same_sources() and source().context.areas[0].reserved == [chosen])
	before = hash_value(); history = depth()
	var bad_area: Dictionary = invoke("piece/context/area/upsert",{"region_id":"protected_plot","layer_id":"lower","min_xz":[20,20],"max_xz":[40,40],"allowed_species":[],"allow_rare":false,"reserved":[]})
	var bad_species: Dictionary = invoke("piece/context/rules/set",{"biome_ids":["forest"],"allowed_species":["absent"],"allow_rare":false})
	var bad_shape: Dictionary = area.duplicate(true); bad_shape.max_xz = [0,0]
	var inverted: Dictionary = invoke("piece/context/area/upsert",bad_shape)
	check("context_rejects_region_collision_catalog_and_inverted_rect",not bad_area.ok and not bad_species.ok and not inverted.ok and hash_value() == before and depth() == history)
	invoke("terrain/layer/protection",{"layer_id":"lower","region_ids":["arena"]})
	invoke("terrain/layer/lock",{"layer_id":"lower","locked":true})
	before = hash_value(); history = depth()
	var denied_area: Dictionary = invoke("piece/context/area/remove",{"region_id":"arena"})
	var denied_move: Dictionary = area.duplicate(true); denied_move.layer_id = "plateau"
	var denied_area_move: Dictionary = invoke("piece/context/area/upsert",denied_move)
	check("area_source_layer_lock_prevents_remove_and_transfer",not denied_area.ok and not denied_area_move.ok and hash_value() == before and depth() == history)
	invoke("terrain/layer/lock",{"layer_id":"lower","locked":false})
	var moved_area: Dictionary = area.duplicate(true); moved_area.layer_id = "plateau"; moved_area.min_xz = [210,10]; moved_area.max_xz = [230,40]
	var moved: Dictionary = invoke("piece/context/area/upsert",moved_area)
	check("area_transfer_preserves_protection_on_new_owner",moved.ok and "arena" not in source().layers[0].protected_regions and "arena" in source().layers[2].protected_regions)
	var deleted_area: Dictionary = invoke("piece/context/area/remove",{"region_id":"arena"})
	check("area_removal_cleans_protection_references",deleted_area.ok and source().context.areas.is_empty() and source().layers[0].protected_regions.is_empty())
	var socket := {"socket_id":"entry","surface_id":"lower","position_xyz":[50,0,100],"kind":"entrance"}
	var socket_added: Dictionary = invoke("piece/socket/upsert",socket)
	before = hash_value(); history = depth()
	var off_floor: Dictionary = socket.duplicate(true); off_floor.position_xyz = [9000,0,9000]
	var invalid_socket: Dictionary = invoke("piece/socket/upsert",off_floor)
	check("socket_uses_canonical_surface_compiler",socket_added.ok and not invalid_socket.ok and hash_value() == before and depth() == history,invalid_socket)
	invoke("terrain/layer/lock",{"layer_id":"lower","locked":true})
	before = hash_value(); history = depth()
	var locked_socket: Dictionary = invoke("piece/socket/remove",{"socket_id":"entry"})
	check("socket_lock_prevents_mutation",not locked_socket.ok and hash_value() == before and depth() == history)
	invoke("terrain/layer/lock",{"layer_id":"lower","locked":false})
	var socket_deleted: Dictionary = invoke("piece/socket/remove",{"socket_id":"entry"})
	var no_socket: bool = source().sockets.is_empty()
	var undo_socket: Dictionary = invoke("piece/history/undo")
	check("socket_remove_and_undo_restore_marker",socket_deleted.ok and no_socket and undo_socket.ok and source().sockets[0].socket_id == "entry")
	invoke("piece/context/area/upsert",area)
	var rich_source: Dictionary = source()
	# Scatter preview is reviewed, hash guarded, and invalidated by source changes.
	reset_pair(flat_source())
	var scatter := {"definition_id":"woodland_shrub","surface_id":"floor","center_xz":[200,200],"radius":120,"count":8,"spacing":8,"seed_text":"41","snap":0,"exclusions":[]}
	before = hash_value(); history = depth()
	var preview: Dictionary = invoke("objects/scatter/preview",scatter)
	var preview_hash := str(preview.get("proposal_hash",""))
	var wrong_hash: Dictionary = invoke("objects/scatter/apply",{"proposal_hash":"a".repeat(64)})
	var preview_pure: bool = preview.ok and not preview_hash.is_empty() and preview.preview_objects.size() == 8 and hash_value() == before and depth() == history and not wrong_hash.ok
	var discarded: Dictionary = invoke("objects/scatter/discard")
	check("scatter_discard_restores_view_without_source_mutation",discarded.ok and hash_value() == before and depth() == history and ax_panel.pending.is_empty())
	var preview_again: Dictionary = invoke("objects/scatter/preview",scatter)
	preview_pure = preview_pure and preview_again.ok and preview_again.proposal_hash == preview_hash
	var applied: Dictionary = invoke("objects/scatter/apply",{"proposal_hash":preview_hash})
	var realized: bool = applied.ok and applied.added_ids.size() == 8 and source().placements.size() == 8
	invoke("piece/history/undo")
	var original_restored: bool = hash_value() == before
	var next_preview: Dictionary = invoke("objects/scatter/preview",scatter)
	invoke("objects/place",{"placement_id":"change","definition_id":"woodland_shrub","surface_id":"floor","position_xz":[24,24]})
	var stale: Dictionary = invoke("objects/scatter/apply",{"proposal_hash":next_preview.get("proposal_hash","")})
	check("scatter_review_hash_apply_undo_and_stale_are_guarded",preview_pure and realized and original_restored and next_preview.ok and not stale.ok and source().placements.size() == 1,{"preview":preview.get("code"),"apply":applied.get("code"),"stale":stale.get("code")})
	reset_pair(rich_source)
	var path: String = ProjectSettings.globalize_path("res://.godot/map_authoring/content_"+Crypto.new().generate_random_bytes(8).hex_encode()+".json")
	var saved: Dictionary = invoke("piece/document/save",{"path":path}); before = hash_value()
	invoke("piece/document/name",{"name":"Depois de salvar"})
	var reopened: Dictionary = invoke("piece/document/open",{"path":path,"confirm_discard":true})
	check("store_roundtrip_preserves_real_authoring_source",saved.ok and reopened.ok and hash_value() == before and Store.load_source(path).output_hash == before and source().placements.size() == 2 and source().context.areas.size() == 1 and source().sockets[0].socket_id == "entry")
	finish()

func flat_source() -> Dictionary:
	var d: Dictionary = Document.empty("scatter_content")
	d.layers = [{"layer_id":"floor","name":"Chão","origin_xz":[0,0],"columns":5,"rows":5,"sample_spacing":100,"heights":[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],"material_masks":{},"locked":false,"protected_regions":[]}]
	return d

func finish() -> void:
	Presentation.active_mode = "ux"
	var ok: bool = checks.size() == expected_count() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print(marker()+" "+JSON.stringify({"ok":ok,"count":checks.size(),"expected_count":expected_count(),"checks":checks}))
	if gui_shell != null: gui_shell.free()
	if ax_shell != null: ax_shell.free()
	quit(0 if ok else 1)
