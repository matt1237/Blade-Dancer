class_name CombatTuningSchema

## Runtime Sword Tuner schema. Every value is saved independently per sword style.
const PARAM_SECTIONS: Array = [
	{"title": "Sword Rhythm", "params": [
		{"key":"swing_frequency", "label":"Frequency", "default":0.6, "min":0.05, "max":2.0, "step":0.01, "suffix":" cycles/s", "is_toggle":false, "tooltip":"Autonomous back-and-forth swing frequency."},
		{"key":"arc_degrees", "label":"Base Arc", "default":100.0, "min":20.0, "max":220.0, "step":1.0, "suffix":"°", "is_toggle":false, "tooltip":"The normal angular width of each swing."},
		{"key":"max_arc_degrees", "label":"Max Arc", "default":112.0, "min":20.0, "max":300.0, "step":1.0, "suffix":"°", "is_toggle":false, "tooltip":"Upper arc limit when the swing is fully opened by input."},
		{"key":"rotation_speed", "label":"Rotational Response", "default":10.0, "min":1.0, "max":30.0, "step":0.1, "suffix":"", "is_toggle":false, "tooltip":"How quickly the sword aim follows the mouse."}
	]},
	{"title": "Mouse Influence", "params": [
		{"key":"angular_influence_strength", "label":"Angular Influence Strength", "default":1.0, "min":0.0, "max":3.0, "step":0.05, "suffix":"x", "is_toggle":false, "tooltip":"How strongly mouse angular movement feeds or fights the swing."},
		{"key":"angular_influence_cap", "label":"Angular Influence Cap", "default":1.0, "min":0.1, "max":3.0, "step":0.05, "suffix":"x", "is_toggle":false, "tooltip":"Maximum normalized mouse influence."},
		{"key":"counter_swing_resistance", "label":"Counter-Swing Resistance", "default":6.0, "min":0.0, "max":20.0, "step":0.5, "suffix":"", "is_toggle":false, "tooltip":"Resistance and tension build while deliberately fighting the autonomous swing."},
		{"key":"stored_tension", "label":"Stored Tension", "default":35.0, "min":0.0, "max":90.0, "step":1.0, "suffix":"°", "is_toggle":false, "tooltip":"Maximum disagreement the sword can store before releasing."},
		{"key":"tension_release_multiplier", "label":"Tension Release Multiplier", "default":12.0, "min":1.0, "max":40.0, "step":0.5, "suffix":"x", "is_toggle":false, "tooltip":"How quickly stored counter-swing tension unloads."}
	]},
	{"title": "Hand", "params": [
		{"key":"hand_distance_min", "label":"Min Radius", "default":30.0, "min":5.0, "max":120.0, "step":1.0, "suffix":" px", "is_toggle":false, "tooltip":"Closest hand radius. Mouse distance is clamped upward to this value."},
		{"key":"hand_distance_max", "label":"Max Radius", "default":30.0, "min":5.0, "max":180.0, "step":1.0, "suffix":" px", "is_toggle":false, "tooltip":"Farthest hand radius. Mouse distance is clamped downward to this value."},
		{"key":"radial_response", "label":"Radial Response", "default":1.0, "min":0.0, "max":2.0, "step":0.05, "suffix":"x", "is_toggle":false, "tooltip":"How directly mouse distance controls hand radius."},
		{"key":"radial_smoothing", "label":"Radial Smoothing", "default":0.0, "min":0.0, "max":30.0, "step":0.5, "suffix":"", "is_toggle":false, "tooltip":"Additional smoothing on radial hand movement. Zero is immediate."},
		{"key":"hand_velocity_influence", "label":"Hand Positional Influence on Sword Velocity", "default":1.0, "min":0.0, "max":2.0, "step":0.05, "suffix":"x", "is_toggle":false, "tooltip":"How much hand translation contributes to blade velocity."}
	]},
	{"title": "Physical Feel", "params": [
		{"key":"sword_inertia", "label":"Sword Inertia", "default":1.0, "min":0.0, "max":3.0, "step":0.05, "suffix":"x", "is_toggle":false, "tooltip":"How much the blade resists instant changes."},
		{"key":"angular_damping", "label":"Angular Damping", "default":1.0, "min":0.0, "max":3.0, "step":0.05, "suffix":"x", "is_toggle":false, "tooltip":"How quickly rotational motion settles."},
		{"key":"follow_through", "label":"Follow-Through", "default":1.0, "min":0.0, "max":3.0, "step":0.05, "suffix":"x", "is_toggle":false, "tooltip":"How strongly motion continues after a mouse whip."},
		{"key":"reversal_resistance", "label":"Reversal Resistance", "default":0.0, "min":0.0, "max":2.0, "step":0.05, "suffix":"x", "is_toggle":false, "tooltip":"Resistance as the autonomous swing reverses direction."},
		{"key":"max_tip_velocity", "label":"Max Tip Velocity", "default":1800.0, "min":100.0, "max":4000.0, "step":25.0, "suffix":" px/s", "is_toggle":false, "tooltip":"Hard cap on blade tip velocity."}
	]},
	{"title": "Impact", "params": [
		{"key":"hitstop", "label":"Hitstop", "default":0.06, "min":0.0, "max":0.3, "step":0.005, "suffix":" s", "is_toggle":false, "tooltip":"Freeze time on a flesh hit."},
		{"key":"enemy_recoil", "label":"Enemy Recoil", "default":180.0, "min":0.0, "max":600.0, "step":10.0, "suffix":"", "is_toggle":false, "tooltip":"Force applied to enemies on a sword hit."},
		{"key":"blade_hesitation", "label":"Blade Hesitation on Flesh", "default":0.035, "min":0.0, "max":0.2, "step":0.005, "suffix":" s", "is_toggle":false, "tooltip":"Brief blade resistance after cutting flesh."},
		{"key":"clash_impulse", "label":"Clash Impulse", "default":230.0, "min":0.0, "max":700.0, "step":10.0, "suffix":"", "is_toggle":false, "tooltip":"Pushback created by a sword clash."},
		{"key":"slide_threshold", "label":"Slide Threshold", "default":60.0, "min":0.0, "max":90.0, "step":1.0, "suffix":"°", "is_toggle":false, "tooltip":"Angle threshold for a blade slide instead of a direct clash."}
	]},
	{"title": "Weapon Bind", "params": [
		{"key":"bind_enabled", "label":"Enabled", "default":0.0, "min":0.0, "max":1.0, "step":1.0, "suffix":"", "is_toggle":true, "tooltip":"Allow active enemy weapons to lock against your weapon in a bind."},
		{"key":"bind_chance", "label":"Bind Chance", "default":0.5, "min":0.0, "max":1.0, "step":0.05, "suffix":"", "is_toggle":false, "tooltip":"Chance that a valid weapon clash becomes a bind."},
		{"key":"bind_duration", "label":"Bind Duration", "default":1.1, "min":0.2, "max":3.0, "step":0.05, "suffix":" s", "is_toggle":false, "tooltip":"How long the weapon bind lasts without a dash break."},
		{"key":"bind_break_damage", "label":"Break Damage", "default":18.0, "min":0.0, "max":60.0, "step":1.0, "suffix":"", "is_toggle":false, "tooltip":"Damage dealt when dashing out of a weapon bind."},
		{"key":"bind_break_knockback", "label":"Break Knockback", "default":260.0, "min":0.0, "max":600.0, "step":10.0, "suffix":"", "is_toggle":false, "tooltip":"Force applied to the bound enemy when breaking free."},
		{"key":"bind_break_stagger", "label":"Break Stagger", "default":0.5, "min":0.0, "max":2.0, "step":0.05, "suffix":" s", "is_toggle":false, "tooltip":"Enemy stagger duration after a dash break."},
		{"key":"bind_break_hitstop", "label":"Break Hitstop", "default":0.05, "min":0.0, "max":0.3, "step":0.005, "suffix":" s", "is_toggle":false, "tooltip":"Hitstop when the bind is broken."}
	]}
]

static func is_core_param(param_key: String) -> bool:
	return param_key in ["arc_degrees", "swing_frequency", "rotation_speed", "hand_distance_min", "hand_distance_max"]

static func default_value(param_key: String) -> float:
	for section: Dictionary in PARAM_SECTIONS:
		for param: Dictionary in section["params"]:
			if param["key"] == param_key:
				return param["default"]
	return 0.0

static func all_keys() -> Array[String]:
	var keys: Array[String] = []
	for section: Dictionary in PARAM_SECTIONS:
		for param: Dictionary in section["params"]:
			keys.append(param["key"] as String)
	return keys
