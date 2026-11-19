class_name KitResourcePanel
extends Control
## E12 H3: class-resource panel (next to VIDA and SP, wired by H4). Draws the `resources`
## of a ragrpg_kit_hud_v1 dictionary: pips as dots, unlimited pips as an infinity sign with
## the mode deadline, charges as diamonds with the recharge, timers as a draining bar.
## Presentation only. It does not trust the DTO: any malformed resource hides the panel.

const PANEL_WIDTH := 252.0
const ROW_HEIGHT := 22.0
const PADDING := 6.0
const LABEL_WIDTH := 112.0
const FONT_SIZE := 12
const PIP_RADIUS := 4.5
const PIP_STEP := 12.0
const TIMER_BAR := Vector2(70.0, 6.0)

var _rows: Array[Dictionary] = []
## Number of times _draw drew rows (tests and captures).
var draw_count := 0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## `{}` (or anything malformed) hides the panel; otherwise draws dto["resources"].
func set_state(dto: Variant) -> void:
	_rows = rows_for(dto)
	visible = not _rows.is_empty()
	custom_minimum_size = Vector2(PANEL_WIDTH, PADDING * 2.0 + ROW_HEIGHT * _rows.size()) if visible else Vector2.ZERO
	size = custom_minimum_size
	queue_redraw()

## What the panel draws, one dictionary per row (also used by tests). Empty when there is
## nothing valid to draw.
func plan() -> Array[Dictionary]:
	return _rows

