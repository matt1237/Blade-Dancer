class_name FlowColorUtils extends RefCounted
## Single source of truth for the oscillating two-tone shimmers: the "Flow"
## white<->gold used by the HD body aura, afterimages, sword outline/glow and
## drawn-in motes, and the blue<->white used by the charged Guard hand glow and
## its afterimages. Keeping both here means each presentation breathes in sync.

## Flow ratio (0-1) at which the whole Flow-visual package turns on. Below
## this, none of the aura/afterimage/sword-glow/mote effects are visible.
const ONSET_RATIO: float = 0.4

const LIGHT_TONE: Color = Color(1.0, 0.98, 0.90, 1.0)
const GOLD_TONE: Color = Color(1.0, 0.74, 0.16, 1.0)

## Returns 0 below the onset ratio, ramping linearly to 1 at full Flow.
static func intensity(flow_ratio: float) -> float:
	return clampf((clampf(flow_ratio, 0.0, 1.0) - ONSET_RATIO) / (1.0 - ONSET_RATIO), 0.0, 1.0)

## The shimmering white<->gold color used by every Flow-driven visual.
## Oscillation speed and contrast both grow with flow_ratio so the shimmer
## reads as calm near the onset threshold and lively at max Flow.
static func oscillating_color(time: float, flow_ratio: float) -> Color:
	var eased: float = intensity(flow_ratio)
	var speed: float = lerpf(0.7, 3.4, eased)
	var wave: float = 0.5 + 0.5 * sin(time * speed)
	return LIGHT_TONE.lerp(GOLD_TONE, wave * lerpf(0.35, 1.0, eased))

const CHARGE_BLUE_TONE: Color = Color(0.18, 0.62, 1.0, 1.0)
const CHARGE_WHITE_TONE: Color = Color(0.86, 0.97, 1.0, 1.0)
## How fast the charged Guard's blue<->white shimmer breathes, in radians/second.
const CHARGE_SHIMMER_SPEED: float = 5.0

## The blue<->white shimmer of the charged Guard state -- the charged sibling of
## oscillating_color() above. Guard charge is a binary state rather than a 0-1 flow
## ratio, so this needs no intensity ramp. Returned opaque: callers set their own
## alpha, which is what makes the afterimage trail fade with age.
static func charged_oscillating_color(time: float) -> Color:
	var wave: float = 0.5 + 0.5 * sin(time * CHARGE_SHIMMER_SPEED)
	return CHARGE_BLUE_TONE.lerp(CHARGE_WHITE_TONE, wave)
