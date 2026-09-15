@tool
class_name ResonanceRushChunk extends Node2D

## Editor-authored piece of Resonance Rush terrain.
##
## Select DrivePath in the 2D editor and move its Curve2D points. The visible
## graybox ground, generated CollisionPolygon2D, and entry/exit sockets rebuild
## from that exact same curve both in-editor and at runtime.

const STANDALONE_PLAYTEST_SCENE = "res://scenes/minigames/resonance_rush/rush_chunk_graybox_playtest.tscn"

@export_category("Chunk Identity")
@export var chunk_id: String = "graybox_chunk"
## Primary routes determine world start/end; optional stacked platforms do not.
@export var is_primary_route: bool = true
## Loops/overhangs are drawn as standalone track ribbons, not downward-filled
## polygons that would self-intersect.
@export var track_only_mode: bool = false

@export_category("Track Connections")
## Explicit forward connection to another RushChunk. Required whenever more
## than one track could plausibly connect at the same junction (e.g. a loop's
## entrance and a straight road both starting at the same point) — proximity
## alone cannot disambiguate that case.
@export var forced_next_chunk: NodePath = NodePath()
## Explicit backward connection, used when moving in reverse off this track's
## start point.
@export var forced_previous_chunk: NodePath = NodePath()

@export_category("Ground Preview")
@export var ground_depth: float = 220.0
@export var ground_color: Color = Color("414854")
@export var surface_color: Color = Color("7ee35f")
@export var surface_width: float = 8.0
@export var show_ground_preview: bool = true
@export var show_socket_guides: bool = true

@export_category("Ground Art")
## Optional tileable ground texture. When set, it replaces the flat
## ground_color fill on GroundPreview, wrapped with CanvasItem's own repeat
## so it tiles across the polygon instead of stretching.
@export var ground_texture: Texture2D
@export var ground_texture_scale: Vector2 = Vector2.ONE

@export_category("Collision")
@export var collision_enabled: bool = true

var _last_editor_signature: int = -1

func _ready() -> void:
	_rebuild_from_drive_path()
	_set_socket_labels_visible(Engine.is_editor_hint())
	set_process(Engine.is_editor_hint())
	# F6 runs the currently open chunk scene. Redirect that standalone run to
	# the tiny driving harness so authors do not need to manually switch scenes.
	# When this chunk is instanced by the harness, current_scene is the harness
	# root instead, so this cannot recurse.
	if not Engine.is_editor_hint() and get_tree().current_scene == self:
		call_deferred("_open_standalone_playtest")

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var signature: int = _editor_signature()
	if signature != _last_editor_signature:
		_last_editor_signature = signature
		_rebuild_from_drive_path()

func _editor_signature() -> int:
	var drive_path: Path2D = get_node_or_null("DrivePath") as Path2D
	if drive_path == null or drive_path.curve == null:
		return 0
	var signature_text: String = "%s|%s|%s|%s|%s|%s|%s|%s" % [ground_depth, ground_color, surface_color, surface_width, show_ground_preview, show_socket_guides, collision_enabled, track_only_mode]
	for index: int in drive_path.curve.point_count:
		signature_text += "|%s|%s|%s" % [
			drive_path.curve.get_point_position(index),
			drive_path.curve.get_point_in(index),
			drive_path.curve.get_point_out(index),
		]
	return hash(signature_text)

func _open_standalone_playtest() -> void:
	var error_code: int = get_tree().change_scene_to_file(STANDALONE_PLAYTEST_SCENE)
	if error_code != OK:
		push_error("ResonanceRushChunk: could not open standalone playtest (%s)" % error_string(error_code))

## The playable surface in this chunk's local coordinates.
func get_surface_points() -> PackedVector2Array:
	var drive_path: Path2D = get_node_or_null("DrivePath") as Path2D
	if drive_path == null or drive_path.curve == null:
		return PackedVector2Array()
	return drive_path.curve.get_baked_points()

func get_entry_position() -> Vector2:
	var points: PackedVector2Array = get_surface_points()
	return points[0] if not points.is_empty() else Vector2.ZERO

