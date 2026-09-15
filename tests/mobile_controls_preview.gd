class_name MobileControlsPreview extends Control

const MOBILE_CONTROLS_SCENE: PackedScene = preload("res://scenes/ui/mobile_controls.tscn")

func _ready() -> void:
	var controls: MobileControls = MOBILE_CONTROLS_SCENE.instantiate() as MobileControls
	controls.force_visible_on_desktop = true
	add_child(controls)
	controls.set_gameplay_visible(true)
