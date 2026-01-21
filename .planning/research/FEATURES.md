# Feature Landscape: Room/Building Editors in Simulation Games

**Domain:** Mobile theater/venue simulation with isometric grid-based building
**Researched:** 2026-01-21
**Overall confidence:** MEDIUM (good ecosystem understanding, some mobile-specific gaps)

## Executive Summary

Room/building editors in simulation games fall into clear patterns: **selection-based manipulation** (select, move, resize, delete), **visual feedback systems** (ghost previews, validation indicators), and **constraint management** (costs, requirements, spatial rules). Mobile implementations prioritize **immediate touch feedback** and **clear visual states** over complex modal dialogs.

**Critical insight for TheaterCity:** Players expect to **edit after building** (not just build-once), and expect **visual confirmation before committing** (ghost preview, cost display, validation feedback). The existing draw-box → place-doors workflow is good for initial creation, but editing requires different interaction patterns.

---

## Table Stakes Features

Features users expect in any building editor. Missing = product feels incomplete or frustrating.

| Feature | Why Expected | Complexity | Mobile Considerations | Phase |
|---------|--------------|------------|----------------------|-------|
| **Select existing room** | Can't edit without selecting | LOW | Large touch targets (min 44x44dp), visual highlight | Phase 1 |
| **Delete room** | Mistakes happen, plans change | LOW | Confirmation prompt, undo support | Phase 1 |
| **Visual selection feedback** | User needs to know what's selected | LOW | Highlight/outline, distinct color | Phase 1 |
| **Undo/Redo** | Players fear irreversible mistakes | MEDIUM | Touch-friendly undo button, gesture support | Phase 2 |
| **Ghost preview placement** | See before committing | MEDIUM | Semi-transparent preview, valid/invalid states | Phase 1 |
| **Cost display before placement** | Budget management critical | LOW | Always-visible cost indicator | Phase 1 |
| **Validation feedback** | Know why placement failed | MEDIUM | Visual + text explanation (size, furniture, doors) | Phase 2 |
| **Grid snapping** | Align to isometric grid | LOW | Already implemented via tile coordinates | Exists |
| **Move furniture** | Rearrange without rebuilding | MEDIUM | Drag gesture, grid snap, collision detection | Phase 2 |
| **Delete furniture** | Remove unwanted items | LOW | Tap-select then delete, or hold-to-delete | Phase 2 |
| **Add furniture to existing room** | Expand room functionality | MEDIUM | Placement mode, ghost preview, cost display | Phase 2 |
| **Persistent save** | Changes must survive restart | MEDIUM | Save to file/database, load on startup | Phase 3 |
| **Visual feedback for invalid states** | Clear red/gray for "can't place here" | LOW | Color change, visual indicator, haptic feedback | Phase 1 |

### Why These Are Table Stakes

