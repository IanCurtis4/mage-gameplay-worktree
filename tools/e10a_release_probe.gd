extends SceneTree
## E10a T13 (C10): native standard engine mounting the EXACT exported E10a candidate PCK
## (--main-pack), isolated APPDATA. Never touches personal profiles.
## Mode (user args):
##   inspect <evidence_dir> <expected.json> <app_name>
##       the Acolyte base and the two pure kits (Priest, Cultist) ready and offered, their three
##       bodies (V2 directional), the 22 skill icons and the icon each family skill resolves, the
##       three items (definition, loot, painted icon, in-hand art through hand_rigs.json), the
##       effect entries (feedback recipes and vfx entries of every family skill), the snapshot
##       fragments and the fixtures left out of the pack.
## `expected.json` is computed by tools/e10a_package.ps1 from the candidate commit itself.
var checks: Array[Dictionary] = []
var folder := ""

func _initialize() -> void: _run.call_deferred()

func check(id: String, value: bool, detail: Variant = "") -> void:
	checks.append({"id": id, "ok": value, "detail": str(detail)})
	print("E10A_T13_CHECK ", id, " ", value, " ", str(detail).left(400))

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 or args[0] != "inspect":
		push_error("Usage: -- inspect <evidence_dir> <expected.json> <app_name>")
		quit(2)
		return
	folder = args[1]
	inspect(args[2], args[3])

