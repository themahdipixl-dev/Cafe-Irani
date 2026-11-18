class_name CafeMaterials
extends RefCounted
## Swaps the glb's `Cafe_Flat` and `Cafe_Glass` materials for shared ShaderMaterials.
##
## cafe_final.glb stores material data in vertices (see cafe_flat.gdshader), which Godot's
## importer does not understand. Every surface that uses one of those two materials gets a
## surface override, so the whole cafe renders with 2 shared materials. The glb is not modified.

const FLAT_NAME := "Cafe_Flat"
const GLASS_NAME := "Cafe_Glass"
const PALETTE_SIZE := 32


## Applies the shader materials below [param root]. Returns {flat, glass} surface counts.
static func apply(root: Node, palette_path: String, flat_shader: Shader,
		glass_shader: Shader, emission_energy: float) -> Dictionary:
	var flat_mat := ShaderMaterial.new()
	flat_mat.shader = flat_shader
	flat_mat.set_shader_parameter("emission_palette", _load_palette(palette_path))
	flat_mat.set_shader_parameter("emission_energy", emission_energy)
	var glass_mat := ShaderMaterial.new()
	glass_mat.shader = glass_shader
	var stats := {"flat": 0, "glass": 0}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null:
				continue
			if mat.resource_name == FLAT_NAME:
				mi.set_surface_override_material(s, flat_mat)
				stats.flat += 1
			elif mat.resource_name == GLASS_NAME:
				mi.set_surface_override_material(s, glass_mat)
				stats.glass += 1
	return stats


## Reads the emission palette JSON into a Vector3 array indexed by palette index.
## Loaded as a JSON resource (not FileAccess) so it also works in exported builds.
static func _load_palette(path: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	out.resize(PALETTE_SIZE)
	var res := load(path) as JSON
	if res == null or typeof(res.data) != TYPE_DICTIONARY or not (res.data as Dictionary).has("palette"):
		push_warning("CafeMaterials: cannot read %s" % path)
		return out
	for item in (res.data as Dictionary)["palette"]:
		var entry: Dictionary = item
		var idx := int(entry["index"])
		var rgb: Array = entry["rgb"]
		if idx > 0 and idx < PALETTE_SIZE:
			out[idx] = Vector3(float(rgb[0]), float(rgb[1]), float(rgb[2]))
	return out
