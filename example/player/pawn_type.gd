class_name PawnType
extends Resource
## One kind of pawn: its look and its numbers. One file per variant, never changed while playing.

## Color of the pawn.
@export var tint: Color = Color.WHITE
## Letter shown over the pawn.
@export var badge: String = "A"
## Speed in the 2D world.
@export_range(0.0, 1000.0, 10.0, "suffix:px/s") var speed_2d_px_s: float = 180.0
## Speed in the 3D world.
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var speed_3d_m_s: float = 7.2
## How long the emote flash takes to reach white.
@export_range(0.0, 1.0, 0.01, "suffix:s") var flash_in_s: float = 0.08
## How long the emote flash takes to fade back to the tint.
@export_range(0.0, 2.0, 0.01, "suffix:s") var flash_out_s: float = 0.2
