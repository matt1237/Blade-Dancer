class_name GameplayBounds extends RefCounted

const DEFAULT_ARENA_RECT: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)

static func arena_rect(scene: Node) -> Rect2:
	if scene != null and scene.has_method("get_gameplay_arena_rect"):
		var scene_rect: Variant = scene.call("get_gameplay_arena_rect")
		if scene_rect is Rect2:
			return scene_rect as Rect2
	return DEFAULT_ARENA_RECT
