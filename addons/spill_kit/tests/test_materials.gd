extends "res://addons/spill_kit/tests/spill_test.gd"

## SpillMaterials and SpillShapes: the kit's wet look, a PBR type's own textures, and a game's own
## material.

const Shape := SpillShapes.Shape
const OWN_SHADER := "shader_type spatial;\nuniform sampler2D albedo_tex : source_color;\nuniform vec4 albedo_color : source_color;\nvoid fragment() { ALBEDO = texture(albedo_tex, UV).rgb * albedo_color.rgb; }\n"


func test_a_type_with_only_a_colour_looks_wet() -> void:
	var type := new_type({"color": Color(0.3, 0.5, 0.1)})
	var mark := SpillMaterials.build(type, Shape.MARK) as StandardMaterial3D
	check(mark != null, "a StandardMaterial3D")
	if mark == null:
		return
	check(mark.albedo_texture == SpillShapes.albedo(Shape.MARK), "the kit's splat")
	check(mark.normal_enabled and mark.normal_texture == SpillShapes.normal(Shape.MARK), "with its normal map")
	check(near(mark.roughness, 0.15) and near(mark.metallic, 0.0), "wet: low roughness")
	check(mark.albedo_color == type.color, "in the type's colour")
	check(mark.vertex_color_use_as_albedo, "each mark's shade multiplies it")
	check(mark.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and near(mark.alpha_scissor_threshold, 0.5), "cut at alpha 0.5")
	var drop := SpillMaterials.build(type, Shape.DROP) as StandardMaterial3D
	check(drop.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES, "a drop faces the camera")
	check(drop.albedo_color == Color.WHITE and drop.vertex_color_use_as_albedo, "a drop's colour comes from its particle")
	check(drop.normal_texture == SpillShapes.normal(Shape.DROP), "a round bead's normal map")
	var puddle := SpillMaterials.build(type, Shape.PUDDLE) as StandardMaterial3D
	check(puddle.albedo_texture == SpillShapes.albedo(Shape.PUDDLE), "the kit's puddle")
	var soft := SpillMaterials.build(new_type({"alpha_scissor": 0.0}), Shape.MARK) as BaseMaterial3D
	check(soft.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "alpha_scissor 0: soft edges, blended")


func test_a_pbr_type_gets_its_normal_and_orm_textures() -> void:
	var albedo := _texture(Color(1, 1, 1, 1))
	var normal := _texture(Color(0.5, 0.5, 1))
	var orm := _texture(Color(1, 0.4, 0.8))
	var type := new_type({
		"mark_albedo_texture": albedo, "mark_normal_texture": normal, "mark_orm_texture": orm,
		"puddle_normal_texture": normal, "roughness": 0.3, "metallic": 0.9, "specular": 0.8,
		"normal_scale": 2.5,
	})
	var mark := SpillMaterials.build(type, Shape.MARK) as ORMMaterial3D
	check(mark != null, "with an ORM texture: an ORMMaterial3D")
	if mark == null:
		return
	check(mark.albedo_texture == albedo, "its albedo")
	check(mark.normal_enabled and mark.normal_texture == normal, "its normal map")
	check(near(mark.normal_scale, 2.5), "its normal strength")
	check(mark.orm_texture == orm and mark.ao_enabled, "its ORM, occlusion on")
	check(near(mark.roughness, 0.3) and near(mark.metallic, 0.9) and near(mark.metallic_specular, 0.8), "its roughness, metallic and specular")
	var puddle := SpillMaterials.build(type, Shape.PUDDLE) as StandardMaterial3D
	check(puddle.normal_texture == normal and puddle.albedo_texture == SpillShapes.albedo(Shape.PUDDLE), "a normal map on the kit's puddle")
	var flat := SpillMaterials.build(new_type({"mark_albedo_texture": albedo}), Shape.MARK) as BaseMaterial3D
	check(not flat.normal_enabled, "an albedo of yours with no normal map: no normal map (the kit's splat's would not fit it)")


func test_the_pool_draws_with_the_pbr_material() -> void:
	box(Vector3.ZERO)
	var pool := new_pool()
	var normal := _texture(Color(0.5, 0.5, 1))
	var orm := _texture(Color(1, 0.4, 0.8))
	var type := new_type({
		"mark_normal_texture": normal, "mark_orm_texture": orm, "puddle_normal_texture": normal,
		"puddle_orm_texture": orm, "drop_normal_texture": normal, "puddle_grow_s": 0.0,
	})
	await physics()
	pool.spill(type, Vector3(0, 1, 0))
	pool.puddle(type, Vector3(0, 1, 0))
	var marks: MultiMesh = null
	var puddle: MeshInstance3D = null
	var spray: CPUParticles3D = null
	for child in pool.get_children(true):
		if child is MultiMeshInstance3D:
			marks = (child as MultiMeshInstance3D).multimesh
		elif child is MeshInstance3D and (child as MeshInstance3D).visible:
			puddle = child
		elif child is CPUParticles3D and spray == null:
			spray = child
	var mark_material := marks.mesh.surface_get_material(0) as ORMMaterial3D
	check(mark_material != null and mark_material.normal_texture == normal and mark_material.orm_texture == orm, "the marks' MultiMesh draws with the type's normal and ORM")
	var puddle_material := puddle.material_override as ORMMaterial3D
	check(puddle_material != null and puddle_material.normal_texture == normal and puddle_material.orm_texture == orm, "the puddle too")
	var drop_material := spray.mesh.surface_get_material(0) as BaseMaterial3D
	check(drop_material != null and drop_material.normal_texture == normal, "and the drops")
	check(spray.color == type.color, "the drops in the type's colour")
	type.metallic = 1.0
	pool.refresh(type)
	mark_material = marks.mesh.surface_get_material(0) as ORMMaterial3D
	check(near(mark_material.metallic, 1.0), "refresh() takes the type's new values")
	check(pool.mark_count(type) == 1, "and the marks on the floor stay")


