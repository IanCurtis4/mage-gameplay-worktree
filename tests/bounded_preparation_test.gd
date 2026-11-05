extends SceneTree
const Jobs = preload("res://scripts/core/bounded_preparation.gd")
const Release = preload("res://scripts/map_authoring/release/map_release.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
var checks := 0; var failures := 0
var mutex := Mutex.new()
var active := 0; var peak := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func fake(item: Dictionary) -> Dictionary:
	mutex.lock(); active += 1; peak = maxi(peak,active); mutex.unlock()
	OS.delay_msec(10 if item.id % 2 == 0 else 2)
	var answer := {"ok":item.id != 1,"id":item.id,"code":"failure_1" if item.id == 1 else ""}
	mutex.lock(); active -= 1; mutex.unlock()
	return answer
func run() -> void:
	check(Jobs.run([],fake).rows.is_empty(),"empty job does not start work")
	var items: Array = [{"id":0},{"id":1},{"id":2},{"id":3}]
	var original := var_to_bytes(items)
	var serial := Jobs.run(items,fake,1)
	check(serial.lanes == 1 and peak == 1 and active == 0,"serial path joins every item")
	peak = 0
	var parallel := Jobs.run(items,fake,99)
	check(parallel.lanes <= 2 and peak <= 2 and active == 0,"lane count is bounded and joined on failure")
	check(var_to_bytes(items) == original,"input descriptions remain unchanged")
	var same := true
	for i: int in items.size():
		same = same and parallel.rows[i].index == i and serial.rows[i].built == parallel.rows[i].built
	check(same,"results and failures retain original order despite different completion order")
	check(parallel.rows[1].built.code == "failure_1" and parallel.rows[2].built.ok,"failure remains attached to its own input")
	var loaded := Release.load_package("sanctuary_woods")
	check(loaded.ok,"pinned public loader accepts unchanged package")
	if loaded.ok:
		var public := Candidate.create("patrol",loaded.package,loaded.package.source_hash)
		var direct := Candidate._create_approved("patrol",loaded.package,loaded.package.source_hash)
		check(public.ok and public.candidate == direct.candidate,"private immediate handoff produces identical candidate")
		var external := Candidate.prepare(public.candidate)
		var prepared := Release.prepare("sanctuary_woods")
		check(external.ok and prepared.ok and external.manifest.to_data() == prepared.manifest.to_data(),"release preparation preserves complete public manifest")
		check(external.ok and prepared.ok and external.rules == prepared.rules and external.entry == prepared.entry and external.candidate_hash == prepared.candidate_hash,"rules, entry and candidate identity are unchanged")
		var altered: Dictionary = public.candidate.duplicate(true)
		altered.package.manifest.input["unreviewed"] = true
		check(not Candidate.valid(altered) and not Candidate.prepare(altered).ok,"public prepare rejects modified candidate")
		check(not Candidate.create("patrol",loaded.package,"0".repeat(64)).ok,"public create still enforces source identity")
		var listing: Dictionary = Release.registry().registry.duplicate(true)
		for entry: Dictionary in listing.packages:
			if entry.package_id == "sanctuary_woods": entry.package_hash = "0".repeat(64)
		check(not Release.prepare("sanctuary_woods",listing).ok,"release prepare refuses wrong pin before private handoff")
	print("Bounded preparation: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
