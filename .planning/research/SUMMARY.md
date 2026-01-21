# Research Summary: Room Editing & Persistence

**Project:** TheaterCity
**Milestone:** Room editing and persistence
**Synthesized:** 2026-01-21
**Overall Confidence:** HIGH

---

## Executive Summary

Building room editing and persistence for TheaterCity's mobile theater simulation requires extending the existing state-machine-driven architecture with three core additions: (1) a RoomManager singleton to track completed rooms and their visuals, (2) dictionary-based serialization using `FileAccess.store_var()` for persistence, and (3) a parallel RoomEditController state machine for editing workflows. The existing data/visual separation (RoomInstance as pure data, operations creating visuals) is ideal for save/load.

**Critical insight:** Use binary persistence (`store_var()`) over JSON. Your RoomInstance already uses Vector2i, Rect2i, and typed arrays that serialize natively with store_var(). JSON would require manual conversion of every Godot type, adding complexity without benefit.

**Top risks:** Navigation map updates after edits (patrons walk through walls), save file corruption on mobile (crashes during write), and touch input conflicts between camera pan and room selection. All three are architectural decisions that must be addressed during implementation, not deferred to polish.

**Recommended approach:** Build in phases - RoomManager/selection first, then serialization, then furniture editing, then deletion. This order respects dependencies and delivers value incrementally.

---

## Technology Decisions

### Core Stack (No New Dependencies)

| Technology | Purpose | Rationale |
|------------|---------|-----------|
| **FileAccess.store_var()** | Save/load game data | Native Vector2i/Rect2i support, binary format, zero dependencies |
| **UndoRedo (built-in)** | Action history | Godot's built-in undo system, designed for editor workflows |
| **Area2D + CollisionShape2D** | Room/furniture selection | Standard 2D picking, works with touch input |
| **user:// path** | Save file location | Cross-platform, sandboxed, survives app updates |

### Why NOT JSON

- JSON doesn't support Vector2i, Rect2i, or typed arrays
- Requires manual to_dict()/from_dict() for every Godot type
- Larger files, slower parsing than binary
- Only use JSON for export/sharing features

### New Components to Create

| Component | Type | Purpose |
|-----------|------|---------|
| RoomManager | Autoload singleton | Track rooms, selection state, visual nodes |
| RoomSerializer | Static utility class | Serialize/deserialize RoomInstance |
| RoomEditController | Node controller | State machine for edit workflow |
| SelectionManager | RefCounted helper | Visual selection feedback |
| DeletionOperation | RefCounted operation | Cleanup for room/furniture deletion |

### Files to Modify (Minimal)

| File | Change |
|------|--------|
| `RoomInstance.gd` | Add to_dict()/from_dict() methods |
| `RoomBuildController.gd` | Add RoomManager.register_room() call on completion |
| `Main.gd` | Add edit mode toggle |

---

## Architecture Approach

### Pattern: Parallel State Machines

**Build workflow** (existing): `idle -> select_room -> draw_box -> place_doors -> place_furniture -> complete`

**Edit workflow** (new): `idle -> select_room -> edit_mode -> [add/remove furniture, delete room] -> idle`

Key insight: Don't merge edit states into build controller. Build is linear, edit is iterative. Separate controllers share operations but have different lifecycles.

### Data Flow

```
User Input -> RoomEditController (state machine)
    -> Modifies RoomInstance (pure data)
    -> Operations (stateless) update visuals
    -> RoomManager tracks both data and visuals
    -> RoomSerializer persists to user://saves/rooms.dat
```

### Serialization Strategy

Store RoomInstance as Dictionary, resolve FurnitureResource by ID on load:

```gdscript
# RoomInstance.to_dict()
{
    "id": "room_1",
    "room_type_id": "lobby",
    "bounding_box": bounding_box,  # Rect2i serializes natively
    "walls": walls,                # Array[Vector2i] serializes natively
    "doors": [{"pos": Vector2i, "dir": int}],
    "furniture": [{"id": "chair", "pos": Vector2i, "rot": 0}]
}
```

### Visual-Data Separation (Preserve Existing Pattern)

- **RoomInstance**: Pure data, RefCounted, no Node dependencies
- **Operations**: Stateless helpers that create/modify visuals from data
- **RoomManager**: Tracks both RoomInstance and visual nodes in parallel dictionaries
- **On load**: Recreate visuals from data, don't serialize Node trees

---

## Feature Priorities

### Phase 1: Room Selection & Visual Feedback (MVP Foundation)

**What to build:**
- RoomManager singleton (empty registry)
- Room selection via tap (Area2D hit detection)
- Visual selection feedback (highlight/outline)
- Disable camera pan during edit mode

**Delivers:** Players can select existing rooms. Foundation for all editing.

**Critical pitfall:** Touch input conflicts with camera pan. Must toggle camera.enable_pinch_pan = false during edit mode.

