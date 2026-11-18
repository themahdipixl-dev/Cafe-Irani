shader_type spatial;
render_mode cull_disabled;
// Shared material for every flat-colored cafe mesh (glb material `Cafe_Flat`).
// Vertex data baked into cafe_final.glb:
//   COLOR_0      = albedo (linear rgb)
//   TEXCOORD_0   = (roughness, metallic)
//   TEXCOORD_1.u = emission palette index / 32 (index 0 = no emission)
// The palette comes from cafe_emission_palette.json (set by CafeMaterials).

uniform vec3 emission_palette[32];
uniform float emission_energy = 1.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = clamp(UV.x, 0.0, 1.0);
	METALLIC = clamp(UV.y, 0.0, 1.0);
	int idx = clamp(int(floor(UV2.x * 32.0 + 0.5)), 0, 31);
	if (idx > 0) {
		EMISSION = emission_palette[idx] * emission_energy;
	}
}