func test_a_shader_of_the_game_s_own() -> void:
	var shader := Shader.new()
	shader.code = OWN_SHADER
	var own := ShaderMaterial.new()
	own.shader = shader
	var type := new_type({
		"mark_material": own, "puddle_material": own, "texture_parameter": &"albedo_tex",
		"color": Color(0.2, 0.6, 0.1),
	})
	check(type.problems().is_empty(), "its uniforms are found: no problem (%s)" % [type.problems()])
	var mark := SpillMaterials.build(type, Shape.MARK) as ShaderMaterial
	check(mark != null and mark != own, "a copy of it")
	check(mark.shader == shader, "the same shader")
	check(mark.get_shader_parameter(&"albedo_tex") == SpillShapes.albedo(Shape.MARK), "the kit's splat in texture_parameter")
	check(mark.get_shader_parameter(&"albedo_color") == type.color, "the colour in color_parameter")
	check(own.get_shader_parameter(&"albedo_color") == null, "the type's own material is not touched")
	var mine := _texture(Color.WHITE)
	type.puddle_albedo_texture = mine
	var puddle := SpillMaterials.build(type, Shape.PUDDLE) as ShaderMaterial
	check(puddle.get_shader_parameter(&"albedo_tex") == mine, "the type's own texture when it has one")
	type.texture_parameter = &"albedo_texture"
	var warned := "\n".join(type.problems())
	check(warned.contains("albedo_texture"), "a uniform the shader lacks is warned")
	var other := SpillMaterials.build(type, Shape.MARK) as ShaderMaterial
	check(other.get_shader_parameter(&"albedo_texture") == null, "and nothing is written in it")


func test_a_standard_material_of_the_game_s_own() -> void:
	var own := StandardMaterial3D.new()
	var crust := _texture(Color.WHITE)
	own.albedo_texture = crust
	own.emission_enabled = true
	var type := new_type({"mark_material": own, "puddle_material": StandardMaterial3D.new()})
	var mark := SpillMaterials.build(type, Shape.MARK) as StandardMaterial3D
	check(mark != own and mark.emission_enabled, "a copy, with its own settings")
	check(mark.albedo_texture == crust, "its own albedo stays")
	check(mark.albedo_color == type.color, "in the type's colour")
	var puddle := SpillMaterials.build(type, Shape.PUDDLE) as StandardMaterial3D
	check(puddle.albedo_texture == SpillShapes.albedo(Shape.PUDDLE), "with none, the kit's puddle")


func test_the_kit_s_shapes_rise_like_a_liquid() -> void:
	var size: int = SpillShapes.SIZES[Shape.DROP]
	var drop := SpillShapes.heights(Shape.DROP)
	check(near(drop[size / 2 * size + size / 2], 1.0, 0.05), "a drop is highest in its middle")
	check(drop[0] == 0.0, "nothing in a corner")
	var image := SpillShapes.normal(Shape.DROP).get_image()
	if image == null:
		# The dummy renderer of a headless run keeps no pixels.
		check(true, "no pixels to read here")
		return
	var middle := image.get_pixel(size / 2, size / 2)
	check(middle.b > 0.95, "its middle faces straight out")
	var left := image.get_pixel(size / 2 - size / 3, size / 2)
	check(left.r < 0.4, "its left side leans left (%.2f)" % left.r)
	var top := image.get_pixel(size / 2, size / 2 - size / 3)
	check(top.g > 0.6, "its top side leans up the image, OpenGL's way (%.2f)" % top.g)
	var mark := SpillShapes.heights(Shape.MARK)
	var mark_size: int = SpillShapes.SIZES[Shape.MARK]
	check(near(mark[mark_size / 2 * mark_size + mark_size / 2], 1.0, 0.001), "a mark is flat in its middle")
	var albedo := SpillShapes.albedo(Shape.MARK).get_image()
	if albedo != null:
		check(albedo.get_pixel(0, 0).a == 0.0 and albedo.get_pixel(mark_size / 2, mark_size / 2).a == 1.0, "its shape is in the alpha")


func _texture(color: Color) -> Texture2D:
	var image := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
