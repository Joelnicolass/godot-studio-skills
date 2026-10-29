// The example's ground: its colour meets the far grass (GrassKit's grass_ground.gdshaderinc), so
// the edge of the drawn grass never shows, and the wind's gusts cross it as pale bands. A game's
// ground shader does the same with its own colour.
shader_type spatial;

#include "res://addons/grass_kit/field/grass_ground.gdshaderinc"

uniform vec3 ground_color : source_color = vec3(0.26, 0.3, 0.13);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 xz = world_position.xz;
	vec3 colour = grasskit_ground_color(ground_color, xz, 1.0);
	ALBEDO = colour * (1.0 + grasskit_ground_bands(xz, 0.12));
	ROUGHNESS = 0.95;
}
