extends Node2D

## Static phase contact sheet, not a gameplay simulation or animation clock.
func _ready() -> void:
	var phases: Array[float] = [0.0, 0.3, 0.5, 0.65, 1.0]
	var captions: Array[String] = ["WHITE REST", "INWARD WINDUP", "BEAT / GOLD PEAK", "OUTWARD RELEASE", "WHITE RECOVERY"]
	for i: int in range(phases.size()):
		var visualizer: MetronomeVisualizer = MetronomeVisualizer.new()
		add_child(visualizer)
		visualizer.set_process(false)
		visualizer.position = Vector2(115.0 + i * 215.0, 220.0)
		visualizer._update_visual(phases[i])
		var label: Label = Label.new()
		label.text = captions[i]
		label.position = Vector2(40.0 + i * 215.0, 330.0)
		add_child(label)
