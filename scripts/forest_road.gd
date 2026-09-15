class_name ForestRoad extends Node2D

const PATH_SEGMENT_A: Texture2D = preload("res://assets/generated/forest_path_segment_a_frame_0.png")
const PATH_SEGMENT_B: Texture2D = preload("res://assets/generated/forest_path_segment_b_frame_0.png")
const PATH_SEGMENT_C: Texture2D = preload("res://assets/generated/forest_path_segment_c_frame_0.png")
const PATH_GRASS_TRANSITION: Texture2D = preload("res://assets/generated/forest_path_grass_transition_frame_0.png")
const PATH_SEGMENTS: Array[Texture2D] = [PATH_SEGMENT_A, PATH_SEGMENT_B, PATH_SEGMENT_C]

func _ready() -> void:
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _is_hd_visual() -> bool:
	var current_scene: Node = get_tree().current_scene
	return current_scene != null and str(current_scene.get("visual_style")) == "hd"

func _draw() -> void:
	# HD travel wear is organically blended by ForestFloor's world-space shader.
	# Keep this scene node/class available; neither style needs road stamps here.
	pass