## Defensive reading of the DTO into display rows.
static func rows_for(dto: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if typeof(dto) != TYPE_DICTIONARY: return rows
	var state: Dictionary = dto
	if state.is_empty(): return rows
	if not HudPalette.is_clean_state(state): return rows
	if not state.has("resources") or typeof(state["resources"]) != TYPE_ARRAY: return rows
	var seen: Dictionary = {}
	for entry: Variant in state["resources"]:
		var row := _row(entry)
		if row.is_empty() or seen.has(row["id"]): return [] as Array[Dictionary]
		seen[row["id"]] = true
		rows.append(row)
	return rows

static func _timer_pair(entry: Dictionary, required: bool) -> Dictionary:
	var has_remaining := entry.has("remaining")
	var has_total := entry.has("total")
	if not has_remaining and not has_total:
		return {"ok": not required}
	if not has_remaining or not has_total: return {"ok": false}
	if not HudPalette.is_number(entry["remaining"]) or not HudPalette.is_number(entry["total"]): return {"ok": false}
	var remaining := float(entry["remaining"])
	var total := float(entry["total"])
	if total <= 0.0 or remaining < 0.0 or remaining > total: return {"ok": false}
	return {"ok": true, "remaining": remaining, "total": total}

static func _row(entry: Variant) -> Dictionary:
	if typeof(entry) != TYPE_DICTIONARY: return {}
	var data: Dictionary = entry
	if typeof(data.get("id")) != TYPE_STRING_NAME: return {}
	if typeof(data.get("label")) != TYPE_STRING or String(data["label"]).is_empty(): return {}
	if typeof(data.get("kind")) != TYPE_STRING_NAME: return {}
	if data.has("element") and not HudPalette.is_known_element(data["element"]): return {}
	var kind: StringName = data["kind"]
	var row := {"id": data["id"], "kind": kind, "label": String(data["label"]), "color": HudPalette.element_color(data.get("element", &"none"))}
	if kind == &"timer":
		var timer := _timer_pair(data, true)
		if not timer["ok"] or data.has("value") or data.has("max"): return {}
		row["remaining"] = timer["remaining"]
		row["total"] = timer["total"]
		row["ratio"] = float(timer["remaining"]) / float(timer["total"])
		row["time_text"] = "%.1fs" % float(timer["remaining"])
		return row
	if kind != &"pips" and kind != &"charges": return {}
	if typeof(data.get("value")) != TYPE_INT or typeof(data.get("max")) != TYPE_INT: return {}
	var value: int = data["value"]
	var maximum: int = data["max"]
	if value < 0 or maximum < 1: return {}
	var unlimited: bool = false
	if data.has("unlimited"):
		if typeof(data["unlimited"]) != TYPE_BOOL or kind != &"pips": return {}
		unlimited = data["unlimited"]
	if value > maximum and not unlimited: return {}
	row["value"] = value
	row["max"] = maximum
	row["unlimited"] = unlimited
	var pair := _timer_pair(data, unlimited)
	if not pair["ok"]: return {}
	if pair.has("remaining"):
		row["remaining"] = pair["remaining"]
		row["total"] = pair["total"]
		row["ratio"] = float(pair["remaining"]) / float(pair["total"])
		# A charge row shows the recharge only while it is recharging.
		row["time_text"] = "%.1fs" % float(pair["remaining"]) if unlimited or value < maximum else ""
	else:
		row["time_text"] = ""
	return row

func _draw() -> void:
	if _rows.is_empty(): return
	draw_count += 1
	var font := get_theme_default_font()
	draw_rect(Rect2(Vector2.ZERO, size), HudPalette.PANEL_BACK)
	draw_rect(Rect2(Vector2.ZERO, size), HudPalette.PIP_OUTLINE, false, 1.0)
	for index: int in _rows.size():
		var row := _rows[index]
		var top := PADDING + ROW_HEIGHT * index
		var mid := top + ROW_HEIGHT * 0.5
		var baseline := mid + FONT_SIZE * 0.36
		var color: Color = row["color"]
		draw_string(font, Vector2(PADDING + 2.0, baseline), String(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH - 4.0, FONT_SIZE, HudPalette.TEXT_DIM)
		var x := PADDING + LABEL_WIDTH
		var kind: StringName = row["kind"]
		if kind == &"timer":
			_draw_bar(Rect2(x, mid - TIMER_BAR.y * 0.5, TIMER_BAR.x, TIMER_BAR.y), float(row["ratio"]), color)
			_draw_text(font, Vector2(x + TIMER_BAR.x + 6.0, baseline), String(row["time_text"]))
		elif kind == &"pips" and row["unlimited"]:
			draw_string_outline(font, Vector2(x, baseline + 2.0), "∞", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE + 6, 3, HudPalette.TEXT_OUTLINE)
			draw_string(font, Vector2(x, baseline + 2.0), "∞", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE + 6, color)
			_draw_bar(Rect2(x + 22.0, mid - TIMER_BAR.y * 0.5, TIMER_BAR.x - 18.0, TIMER_BAR.y), float(row["ratio"]), color)
			_draw_text(font, Vector2(x + 22.0 + TIMER_BAR.x - 12.0, baseline), String(row["time_text"]))
		else:
			var count: int = row["max"]
			for slot: int in count:
				var center := Vector2(x + PIP_RADIUS + slot * PIP_STEP, mid)
				var filled := slot < int(row["value"])
				if kind == &"charges":
					var diamond := PackedVector2Array([center + Vector2(0, -PIP_RADIUS - 1.0), center + Vector2(PIP_RADIUS + 1.0, 0), center + Vector2(0, PIP_RADIUS + 1.0), center + Vector2(-PIP_RADIUS - 1.0, 0)])
					draw_colored_polygon(diamond, color if filled else HudPalette.PIP_EMPTY)
					draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), HudPalette.PIP_OUTLINE, 1.0, true)
				else:
					draw_circle(center, PIP_RADIUS, color if filled else HudPalette.PIP_EMPTY)
					draw_arc(center, PIP_RADIUS, 0.0, TAU, 16, HudPalette.PIP_OUTLINE, 1.0, true)
			if String(row["time_text"]) != "":
				_draw_text(font, Vector2(x + count * PIP_STEP + 4.0, baseline), String(row["time_text"]))

func _draw_bar(rect: Rect2, ratio: float, color: Color) -> void:
	draw_rect(rect, HudPalette.PIP_EMPTY)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(ratio, 0.0, 1.0), rect.size.y)), color)
	draw_rect(rect, HudPalette.PIP_OUTLINE, false, 1.0)

func _draw_text(font: Font, position: Vector2, text: String) -> void:
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 3, HudPalette.TEXT_OUTLINE)
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, HudPalette.TEXT)
