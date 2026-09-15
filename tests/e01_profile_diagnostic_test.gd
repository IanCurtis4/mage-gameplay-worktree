extends SceneTree

var failures := 0
var checks := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e01_profile_diagnostic")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	var scene: PackedScene = load("res://scenes/diagnostics/e01_profile_diagnostic.tscn")
	var diagnostic := scene.instantiate() as E01ProfileDiagnostic
	diagnostic.set_profile_directory(root_directory.path_join("isolated_profile"))
	root.add_child(diagnostic)
	await process_frame
	_check(diagnostic.profile_directory != "user://e01_manual_test" and diagnostic.status_label.text.contains("save normal não é usado"), "test injects an isolated directory before ready and diagnostic labels the save boundary")
	var swordsman: Dictionary = diagnostic.create_swordsman()
	var mage: Dictionary = diagnostic.create_mage()
	var select_swordsman: Dictionary = diagnostic.select_alt(&"swordsman")
	_check(swordsman["ok"] and mage["ok"] and select_swordsman["ok"] and diagnostic.profile_label.text.contains("XP base") and diagnostic.profile_label.text.contains("Alt Mago"), "two alts can be created, selected, and displayed with persistent XP")
	var started: Dictionary = diagnostic.start_simulation()
	var runtime: RunState = diagnostic.active_run
	diagnostic.apply_test_augment()
	var viewport := get_root().get_viewport().get_visible_rect()
	var buttons_fit := true
	for button: Button in [diagnostic.create_swordsman_button, diagnostic.create_mage_button, diagnostic.select_swordsman_button, diagnostic.select_mage_button, diagnostic.start_run_button, diagnostic.reward_button, diagnostic.retry_reward_button, diagnostic.augment_button, diagnostic.victory_button, diagnostic.death_button, diagnostic.abandon_button]:
		buttons_fit = buttons_fit and viewport.encloses(button.get_global_rect())
	_check(started["ok"] and runtime != null and runtime.augment_stacks.get(&"vitality", 0) == 1 and diagnostic.run_label.text.contains("SIMULAÇÃO DE TESTE") and buttons_fit, "simulation starts from facade snapshot, runtime augment is isolated, and controls fit the 1280x720 viewport")
	var reward: Dictionary = diagnostic.grant_simulation_reward()
	var retry: Dictionary = diagnostic.retry_last_reward_literal()
	var profile: ProfileState = diagnostic.facade.current_profile()
	var character: CharacterState = profile.character_by_id(swordsman["character_id"])
	_check(reward["ok"] and retry["ok"] and retry["already_applied"] and character.base_xp_total == 100 and character.job_xp_total == 80, "literal reward retry preserves request context and cannot duplicate XP")
	var ended: Dictionary = diagnostic.end_simulation(&"completed")
	var mage_selected: Dictionary = diagnostic.select_alt(&"mage")
	var second_started: Dictionary = diagnostic.start_simulation()
	_check(ended["ok"] and mage_selected["ok"] and second_started["ok"] and diagnostic.active_run.augment_stacks.is_empty(), "ending and starting another alt produces a fresh runtime without leaked augments")
	_check(diagnostic.create_swordsman_button.disabled and diagnostic.create_mage_button.disabled and diagnostic.retry_reward_button != null and diagnostic.log_label.get_parsed_text().contains("no-op confirmado"), "main diagnostic controls prevent duplicate alts and show the confirmed no-op")
	diagnostic.queue_free()
	await process_frame
	var reopened := scene.instantiate() as E01ProfileDiagnostic
	reopened.set_profile_directory(root_directory.path_join("isolated_profile"))
	root.add_child(reopened)
	await process_frame
	_check(reopened.facade.current_profile().reward_session == null and reopened.log_label.get_parsed_text().contains("sessão abandonada fechada na reabertura") and reopened.log_label.get_parsed_text().contains(second_started["run_id"]), "reopening the same profile visibly closes the real abandoned session without resuming it")
	reopened.queue_free()
	_cleanup_directory(root_directory)
	print("Diagnóstico E01.3-C: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _cleanup_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	for child: String in directory.get_directories():
		_cleanup_directory(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
