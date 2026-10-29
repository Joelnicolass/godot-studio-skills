// The minimal example's floor. GrassKit's grass_ground.gdshaderinc gives it the grass's colour
// under the blades and the far grass's colour where they fade out, so the edge of the drawn grass
// never shows. A game's own ground shader includes it the same way.
shader_type spatial;

#include "res://addons/grass_kit/field/grass_ground.gdshaderinc"

uniform vec3 soil_color : source_color = vec3(0.33, 0.27, 0.18);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = grasskit_ground_color(soil_color, world_position.xz, 1.0);
	ROUGHNESS = 0.95;
}