### Phase 2: Serialization & Persistence

**What to build:**
- RoomInstance.to_dict() / from_dict() methods
- RoomSerializer with save_to_file() / load_from_file()
- Atomic save (write to .tmp, verify, rename)
- Auto-save on room completion, app suspension

**Delivers:** Changes survive app restart.

**Critical pitfall:** Save file corruption. Use temp file + rename pattern for atomic writes. Mobile crashes are common.

### Phase 3: Furniture Editing

**What to build:**
- Add furniture to existing room (reuse FurnitureOperation)
- Move furniture (drag with grid snap)
- Delete furniture (with visual node cleanup)
- Rotate furniture (90-degree increments)
- Basic undo/redo (UndoRedo class)

**Delivers:** Players can customize rooms after building.

**Critical pitfall:** Furniture visual nodes not cleaned up on delete. Track visual_node in FurniturePlacement, call queue_free().

### Phase 4: Room Deletion

**What to build:**
- Delete room flow with confirmation
- DeletionOperation (clean up tilemap cells, furniture nodes)
- Unregister from Targets singleton
- Update navigation mesh

**Delivers:** Players can remove unwanted rooms.

**Critical pitfall:** Deleted room still registered as navigation target. Must call Targets.unregister_room() and update nav mesh.

### Defer to Post-MVP

| Feature | Why Defer |
|---------|-----------|
| Room resize | HIGH complexity, players can delete + rebuild |
| Copy/paste rooms | Nice-to-have, not blocking editing |
| Room templates | Requires copy/paste foundation |
| Multi-select | Complex interaction model |
| Floor/wall customization | Pure aesthetics |

---

## Risk Mitigation

### Critical Risks (Address During Implementation)

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Navigation not updated after edits** | Patrons walk through walls | Call _navigation_op.update_room_navigation() after ANY room modification |
| **Save file corruption** | Data loss, negative reviews | Atomic writes: write to .tmp, verify JSON parse, rename to final |
| **Touch conflicts with camera** | Editing unusable on mobile | Toggle camera.enable_pinch_pan = false during edit mode |
| **RefCounted memory leaks** | App crashes after 50+ edits | Explicitly disconnect signals before dropping RoomInstance references |
| **Coordinate confusion** | Furniture offset after load | Always store absolute tile coords (Vector2i), never world positions |

### Moderate Risks (Address in Phase)

| Risk | Phase | Mitigation |
|------|-------|------------|
| Invalid state saved | Phase 2 | Validate rooms before serialization, skip invalid |
| Furniture nodes not cleaned up | Phase 3 | Track visual_node reference, queue_free() on delete |
| No undo/redo | Phase 3 | Use built-in UndoRedo class, implement with editing |
| Auto-save too frequent | Phase 2 | Event-based with 5s debounce, not timer-based |
| TileMap performance with 50+ rooms | Phase 1 | Test early on mobile, consider per-room TileMapLayers if needed |

### Mobile-Specific Testing Checklist

- [ ] Select room with single tap (not triggering pan)
- [ ] Save -> kill app -> relaunch -> verify persistence
- [ ] 50 rooms at >30fps on mid-range device
- [ ] Save with 90% storage full (error handling)
- [ ] Rotate device during edit (no crashes)
- [ ] Phone call during auto-save (completes or retries)
- [ ] 30 minutes heavy editing (memory <300MB)

---

## Implementation Notes

### Selection Pattern (Mobile-Optimized)

```gdscript
# Distinguish tap from drag
const TAP_THRESHOLD := 20  # pixels
const TAP_TIME_MS := 300

func _on_screen_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        _touch_start_pos = event.position
        _touch_start_time = Time.get_ticks_msec()
    else:
        var moved = event.position.distance_to(_touch_start_pos)
        var duration = Time.get_ticks_msec() - _touch_start_time
        if moved < TAP_THRESHOLD and duration < TAP_TIME_MS:
            _handle_tap(event.position)  # Selection
```

### Atomic Save Pattern

```gdscript
func save_game_safe(data: Dictionary) -> void:
    var temp_path = "user://save.dat.tmp"
    var final_path = "user://save.dat"

    var file = FileAccess.open(temp_path, FileAccess.WRITE)
    file.store_var(data)
    file.close()

    # Verify and commit
    var verify = FileAccess.open(temp_path, FileAccess.READ)
    if verify.get_var():
        DirAccess.rename_absolute(temp_path, final_path)
```

### Navigation Update Pattern

```gdscript
# After ANY room modification:
func _update_after_room_edit(room: RoomInstance) -> void:
    _wall_op.update_wall_visuals(room, tilemap_layer)
    _furniture_op.update_furniture_visuals(room, furniture_visuals)
    _navigation_op.update_room_navigation(room, tilemap_layer)  # CRITICAL
    Targets.notify_navigation_changed()
```

