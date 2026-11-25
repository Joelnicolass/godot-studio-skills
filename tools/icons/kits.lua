-- The colour of each kit and the glyph of each class.
-- A new class: add it to `icons` with a glyph of glyphs.lua and regenerate (see README.md).
--
--   { "glyph" }                    the glyph alone
--   { "glyph", badge = "check" }   with a light mark at the bottom right (glyphs.lua, table B)
--   { "glyph", dim = "2d" }        with Godot's blue (2D) or red (3D) dot: only for the classes
--                                  that have a twin in the other dimension
--   dx, dy                         move the glyph so the mark does not cover it

local kits = {
	{ id = "bot_kit", name = "BotKit", color = "#a7b4c8" }, -- steel
	{ id = "command_kit", name = "CommandKit", color = "#98a2ff" }, -- lavender
	{ id = "fsm_kit", name = "FsmKit", color = "#ea62c2" }, -- magenta
	{ id = "grass_kit", name = "GrassKit", color = "#8fd03f" }, -- lime
	{ id = "grid_kit", name = "GridKit", color = "#2fc4cc" }, -- cyan
	{ id = "mp_kit", name = "MpKit", color = "#3d8ef5" }, -- blue
	{ id = "perception_kit", name = "PerceptionKit", color = "#a45ff0" }, -- violet
	{ id = "plat_kit", name = "PlatKit", color = "#efe4c8" }, -- cream
	{ id = "prop_kit", name = "PropKit", color = "#2faf7c" }, -- emerald
	{ id = "rts_kit", name = "RtsKit", color = "#f58a33" }, -- orange
	{ id = "spill_kit", name = "SpillKit", color = "#e5484d" }, -- red
	{ id = "turn_kit", name = "TurnKit", color = "#c08a5c" }, -- copper
	{ id = "wallet_kit", name = "WalletKit", color = "#f4c531" }, -- gold
}

