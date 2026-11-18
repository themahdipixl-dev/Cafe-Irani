shader_type spatial;
render_mode blend_mix, cull_disabled;
// Shared material for every cafe window/glass mesh (glb material `Cafe_Glass`).
// Vertex data baked into cafe_final.glb:
//   COLOR_0      = glass tint (rgb) + opacity (a)
//   TEXCOORD_0.u = roughness

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
	ROUGHNESS = clamp(UV.x, 0.0, 1.0);
	METALLIC = 0.0;
}
