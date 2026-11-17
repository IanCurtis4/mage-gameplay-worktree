class_name ActorCastBar
extends RefCounted
## E12 H3: thin cast bar drawn over any CombatActor (player, enemy, future ally), right
## below the HP bar. Same fill ratio and colors as CastBar (HudPalette). Presentation
## only: it reads the dictionary it is given and draws; no rule, clock or state.

const HEIGHT := 3.0
const LABEL_SIZE := 10

## `canvas` is the actor (called from its _draw); `top_y` is the local y where the bar
## starts (for example overhead_bar_y() + 6 + margin); `width` is the bar width.
## `flash` is &"cancel" or &"release": during the flash the caller passes the last
## active progress; with no valid progress the flash draws a full bar in its color.
## Malformed or inactive progress without a flash draws nothing.
static func draw_overhead(canvas: CanvasItem, progress: Variant, top_y: float, width: float, flash: StringName = &"", show_label: bool = false) -> void:
	if canvas == null: return
	var plan := plan_overhead(progress, top_y, width, flash, show_label)
	if plan.is_empty(): return
	var back: Rect2 = plan["back"]
	canvas.draw_rect(back, HudPalette.CAST_BACK)
	canvas.draw_rect(plan["fill"], plan["color"])
	var label: String = plan["label"]
	if label != "":
		var font := ThemeDB.fallback_font
		var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
		var pos := Vector2(back.position.x + (back.size.x - text_width) * 0.5, back.end.y + LABEL_SIZE + 1.0)
		canvas.draw_string_outline(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, 3, HudPalette.TEXT_OUTLINE)
		canvas.draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, HudPalette.TEXT)

## Pure geometry of the bar (also used by tests). Empty when nothing is to be drawn.
static func plan_overhead(progress: Variant, top_y: float, width: float, flash: Variant = &"", show_label: bool = false) -> Dictionary:
	if not is_finite(top_y) or not is_finite(width) or width <= 0.0: return {}
	var read := HudPalette.read_cast(progress)
	var flashing := HudPalette.is_flash_kind(flash)
	if read.is_empty() and not flashing: return {}
	var ratio := 1.0 if read.is_empty() else float(read["ratio"])
	if flashing and flash == &"release": ratio = 1.0
	var back := Rect2(-width * 0.5, top_y, width, HEIGHT)
	var label := String(read.get("label", "")) if show_label and not read.is_empty() else ""
	return {
		"back": back,
		"fill": Rect2(back.position, Vector2(width * ratio, HEIGHT)),
		"color": HudPalette.flash_color(flash if flashing else &""),
		"ratio": ratio,
		"label": label,
	}