### Signal Cleanup Pattern (Prevent Memory Leaks)

```gdscript
func start_editing_room(room: RoomInstance) -> void:
    # Disconnect old room first
    if _active_room and _active_room.placement_changed.is_connected(_on_changed):
        _active_room.placement_changed.disconnect(_on_changed)

    _active_room = room
    room.placement_changed.connect(_on_changed)

func finish_editing_room() -> void:
    if _active_room and _active_room.placement_changed.is_connected(_on_changed):
        _active_room.placement_changed.disconnect(_on_changed)
    _active_room = null
```

---

## Implications for Roadmap

### Suggested Phase Structure

| Phase | Name | Delivers | Features from FEATURES.md | Pitfalls to Avoid |
|-------|------|----------|--------------------------|-------------------|
| **1** | Room Selection & Feedback | Foundation for editing | Select room, visual feedback, ghost preview | Touch conflicts (#5), no visual feedback (#11) |
| **2** | Persistence | Changes survive restart | Save/load, cost display, validation feedback | Save corruption (#2), coordinate confusion (#4) |
| **3** | Furniture Editing | Room customization | Move/add/delete/rotate furniture, undo/redo | Visual node cleanup (#7), no undo (#8) |
| **4** | Room Deletion | Remove unwanted rooms | Delete room with confirmation | Navigation targets (#13), nav mesh update (#1) |

### Build Order Rationale

1. **Selection first:** Can't edit without selecting. Validates touch input pipeline.
2. **Persistence before editing:** Save incomplete edits. Prevents data loss during development.
3. **Furniture before deletion:** More common operation, clearer interaction model.
4. **Deletion last:** Requires both save (to persist deletions) and edit (to select what to delete).

### Research Flags for Planning

| Phase | Research Needed | Reason |
|-------|-----------------|--------|
| Phase 1 | LOW | Well-documented patterns for selection |
| Phase 2 | MEDIUM | Save file versioning/migration strategy |
| Phase 3 | MEDIUM | Mobile gesture patterns for drag-and-drop |
| Phase 4 | LOW | Standard deletion flow |

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| **Stack choices** | HIGH | Godot built-ins (FileAccess, UndoRedo), verified patterns |
| **Architecture** | HIGH | Extends existing patterns (state machine, operations, singletons) |
| **Features** | HIGH | Cross-referenced Two Point Hospital, Prison Architect, The Sims |
| **Pitfalls** | MEDIUM | Verified with Godot community sources, some platform-specific gaps |
| **Mobile touch patterns** | MEDIUM | General guidelines found, fewer sim-specific examples |
| **Performance** | MEDIUM | Need to test with 50+ rooms on actual mobile device |

### Gaps to Address During Planning

1. **Save file versioning:** How to handle schema changes in future updates?
2. **iOS vs Android lifecycle:** Auto-save timing differences on app suspension
3. **Touch gesture discoverability:** How to teach rotation gesture without tutorial?
4. **Large theater performance:** May need per-room TileMapLayers if >50 rooms

---

## Aggregated Sources

### Godot Documentation & Tutorials
- [FileAccess class documentation](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)
- [Saving games - Godot docs](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [UndoRedo class documentation](https://docs.godotengine.org/en/stable/classes/class_undoredo.html)
- [Navigation using NavigationAgents](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationagents.html)
- [GDQuest Save Systems](https://www.gdquest.com/library/save_game_godot4/)
- [GDQuest FSM Tutorial](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)

### Simulation Game References
- [Two Point Hospital Rooms Wiki](https://two-point-hospital.fandom.com/wiki/Rooms)
- [Prison Architect Room Wiki](https://prisonarchitect.paradoxwikis.com/Room)
- [The Sims 4 Build Mode Tips](https://gamerant.com/sims-4-build-mode-tips-guide/)

### Mobile UX & Touch Patterns
- [Mobile Touch Controls - MDN](https://developer.mozilla.org/en-US/docs/Games/Techniques/Control_mechanisms/Mobile_touch)
- [Using Gestures in Mobile Game Design](https://www.gamedeveloper.com/design/using-gestures-in-mobile-game-design)
- [Modal UX Best Practices - LogRocket](https://blog.logrocket.com/ux-design/modal-ux-design-patterns-examples-best-practices/)

### Godot Community Issues & Discussions
- [NavigationRegion2D pathfinding issues](https://github.com/godotengine/godot/issues/110686)
- [RefCounted garbage collection with signals](https://forum.godotengine.org/t/do-signal-connections-prevent-refcounted-garbage-collection/111346)
- [Touch input conflicts](https://forum.godotengine.org/t/issue-with-touch-and-drag-simultaneously/119328)
- [TileMap performance issues](https://github.com/godotengine/godot/issues/72458)

---

**Research complete.** Ready for roadmap creation and requirements definition.
