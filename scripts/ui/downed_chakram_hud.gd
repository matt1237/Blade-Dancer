extends Control
## Read-only recovery markers. No persistent per-disc nodes/state: rebuild the
## draw list from the canonical group each frame; pickup/reset cannot orphan UI.
const ICON_RADIUS: float = 18.0
const MARKER_EXTENT: float = 30.0
const EDGE_INSET: float = 32.0
var markers: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS # Clear immediately even when paused.

func _process(_delta: float) -> void:
	var main: Node = get_parent().get_parent()
	var health: CanvasItem = main.get_node_or_null("CanvasLayer/HealthLabel") as CanvasItem
	var enabled: bool = health != null and health.is_visible_in_tree() and not bool(main.get("run_over")) and not get_tree().paused
	for path: String in ["CanvasLayer/HomeMenu", "CanvasLayer/EndRunHub", "CanvasLayer/BonusPanel"]:
		var overlay: CanvasItem = main.get_node_or_null(path) as CanvasItem
		if overlay != null and overlay.is_visible_in_tree(): enabled = false
	refresh_markers(get_tree().get_nodes_in_group("chakram"), enabled)

static func safe_marker_rect(view: Rect2) -> Rect2:
	var margin: float = EDGE_INSET + MARKER_EXTENT
	# Reserve timer/score rows, including upward arrow; left HUD is handled below.
	var top: float = maxf(margin, 108.0)
	return Rect2(view.position + Vector2(margin, top), Vector2(maxf(1, view.size.x - margin * 2), maxf(1, view.size.y - top - margin)))

static func edge_position(target: Vector2, view: Rect2) -> Vector2:
	var safe: Rect2 = safe_marker_rect(view)
	var origin: Vector2 = view.get_center().clamp(safe.position, safe.end)
	var direction: Vector2 = target - origin
	if direction.length_squared() < 0.001: return origin
	var tx: float = INF
	var ty: float = INF
	if absf(direction.x) > 0.001:
		tx = ((safe.end.x if direction.x > 0 else safe.position.x) - origin.x) / direction.x
	if absf(direction.y) > 0.001:
		ty = ((safe.end.y if direction.y > 0 else safe.position.y) - origin.y) / direction.y
	var point: Vector2 = (origin + direction * minf(tx, ty)).clamp(safe.position, safe.end)
	# Existing HP/Flow/Dash/Grapple/Deflect stack occupies the upper-left.
	if point.x < view.position.x + 280.0 and point.y < view.position.y + 270.0:
		point.y = minf(view.position.y + 270.0, safe.end.y)
	return point

static func disc_is_offscreen(disc: Chakram, view: Rect2) -> bool:
	# A conservative art bounding square (34px world art, centered at origin).
	# Partial visibility does NOT trigger a marker. Includes real canvas zoom,
	# focus, camera offset, rotation and parent transforms, not guessed zoom math.
	var transform: Transform2D = disc.get_global_transform_with_canvas()
	var bounds: Rect2 = Rect2(transform * Vector2(-17, -17), Vector2.ZERO)
	for corner: Vector2 in [Vector2(17, -17), Vector2(-17, 17), Vector2(17, 17)]:
		bounds = bounds.expand(transform * corner)
	return not view.intersects(bounds, true)

func refresh_markers(discs: Array, enabled: bool) -> void:
	markers.clear()
	visible = enabled
	if enabled:
		var view: Rect2 = get_viewport_rect()
		var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
		for node: Node in discs:
			var disc: Chakram = node as Chakram
			if not is_instance_valid(disc) or not disc.is_inside_tree() or disc.get_viewport() != get_viewport(): continue
			if not disc.is_downed_for_presentation() or not disc.is_visible_in_tree() or not disc_is_offscreen(disc, view): continue
			var target: Vector2 = disc.get_global_transform_with_canvas() * Vector2.ZERO
			var point: Vector2 = edge_position(target, view)
			# Separate coincident targets tangentially. Arrow still aims at its own
			# actual target after displacement; every grounded disc retains a marker.
			var safe: Rect2 = safe_marker_rect(view)
			for attempt: int in range(markers.size() + 1):
				var overlaps: bool = false
				for other: Dictionary in markers:
					if point.distance_to(other["viewport_position"]) < 42.0: overlaps = true
				if not overlaps: break
				var tangent: Vector2 = Vector2.DOWN if absf(point.x - safe.position.x) < 1 or absf(point.x - safe.end.x) < 1 else Vector2.RIGHT
				# Short landscape canvases have no vertical room below the left
				# HUD stack: stack inward instead, preserving HUD clearance.
				if tangent == Vector2.DOWN and safe.end.y - maxf(safe.position.y, view.position.y + 270.0) < 42.0:
					tangent = Vector2.RIGHT
				var offset: float = 44.0 * float(attempt / 2 + 1) * (1.0 if attempt % 2 == 0 else -1.0)
				point = (edge_position(target, view) + tangent * offset).clamp(safe.position, safe.end)
				if point.x < view.position.x + 280.0 and point.y < view.position.y + 270.0:
					point.y = minf(view.position.y + 270.0, safe.end.y)
			markers.append({"disc": disc, "viewport_position": point, "position": to_local * point, "direction": (to_local * target - to_local * point).normalized()})
	queue_redraw()

func _draw() -> void:
	for marker: Dictionary in markers:
		var disc: Chakram = marker["disc"] as Chakram
		if not is_instance_valid(disc) or not disc.is_downed_for_presentation(): continue
		var center: Vector2 = marker["position"]
		var direction: Vector2 = marker["direction"]
		# Small canonical UI geometry, with the actual disc art inside it.
		draw_circle(center, ICON_RADIUS, Color(0.06, 0.07, 0.10, 0.9))
		draw_arc(center, ICON_RADIUS, 0, TAU, 40, Color(1, 0.86, 0.16, 0.95), 2.0, true)
		disc.draw_recovery_icon(self, center)
		var tip: Vector2 = center + direction * 29.0
		var base: Vector2 = center + direction * 21.0
		var side: Vector2 = direction.orthogonal() * 5.0
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), Color(1, 0.9, 0.2))
