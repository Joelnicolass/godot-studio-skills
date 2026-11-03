@tool
class_name SpillType
extends Resource

## One substance that spills: blood, ichor, oil, slime, ink. How its drops fly, the marks they leave
## on the floor and the puddle under a body that dies, and how the three look. A type with only a
## colour already looks wet: the kit draws its own drop, marks and puddle, with normal maps. Give a
## surface its own textures (albedo, normal, ORM) for a PBR look of yours, or its own material (your
## game's shader). Looks only: when a hit bleeds is up to SpillSource3D.

## The colour of the drops, the marks and the puddle. Its alpha is their opacity when alpha_scissor
## is 0.
@export var color := Color(0.45, 0.04, 0.04)
## 0 = a mirror (fresh, wet), 1 = matte (dry). Multiplies an ORM texture's green.
@export_range(0.0, 1.0, 0.01) var roughness := 0.15
## 0 = a liquid, 1 = a metal (mercury, molten metal). Multiplies an ORM texture's blue.
@export_range(0.0, 1.0, 0.01) var metallic := 0.0
## How bright the highlights are.
@export_range(0.0, 1.0, 0.01) var specular := 0.5
## How much the normal maps raise the surface (0 = flat).
@export_range(0.0, 4.0, 0.01, "or_greater") var normal_scale := 1.0
## Above 0, pixels with less alpha are cut: hard edges that never sort wrongly where marks overlap.
## 0 = soft edges, blended by alpha (color's alpha too).
@export_range(0.0, 1.0, 0.01) var alpha_scissor := 0.5

@export_group("Spray")
## Drops of a light hit.
@export_range(0, 128) var drops := 14
## Side of a drop.
@export_range(0.005, 1.0, 0.005, "suffix:m") var drop_size_m := 0.09
## How fast the drops leave (each one 25 % more or less).
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var drop_speed_m_s := 1.9
## How wide the spray opens around its way.
@export_range(0.0, 180.0, 0.5, "degrees") var spread_deg := 28.0
## How far above the horizon the drops leave (90 = straight up).
@export_range(-90.0, 90.0, 0.5, "degrees") var rise_deg := 51.0
## Seconds a drop flies (it falls through the floor: the marks are what it leaves).
@export_range(0.05, 5.0, 0.05, "suffix:s") var drop_life_s := 0.7
## Each drop is drop_size_m times a size between these.
@export_range(0.05, 4.0, 0.05) var drop_scale_min := 0.6
@export_range(0.05, 4.0, 0.05) var drop_scale_max := 1.4
## Its shape (alpha) and colour, multiplied by color. Null = the kit's round drop.
@export var drop_albedo_texture: Texture2D
## Null = the kit's round drop's, or none with a drop_albedo_texture of yours.
@export var drop_normal_texture: Texture2D
## Occlusion (red), roughness (green), metallic (blue). Null = roughness and metallic alone.
@export var drop_orm_texture: Texture2D
## Replaces the kit's material on the drops: your game's own shader or material. A shader may take
## each drop's colour from COLOR (the particle's, this type's colour) and declare no uniform; the
## ones it declares (texture_parameter, color_parameter) are written too.
@export var drop_material: Material

@export_group("Heavy spray")
## Drops of a heavy hit. The heavy spray is tuned on its own; its drops look like the light ones
## (the Spray group's textures and material).
@export_range(0, 256) var heavy_drops := 32
## Side of a heavy hit's drop.
@export_range(0.005, 1.0, 0.005, "suffix:m") var heavy_drop_size_m := 0.12
## How fast they leave (each one 25 % more or less).
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var heavy_drop_speed_m_s := 3.0
## How wide it opens around its way.
@export_range(0.0, 180.0, 0.5, "degrees") var heavy_spread_deg := 38.0
## How far above the horizon they leave.
@export_range(-90.0, 90.0, 0.5, "degrees") var heavy_rise_deg := 45.0
## Seconds a heavy hit's drop flies.
@export_range(0.05, 5.0, 0.05, "suffix:s") var heavy_drop_life_s := 0.85
## Each one is heavy_drop_size_m times a size between these.
@export_range(0.05, 4.0, 0.05) var heavy_drop_scale_min := 0.7
@export_range(0.05, 4.0, 0.05) var heavy_drop_scale_max := 1.6

