// For the game's ground shader, so the ground and the grass meet without a seam. Include it with
//   #include "res://addons/grass_kit/field/grass_ground.gdshaderinc"
// GrassKit's far grass fades to a colour between the ground's and the grass's; this gives the
// ground that same colour where the drawn grass ends and beyond it, so the edge never shows. The
// wind's gusts can cross the ground too, as pale bands. The values are global uniforms a
// GrassField3D writes every frame.

#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"

// x, y: the field's centre (x, z). z: its radius. w: where its blades start fading to the colour.
global uniform vec4 grasskit_field;
// rgb: the colour the grass reads as from afar (linear). a: how much of it the far grass keeps
// (GrassLook.far_grass).
global uniform vec4 grasskit_grass;

// The ground's colour `ground_rgb` at `xz`, where grass grows by `grass_here` (0..1, from the
// game's own map): towards the colour the far grass fades to, from where the blades start fading.
vec3 grasskit_ground_color(vec3 ground_rgb, vec2 xz, float grass_here) {
	float d = distance(xz, grasskit_field.xy);
	float far = smoothstep(grasskit_field.w, grasskit_field.z, d);
	vec3 meet = mix(ground_rgb, grasskit_grass.rgb, grasskit_grass.a);
	return mix(ground_rgb, meet, far * clamp(grass_here, 0.0, 1.0));
}

// Pale bands where the wind's gusts cross the ground (bigger than on the grass, as from afar):
// multiply the ground's colour by 1.0 + this.
float grasskit_ground_bands(vec2 xz, float amount) {
	return grasskit_wind_gust(xz * 0.5) * grasskit_wind.z * amount;
}
