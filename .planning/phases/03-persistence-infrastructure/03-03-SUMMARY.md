---
phase: 03-persistence-infrastructure
plan: 03
subsystem: storage
tags: [persistence, auto-save, debounce, mobile]

dependency_graph:
  requires: ["03-02"]
  provides: ["save-load-integration", "auto-save", "mobile-safe-save"]
  affects: ["04-*", "05-*", "06-*", "07-*"]

tech_stack:
  added: []
  patterns: ["debounce-timer", "notification-handler"]

key_files:
  created: []
  modified:
    - scripts/RoomManager.gd

decisions:
  - id: "debounce-5s"
    choice: "5-second debounce timer for auto-save"
    rationale: "Prevents excessive disk writes during rapid room building/editing"

  - id: "load-without-signal"
    choice: "Load rooms directly to _rooms array without room_added signal"
    rationale: "Restored rooms are not 'new' - avoid triggering downstream handlers"

  - id: "immediate-save-on-suspend"
    choice: "Stop debounce timer and save immediately on app backgrounding"
    rationale: "Mobile apps can be killed without warning - must save pending changes"

metrics:
  duration: "3 minutes"
  completed: "2026-01-23"
---

# Phase 3 Plan 3: SaveLoad Integration Summary

**One-liner:** Auto-save with 5-second debounce, load-on-startup, and immediate save on mobile app suspension.

## What Was Built

### 1. Load-on-Startup
- `_ready()` calls `_load_saved_rooms()` on game start
- Uses `RoomSerializer.load_rooms()` to restore persisted rooms
- Creates selection Area2D for each loaded room
- Connects `placement_changed` signal for future auto-save
- Does NOT emit `room_added` signal (rooms are restored, not new)

### 2. Debounced Auto-Save
- 5-second debounce timer (`SAVE_DEBOUNCE_SECONDS = 5.0`)
- `_schedule_save()` sets pending flag and starts timer
- Multiple changes within 5s consolidate to single save
- `register_room()` triggers auto-save for new rooms
- `placement_changed` signal triggers auto-save for furniture/door changes

### 3. App Suspension Save (Mobile)
- `_notification()` handles `NOTIFICATION_WM_GO_BACKGROUND`
- Also handles `NOTIFICATION_WM_CLOSE_REQUEST` (desktop window close)
- Immediate save when pending (stops debounce timer, saves now)
- Prevents data loss on mobile app kill

## Key Implementation Details

### Data Flow
```
Game Start -> _ready() -> _load_saved_rooms() -> RoomSerializer.load_rooms()
                       -> _setup_save_timer()

Room Built -> register_room() -> _schedule_save() -> [5s debounce] -> _perform_save()

Furniture Added -> placement_changed signal -> _on_room_changed() -> _schedule_save()

App Background -> _notification() -> stop timer + _perform_save()
```

### Signal Connections
- `room.placement_changed` -> `_on_room_changed()` (for all rooms, loaded or new)
- `_save_debounce_timer.timeout` -> `_on_save_timer_timeout()`

### Debounce Logic
```gdscript
func _schedule_save() -> void:
    _save_pending = true
    if _save_debounce_timer.is_stopped():
        _save_debounce_timer.start()
    # Timer already running will fire and save
```

## Commits

| Hash | Description |
|------|-------------|
| ca4d30b | feat(03-03): add load-on-startup to RoomManager |
| 2f40bf2 | feat(03-03): add debounced auto-save to RoomManager |
| 78884a5 | feat(03-03): add app suspension save for mobile |

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| 5-second debounce | Balances responsiveness with disk I/O efficiency |
| Direct array assignment on load | Avoids triggering room_added signal for restored rooms |
| Signal connection for all rooms | Ensures furniture/door changes auto-save for both new and loaded rooms |
| Immediate save on suspend | Mobile can kill app without warning - must not lose pending data |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

1. [x] RoomManager loads saved rooms in _ready() via _load_saved_rooms()
2. [x] register_room() schedules debounced save
3. [x] placement_changed signal triggers save (infrastructure ready)
4. [x] 5-second debounce timer prevents excessive saves
5. [x] App suspension (NOTIFICATION_WM_GO_BACKGROUND) triggers immediate save
6. [x] Window close triggers immediate save

**Note:** Full furniture/door auto-save verification requires Phase 5 (Furniture Editing Operations) which implements the actual editing UI.

## Next Phase Readiness

Phase 3 Plan 4 (if exists) or Phase 4 continuation can proceed. Persistence infrastructure is complete:
- Rooms save to `user://saves/rooms.json`
- Rooms load on game start
- Changes auto-save with debounce
- Mobile-safe save on app background

### Blockers
None.

### Technical Debt
None identified.
