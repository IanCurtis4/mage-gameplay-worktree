extends SceneTree
## Former boundary reproducer, now verifies the authorized detached projection.
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var f := F.make("f7_migration_boundary")
	var source := F.legacy(f["facade"].current_profile())
	var directory: String = f["directory"].path_join("legacy_only")
	var primary := directory.path_join(ProfileStore.PRIMARY_FILE)
	F.write(primary, source)
	var facade := ProfileFacade.new(ProfileStore.new(directory))
	var opened := facade.open_profile()
	var preview := facade.preview_asset_migration()
	assert(opened.get("error_code") == &"migration_required" and preview.get("ok", false))
	assert(FileAccess.get_file_as_string(primary) == source)
	assert(facade.current_profile() == null)
	print("F7 migration boundary: open keys=%s; preview keys=%s; plan keys=%s" % [opened.keys(), preview.keys(), preview["plan"].keys()])
	print("F7 migration boundary: source unchanged=true; current_profile=null; legacy characters exposed=%s" % opened.has("legacy_profile"))
	var plan: Dictionary = preview["plan"]
	assert(plan["characters"].size() == 2 and plan["characters"][0]["display_name"] == "Primeira")
	assert(plan["destinations"].is_empty() and not preview["complete"])
	var panel := AssetMigrationPanel.new()
	root.add_child(panel)
	panel.configure(facade)
	assert((panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.a == 1.0, "migration modal hides underlying preparation text")
	assert(panel.confirm().get("error_code") == &"confirmation_required")
	for asset: Dictionary in plan["assets"]:
		if asset["host_id"].is_empty(): panel.choose(asset["instance_id"], plan["characters"][0]["character_id"])
	assert(panel.preview["complete"] and not panel.preview["plan"]["removals"].is_empty())
	assert(not panel.confirm_check.button_pressed and panel.confirm_button.disabled)
	assert("Primeira" in panel.report.text and "Segunda" in panel.report.text and panel.preview["plan_digest"] in panel.report.text)
	var forged: Dictionary = panel.preview["plan"].duplicate(true)
	forged["characters"][0]["display_name"] = "Alterado"
	assert(MigrationPlan.validate(forged, source).get("error_code") == &"invalid_migration_plan")
	assert(facade.preview_asset_migration()["plan"]["characters"][0]["display_name"] == "Primeira")
	assert(FileAccess.get_file_as_string(primary) == source)
	panel.confirm_check.button_pressed = true
	if "--capture-f7" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		await process_frame
		await RenderingServer.frame_post_draw
		var directory_path := "res://.godot/verification/e07_f7/native"
		DirAccess.make_dir_recursive_absolute(directory_path)
		assert(root.get_texture().get_image().save_png(directory_path.path_join("migration.png")) == OK)
	var applied := panel.confirm()
	assert(applied["ok"] and facade.current_profile() != null)
	assert(FileAccess.get_file_as_string(directory.path_join("profile.ownership.%s.json" % source.sha256_text())) == source)
	assert(ProfileFacade.new(ProfileStore.new(directory)).open_profile()["ok"])
	panel.free()
	print("E07 F7 migration: PASS (16 assertions; opaque modal/original missing-roster boundary resolved)")
	quit(0)
