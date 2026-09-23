# Blade Dancer Development Log

This is an append-only record of dated project decisions. Current rules live in `res://docs/PROJECT_ART_STYLE_GUIDE.md`; this file records how and when they changed.

## 2026-09-09 — Professional project documentation and Chasm foundation

### Decision

Treat Blade Dancer as a release project with explicit asset organization, documented visual rules, reversible changes, and verification gates.

### Chasm scope

- The Chasm begins as a single open-concept arena.
- The supplied cavern image is the main illustrated background plate.
- Visible art and invisible gameplay collision remain separate.
- Existing Forest, combat, player, enemy, sword, and grapple systems remain untouched by this setup.

### Asset organization

The source image was moved once, before any scene or script references were created:

```text
Before: res://assets/Imported Graphics&Images/Hand-Painted Crystal Cavern Arena.png
After:  res://assets/source/chasm/hand_painted_crystal_cavern_arena.png
```

No existing project references to the old image path were found during setup. The repository already had unrelated in-progress work in its working tree, so this setup did not create a Git commit; the image move remains an uncommitted, independently verifiable change.

### New project records

- `res://docs/PROJECT_ART_STYLE_GUIDE.md` — current human-readable rules and beginner glossary.
- `res://docs/DEVELOPMENT_LOG.md` — this dated history.
- `res://docs/ASSET_MANIFEST.md` — asset inventory and provenance.
- `res://resources/styles/chasm_art_style.gd` — custom Godot Resource class.
- `res://resources/styles/chasm_art_style.tres` — machine-readable Chasm style contract.

### Mentor note

Technical terms should always be introduced in plain English first. Future changes should explain the purpose, risk, verification, and rollback path in bite-sized steps.

## 2026-09-09 — Chasm perimeter collision pass

### Decision

Replace the four coarse Chasm walls with twelve invisible, overlapping rectangle segments that follow the illustrated cavern's walkable floor: a short top span, angled upper corners, stepped side slopes, and a broad lower span. The source artwork remains visual-only; `ChasmBounds` remains the separate gameplay collision body on layer 4.

### Runtime protection

The Chasm is a single full-viewport plate, so its presentation camera is held at the 1280×720 arena center while the player moves. This prevents camera travel from exposing Forest's fallback presentation outside the supplied artwork.

### Verification

- Chasm scene reloads with 12 collision shapes and no configuration warnings.
- `validate_physics_setup` reports no issues for `Player` against `ChasmStage/ChasmBounds`.
- Main scene launches and Adventure navigation reaches Chasm without runtime errors.
- Bounded live movement checks reached the top, left, lower-right, and bottom perimeter without leaving the playable illustrated floor.

### Rollback

The previous four-wall layout remains represented by the preserved editor/conflict copy under `.godot/ziva-sync-conflicts/`; the authored Chasm source image remains untouched under `res://assets/source/chasm/`.

## 2026-09-10 — Chasm spawn and Forest-content isolation

### Decision

Treat the currently saved `ChasmBounds` rectangle segments as the only source of truth for enemy placement. The runtime reads their live endpoints, closes small editor-created gaps with invisible collision bridges, and rejects spawn candidates outside the resulting perimeter or within 52 pixels of a wall.

### Forest isolation

When `active_adventure_zone == "chasm"`, `ArenaGenerator` clears and disables Forest modules, traps, population objects, and their navigation bounds; the outer Forest collision body is disabled as well. Forest regeneration resumes when returning to Forest or Backyard. Chasm also suppresses normal chest spawns and Forest boss props; the existing enemy wave/combat path remains active.

### Verification

- `tests/chasm_boundary_test.gd`: 6 passed, including saved-shape edits, wall clearance, wave-spawn filtering, disabled-generation clearing, and Forest regeneration recovery.
- `tests/terrain_system_test.gd`: 7 passed.
- Bounded live Chasm playtest: two enemy spawn cycles passed the saved-perimeter query; Forest bounds and population counts were zero; traps, mud, and chests were zero; no runtime errors.
