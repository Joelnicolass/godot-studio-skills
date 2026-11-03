class_name SpillMaterials
extends RefCounted

## The material of a type's drops, marks or puddle. With no material of the type's own: a PBR
## material (StandardMaterial3D, or ORMMaterial3D with an ORM texture) built from its fields, with the
## type's textures or the kit's shapes (SpillShapes). With one: a copy of it, given the surface's
## albedo texture and the type's colour (on a ShaderMaterial through texture_parameter and
## color_parameter, when its shader declares them). Every renderer draws them, Compatibility and
## WebGL 2 too.
##
## The drops take their colour from the particles' (CPUParticles3D.color, the type's colour) and each
## mark its shade from the MultiMesh, both as vertex colour, so the same material serves every drop
## and every mark of a type.

const Shape := SpillShapes.Shape


## The material of [param type]'s [param shape] (DROP, MARK or PUDDLE).
static func build(type: SpillType, shape: Shape) -> Material:
	var own := own_material(type, shape)
	if own != null:
		return _dressed(own, type, shape)
	var albedo := albedo_texture(type, shape)
	var orm := orm_texture(type, shape)
	var material: BaseMaterial3D = ORMMaterial3D.new() if orm != null else StandardMaterial3D.new()
	# A drop's colour comes in its vertex colour (the particles'); a mark's shade too, multiplied.
	material.albedo_color = Color.WHITE if shape == Shape.DROP else type.color
	material.albedo_texture = albedo if albedo != null else SpillShapes.albedo(shape)
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = type.roughness
	material.metallic = type.metallic
	material.metallic_specular = type.specular
	var normal := normal_texture(type, shape)
	material.normal_enabled = normal != null
	material.normal_texture = normal
	material.normal_scale = type.normal_scale
	if orm != null:
		(material as ORMMaterial3D).orm_texture = orm
		material.ao_enabled = true
	if type.alpha_scissor > 0.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = type.alpha_scissor
	else:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if shape == Shape.DROP:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return material


## The type's own material for [param shape] (null: the kit builds one).
static func own_material(type: SpillType, shape: Shape) -> Material:
	return [type.drop_material, type.mark_material, type.puddle_material][shape]


## The type's albedo texture for [param shape] (null: the kit's shape).
static func albedo_texture(type: SpillType, shape: Shape) -> Texture2D:
	return [type.drop_albedo_texture, type.mark_albedo_texture, type.puddle_albedo_texture][shape]


## The normal map the kit's material uses for [param shape]: the type's; with none, the kit's shape's
## when the albedo is the kit's too, else none (a normal map of the kit's splat would not fit yours).
static func normal_texture(type: SpillType, shape: Shape) -> Texture2D:
	var own: Texture2D = [type.drop_normal_texture, type.mark_normal_texture, type.puddle_normal_texture][shape]
	if own != null:
		return own
	return SpillShapes.normal(shape) if albedo_texture(type, shape) == null else null


## The type's ORM texture for [param shape] (null: none).
static func orm_texture(type: SpillType, shape: Shape) -> Texture2D:
	return [type.drop_orm_texture, type.mark_orm_texture, type.puddle_orm_texture][shape]


# A copy of the type's own material with the surface's albedo (the type's, else the material's own,
# else the kit's shape) and the type's colour.
static func _dressed(own: Material, type: SpillType, shape: Shape) -> Material:
	var copy := own.duplicate() as Material
	var albedo := albedo_texture(type, shape)
	var base := copy as BaseMaterial3D
	if base != null:
		if albedo != null:
			base.albedo_texture = albedo
		elif base.albedo_texture == null:
			base.albedo_texture = SpillShapes.albedo(shape)
		base.albedo_color = type.color
		return copy
	var shader_material := copy as ShaderMaterial
	if shader_material == null or shader_material.shader == null:
		return copy
	var names := SpillType.uniforms(shader_material.shader)
	if names.has(type.texture_parameter):
		if albedo != null:
			shader_material.set_shader_parameter(type.texture_parameter, albedo)
		elif shader_material.get_shader_parameter(type.texture_parameter) == null:
			shader_material.set_shader_parameter(type.texture_parameter, SpillShapes.albedo(shape))
	if names.has(type.color_parameter):
		shader_material.set_shader_parameter(type.color_parameter, type.color)
	return copy
