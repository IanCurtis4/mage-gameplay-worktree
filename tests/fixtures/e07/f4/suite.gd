extends SceneTree
const F = preload("res://tests/e06_tx_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _run() -> void: pass
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func make(label: String) -> Dictionary:
	var fixture := F.make(self,"f4_"+label)
	var host: RunController = fixture["controller"]
	fixture["facade"]._reward_resolver = ProfileRewardResolver.new({&"fixture_reward":{"base_xp":100,"job_xp":80,"equipment_ids":[&"traveler_charm"]}})
	disable(host)
	host.encounter_active = false
	host.rng.seed = 20261021
	host.player.attack_cooldown = 0.375
	host.player.health._hp_deficit = 3.25
	host.player._sp_deficit = 2.75
	paused = true
	var barrier := SnapshotTickBarrier.new()
	check(barrier.acquire(host)["ok"],"fixture at a coherent frozen tick")
	fixture["barrier"] = barrier
	fixture["service"] = ExpeditionService.new(fixture["facade"])
	return fixture
func disable(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child: Node in node.get_children(): disable(child)
func cut(f: Dictionary, request: String, suspend: bool = false) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result: Dictionary = f["service"].checkpoint(f["controller"],f["barrier"],"fixture_expedition",&"fixture_phase",request,f["facade"].current_profile().revision,suspend)
	if result.get("ok",false):
		var slot: ExpeditionAssetLock = f["facade"].current_profile().expeditions["fixture_expedition"]
		print("F4_METRIC "+JSON.stringify({"request":request,"elapsed_usec":Time.get_ticks_usec()-started,"snapshot_bytes":slot.checkpoint["byte_count"],"base64_bytes":slot.checkpoint["snapshot"].length(),"profile_bytes":F.disk(f).to_utf8_buffer().size()}))
	return result
func dispose(f: Dictionary) -> void:
	f["barrier"].release()
	f["controller"].free()
	paused = false
func write(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE); file.store_string(text); file.close()
func finish() -> void:
	print("E07 F4 %s: %d checks, %d failures" % [get_script().resource_path.get_file(),checks,failures])
	quit(1 if failures else 0)
