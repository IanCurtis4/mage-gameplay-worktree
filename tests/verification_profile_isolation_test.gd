extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var default_menu := scene.instantiate() as CharacterMenu
	root.add_child(default_menu)
	await process_frame
	_check(DisplayServer.get_name() == "headless", "verification test runs headless")
	_check(default_menu.profile_directory == CharacterMenu.HEADLESS_PROFILE_DIRECTORY, "default headless entry redirects before opening a profile")
	_check(default_menu.facade._store._base_directory == CharacterMenu.HEADLESS_PROFILE_DIRECTORY and default_menu.facade.current_profile() != null, "headless menu opens only the ignored verification directory")
	var directory := "res://.godot/verification/explicit_menu_%d" % Time.get_ticks_usec()
	var explicit_menu := scene.instantiate() as CharacterMenu
	explicit_menu.set_profile_directory(directory)
	root.add_child(explicit_menu)
	await process_frame
	_check(explicit_menu.profile_directory == directory and explicit_menu.facade._store._base_directory == directory, "explicit fixture directory is never overridden")
	var facade_directory := directory + "_facade"
	var facade := ProfileFacade.new(ProfileStore.new(facade_directory))
	var provided_menu := scene.instantiate() as CharacterMenu
	provided_menu.set_profile_facade(facade)
	root.add_child(provided_menu)
	await process_frame
	_check(provided_menu.facade == facade and facade._store._base_directory == facade_directory and facade.current_profile() != null, "explicit fixture facade is never replaced")
	default_menu.queue_free()
	explicit_menu.queue_free()
	provided_menu.queue_free()
	await process_frame
	print("Verification profile isolation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
