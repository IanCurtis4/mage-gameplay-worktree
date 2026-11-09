extends "res://tools/map_editor_release/republish.gd"
## E08 P5 B2b: runs the existing republish tool through the P5 fixture wrapper, which
## prepends the evidence folder as the first user argument. Only the --file mode is
## exposed: it recompiles a released map from its committed (unchanged) source with
## the real patrol producer and writes the publication bytes to the given path, so
## nothing tracked under res://data is written inside the shared fixture.
## Usage: -- {output} --file <source.patrol.json> <file name in {output}>
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4 or args[1] != "--file": _done({"ok":false,"code":"arguments_invalid"}); return
	_file(args[2],String(args[0]).path_join(args[3]))
