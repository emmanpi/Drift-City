shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Toute la ville tient dans 5 atlas de 4096×4096. Chaque sommet porte dans
// UV2.x l'indice de sa cellule (0..63) ; la table des cellules donne le
// rectangle occupé par la texture dans la page.
//
// Les UV d'origine sont répétés (valeurs de -168 à +120), d'où le fract()
// par cellule : la texture se répète donc à l'intérieur de sa cellule comme
// avec un sampler en mode repeat. textureGrad garde les mipmaps corrects au
// passage des raccords.

uniform sampler2D atlas_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 cells[64];
uniform float roughness_value = 1.0;
uniform float specular_value = 0.5;

varying vec2 cell_offset;
varying vec2 cell_scale;

void vertex() {
	vec4 cell = cells[int(UV2.x + 0.5)];
	cell_offset = cell.xy;
	cell_scale = cell.zw;
}

void fragment() {
	vec2 tiled = cell_offset + fract(UV) * cell_scale;
	vec2 raw = cell_offset + UV * cell_scale;
	ALBEDO = textureGrad(atlas_tex, tiled, dFdx(raw), dFdy(raw)).rgb;
	METALLIC = 0.0;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
}
