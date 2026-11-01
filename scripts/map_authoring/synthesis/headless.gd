extends SceneTree
## Checkpoint43 (F9-05/09, P3a): command line for regional synthesis, the same
## service as the terrain screen and AX.
##   godot --headless --path <projeto> --script res://scripts/map_authoring/synthesis/headless.gd -- <peça.source.json> <pedido.json> [<saída.source.json>]
## Prints MAP_SYNTHESIS_RESULT with the proposal summary (hashes, diff, metrics).
## The input piece is never written; the optional output must be a new file
## (an existing one is refused with io_conflict).
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
const Synthesis = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Section = preload("res://scripts/map_authoring/synthesis/synthesis_section.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var result := Synthesis.fail("arguments_invalid")
	if args.size() in [2,3]:
		var source := Store.load_source(args[0])
		var request: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1])) if FileAccess.file_exists(args[1]) else null
		if not source.ok: result = source
		elif not source.valid: result = Synthesis.fail("source_invalid")
		elif not request is Dictionary: result = Synthesis.fail("synthesis_request_invalid")
		else:
			var proposal := Synthesis.prepare(source.data,_numbers(request))
			result = Section.summary(proposal)
			if proposal.ok and args.size() == 3:
				var saved := Store.save_source(args[2],proposal.source,"")
				result["written"] = saved.ok
				if not saved.ok: result.ok = false; result.code = saved.code
	print("MAP_SYNTHESIS_RESULT " + JSON.stringify(result))
	quit(0 if result.get("ok",false) else 1)

# JSON numbers arrive as floats; counts in the request are integers.
static func _numbers(request: Dictionary) -> Dictionary:
	var copy := request.duplicate(true)
	var objects: Variant = copy.get("channels",{}).get("objects") if copy.get("channels") is Dictionary else null
	if objects is Dictionary and objects.get("count") is float and objects.count == floor(objects.count): objects.count = int(objects.count)
	return copy
