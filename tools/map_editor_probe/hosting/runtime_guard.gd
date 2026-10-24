extends SceneTree

func _initialize() -> void:
	var clean := not Engine.is_editor_hint() and not Engine.has_meta("m0_subject") and not Engine.has_meta("m0_state")
	print("M0_RESULT " + JSON.stringify({"ok": clean, "checks": [{"name": "editor_plugins_absent_in_runtime", "ok": clean}]}))
	quit(0 if clean else 1)