local icons = {
	-- bot_kit
	Bot3D = { "robot" },
	BotDebug = { "bug" },
	BotDifficulty = { "bars" },
	BotGoal3D = { "flag" },
	BotMode = { "gear" },
	BotWeapon = { "crosshair" },

	-- command_kit
	GameCommands = { "prompt" },

	-- fsm_kit
	FsmMachine = { "state_graph" },
	FsmState = { "state" },

	-- grass_kit
	GrassClear3D = { "grass_gap" },
	GrassClearing = { "grass_gaps" },
	GrassField3D = { "tuft" },
	GrassGround = { "grass_ground" },
	GrassLook = { "grass_look" },
	GrassMap = { "painted_map" },
	GrassMesh = { "blade_mesh" },
	GrassQuality = { "blade_levels" },
	GrassWind = { "wind" },

	-- grid_kit
	GridBoard = { "checker" },
	GridCursor = { "cell_cursor" },
	GridLayout = { "grid_sheet" },
	GridView3D = { "iso_tile" },

	-- mp_kit
	MpActor = { "pawn" },
	MpBootMenu = { "menu_window" },
	MpCustomPipe = { "pipe" },
	MpFlow = { "flow" },
	MpGame = { "gamepad" },
	MpInput = { "dpad" },
	MpInviteLabel = { "envelope" },
	MpLanBeacon = { "beacon" },
	MpLeaveButton = { "exit" },
	MpLobbyClient = { "monitor" },
	MpLobbyConfig = { "house", badge = "knob", dx = -1, dy = -1 },
	MpLobbyEndpoint = { "plug" },
	MpLobbyScreen = { "lobby_window" },
	MpLobbyServer = { "rack" },
	MpLocalSeat = { "chair" },
	MpLocalServer = { "monitor_rack" },
	MpMatch = { "trophy" },
	MpMatchAgent = { "ticket" },
	MpMatchGate = { "door" },
	MpMatchLauncher = { "rocket" },
	MpMatchmaker = { "pair" },
	MpNetConfig = { "sliders" },
	MpNetQuality = { "pulse" },
	MpOnline = { "cloud" },
	MpProcessRunner = { "terminal" },
	MpProcessRunnerStub = { "terminal_hollow" },
	MpReplicate = { "copy" },
	MpRoomDirectory = { "rooms" },
	MpRoomRules = { "checklist" },
	MpRoomServer = { "house_rack" },
	MpSlotSpawner = { "pawn", badge = "slots", dx = -2, dy = -1 },
	MpSpawner = { "pawn", badge = "plus", dx = -2, dy = -1 },
	MpStartButton = { "play_button" },
	MpState = { "braces" },
	MpWaitingLabel = { "hourglass" },
	MpWorld = { "globe" },
	MpWorldLoader = { "globe", badge = "down", dx = -1, dy = -1 },
	MpWorldReady = { "globe", badge = "check", dx = -1, dy = -1 },
	MpWorldRef = { "globe", badge = "link", dx = -1, dy = -1 },

	-- perception_kit
	PerceptionSensor2D = { "eye", dim = "2d", dy = -2 },
	PerceptionSensor3D = { "eye", dim = "3d", dy = -2 },
	PerceptionTarget2D = { "bullseye", dim = "2d", dx = -1, dy = -1 },
	PerceptionTarget3D = { "bullseye", dim = "3d", dx = -1, dy = -1 },

	-- plat_kit
	PlatMotor = { "jump" },

	-- prop_kit
	PropBatch3D = { "forest" },
	PropFlatGround = { "slab" },
	PropGround = { "hill" },
	PropKeepOut = { "no_entry" },
	PropMask = { "mask" },
	PropNavBake = { "zones", badge = "check", dx = -1, dy = -1 },
	PropNavZones2D = { "zones", dim = "2d", dx = -1, dy = -1 },
	PropNavZones3D = { "zones", dim = "3d", dx = -1, dy = -1 },
	PropRayGround = { "ray_ground" },
	PropScatter2D = { "scatter", dim = "2d", dx = -1, dy = -1 },
	PropScatter3D = { "scatter", dim = "3d", dx = -1, dy = -1 },
	PropScatterRules = { "clusters" },
	PropVariant = { "pine_rock" },

	-- rts_kit
	RtsArcFormation = { "formation_arc" },
	RtsArmedCommand = { "crosshair" },
	RtsArmedPreview = { "reticle_dashed" },
	RtsCamera2D = { "camera", dim = "2d", dy = -2 },
	RtsCamera3D = { "camera", dim = "3d", dy = -2 },
	RtsCameraEffect = { "camera", badge = "burst", dy = -3 },
	RtsCommandCard = { "card_grid" },
	RtsCommandCatalog = { "stack_commands" },
	RtsCommandCue = { "cue" },
	RtsCommandInput = { "chevrons", badge = "cursor", dx = -2, dy = -2 },
	RtsCommandRig = { "toolbox" },
	RtsCommandState = { "leds" },
	RtsCommandType = { "command_tile" },
	RtsCueSet = { "stack_cues" },
	RtsCursorSkin = { "cursor_skin" },
	RtsFormation = { "formation" },
	RtsFormationCatalog = { "stack_formations" },
	RtsGroupKeys = { "key" },
	RtsMenuEntry = { "entry" },
	RtsOrderButton = { "mouse" },
	RtsOrderInput = { "order_arrow", badge = "cursor", dx = -1, dy = -3 },
	RtsOrderMenu = { "menu_popup" },
	RtsOrders = { "orders" },
	RtsPing2D = { "ping", dim = "2d", dx = -1, dy = -1 },
	RtsPing3D = { "ping", dim = "3d", dx = -1, dy = -1 },
	RtsPointer = { "cursor" },
	RtsRadialAnimator = { "ring_play" },
	RtsRadialDecor = { "pie" },
	RtsRadialLayout = { "ring_center" },
	RtsRadialMenu = { "ring_segments" },
	RtsRadialRing = { "ring_arc" },
	RtsRadialRings = { "ring_dots" },
	RtsRadialSlot = { "slot" },
	RtsRefusalReason = { "bubble_x" },
	RtsRowFormation = { "formation_rows" },
	RtsSelectInput = { "marquee", badge = "cursor", dx = -1, dy = -1 },
	RtsSelection = { "marquee" },
	RtsTargetProbe = { "magnifier" },
	RtsUnit = { "unit" },
	RtsWedgeFormation = { "formation_wedge" },

	-- spill_kit
	SpillPool3D = { "puddle" },
	SpillSource3D = { "drops" },
	SpillType = { "flask" },

	-- turn_kit
	TurnClock = { "clock" },
	TurnSeat = { "chair" },

	-- wallet_kit
	Wallet = { "pouch" },
	WalletSubstitute = { "exchange" },
}

return { kits = kits, icons = icons }
