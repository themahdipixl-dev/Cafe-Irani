class_name InstanceBatcher
extends RefCounted
## Turns repeated meshes into MultiMeshInstance3D nodes (one draw call per group).
##
## The glb importer shares one Mesh resource between all nodes that use the same model
## (trees, lamp posts, benches, rooftop props, cafe chairs...). Every group of nodes that
## share a Mesh is replaced by a single MultiMeshInstance3D that draws the same mesh at the
## same transforms. Nothing is built in code: the models and their positions come from the glb.
##
## Skipped (left untouched): nodes under an excluded name prefix (cars), nodes with children,
## a script, a skin, material overrides, hidden nodes and mirrored (negative scale) nodes.


## Batches every eligible MeshInstance3D under `root`. Returns {"batches": int, "removed": int}.
## `chunk_size` (meters) splits a group into grid cells so culling still works; 0 = no split.
static func batch(root: Node3D, exclude_prefixes: PackedStringArray = [],
		min_instances: int = 2, chunk_size: float = 40.0) -> Dictionary:
	var groups := {}
	var inv := root.global_transform.affine_inverse()
	_collect(root, root, exclude_prefixes, chunk_size, inv, groups)

	var batches := 0
	var removed := 0
	for key in groups:
		var items: Array = groups[key]
		if items.size() < min_instances:
			continue
		var first: MeshInstance3D = items[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = first.mesh
		mm.instance_count = items.size()
		for i in range(items.size()):
			var item: MeshInstance3D = items[i]
			mm.set_instance_transform(i, inv * item.global_transform)
		var holder := MultiMeshInstance3D.new()
		holder.name = "Batch_%s" % first.name
		holder.multimesh = mm
		holder.cast_shadow = first.cast_shadow
		holder.layers = first.layers
		root.add_child(holder)
		for item in items:
			item.queue_free()
		batches += 1
		removed += items.size()
	return {"batches": batches, "removed": removed}


static func _collect(node: Node, root: Node3D, exclude_prefixes: PackedStringArray,
		chunk_size: float, inv: Transform3D, groups: Dictionary) -> void:
	for child in node.get_children():
		var skip := false
		for prefix in exclude_prefixes:
			if String(child.name).begins_with(prefix):
				skip = true
				break
		if skip:
			continue
		var mi := child as MeshInstance3D
		if mi != null and _is_batchable(mi):
			var pos := (inv * mi.global_transform).origin
			var cell := Vector2i.ZERO
			if chunk_size > 0.0:
				cell = Vector2i(floori(pos.x / chunk_size), floori(pos.z / chunk_size))
			var key := "%d|%d|%d|%d|%d" % [mi.mesh.get_instance_id(), cell.x, cell.y,
					mi.cast_shadow, mi.layers]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(mi)
		_collect(child, root, exclude_prefixes, chunk_size, inv, groups)


static func _is_batchable(mi: MeshInstance3D) -> bool:
	if mi.mesh == null or not mi.visible or mi.get_child_count() > 0:
		return false
	if mi.get_script() != null or mi.skin != null or mi.material_override != null:
		return false
	for i in range(mi.get_surface_override_material_count()):
		if mi.get_surface_override_material(i) != null:
			return false
	# Mirrored nodes would render inside-out in a MultiMesh, so they stay as normal nodes.
	return mi.global_transform.basis.determinant() > 0.0