**Selection/deletion:** [Two Point Hospital](https://two-point-hospital.fandom.com/wiki/Rooms) allows room editing via select → edit button. [Prison Architect](https://prisonarchitect.paradoxwikis.com/Room) supports room deletion and modification. Players in 2026 expect "I built it wrong, let me fix it" as baseline.

**Visual feedback:** [Research shows](https://www.bravezebra.com/blog/visual-feedback-game-design/) instant visual responses affirm player actions and encourage experimentation. Ghost previews are standard in [Minecraft](https://www.curseforge.com/minecraft/mc-mods/placement-preview), [Factorio](https://forums.factorio.com/viewtopic.php?t=117176), and [The Sims 4](https://gamerant.com/sims-4-build-mode-tips-guide/).

**Undo/Redo:** [Considered essential](https://help.magicplan.app/undo) for editing tools. [Users edit without fear](https://dev.to/timbeaudet/crafting-games-building-a-custom-editor-with-undoredo-support-500i) when undo exists. Mobile touch interfaces are imprecise—undo is even more critical.

**Cost display:** [Construction and management sims](https://en.wikipedia.org/wiki/Construction_and_management_simulation) require maintaining positive budget balance. [Budget simulation games](https://www.fastercapital.com/content/Budget-Simulation--How-to-Use-Budget-Games-and-Exercises-to-Enhance-Your-Budgeting-Skills.html) show that real-time cost feedback is cornerstone of player understanding.

**Persistence:** Obviously required. Players expect saved games in 2026.

---

## Differentiators

Features that set products apart. Not expected baseline, but add significant value.

| Feature | Value Proposition | Complexity | Mobile Considerations | Priority |
|---------|-------------------|------------|----------------------|----------|
| **Resize existing room** | Fix mistakes without rebuild | HIGH | Two-finger pinch gesture, or drag-corner handles | High |
| **Room templates** | Speed up repetitive building | MEDIUM | Save/load room configurations with furniture | Medium |
| **Copy/paste rooms** | Duplicate successful layouts | MEDIUM | Tap-to-copy, tap-to-paste workflow | High |
| **Rotate furniture** | Fine-tune layout | LOW | Two-finger rotation gesture, or rotation button | High |
| **Multi-select** | Bulk operations (delete, move) | HIGH | Drag box selection, shift-tap equivalent | Low |
| **Build mode toggle** | Separate edit from play | LOW | Persistent toggle button, different camera behavior | Medium |
| **Cost breakdown tooltip** | Understand expenses | LOW | Long-press for detailed cost (walls, doors, furniture) | Medium |
| **Validation preview** | See requirements before building | MEDIUM | "Room needs: 2 more chairs" live feedback | High |
| **Collision preview** | See what blocks placement | MEDIUM | Show overlapping entities in red | Medium |
| **Floor/wall customization** | Aesthetic personalization | HIGH | Pattern picker UI, preview before applying | Low |
| **Furniture quick-add menu** | Fast furniture placement | LOW | Context menu when room selected | High |
| **Zoom to fit room** | Navigate large venues | LOW | Double-tap room to zoom and center | Low |

### Why These Differentiate

**Resize:** [Two Point Hospital](https://gamefaqs.gamespot.com/pc/230622-two-point-hospital/faqs/76595/room-templates) lets you add/remove space with add/remove blueprint buttons. This is *advanced* functionality—many sims don't support it.

**Templates/Copy-paste:** [GameMaker room editor](https://manual.gamemaker.io/monthly/en/The_Asset_Editors/Rooms.htm) supports copy/paste selections. [Dwarf Fortress players request this](https://steamcommunity.com/app/975370/discussions/0/3716062978749219339/) because repetitive building is tedious. Templates were added to Two Point Hospital in [Version 1.11](https://two-point-hospital.fandom.com/wiki/Rooms) addressing "lack of copy rooms" criticism.

**Rotation:** [The Sims 4](https://gamerant.com/sims-4-build-mode-tips-guide/) supports furniture rotation (arrow keys on PC). [ESO Housing](https://esoui.com/downloads/info1944-FurnitureSnap.html) and [FFXIV Housing](https://hgxiv.com/basics-guide/) have configurable rotation snap increments. Common but not universal.

**Build mode toggle:** [Unreal Engine's Play vs Simulate](https://dev.epicgames.com/documentation/en-us/unreal-engine/playing-and-simulating-in-unreal-engine) distinction, or [Unity's Edit vs Play mode](https://docs.unity3d.com/Manual/GameView.html). Separates "arranging things" from "experiencing simulation."

**Validation preview:** Live feedback like ["Room needs: 2 more chairs"](https://pvigier.github.io/2022/11/05/room-generation-using-constraint-satisfaction.html) helps players meet requirements without trial-and-error. Goes beyond binary valid/invalid.

---

## Anti-Features

Features to explicitly NOT build. Common mistakes or scope traps.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Free-form drawing (non-grid)** | Breaks isometric rendering, complicates pathfinding | Keep grid-based tile system, allow any rectangular bounding box |
| **Nested modal dialogs** | [Modal overuse annoying](https://www.eleken.co/blog-posts/modal-ux), [nested modals too complex](https://blog.logrocket.com/ux-design/modal-ux-design-patterns-examples-best-practices/) | Use bottom sheets, inline editing, or single confirmation dialog |
| **Pixel-precise dragging** | Touch input imprecise, fingers obscure target | Snap to grid, use drag-offset (item under finger offset up) |
| **Tiny touch targets** | [Mobile needs 44x44dp minimum](https://developer.mozilla.org/en-US/docs/Games/Techniques/Control_mechanisms/Mobile_touch) | Large buttons, generous tap areas, visual spacing |
| **Hidden validation rules** | Player builds, wonders why invalid | Always show requirements, live feedback during construction |
| **Multi-step furniture placement** | Tap furniture → confirm type → drag → confirm rotation → confirm placement = 5 steps | Single drag from palette with rotation gesture while dragging |
| **Undo without redo** | Players overshoot, want to go forward again | Implement both or neither (redo is cheap once undo exists) |
| **Auto-save without undo** | Irreversible mistakes, player frustration | Manual save checkpoints, or auto-save + undo history |
| **Edit during simulation** | State conflicts (patron in room being deleted) | Separate build mode, pause simulation during edits, or queue changes |
| **Complex gesture combos** | [Gestures hard to guess](https://gamemaker.io/en/tutorials/gesture-events), [many unintuitive](https://www.gamedeveloper.com/design/using-gestures-in-mobile-game-design) | Stick to standard gestures (tap, drag, pinch-zoom), provide alternative button controls |
| **Background furniture placement** | Can't see behind UI, finger obscures view | Use transparent preview, offset item above finger, zoom/pan before placement |

### Why These Are Anti-Features

**Non-grid free-form:** Prison Architect and Two Point Hospital both use grid systems. Free-form looks flexible but creates pathfinding nightmares and rendering complexity for isometric views.

**Modal overuse:** [Common mistake](https://www.nngroup.com/articles/modal-nonmodal-dialog/) is interrupting users unnecessarily. [Developers overuse modals](https://medium.com/design-bootcamp/ux-blueprint-09-modal-and-non-modal-components-in-ui-design-why-they-matter-75e6ffb62946) to the point users dismiss on instinct.

**Touch precision:** [Mobile players expect immediate, accurate responses](https://blog.nashtechglobal.com/mobile-game-testing-touch-gesture-testing/). [Poor touch handling = frustration and abandonment](https://saropa-contacts.medium.com/2025-guide-to-haptics-enhancing-mobile-ux-with-tactile-feedback-676dd5937774).

**Edit during simulation:** Leads to edge cases: "What if patron walks through door being deleted?" "What if furniture moved while patron using it?" Cleanest solution is build mode toggle.

---

## Feature Dependencies

Visual representation of what must be built first:

```
Foundation (Exists):
├── Grid system (Vector2i coordinates)
├── Room creation (draw-box, doors, furniture)
└── Room type constraints (min/max size, required furniture)

Phase 1 (Selection & Basic Editing):
├── Room selection (tap to select)
│   ├── Visual selection feedback (highlight)
│   └── Cost display (for existing rooms)
├── Ghost preview (for validation)
└── Room deletion (with confirmation)

Phase 2 (Furniture & Undo):
├── Furniture manipulation (requires Room selection)
│   ├── Move furniture (drag with grid snap)
│   ├── Delete furniture (tap-select → delete)
│   ├── Add furniture (placement mode)
│   └── Rotate furniture (gesture or button)
├── Undo/Redo system (affects all operations)
└── Validation feedback (live requirements display)

Phase 3 (Persistence):
├── Save system (requires all editing operations complete)
└── Load system (restore room state on startup)

Advanced (Differentiators):
├── Resize room (requires Room selection, complex)
├── Copy/paste rooms (requires Room selection)
├── Room templates (requires Copy/paste)
└── Build mode toggle (isolates editing from simulation)
```

**Critical path:** Selection → Delete → Move furniture → Undo → Save

**Why this order:**
1. **Selection first:** Can't edit without selecting. Simplest operation, validates touch input pipeline.
2. **Delete before resize:** Deleting simpler than resizing (no validation complexity). Players can rebuild if needed.
3. **Furniture before resize:** More common operation, clearer interaction model.
4. **Undo after operations exist:** Need something to undo. Implement after 3-4 operations to understand command pattern.
5. **Save last:** Pointless to persist if editing incomplete. Validate editing workflows first.

---

## MVP Recommendation

For minimal viable editing (players can fix mistakes, persist changes):

### Must Have (Phase 1):
1. **Room selection** - Tap room → highlight selection
2. **Room deletion** - Delete button → confirmation → remove room
3. **Ghost preview** - Visual feedback for valid/invalid placement during creation
4. **Cost display** - Always show cost of selected/preview room
5. **Visual validation feedback** - Red/green indicators for placement validity

### Should Have (Phase 2):
6. **Move furniture** - Drag furniture within room, snap to grid
7. **Add furniture to room** - Placement mode for existing rooms
8. **Delete furniture** - Remove individual furniture pieces
9. **Rotate furniture** - 4-direction rotation (North/East/South/West)
10. **Undo/Redo** - One-level undo minimum, expand to stack later

### Must Have (Phase 3):
11. **Persistent save/load** - Changes survive app restart

### Defer to Post-MVP:
- **Resize room:** HIGH complexity, players can delete+rebuild
- **Copy/paste rooms:** Nice-to-have, not critical for fixing mistakes
- **Room templates:** Requires copy/paste foundation
- **Multi-select:** Complex interaction model, single operations sufficient
- **Floor/wall customization:** Pure aesthetics, no gameplay impact
- **Build mode toggle:** Can defer if simulation handles in-progress edits gracefully

---

## Mobile Touch UX Patterns

Key interaction patterns for mobile building editors:

### Selection Pattern
```
Tap room → Visual highlight + Show room info panel
- Panel shows: Type, size, cost, furniture count
- Panel actions: Delete, Edit (enter edit mode), View requirements
```

### Drag-to-Move Pattern
```
Long-press furniture → Enter drag mode → Drag → Release to place
- Visual: Item follows finger with offset (visible above finger)
- Feedback: Green outline = valid, Red outline = invalid (collision/out-of-bounds)
- Haptic: Vibrate on snap-to-grid, error vibration on invalid drop
```

### Rotation Pattern (Two Options)
```
Option A: Rotation button
- Tap furniture → Show rotation button → Tap to rotate 90° clockwise

Option B: Two-finger rotation gesture
- Pinch-rotate while dragging furniture → Snap to 90° increments
- More intuitive but requires gesture tutorial
```

### Validation Feedback Pattern
```
During placement:
- Ghost preview (semi-transparent)
- Valid state: Green tint
- Invalid state: Red tint + Reason text ("Too small", "Missing required door")
- Cost display: Floating next to ghost
```

### Undo/Redo Pattern
```
Persistent undo/redo buttons (top-left or bottom-right)
- Disabled (grayed) when unavailable
- Show operation name on long-press ("Undo: Delete Room")
- Alternative: Two-finger swipe left = undo, right = redo
```

### Confirmation Pattern
```
Delete operations:
- Bottom sheet (not modal) slides up
- "Delete [Room Type]? This cannot be undone."
- Actions: Cancel (large, left) | Delete (red, right)
- Alternative: Undo instead of confirmation (faster, less disruptive)
```

### Expected Touch Gestures (Standard)
| Gesture | Purpose | Standard Usage |
|---------|---------|----------------|
| **Tap** | Select object | Single finger, quick touch |
| **Long-press** | Enter drag mode, show context menu | Hold 500ms+ |
| **Drag** | Move object | After long-press or from palette |
| **Pinch-zoom** | Zoom camera | Two fingers, spread/contract |
| **Two-finger drag** | Pan camera | Two fingers, parallel movement |
| **Two-finger rotate** | Rotate object (optional) | Two fingers, circular motion |

**Critical:** [Mobile players expect instant feedback](https://www.yellowbrick.co/blog/animation/top-tips-for-mobile-game-touch-interface-design) - haptic response within milliseconds, visual change immediate. [Delays disrupt experience](https://hypersense-software.com/blog/2024/07/15/haptic-technology-user-experience/).

---

## Isometric Grid Considerations

Specific challenges for isometric grid-based building:

### Screen-to-Tile Conversion
- **Problem:** Touch position in screen space must convert to isometric tile coordinates
- **Solution:** Already implemented in `CLAUDE.md` with `_screen_to_tile()` helper (64x32 tile size)
- **Touch consideration:** Touch points less precise than mouse, expand tap detection radius

### Visual Depth
- **Problem:** Which room selected when rooms visually overlap?
- **Solution:** Use Z-order (closer to camera = higher priority), or show selection radius around tap point

### Drag Offset
- **Problem:** Finger obscures item being dragged in isometric view
- **Solution:** Offset dragged item above finger by ~100-150dp (roughly 2-3 tiles up)
- **Visual aid:** Draw line from finger to item, or shadow/ground marker showing actual position

### Grid Snapping
- **Strength:** Already using `Vector2i` tile coordinates, snapping implicit
- **Enhancement:** Show grid lines during placement mode (subtle, not intrusive)

### Door Placement Validation
- **Existing:** Doors must be on wall with 2-3 neighbors, direction auto-determined
- **Enhancement:** During room creation, highlight valid door positions (walls with 2-3 neighbors in green)

---

## Technical Implementation Notes

### State Management for Editing
```
EditState enum:
- IDLE: No editing, simulation running
- SELECTING: Room selected, showing info panel
- PLACING: Ghost preview active, dragging new room
- EDITING: Room selected, furniture manipulation mode
- DRAGGING: Actively dragging furniture
```

### Undo/Redo Command Pattern
```gdscript
# Base command
class EditCommand:
    func execute() -> void
    func undo() -> void

# Example: DeleteRoomCommand
class DeleteRoomCommand extends EditCommand:
    var room_data: RoomInstance
    func execute():
        # Remove room from storage, tilemap
    func undo():
        # Restore room_data
```

### Selection System
```gdscript
# In room_build_controller.gd or new room_edit_controller.gd
var selected_room: RoomInstance = null

func _on_room_tapped(tile_pos: Vector2i):
    var room = get_room_at_tile(tile_pos)
    if room:
        select_room(room)

func select_room(room: RoomInstance):
    selected_room = room
    emit_signal("room_selected", room)
    # UI listens and shows info panel
```

### Persistent Storage Format
```json
{
  "version": "1.0",
  "rooms": [
    {
      "id": "uuid",
      "type_id": "theater_stage",
      "bounding_box": {"x": 10, "y": 5, "width": 8, "height": 6},
      "doors": [
        {"position": {"x": 14, "y": 5}, "direction": 1}
      ],
      "furniture": [
        {"id": "spotlight", "position": {"x": 12, "y": 7}, "rotation": 0}
      ]
    }
  ]
}
```

---

## Performance Considerations

### Mobile Performance Targets
- **Target:** 60 FPS during editing (16.67ms per frame)
- **Ghost preview:** Render semi-transparent sprites, reuse existing rendering pipeline
- **Selection highlight:** Shader-based outline (more efficient than multiple draw calls)
- **Undo stack:** Limit to 20-50 commands (memory vs usability tradeoff)

### Optimization Strategies
1. **Lazy validation:** Only validate on placement, not during every drag frame
2. **Dirty flag:** Only recalculate costs when room modified
3. **Culling:** Only render furniture/rooms in camera view
4. **Pooling:** Reuse ghost preview nodes, don't create/destroy each frame

---

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Table stakes features | HIGH | Cross-referenced multiple successful sims (Two Point Hospital, Prison Architect, The Sims) |
| Mobile touch patterns | MEDIUM | Found general mobile UX guidelines, fewer specific sim-game examples |
| Isometric grid interaction | MEDIUM | Found technical resources, but specific mobile+isometric building editors rare |
| Visual feedback patterns | HIGH | Consistent patterns across Minecraft, Factorio, Sims, construction sims |
| Anti-features | HIGH | Verified via UX research (modal overuse, touch precision) and game forums (player complaints) |
| Feature dependencies | HIGH | Logical ordering based on implementation complexity and user workflows |

---

## Open Questions for Phase-Specific Research

1. **Resize implementation:** How do successful sims handle room resizing? (Two Point Hospital example found, need implementation details)
2. **Build mode vs live editing:** Should simulation pause during editing, or handle in-progress edits? (Performance vs UX tradeoff)
3. **Touch gesture discoverability:** How do mobile games teach non-standard gestures (rotation, multi-select)? (Tutorial patterns needed)
4. **Validation error messaging:** Optimal UI position and verbosity for constraint feedback on small mobile screens?
5. **Undo scope:** Should undo be global (all operations) or contextual (per-room editing session)?

---

## Sources

### Simulation Game Features:
- [Two Point Hospital Rooms Wiki](https://two-point-hospital.fandom.com/wiki/Rooms)
- [Two Point Hospital Room Templates FAQ](https://gamefaqs.gamespot.com/pc/230622-two-point-hospital/faqs/76595/room-templates)
- [Two Point Hospital Beginner's Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1632044281)
- [Prison Architect Room Wiki](https://prisonarchitect.paradoxwikis.com/Room)
- [Prison Architect Room Size Advice](https://prison-architect.fandom.com/wiki/Room_Size_Advice)
- [The Sims 4 Build Mode Tips](https://gamerant.com/sims-4-build-mode-tips-guide/)
- [Construction and Management Simulation - Wikipedia](https://en.wikipedia.org/wiki/Construction_and_management_simulation)

### Templates & Copy-Paste:
- [GameMaker Room Editor Manual](https://manual.gamemaker.io/monthly/en/The_Asset_Editors/Rooms.htm)
- [Dwarf Fortress Room Templates Discussion](https://steamcommunity.com/app/975370/discussions/0/3716062978749219339/)
- [Simulator Game Template with Placement System](https://www.fab.com/listings/b0dc1993-d7c2-4ef2-9e9b-de7cea2b2acf)

### Mobile Touch UX:
- [Mobile Touch Controls - MDN](https://developer.mozilla.org/en-US/docs/Games/Techniques/Control_mechanisms/Mobile_touch)
- [GameMaker Gesture Events Tutorial](https://gamemaker.io/en/tutorials/gesture-events)
- [Using Gestures in Mobile Game Design](https://www.gamedeveloper.com/design/using-gestures-in-mobile-game-design)
- [2025 Guide to Haptics](https://saropa-contacts.medium.com/2025-guide-to-haptics-enhancing-mobile-ux-with-tactile-feedback-676dd5937774)
- [Mobile Game Touch Interface Design Tips](https://www.yellowbrick.co/blog/animation/top-tips-for-mobile-game-touch-interface-design)
- [Mobile Game Testing: Touch & Gesture Testing](https://blog.nashtechglobal.com/mobile-game-testing-touch-gesture-testing/)

### Undo/Redo Systems:
- [Crafting Games: Building a Custom Editor with Undo/Redo](https://dev.to/timbeaudet/crafting-games-building-a-custom-editor-with-undoredo-support-500i)
- [Undo & Redo - magicplan Help](https://help.magicplan.app/undo)

### Visual Feedback & Ghost Preview:
- [Minecraft Placement Preview Mod](https://www.curseforge.com/minecraft/mc-mods/placement-preview)
- [Factorio Ghost Buildings Highlight Discussion](https://forums.factorio.com/viewtopic.php?t=117176)
- [Visual Feedback in Game Design](https://www.bravezebra.com/blog/visual-feedback-game-design/)

### Furniture Placement & Grid Snap:
- [The Sims 4 Build Mode Tips](https://gamerant.com/sims-4-build-mode-tips-guide/)
- [ESO Furniture Snap Addon](https://esoui.com/downloads/info1944-FurnitureSnap.html)
- [FFXIV Housing Basics Guide](https://hgxiv.com/basics-guide/)
- [Grid Building Plugin for Godot 4](https://chris-tutorials.itch.io/grid-building-godot)

### Isometric Grid Implementation:
- [Pikuma: Isometric Projection in Game Development](https://pikuma.com/blog/isometric-projection-in-games)
- [Unity: Isometric 2D Environments with Tilemap](https://unity.com/blog/engine-platform/isometric-2d-environments-with-tilemap)
- [How to Create an Isometric Game in 2025](https://www.brsoftech.com/blog/how-to-create-isometric-game/)

### Modal Dialog Anti-Patterns:
- [Mastering Modal UX: Best Practices](https://www.eleken.co/blog-posts/modal-ux)
- [Modal UX Design Patterns - LogRocket](https://blog.logrocket.com/ux-design/modal-ux-design-patterns-examples-best-practices/)
- [Modal & Nonmodal Dialogs - Nielsen Norman Group](https://www.nngroup.com/articles/modal-nonmodal-dialog/)

### Budget & Validation Feedback:
- [Budget Simulation Games](https://www.fastercapital.com/content/Budget-Simulation--How-to-Use-Budget-Games-and-Exercises-to-Enhance-Your-Budgeting-Skills.html)
- [Room Generation using Constraint Satisfaction](https://pvigier.github.io/2022/11/05/room-generation-using-constraint-satisfaction.html)
- [UX/UI Design for Complex Digital Simulation Games](https://www.researchgate.net/publication/379815152_UXUI_design_for_complex_digital_simulation_games_the_case_of_MSP_Challenge)

### Edit vs Play Modes:
- [Unreal Engine: Playing and Simulating](https://dev.epicgames.com/documentation/en-us/unreal-engine/playing-and-simulating-in-unreal-engine)
- [Unity: Edit Mode vs Play Mode Tests](https://docs.unity3d.com/Packages/com.unity.test-framework@1.1/manual/edit-mode-vs-play-mode-tests.html)

---

**Research complete.** Ready for roadmap creation and requirements definition.
