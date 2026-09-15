class_name TerrainConfig extends Resource

@export_category("Generation")
## Lowest number of walls/traps the generator may place in one arena.
@export_range(0, 8, 1) var minimum_modules: int = 3
## Highest number of walls/traps the generator may place in one arena.
@export_range(0, 8, 1) var maximum_modules: int = 3
## How many candidate positions are tried before an unsafe module is skipped.
## Higher values improve placement success but require slightly more generation work.
@export var placement_attempts_per_module: int = 60
## Ensures every generated layout includes one mud patch when the module budget allows it.
@export var guarantee_mud_patch: bool = true
## Ensures every generated layout includes one bear trap when the module budget allows it.
@export var guarantee_bear_trap: bool = true

@export_category("Arena Safety")
## Full playable arena rectangle used by placement and enemy navigation checks.
@export var arena_rect: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
## Player's starting location. Terrain generation protects the area around this point.
@export var player_spawn: Vector2 = Vector2(640.0, 360.0)
## Minimum pixels between the player spawn and any generated terrain footprint.
@export var player_spawn_clearance: float = 150.0
## Minimum pixels reserved between generated terrain and the outer arena boundary.
@export var arena_edge_clearance: float = 70.0
## Minimum empty gap between separate terrain modules.
@export var module_spacing: float = 34.0
## Required fraction of arena area left unobstructed. 0.6 means at least 60% open.
@export_range(0.4, 1.0, 0.05) var minimum_open_area_ratio: float = 0.6
## Additional clear space around traps so their warning artwork remains readable.
@export var trap_telegraph_clearance: float = 36.0
## Extra wall padding used by enemy pathfinding so enemies do not scrape obstacle edges.
@export var navigation_margin: float = 24.0
## Size of one enemy-navigation grid square. Smaller is more precise but costs more work.
@export var navigation_cell_size: float = 40.0
## Visual layer for solid walls (TerrainModule). Below actors (z_index 2), above the floor.
@export var wall_visual_z_index: int = 1
## Visual layer for traps/hazards (BearTrap, MudPatch). Below actors (z_index 2), above the floor.
## Kept separate from wall_visual_z_index: walls and traps are different things and must be
## independently tunable, even though they currently share the same default value.
@export var trap_visual_z_index: int = 1
## Thickness of the Forest perimeter collision and grass visual. Centered exactly on the
## arena_rect edge so the physical wall, the chakram/projectile bounce boundary, and the
## grass art all line up at the same place the player's movement clamp already stops at.
@export var arena_border_thickness: float = 52.0

@export_category("Mud")
## Player movement multiplier while inside mud. 0.7 means movement is reduced by 30%.
@export_range(0.1, 1.0, 0.05) var mud_movement_multiplier: float = 0.7
## Prevents starting a dash and cancels an active dash when entering mud.
@export var mud_disables_dash: bool = true
## Mud patch radius in pixels, affecting both artwork and player detection.
@export var mud_radius: float = 46.0

@export_category("Bear Trap")
## Seconds the player cannot move or dash after triggering a bear trap.
@export var bear_trap_root_duration: float = 1.0
## Seconds before a triggered bear trap becomes armed again.
@export var bear_trap_rearm_duration: float = 4.0
## Bear-trap activation radius in pixels.
@export var bear_trap_radius: float = 22.0

@export_category("Debug")
## Prints seed, module count, open-space percentage, and rejected candidates after generation.
@export var print_generation_report: bool = true
## Draws module footprint rectangles for diagnosing placement and overlap rules.
@export var draw_placement_bounds: bool = false
