class_name PXModeTabTest extends Node

## The shared gateway at the top of Training Tools chooses OS Mode (the game's
## authored sword) or PX Mode (the physics sword), and swaps which tab set is
## shown. These checks pin the contract: the gateway exists, it defaults to OS,
## flipping it persists into the PX prototype's OWN save and never writes the
## game's preset save, and the two tab sets swap. The PX save is captured and
## restored so the test can never leave stray data behind.

const PX_SAVE_PATH: String = "user://bdpx_global.json"
const PRESET_SAVE_PATH: String = "user://blade_dancer_global_presets.json"

func _read_or_empty(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	return ""

func _restore(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()

func test_gateway_switches_modes_persists_to_px_save_and_swaps_tab_sets() -> void:
	var had_px_save: bool = FileAccess.file_exists(PX_SAVE_PATH)
	var px_original: String = _read_or_empty(PX_SAVE_PATH)
	var preset_before: String = _read_or_empty(PRESET_SAVE_PATH)
	# Start from a known clean PX state so the default is deterministic.
	BDPXGlobal.clear_save()

	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	add_child(menu)
	var training_tabs: TabContainer = menu.get_node("Panel/TunerRoot/TrainingTabs") as TabContainer
	var px_tabs: TabContainer = menu.get_node("Panel/TunerRoot/PXTabs") as TabContainer
	var header: Control = menu.get_node("Panel/TunerRoot/ModeHeader") as Control
	var os_button: Button = header.find_child("PXModeOS", true, false) as Button
	var px_button: Button = header.find_child("PXModePX", true, false) as Button
	assert(os_button != null and px_button != null, "The gateway must offer an OS button and a PX button.")
	assert(training_tabs.get_node_or_null("PX Motor") == null, "The OS tab set must not contain physics-tuner tabs.")
	assert(px_tabs.get_node_or_null("PX Motor") != null, "PX Mode must own the physics-tuner tab set.")
	# Default is OS Mode: OS is the active (disabled) choice, the OS tabs are shown.
	assert(os_button.disabled and not px_button.disabled, "It must default to OS Mode until deliberately switched.")
	assert(training_tabs.visible and not px_tabs.visible, "OS Mode must show the game's tab set.")

	# Selecting PX persists into the PX prototype's own save and swaps the tab set.
	px_button.pressed.emit()
	assert(bool(BDPXGlobal.load_settings().get("px_mode", false)), "Selecting PX must persist px_mode=true in the PX save.")
	assert(px_button.disabled and not os_button.disabled, "Selecting PX must mark PX as the active mode.")
	assert(px_tabs.visible and not training_tabs.visible, "PX Mode must show the physics-tuner tab set.")
	assert(FileAccess.file_exists(PX_SAVE_PATH), "Switching mode must write the PX save.")
	assert(_read_or_empty(PRESET_SAVE_PATH) == preset_before, "PX Mode must never write the game's preset save.")

	# Returning to OS Mode persists too, and restores the game's tab set.
	os_button.pressed.emit()
	assert(not bool(BDPXGlobal.load_settings().get("px_mode", true)), "Returning to OS Mode must persist px_mode=false.")
	assert(training_tabs.visible and not px_tabs.visible, "OS Mode must show the game's tab set again.")

	# Every PX control carries the full BDOS guidance contract, and the Flesh &
	# Core material knobs are present.
	for expected_key: String in ["stiffness", "helicopter_limit", "sword_mass", "sword_angular_damp", "sword_linear_damp", "com_offset", "flesh_radius", "core_radius", "flesh_drag", "bone_friction", "enemy_mass", "chaser_wanted"]:
		assert(menu.px_controls.has(expected_key), "The PX tuner must expose a control for %s." % expected_key)
	for control_key: String in menu.px_controls.keys():
		var control: Control = menu.px_controls[control_key] as Control
		var tip: String = control.tooltip_text
		assert(tip.contains("WHAT IT IS") and tip.contains("FEELS LIKE") and tip.contains("← LEFT:") and tip.contains("→ RIGHT:") and tip.contains("TIP:"), "PX control %s must carry the 4-part definition/feel/left/right/tip tooltip." % control_key)

	# Regrouped to match the OS Combat Preset: the Swing/Metronome mode has its own
	# tab, and no standalone Ghost tab.
	var tab_titles: Array = []
	for i: int in range(px_tabs.get_tab_count()):
		tab_titles.append(px_tabs.get_tab_title(i))
	assert(tab_titles == ["PX Motor", "PX Metronome", "PX Aim & Hand", "PX Enemies", "PX Flesh & Core"], "PX tabs must be the grouped tabs including the new PX Metronome tab; found %s." % [tab_titles])
	assert(px_tabs.get_node_or_null("PX Metronome") != null, "The metronome must live on its own dedicated tab.")
	var meta_note_ok: bool = false
	for node: Node in (px_tabs.get_node("PX Metronome") as Node).find_children("*", "Label", true, false):
		if (node as Label).text.contains("ONLY while Metronome Swing is ON"):
			meta_note_ok = true
	assert(meta_note_ok, "The PX Metronome tab must explain that Arc/Frequency/Lead are dormant unless the swing is ON.")
	# Every PX control is a BDOS-style slider -- binaries included -- so nothing in
	# the tuner is a toggle button (consistent with the OS Combat Preset).
	for control_key: String in menu.px_controls.keys():
		assert(menu.px_controls[control_key] is HSlider, "PX control %s must be a slider (binaries use a 0-1 slider like BDOS), not a button." % control_key)
	# Every PX control carries the OS-style [?] badge in its title row.
	var heli_control: Control = menu.px_controls["helicopter_limit"] as Control
	var title_row: HBoxContainer = heli_control.get_parent().get_child(0) as HBoxContainer
	var has_badge: bool = false
	for child: Node in title_row.get_children():
		if child is Label and (child as Label).text == "[?]":
			has_badge = true
	assert(has_badge, "Every PX control must carry the [?] badge, exactly like the OS sliders.")

	# The in-game PX tuner offers an explicit BDPX save/load affordance (like the lab's
	# Global tab) plus a "last saved" readout, even though controls auto-save too.
	assert(menu.px_saved_label != null, "The PX tuner must show a last-saved readout.")
	var motor_tab_node: Node = px_tabs.get_node("PX Motor")
	var has_save: bool = false
	var has_load: bool = false
	for node: Node in motor_tab_node.find_children("*", "Button", true, false):
		if (node as Button).text == "Save Settings":
			has_save = true
		elif (node as Button).text == "Load Saved":
			has_load = true
	assert(has_save and has_load, "The PX tuner must offer a Save Settings and a Load Saved button for BDPX.")

	# Core Sword & Reach: because PX now OWNS its aim feel, the aim-inertia knobs live
	# at the top of the PX Aim & Hand tab as their own section (distinct from the OS
	# menu's same-named section, which edits the game's own hand settings).
	var aim_tab_node: Node = px_tabs.get_node("PX Aim & Hand")
	var core_reach_found: bool = false
	for node: Node in aim_tab_node.find_children("*", "Button", true, false):
		if (node as Button).text.contains("Core Sword & Reach"):
			core_reach_found = true
	assert(core_reach_found, "The PX Aim & Hand tab must carry a Core Sword & Reach section header.")
	for expected_aim_key: String in ["aim_inertia_on", "mouse_drag", "rotation_speed", "max_turn_speed_deg"]:
		assert(menu.px_controls.has(expected_aim_key), "The PX tuner must expose the Core Sword & Reach control '%s'." % expected_aim_key)
	menu.free()

	# Restore whatever the PX save looked like before this test.
	BDPXGlobal.clear_save()
	if had_px_save:
		_restore(PX_SAVE_PATH, px_original)