class_name CafeLabels
extends Node
## Persian texts of the cafe (signs, menu boards, prices, chalkboards, posters...).
##
## cafe_v2.glb holds no text meshes, only empty anchor nodes (direct children of `Cafe_Root`)
## named after the original text objects. Each anchor sits at the center of the text's front face.
## Anchor axes: +X = text right, +Y = text normal (faces out), -Z = text up, so the Label3D is
## rotated -90 degrees around X to face along the anchor's +Y.
## Texts, sizes and colors come from cafe11_text_labels.json (matched by `node`). Names that
## Godot/Blender changed are matched too (`.` -> `_`, `+` -> `_p`, `-` -> `_n`).
## Every Label3D costs one draw call, so the labels are visible only while the camera is zoomed in
## (orthographic size <= show_below_size). At the default zoom they add 0 draw calls.

@export_file("*.json") var json_path := "res://assets/cafe/cafe11_text_labels.json"
## Labels are visible only while the camera's orthographic size is at or below this (meters).
@export var show_below_size := 16.0
## Extra size (m) before labels hide again, so they don't flicker around the threshold.
@export var hide_margin := 1.5
## Keep the labels visible at every zoom (for testing).
@export var always_visible := false
## AppFonts key of the font used for the texts.
@export var font_key := "bold"
## Font size in px of the label texture. Only affects sharpness, not the world size.
@export var font_px := 48
## Text width as a share of the original text width in the model (1 = same width).
@export_range(0.2, 1.5) var width_ratio := 1.0
## The font's line height may be at most this many times the original text height.
@export_range(1.0, 4.0) var max_line_ratio := 2.5

var _labels: Array[Label3D] = []
var _shown := false


func _ready() -> void:
	set_process(false)


## Creates a Label3D under every text anchor found below [param root] (the cafe scene root).
func build(root: Node3D) -> void:
	var res := load(json_path) as JSON  # a JSON resource, so it also works in exported builds
	if res == null or typeof(res.data) != TYPE_DICTIONARY or not (res.data as Dictionary).has("items"):
		push_warning("CafeLabels: cannot read %s" % json_path)
		return
	var font: Font = AppFonts.get_font(font_key)
	var measure: Font = font if font != null else ThemeDB.fallback_font
	var missing := 0
	for item in (res.data as Dictionary)["items"]:
		var entry: Dictionary = item
		var anchor := _find_anchor(root, String(entry["node"]))
		if anchor == null:
			missing += 1
			push_warning("CafeLabels: anchor '%s' not found in the cafe glb" % String(entry["node"]))
			continue
		var text := String(entry["text"])
		var size_m: Dictionary = entry["size_m"]
		var label := Label3D.new()
		label.name = "Label_%s" % anchor.name
		label.text = text
		if font != null:
			label.font = font
		label.font_size = font_px
		label.language = "fa"
		label.modulate = Color.html(String(entry["color_hex"]))
		label.shaded = entry.get("emission") == null  # glowing texts stay unlit
		label.outline_size = 0  # an outline would be a second draw call
		label.double_sided = false
		label.alpha_cut = Label3D.ALPHA_CUT_DISCARD  # single pass, no transparency sorting
		label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		# Fit the text to the size of the original text object.
		var text_size := measure.get_multiline_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
		var by_width := float(size_m["width"]) * width_ratio / maxf(text_size.x, 1.0)
		var by_height := float(size_m["height"]) * max_line_ratio / maxf(text_size.y, 1.0)
		label.pixel_size = minf(by_width, by_height)
		label.visible = always_visible
		anchor.add_child(label)
		_labels.append(label)
	_shown = always_visible
	set_process(not _labels.is_empty() and not always_visible)
	print("CafeLabels: %d labels created, %d anchors missing" % [_labels.size(), missing])


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


## Finds the anchor by its JSON name, then by the name the glb importer gives it.
static func _find_anchor(root: Node, node_name: String) -> Node3D:
	var found := root.find_child(node_name, true, false)
	if found == null:
		found = root.find_child(_glb_name(node_name), true, false)
	return found as Node3D


## `Gate_Text_+x` -> `Gate_Text__px`, `CardText.001` -> `CardText_001`.
static func _glb_name(node_name: String) -> String:
	return node_name.replace(".", "_").replace("+", "_p").replace("-", "_n")
