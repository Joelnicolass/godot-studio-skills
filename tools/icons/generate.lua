-- Draws the kits' editor icons: one 16 x 16 SVG per class and one emblem per kit.
--
--   aseprite -b --script-param out=<repo>/addons --script tools/icons/generate.lua
--
-- Reads classes.tsv (which classes carry an icon; list_classes.py writes it), kits.lua (the
-- colour of each kit and the glyph of each class) and glyphs.lua (the glyphs). Writes
-- <out>/<kit>/icons/<class_script>.svg and <out>/<kit>/icons/<kit>.svg, and leaves in
-- manifest.tsv which icon each class got.

local SIZE = 16
local MAX_GLYPH = 14
local MAX_INK = 10
local DIM_COLORS = { ["2d"] = "#8da5f3", ["3d"] = "#fc7f7f" } -- Godot's own for Node2D and Node3D

local here = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)[/\\][^/\\]*$") or "."
local out_dir = app.params.out
if not out_dir or out_dir == "" then
	error("Missing --script-param out=<addons folder>")
end

local data = dofile(app.fs.joinPath(here, "glyphs.lua"))
local config = dofile(app.fs.joinPath(here, "kits.lua"))
local problems = {}

local function problem(text)
	problems[#problems + 1] = text
end

-- ---------------------------------------------------------------- color

local function rgb(hex)
	return {
		tonumber(hex:sub(2, 3), 16),
		tonumber(hex:sub(4, 5), 16),
		tonumber(hex:sub(6, 7), 16),
	}
end

local function mix(a, b, t)
	local result = {}
	for i = 1, 3 do
		result[i] = math.floor(a[i] + (b[i] - a[i]) * t + 0.5)
	end
	return result
end

local function pixel(color)
	return app.pixelColor.rgba(color[1], color[2], color[3], 255)
end

-- The three tones of a kit: its colour, a light one and the dark one of the outline.
local function tones(hex)
	local base = rgb(hex)
	return {
		base = base,
		light = mix(base, { 255, 255, 255 }, 0.55),
		dark = mix(base, { 12, 14, 24 }, 0.72),
	}
end

-- ---------------------------------------------------------------- canvas

local function check_rows(name, rows, limit)
	if not rows then
		problem("glyph \"" .. name .. "\" does not exist")
		return false
	end
	local width = #rows[1]
	for index, row in ipairs(rows) do
		if #row ~= width then
			problem(("glyph \"%s\": row %d is %d wide and the first is %d"):format(name, index, #row, width))
			return false
		end
		if row:find("[^#+o.]") then
			problem(("glyph \"%s\": row %d has a character that is not # + o ."):format(name, index))
			return false
		end
	end
	if width > limit or #rows > limit then
		problem(("glyph \"%s\": it is %d x %d and the most is %d"):format(name, width, #rows, limit))
		return false
	end
	return true
end

local function new_canvas()
	local canvas = {}
	for y = 0, SIZE - 1 do
		canvas[y] = {}
	end
	return canvas
end

local function put(canvas, x, y, value)
	if x >= 0 and x < SIZE and y >= 0 and y < SIZE then
		canvas[y][x] = value
	end
end

local function stamp(canvas, rows, left, top, remap)
	for row_index, row in ipairs(rows) do
		for column = 1, #row do
			local char = row:sub(column, column)
			if char ~= "." then
				put(canvas, left + column - 1, top + row_index - 1, remap and remap[char] or char)
			end
		end
	end
end

-- A mark in the bottom right corner: it clears one pixel around itself so the outline sets it
-- apart from the glyph.
local function stamp_corner(canvas, rows, value)
	local width, height = #rows[1], #rows
	local left, top = SIZE - 1 - width, SIZE - 1 - height
	for y = top - 1, SIZE - 1 do
		for x = left - 1, SIZE - 1 do
			put(canvas, x, y, nil)
		end
	end
	stamp(canvas, rows, left, top, { ["#"] = value, ["+"] = value, ["o"] = "o" })
end

-- The outline: every empty pixel next to (above, below or beside) a painted one.
local function outline(canvas)
	local edge = {}
	for y = 0, SIZE - 1 do
		for x = 0, SIZE - 1 do
			if not canvas[y][x] then
				local touches = (canvas[y - 1] and canvas[y - 1][x])
					or (canvas[y + 1] and canvas[y + 1][x])
					or canvas[y][x - 1]
					or canvas[y][x + 1]
				if touches then
					edge[#edge + 1] = { x, y }
				end
			end
		end
	end
	for _, point in ipairs(edge) do
		canvas[point[2]][point[1]] = "o"
	end
end

local function save(canvas, colors, path)
	local sprite = Sprite(SIZE, SIZE, ColorMode.RGB)
	local image = Image(SIZE, SIZE, ColorMode.RGB)
	for y = 0, SIZE - 1 do
		for x = 0, SIZE - 1 do
			local value = canvas[y][x]
			if value then
				image:drawPixel(x, y, pixel(colors[value]))
			end
		end
	end
	sprite.cels[1].image = image
	sprite.cels[1].position = Point(0, 0)
	sprite:saveCopyAs(path)
	sprite:close()
end

-- ---------------------------------------------------------------- icons

local function class_icon(spec)
	local rows = data.glyphs[spec[1]]
	if not check_rows(spec[1], rows, MAX_GLYPH) then
		return nil
	end
	local canvas = new_canvas()
	local left = (SIZE - #rows[1]) // 2 + (spec.dx or 0)
	local top = (SIZE - #rows) // 2 + (spec.dy or 0)
	if left < 1 or top < 1 or left + #rows[1] > SIZE - 1 or top + #rows > SIZE - 1 then
		problem(("glyph \"%s\": with dx/dy it leaves the canvas or loses its outline"):format(spec[1]))
		return nil
	end
	stamp(canvas, rows, left, top)
	if spec.badge then
		local badge = data.badges[spec.badge]
		if not check_rows(spec.badge, badge, 6) then
			return nil
		end
		stamp_corner(canvas, badge, "+")
	end
	if spec.dim then
		if not DIM_COLORS[spec.dim] then
			problem(("dim = \"%s\" is neither 2d nor 3d"):format(spec.dim))
			return nil
		end
		stamp_corner(canvas, data.badges.dim, spec.dim)
	end
	outline(canvas)
	return canvas
end

-- A kit's emblem: a rounded tile in the kit's colour with the ink in the dark tone.
local function kit_emblem(kit_id)
	local rows = data.emblems[kit_id]
	if not check_rows("emblem " .. kit_id, rows, MAX_INK) then
		return nil
	end
	local canvas = new_canvas()
	for y = 1, SIZE - 2 do
		for x = 1, SIZE - 2 do
			local corner = (x == 1 or x == SIZE - 2) and (y == 1 or y == SIZE - 2)
			if not corner then
				canvas[y][x] = "#"
			end
		end
	end
	stamp(canvas, rows, (SIZE - #rows[1]) // 2, (SIZE - #rows) // 2, { ["#"] = "o", ["+"] = "+", ["o"] = "o" })
	outline(canvas)
	return canvas
end

-- ---------------------------------------------------------------- run

local classes = {}
local seen = {}
local first = true
for line in io.lines(app.fs.joinPath(here, "classes.tsv")) do
	if first then
		first = false
	else
		local kit, class, kind, base, _native, script = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
		if class then
			classes[#classes + 1] = { kit = kit, class = class, kind = kind, base = base, script = script }
			seen[class] = true
		end
	end
end

local palette = {}
for _, kit in ipairs(config.kits) do
	local colors = tones(kit.color)
	palette[kit.id] = {
		["#"] = colors.base,
		["+"] = colors.light,
		["o"] = colors.dark,
		["2d"] = rgb(DIM_COLORS["2d"]),
		["3d"] = rgb(DIM_COLORS["3d"]),
	}
end

local manifest = { "kit\tclass\tkind\tbase\tscript\ticon\tglyph\tmark" }
local written = 0

for _, kit in ipairs(config.kits) do
	local canvas = kit_emblem(kit.id)
	if canvas then
		local relative = ("%s/icons/%s.svg"):format(kit.id, kit.id)
		save(canvas, palette[kit.id], app.fs.joinPath(out_dir, relative))
		manifest[#manifest + 1] = ("%s\t%s\temblem\t\t\taddons/%s\t%s\t"):format(kit.id, kit.name, relative, kit.id)
		written = written + 1
	end
end

for _, entry in ipairs(classes) do
	local spec = config.icons[entry.class]
	if not palette[entry.kit] then
		problem(("%s: kit \"%s\" has no colour in kits.lua"):format(entry.class, entry.kit))
	elseif not spec then
		problem(("%s (%s): no glyph in kits.lua"):format(entry.class, entry.kit))
	else
		local canvas = class_icon(spec)
		if canvas then
			local file = entry.script:match("([^/]+)%.gd$")
			local relative = ("%s/icons/%s.svg"):format(entry.kit, file)
			save(canvas, palette[entry.kit], app.fs.joinPath(out_dir, relative))
			local mark = spec.badge or spec.dim or ""
			manifest[#manifest + 1] = ("%s\t%s\t%s\t%s\t%s\taddons/%s\t%s\t%s"):format(
				entry.kit, entry.class, entry.kind, entry.base, entry.script, relative, spec[1], mark
			)
			written = written + 1
		end
	end
end

for class, _ in pairs(config.icons) do
	if not seen[class] then
		problem(("%s: listed in kits.lua and no longer a class with an icon (run list_classes.py or remove it)"):format(class))
	end
end

local handle = io.open(app.fs.joinPath(here, "manifest.tsv"), "w")
handle:write(table.concat(manifest, "\n"), "\n")
handle:close()

print(("%d icons -> %s"):format(written, out_dir))
if #problems > 0 then
	table.sort(problems)
	print(("%d problems:"):format(#problems))
	for _, text in ipairs(problems) do
		print("  - " .. text)
	end
end