@export_group("Marks")
## Marks a light hit leaves on the floor.
@export_range(0, 16) var marks_per_spray := 1
## Marks a heavy hit leaves on the floor.
@export_range(0, 16) var marks_per_heavy := 3
## The marks fall anywhere this far around the body.
@export_range(0.0, 5.0, 0.05, "suffix:m") var mark_radius_m := 0.6
## Smallest side of a mark.
@export_range(0.01, 4.0, 0.01, "suffix:m") var mark_min_m := 0.25
## Largest side of a mark.
@export_range(0.01, 4.0, 0.01, "suffix:m") var mark_max_m := 0.45
## Its shape (alpha) and colour, multiplied by color. Null = the kit's splat.
@export var mark_albedo_texture: Texture2D
## Null = the kit's splat's, or none with a mark_albedo_texture of yours.
@export var mark_normal_texture: Texture2D
## Occlusion (red), roughness (green), metallic (blue). Null = roughness and metallic alone.
@export var mark_orm_texture: Texture2D
## Replaces the kit's material on the marks: your game's own shader or material (see texture_parameter).
@export var mark_material: Material

@export_group("Puddle")
## Side of a puddle once grown (smaller where the floor is not flat that far).
@export_range(0.1, 10.0, 0.05, "suffix:m") var puddle_size_m := 1.6
## Seconds a puddle takes to grow.
@export_range(0.0, 60.0, 0.1, "suffix:s") var puddle_grow_s := 4.0
## Its shape (alpha) and colour, multiplied by color. Null = the kit's round puddle.
@export var puddle_albedo_texture: Texture2D
## Null = the kit's puddle's, or none with a puddle_albedo_texture of yours.
@export var puddle_normal_texture: Texture2D
## Occlusion (red), roughness (green), metallic (blue). Null = roughness and metallic alone.
@export var puddle_orm_texture: Texture2D
## Replaces the kit's material on the puddle: your game's own shader or material (see texture_parameter).
@export var puddle_material: Material

@export_group("Own material")
## On a ShaderMaterial of yours (drop_material, mark_material, puddle_material): the uniform that
## gets the surface's albedo texture (yours, the material's own, or the kit's shape). A marks' or
## puddle's shader must declare it; a drops' shader may not.
@export var texture_parameter: StringName = &"albedo_texture"
## On a ShaderMaterial of yours: the uniform that gets color. A marks' or puddle's shader must
## declare it; a drops' shader may not (its COLOR is the colour already).
@export var color_parameter: StringName = &"albedo_color"


## What is wrong with this type, as the editor warns it (empty: nothing).
func problems() -> PackedStringArray:
	var out := PackedStringArray()
	if mark_min_m > mark_max_m:
		out.append("mark_min_m is above mark_max_m: every mark is mark_max_m.")
	if drop_scale_min > drop_scale_max or heavy_drop_scale_min > heavy_drop_scale_max:
		out.append("A drop_scale_min is above its drop_scale_max: the drops come out the same size.")
	for surface: Array in [["drop_material", drop_material], ["mark_material", mark_material], ["puddle_material", puddle_material]]:
		var shader_material := surface[1] as ShaderMaterial
		if shader_material == null:
			continue
		if shader_material.shader == null:
			out.append("%s has no shader." % surface[0])
			continue
		# A drops' shader may take the colour from its particle (COLOR) and need no uniform.
		if surface[0] == "drop_material":
			continue
		var names := uniforms(shader_material.shader)
		for wanted: StringName in [texture_parameter, color_parameter]:
			if not wanted.is_empty() and not names.has(wanted):
				out.append("%s's shader has no uniform '%s' (texture_parameter, color_parameter)." % [surface[0], wanted])
	return out


## The uniform names a shader declares.
static func uniforms(shader: Shader) -> Array[StringName]:
	var out: Array[StringName] = []
	for info in shader.get_shader_uniform_list():
		out.append(StringName(info["name"]))
	return out
