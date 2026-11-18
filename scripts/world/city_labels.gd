class_name CityLabels
extends Node
## Persian shop-sign labels for the city chunks.
##
## city_chunks_2x2.glb holds no text, only empty `TextAnchor_sign_NNN` nodes (27 of them).
## The sign texts come from tehran_text_anchors_v5.json (matched by `anchor_object`).
## Every Label3D costs one draw call, so the labels are built once and are visible only while
## the camera is zoomed in (orthographic size <= show_below_size). At the default zoom (36)
## they add 0 draw calls.

@export_file("*.json") var json_path := "res://assets/cafe/tehran_text_anchors_v5.json"
## Labels are visible only while the camera's orthographic size is at or below this (meters).
@export var show_below_size := 16.0
## Extra size (m) before labels hide again, so they don't flicker around the threshold.
@export var hide_margin := 1.5
## Keep the labels visible at every zoom (for testing).
@export var always_visible := false
## AppFonts key of the font used for the signs.
@export var font_key := "bold"
## Font size in px of the label texture. Only affects sharpness, not the world size.
@export var font_px := 48
## How much of the sign board the text may fill (0..1).
@export_range(0.2, 1.0) var fill_ratio := 0.85
@export var text_color := Color(1, 1, 1)

var _labels: Array[Label3D] = []
var _shown := false


func _ready() -> void:
	set_process(false)


## Creates a Label3D under every `TextAnchor_*` node found below [param root].
## The anchors already carry the sign position and rotation (text faces the anchor's +Z).
func build(root: Node3D) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(data) != TYPE_DICTIONARY or not (data as Dictionary).has("signs"):
		push_warning("CityLabels: cannot read %s" % json_path)
		return
	var font: Font = AppFonts.get_font(font_key)
	var measure: Font = font if font != null else ThemeDB.fallback_font
	var signs: Array = (data as Dictionary)["signs"]
	for item in signs:
		var sign_data: Dictionary = item
		var anchor := root.find_child(String(sign_data["anchor_object"]), true, false) as Node3D
		if anchor == null:
			continue  # this sign was dropped from the chunk glb
		var text := String(sign_data["text_fa"])
		var label := Label3D.new()
		label.name = "Label_%s" % String(sign_data["id"])
		label.text = text
		if font != null:
			label.font = font
		label.font_size = font_px
		label.language = "fa"
		label.modulate = text_color
		label.outline_size = 0  # an outline would be a second draw call
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD  # single pass, no transparency sorting
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Fit the text inside the sign board.
		var text_size := measure.get_multiline_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
		var by_width := float(sign_data["sign_width"]) * fill_ratio / maxf(text_size.x, 1.0)
		var by_height := float(sign_data["sign_height"]) * fill_ratio / maxf(text_size.y, 1.0)
		label.pixel_size = minf(by_width, by_height)
		label.visible = always_visible
		anchor.add_child(label)
		_labels.append(label)
	_shown = always_visible
	set_process(not _labels.is_empty() and not always_visible)
	print("CityLabels: %d labels created" % _labels.size())


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return
	var limit := show_below_size + (hide_margin if _shown else 0.0)
	var want := cam.size <= limit
	if want == _shown:
		return
	_shown = want
	for label in _labels:
		label.visible = want
