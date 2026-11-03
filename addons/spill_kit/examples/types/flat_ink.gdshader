// A flat look of a game's own, for the examples' ink: no light, the colour in a few bands of the
// texture's shade, cut by its alpha. SpillKit gives each surface a copy and writes its texture into
// albedo_texture and the type's colour into albedo_color (SpillType.texture_parameter and
// color_parameter). The drops' copy has billboard on: a particle faces the camera.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
uniform vec4 albedo_color : source_color = vec4(1.0);
// Pixels with less alpha are cut.
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
// How many shades the texture's light and dark come down to.
uniform float bands : hint_range(1.0, 8.0, 1.0) = 3.0;
// On for the drops: each particle faces the camera, at its own size.
uniform bool billboard = false;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
				vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
				vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
				vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
				vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	float shade = (floor(texel.r * bands) + 1.0) / (bands + 1.0);
	// A mark's shade comes in COLOR; a drop's COLOR is the type's colour, already in albedo_color.
	vec3 tint = billboard ? vec3(1.0) : COLOR.rgb;
	ALBEDO = albedo_color.rgb * tint * shade;
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
}
