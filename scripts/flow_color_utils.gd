class_name FlowColorUtils extends RefCounted
## Single source of truth for the "Flow" white<->gold shimmer used by the HD
## body aura, afterimages, sword outline/glow, and drawn-in motes, so every
## piece of the Flow presentation breathes in sync.

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