func get_exit_position() -> Vector2:
	var points: PackedVector2Array = get_surface_points()
	return points[points.size() - 1] if not points.is_empty() else Vector2.ZERO

func _rebuild_from_drive_path() -> void:
	var points: PackedVector2Array = get_surface_points()
	if points.size() < 2:
		return
	var ground_polygon: PackedVector2Array = PackedVector2Array()
	if not track_only_mode:
		ground_polygon = _build_ground_polygon(points)

	var preview: Polygon2D = get_node_or_null("GroundPreview") as Polygon2D
	if preview != null:
		preview.polygon = ground_polygon
		if ground_texture != null:
			preview.texture = ground_texture
			preview.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			preview.texture_scale = ground_texture_scale
			preview.color = Color(1.0, 1.0, 1.0, 1.0)
		else:
			preview.texture = null
			preview.color = ground_color
		preview.visible = show_ground_preview and not track_only_mode

	var surface: Line2D = get_node_or_null("SurfacePreview") as Line2D
	if surface != null:
		surface.points = points
		surface.width = surface_width
		surface.default_color = surface_color
		surface.visible = show_ground_preview

	var collision: CollisionPolygon2D = get_node_or_null("GroundBody/GroundCollision") as CollisionPolygon2D
	if collision != null:
		collision.polygon = ground_polygon
		collision.disabled = not collision_enabled or track_only_mode

	_update_socket("EntryMarker", points[0], (points[1] - points[0]).normalized())
	_update_socket("ExitMarker", points[points.size() - 1], (points[points.size() - 1] - points[points.size() - 2]).normalized())
	queue_redraw()

func _build_ground_polygon(surface_points: PackedVector2Array) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array(surface_points)
	var deepest_y: float = surface_points[0].y
	for point: Vector2 in surface_points:
		deepest_y = maxf(deepest_y, point.y)
	var bottom_y: float = deepest_y + ground_depth
	polygon.append(Vector2(surface_points[surface_points.size() - 1].x, bottom_y))
	polygon.append(Vector2(surface_points[0].x, bottom_y))
	return polygon

func _set_socket_labels_visible(labels_visible: bool) -> void:
	for marker_name: String in ["EntryMarker", "ExitMarker"]:
		var label: Label = get_node_or_null("%s/Label" % marker_name) as Label
		if label != null:
			label.visible = labels_visible

func _update_socket(node_name: String, socket_position: Vector2, tangent: Vector2) -> void:
	var marker: Marker2D = get_node_or_null(node_name) as Marker2D
	if marker == null:
		return
	marker.position = socket_position
	marker.rotation = tangent.angle()
	var label: Label = marker.get_node_or_null("Label") as Label
	if label != null:
		label.rotation = -marker.rotation

func _draw() -> void:
	if not Engine.is_editor_hint() or not show_socket_guides:
		return
	var points: PackedVector2Array = get_surface_points()
	if points.size() < 2:
		return
	_draw_socket(points[0], (points[1] - points[0]).normalized(), Color("ffd84d"))
	_draw_socket(points[points.size() - 1], (points[points.size() - 1] - points[points.size() - 2]).normalized(), Color("58d7ff"))

func _draw_socket(socket_position: Vector2, tangent: Vector2, color: Color) -> void:
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	draw_circle(socket_position, 15.0, Color(color.r, color.g, color.b, 0.18))
	draw_arc(socket_position, 15.0, 0.0, TAU, 24, color, 3.0, true)
	draw_line(socket_position - normal * 25.0, socket_position + normal * 25.0, color, 3.0, true)
	draw_line(socket_position - tangent * 12.0, socket_position + tangent * 40.0, color, 3.0, true)
	var arrow_tip: Vector2 = socket_position + tangent * 40.0
	draw_line(arrow_tip, arrow_tip - tangent.rotated(0.55) * 12.0, color, 3.0, true)
	draw_line(arrow_tip, arrow_tip - tangent.rotated(-0.55) * 12.0, color, 3.0, true)
