# Blade Dancer Asset Manifest

This file records important asset locations, provenance, and intended use. It is not a replacement for the Godot `.tres` resources; it explains the asset lifecycle for humans.

## Status vocabulary

- **Source:** untouched original/reference material.
- **Generated:** created or derived during development; not automatically production-approved.
- **Production:** verified for use in the shipped game.
- **Legacy:** retained for compatibility or comparison; do not use as a new source without a deliberate decision.

## Chasm

| Asset | Status | Intended use | Notes |
|---|---|---|---|
| `res://assets/source/chasm/hand_painted_crystal_cavern_arena.png` | Source | Main Chasm visual reference and first background plate | Keep untouched; use `res://resources/styles/chasm_art_style.tres` for project references. |
| `res://resources/styles/chasm_art_style.tres` | Production config | Machine-readable Chasm presentation rules | References the source image; does not replace it. |

## Future Chasm asset families

These entries are placeholders until the source image is formally deconstructed:

- `res://assets/generated/chasm/background/` — derived background exports.
- `res://assets/generated/chasm/props/` — isolated crystals, rocks, supports, rails, and other reusable art.
- `res://scenes/chasm/props/` — reusable Godot scenes for approved props.

## Asset change policy

Before moving or renaming an asset already referenced by a scene, script, or resource:

1. Make a Git checkpoint.
2. Prefer the Godot FileSystem dock.
3. Search for the old path.
4. Verify imports and references.
5. Run tests and a bounded scene check.
6. Add a dated entry to `DEVELOPMENT_LOG.md`.
