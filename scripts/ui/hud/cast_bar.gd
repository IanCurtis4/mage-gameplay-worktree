class_name CastBar
extends Control
## E12 H3: player cast bar for the HUD (centered above the action bar by H4). Shows the
## skill name, the remaining time (%.1fs) and a fill of 1 - remaining / total. Presentation
## only: it receives CombatActor.cast_progress() dictionaries and draws.
## flash(&"cancel" | &"release") keeps the last bar on screen for FLASH_SECONDS in the
## flash color, because the cast reading is already inactive at that moment.

const BAR_SIZE := Vector2(360.0, 20.0)
const FONT_SIZE := 13

var _read: Dictionary = {}
var _last_read: Dictionary = {}
var _flash_kind: StringName = &""
var _flash_time := 0.0
## Number of times _draw drew a bar (tests and captures).
var draw_count := 0

func _init() -> void:
	custom_minimum_size = BAR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	visible = false

## `{"active": false}`, or anything malformed, hides the bar (unless a flash is running).
func set_progress(progress: Variant) -> void:
	_read = HudPalette.read_cast(progress)
	if not _read.is_empty():
		_last_read = _read
	_refresh()

func flash(kind: StringName) -> void:
	if not HudPalette.is_flash_kind(kind) or _last_read.is_empty(): return
	_flash_kind = kind
	_flash_time = HudPalette.FLASH_SECONDS
	set_process(true)
	_refresh()

func is_flashing() -> bool:
	return _flash_time > 0.0

## What the bar shows now: {} (hidden), or {"label", "time_text", "ratio", "color"}.
func plan() -> Dictionary:
	var source := _read
	if source.is_empty() and _flash_time > 0.0:
		source = _last_read
	if source.is_empty(): return {}
	var ratio := float(source["ratio"])
	if _flash_time > 0.0 and _flash_kind == &"release": ratio = 1.0
	return {
		"label": String(source["label"]),
		"time_text": "%.1fs" % float(source["remaining"]),
		"ratio": ratio,
		"color": HudPalette.flash_color(_flash_kind if _flash_time > 0.0 else &""),
	}

func _process(delta: float) -> void:
	_flash_time = maxf(0.0, _flash_time - delta)
	if _flash_time <= 0.0:
		_flash_kind = &""
		set_process(false)
	_refresh()

func _refresh() -> void:
	visible = not plan().is_empty()
	queue_redraw()

func _draw() -> void:
	var data := plan()
	if data.is_empty(): return
	draw_count += 1
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, HudPalette.CAST_BACK)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * float(data["ratio"]), rect.size.y)), data["color"])
	draw_rect(rect, HudPalette.PIP_OUTLINE, false, 1.0)
	var font := get_theme_default_font()
	var baseline := rect.size.y * 0.5 + FONT_SIZE * 0.36
	var label: String = data["label"]
	var time_text: String = data["time_text"]
	draw_string_outline(font, Vector2(8.0, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 70.0, FONT_SIZE, 3, HudPalette.TEXT_OUTLINE)
	draw_string(font, Vector2(8.0, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 70.0, FONT_SIZE, HudPalette.TEXT)
	draw_string_outline(font, Vector2(0.0, baseline), time_text, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 8.0, FONT_SIZE, 3, HudPalette.TEXT_OUTLINE)
	draw_string(font, Vector2(0.0, baseline), time_text, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 8.0, FONT_SIZE, HudPalette.TEXT)
