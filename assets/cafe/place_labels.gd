# Untested helper: creates a Label3D for every sign listed in cafe11_text_labels.json.
# Attach to a Node3D with identity transform (position 0, no rotation, scale 1),
# next to the imported cafe11_no_text.glb instance. Assign a Persian font (e.g. Vazirmatn).
extends Node3D

@export var json_path := "res://cafe11_text_labels.json"
@export var font: Font
@export var font_size := 64

func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	for item in data["items"]:
		if item["kept_in_glb"]:
			continue
		var label := Label3D.new()
		label.name = item["node"]
		label.text = item["text"]
		label.font = font
		label.font_size = font_size
		label.language = "fa"
		label.modulate = Color(item["color_hex"])
		label.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		var b = item["label3d"]["basis_columns"]
		var basis := Basis(
			Vector3(b[0][0], b[0][1], b[0][2]),
			Vector3(b[1][0], b[1][1], b[1][2]),
			Vector3(b[2][0], b[2][1], b[2][2]))
		var p = item["label3d"]["position"]
		label.transform = Transform3D(basis, Vector3(p[0], p[1], p[2]))
		# fit the text width to the original sign width
		var sz := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		label.pixel_size = item["size_m"]["width"] / sz.x
		add_child(label)
