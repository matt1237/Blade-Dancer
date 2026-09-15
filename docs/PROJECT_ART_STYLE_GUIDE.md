# Blade Dancer — Project Art & Style Guide

**Status:** Canonical living guide  
**Version:** 0.1  
**Last updated:** 2026-09-09  
**Machine-readable Chasm style:** `res://resources/styles/chasm_art_style.tres`  
**History:** `res://docs/DEVELOPMENT_LOG.md`  
**Asset inventory:** `res://docs/ASSET_MANIFEST.md`

This document records the current visual rules in plain English. When the current rule changes, update this guide and add a dated entry to `DEVELOPMENT_LOG.md`.

## Mentor note: the short version

For now, remember four rules:

1. **Original art stays safe.** We never paint over or replace the source image.
2. **Visible art and invisible gameplay are separate.** A beautiful picture does not decide where the player can walk.
3. **Save reusable rules in one place.** The `.tres` style resource is the Godot-readable version of the rules.
4. **Make one organized change at a time.** Move or rename assets only after checking references and making a Git checkpoint.

## Chasm visual direction

The Chasm is the open-concept mine/cavern area. The first version is a **single arena** built around the supplied illustrated cavern image:

```text
res://assets/source/chasm/hand_painted_crystal_cavern_arena.png
```

The target is an illustrated, atmospheric fantasy cavern that feels like one authored place rather than a collection of unrelated tiles. The first prototype uses the image as a background plate. Later work may recreate selected rocks, crystals, supports, ledges, and mine objects as modular transparent assets.

### Current scope

- One arena.
- One main illustrated background plate.
- Invisible perimeter collision.
- Existing player, enemies, sword, grapple, and combat remain reusable.
- Decorative objects do not block movement unless they receive an intentional gameplay footprint.
- Chasm work must not change Forest behavior without an explicit decision.

## Visual layer rules

The Chasm should be assembled conceptually in this order:

1. **Background:** the large cavern illustration.
2. **Decorations:** crystals, rocks, rails, supports, lanterns, and other scenery.
3. **Actors:** player, enemies, projectiles, and combat effects.
4. **Foreground:** art intentionally drawn in front of an actor for depth.
5. **Gameplay collision:** invisible shapes that define movement and blocking.

### Beginner glossary

- **Z-order / z-index:** which things are drawn in front of or behind other things. It is not a group of space knights.
- **Collision:** invisible gameplay geometry that stops or detects movement.
- **Background plate:** one large image used as the visual foundation of a scene.
- **Modular prop:** a reusable object, such as one crystal cluster or mine support.
- **Scene / prefab:** a reusable object template in Godot.
- **Resource:** a reusable data file. A `.tres` file is Godot's text-based Resource format.
- **Texture filtering:** whether image pixels stay crisp or become smoothed.
- **Occlusion:** one visual layer hiding part of another to create depth.
- **Source asset:** the untouched original reference file.
- **Generated asset:** a derivative made for use in the game. It must not replace the source asset.
- **Gameplay footprint:** the invisible area used for placement, navigation, or collision.

## Asset organization

```text
res://assets/source/chasm/       untouched reference images
res://assets/generated/chasm/    approved derived/generated art
res://resources/styles/           machine-readable style resources
res://scenes/chasm/              Chasm scenes and reusable props
res://scripts/chasm/             Chasm-specific behavior
res://docs/                      human-readable rules, history, and inventory
```

The source image must remain at its current stable path unless we deliberately perform an asset migration:

```text
res://assets/source/chasm/hand_painted_crystal_cavern_arena.png
```

If an asset must move or be renamed:

1. Make a Git checkpoint first.
2. Move it through Godot's FileSystem dock when possible.
3. Search for old path references.
4. Reopen affected scenes/resources.
5. Run the relevant tests and a bounded playtest.
6. Record the migration in the development log.

## `.tres` authority

`res://resources/styles/chasm_art_style.tres` is the machine-readable runtime contract. It references the source image and stores settings such as scale, tint, layer order, and collision policy.

This Markdown guide is the human-readable explanation. The development log is historical and does not override the current guide. If the two disagree, update the guide and `.tres` together, then record why in the log.

## AI-assisted art rules

- Use the source image as a reference, not as disposable prompt material.
- Keep the original source file unchanged.
- Generate one asset family at a time using the approved reference and style rules.
- Inspect new assets at their actual in-game scale.
- Do not wire a generated asset into gameplay until its scale, orientation, filtering, and layering are verified.
- Separate art extraction from collision authoring. Never assume visible pixels are valid collision geometry.

## Change protocol

When adding or changing Chasm art, document:

- What changed
- Why it changed
- Which source/reference was used
- Which files were added or changed
- Whether it affects collision, navigation, or gameplay
- How it was verified
- How to undo it

## Open decisions

- Final Chasm palette extraction
- Whether the background should be static or have subtle animated layers
- Which visible structures deserve modular prop assets
- Whether any interior ledges or pillars should block movement
- Final atmosphere settings after the source image is previewed in-game