func _walk(path: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(path): out.append(path.path_join(file))
	for dir: String in DirAccess.get_directories_at(path): _walk(path.path_join(dir), out)

func _texture_ok(path: String) -> bool:
	if not ResourceLoader.exists(path): return false
	var texture := load(path) as Texture2D
	return texture != null and texture.get_width() > 0 and texture.get_height() > 0

func inspect(expected_path: String, app_name: String) -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	var name: String = ProjectSettings.get_setting("application/config/name", "")
	check("app_name", name == app_name, name)
	check("isolated_user_dir", OS.get_user_data_dir().ends_with("/" + app_name), OS.get_user_data_dir())
	# The standard engine always carries the `editor` feature even with --main-pack; recorded as
	# information (`editor_feature` in the result), as the E08 release probe does.

	# 1. Identities: the Acolyte base (registered base) and exactly the two pure kits, all ready and valid.
	var kit_ids: Array = expected["kits"].keys()
	kit_ids.sort()
	var pure: Array = []
	for id: StringName in ClassKitRegistry.pure_ids(): pure.append(String(id))
	pure.sort()
	check("pure_kit_registry_ids", pure == kit_ids, pure)
	check("hybrids_still_registered", ClassKitRegistry.hybrid_ids().size() == 4, ClassKitRegistry.hybrid_ids())
	var base_validation := ClassBaseRegistry.validate(&"acolyte")
	check("acolyte_base_ready_and_valid", ClassBaseRegistry.is_base(&"acolyte") and ClassBaseRegistry.ready_for_play(&"acolyte") and base_validation.get("ok", false), base_validation)
	var ready_rows: Array = []
	for id: String in kit_ids:
		var validation := ClassKitRegistry.validate(StringName(id))
		ready_rows.append({"id": id, "ready": ClassKitRegistry.ready_for_play(StringName(id)), "valid": validation.get("ok", false), "name": ClassKitRegistry.display_name(StringName(id))})
	check("kits_ready_and_valid", ready_rows.all(func(row: Dictionary) -> bool: return row.ready and row.valid), ready_rows)
	var catalog := ProfileCatalog.pilot()
	check("acolyte_creatable", catalog.base_class_is_available(&"acolyte"), "")
	var offered: Array = []
	for evolution: EvolutionDefinition in catalog.evolution_definitions_for_origin(&"acolyte"):
		if catalog.evolution_is_ready(evolution.id, &"acolyte"): offered.append(String(evolution.id))
	offered.sort()
	var offered_ok := offered == kit_ids
	for id: String in kit_ids:
		offered_ok = offered_ok and String(ClassKitRegistry.origin(StringName(id))) == String(expected["kits"][id]["origin"])
	check("evolutions_offered_at_job_20", offered_ok, offered)
	var onboarding := 0
	for id: String in kit_ids:
		if ClassKitRegistry.onboarding_script(StringName(id)) != null: onboarding += 1
	check("onboarding_scripts", onboarding == kit_ids.size(), "%d/%d" % [onboarding, kit_ids.size()])

	# 2. Bodies: the three body folders resolve to the V2 atlas, not to a fallback.
	var body_rows: Array = []
	var body_ids: Array = expected["bodies"].keys()
	body_ids.sort()
	for id: String in body_ids:
		var body_folder := ClassBaseRegistry.body_folder(StringName(id)) if ClassBaseRegistry.is_base(StringName(id)) else ClassKitRegistry.body_folder(StringName(id))
		var manifest_path := DirectionalAnimationSet.kit_body_path(body_folder)
		var loaded := DirectionalAnimationSet.load_manifest(manifest_path) if not manifest_path.is_empty() else {}
		body_rows.append({"id": id, "folder": body_folder, "manifest": manifest_path, "loaded": loaded.get("ok", false), "error": loaded.get("error_code", "")})
	check("family_bodies_resolve", body_rows.all(func(row: Dictionary) -> bool: return row.loaded and String(row.folder) == String(row.id) and String(row.manifest) == String(expected["bodies"][row.id]["presentation"])) and body_rows.size() == 3, body_rows)
	var body_textures: Array = expected.get("body_textures", [])
	var body_textures_ok := body_textures.filter(func(path: String) -> bool: return _texture_ok(path))
	check("family_body_textures_load", body_textures_ok.size() == body_textures.size() and body_textures.size() == 3 * 2, "%d/%d" % [body_textures_ok.size(), body_textures.size()])

	# 3. Icons: the 22 SVG of T3 and the icon every family skill resolves through SkillPresentation.
	var icons: Array = expected.get("skill_icons", [])
	var icons_ok := icons.filter(func(path: String) -> bool: return _texture_ok(path))
	check("skill_icons_load", icons_ok.size() == icons.size() and icons.size() == 22, "%d/%d" % [icons_ok.size(), icons.size()])
	var identity_ids: Array = ["acolyte"]
	identity_ids.append_array(kit_ids)
	var skill_rows: Array = []
	for id: String in identity_ids:
		var ids: Array[StringName] = ClassBaseRegistry.skill_ids(StringName(id)) if id == "acolyte" else ClassKitRegistry.skill_ids(StringName(id))
		for skill_id: StringName in ids:
			var texture := SkillPresentation.icon(skill_id)
			var path := texture.resource_path if texture != null else ""
			skill_rows.append({"identity": id, "skill": skill_id, "icon": path, "ok": texture != null and path == "res://assets/art/skills/%s.svg" % skill_id})
	var skill_icons_ok := skill_rows.filter(func(row: Dictionary) -> bool: return row.ok)
	check("family_skills_resolve_own_icon", skill_icons_ok.size() == skill_rows.size() and skill_rows.size() == 22, skill_rows if skill_icons_ok.size() != skill_rows.size() else "%d/%d" % [skill_icons_ok.size(), skill_rows.size()])

	# 4. Effect entries: feedback recipe and vfx entries of every family skill.
	var recipe_rows: Array = []
	var vfx_rows: Array = []
	for id: String in identity_ids:
		var module := ClassKitRegistry.seam_module(StringName(id))
		var vfx: Dictionary = module.vfx_effects() if module != null else {}
		var ids: Array[StringName] = ClassBaseRegistry.skill_ids(StringName(id)) if id == "acolyte" else ClassKitRegistry.skill_ids(StringName(id))
		for skill_id: StringName in ids:
			var recipe := FeedbackRecipeCatalog.recipe(skill_id)
			recipe_rows.append({"skill": skill_id, "ok": not ClassKitRegistry.feedback_recipe(skill_id).is_empty() and not recipe.is_empty()})
		for effect_id: Variant in vfx:
			var entry: Dictionary = vfx[effect_id]
			var resolved := 0
			for kind: Variant in entry.get("kinds", []):
				if not ClassKitRegistry.vfx_effect(StringName(entry.get("skill_id", &"")), StringName(kind)).is_empty(): resolved += 1
			vfx_rows.append({"identity": id, "effect": effect_id, "skill": entry.get("skill_id", ""), "kinds": entry.get("kinds", []).size(), "resolved": resolved})
	var recipes_ok := recipe_rows.filter(func(row: Dictionary) -> bool: return row.ok)
	check("family_feedback_recipes", recipes_ok.size() == recipe_rows.size() and recipe_rows.size() == 22, "%d/%d" % [recipes_ok.size(), recipe_rows.size()])
	var vfx_identities := {}
	for row: Dictionary in vfx_rows: vfx_identities[row.identity] = int(vfx_identities.get(row.identity, 0)) + 1
	var vfx_ok := vfx_rows.all(func(row: Dictionary) -> bool: return row.kinds > 0 and row.resolved == row.kinds) and vfx_identities.size() >= kit_ids.size()
	check("family_vfx_entries_resolve", vfx_ok, {"per_identity": vfx_identities, "entries": vfx_rows.size()})

	# 5. Items: definition, eligibility origin, production loot, painted icon and in-hand art.
	var loaded := BuildContentLoader.load_catalog(true)
	check("content_catalog_loads", loaded.get("ok", false), loaded.get("error_code", ""))
	if loaded.get("ok", false):
		var content: BuildEffectCatalog = loaded["catalog"]
		var table := EquipmentLootProfiles.production(content)
		var item_rows: Array = []
		for item_id: String in expected["items"]:
			var row: Dictionary = expected["items"][item_id]
			var item := content.get_definition(&"equipment", StringName(item_id)) as EquipmentDefinition
			var in_loot := 0
			for category: StringName in EquipmentLootProfiles.CHANCES:
				if (table.profiles[category]["equipment_weights"] as Dictionary).has(StringName(item_id)): in_loot += 1
			var icon := EquipmentPresentation.icon(item) if item != null else null
			var painted := EquipmentPresentation.painted_icon(StringName(item_id))
			var prop := EquipmentArtCatalog.e09_prop_texture(StringName(String(row["prop"])))
			item_rows.append({"id": item_id, "defined": item != null, "resource": ResourceLoader.exists(String(row["resource"])), "loot_categories": in_loot, "icon": icon.resource_path if icon != null else "", "painted": painted != null, "prop_art": prop != null, "prop_error": EquipmentArtCatalog.error_for(String(EquipmentArtCatalog.e09_prop_profile(StringName(String(row["prop"]))).get("path", "")))})
		check("e10a_items_defined_and_in_loot", item_rows.all(func(r: Dictionary) -> bool: return r.defined and r.resource and r.loot_categories == EquipmentLootProfiles.CHANCES.size()) and item_rows.size() == 3, item_rows)
		check("e10a_items_painted_icons", item_rows.all(func(r: Dictionary) -> bool: return r.painted and not String(r.icon).is_empty()), item_rows)
		check("e10a_items_in_hand_art", item_rows.all(func(r: Dictionary) -> bool: return r.prop_art), item_rows)
		var resolver := MobLootResolver.create(content, table)
		check("production_loot_resolver_valid", resolver.get("ok", false), resolver.get("error_code", ""))

	# 6. Snapshot fragments: present, merged without error, and no fixture fragment.
	var fragments := SnapshotRegistry.fragment_paths()
	var expected_fragments: Array = expected.get("fragments", []).duplicate()
	expected_fragments.sort()
	var fragment_list: Array = []
	for path: String in fragments: fragment_list.append(path)
	fragment_list.sort()
	check("snapshot_fragments_exact", fragment_list == expected_fragments, fragment_list)
	var snapshot_registry := SnapshotRegistry.new()
	var schemas := snapshot_registry.coverage_manifest()
	var kit_kinds: Array = expected.get("fragment_kinds", [])
	var known := kit_kinds.filter(func(kind: String) -> bool: return schemas.has(kind))
	check("snapshot_fragments_merge", snapshot_registry.fragment_errors.is_empty() and known.size() == kit_kinds.size() and kit_kinds.size() > 0, {"errors": snapshot_registry.fragment_errors, "known": "%d/%d" % [known.size(), kit_kinds.size()]})

	# 7. Fixtures stay out of the pack; full listing for the record.
	var listing: Array[String] = []
	_walk("res://", listing)
	listing.sort()
	var leaked: Array = []
	for path: String in listing:
		for prefix: String in expected.get("forbidden_prefixes", []):
			if path.begins_with(prefix): leaked.append(path)
	check("fixtures_out_of_pack", leaked.is_empty() and not expected.get("forbidden_prefixes", []).is_empty(), leaked)
	var file := FileAccess.open(folder.path_join("e10a_pack_listing.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(listing, "\t") + "\n")
	file.close()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var result := {"ok": ok, "count": checks.size(), "checks": checks, "pack_entries": listing.size(), "user_data_dir": OS.get_user_data_dir(), "editor_feature": OS.has_feature("editor"), "mode": "native_standard_engine_exact_release_pack"}
	print("E10A_T13_INSPECT_RESULT ", JSON.stringify(result))
	quit(0 if ok else 1)
