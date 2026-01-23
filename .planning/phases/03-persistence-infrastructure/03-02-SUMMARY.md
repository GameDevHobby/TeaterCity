---
phase: 03-persistence-infrastructure
plan: 02
subsystem: persistence
tags: [file-io, json, atomic-write, save-system]

dependency-graph:
  requires:
    - 03-01 (RoomInstance serialization methods)
  provides:
    - Atomic file I/O for room persistence
    - Save/load operations for Array[RoomInstance]
    - Save file management utilities
  affects:
    - 03-03 (SaveLoad integration uses these methods)
    - 03-04 (Auto-save uses save_rooms)
    - Phase 9 (Admin menu can use delete_save_file)

tech-stack:
  added: []
  patterns:
    - Atomic write pattern (temp + verify + rename)
    - Graceful degradation on file errors
    - Static methods for stateless operations

key-files:
  created:
    - Scripts/storage/RoomSerializer.gd
  modified: []

decisions:
  - Atomic write pattern: Write to .tmp, verify JSON valid, rename to final
  - Static methods: RoomSerializer is stateless helper, not singleton
  - Graceful degradation: All errors return empty array or false, never crash
  - JSON with metadata: Save file includes version and saved_at timestamp

metrics:
  duration: ~2 minutes
  completed: 2026-01-23
---

# Phase 3 Plan 2: RoomSerializer Summary

**One-liner:** Atomic file I/O for room persistence with corruption protection using temp-verify-rename pattern.

## What Was Done

### Task 1: Create RoomSerializer with save/load methods

Created `Scripts/storage/RoomSerializer.gd` as a RefCounted class with static methods for file operations.

**Constants defined:**
- `SAVE_PATH = "user://saves/rooms.json"`
- `TEMP_PATH = "user://saves/rooms.json.tmp"`
- `SAVE_DIR = "user://saves"`

**Methods implemented:**

1. **save_rooms(Array[RoomInstance]) -> bool**
   - Creates save directory if needed
   - Builds save data with version and timestamp
   - Writes to temp file first
   - Verifies temp file is valid JSON
   - Atomic rename: delete old, rename temp to final
   - Returns true on success, false on failure

2. **load_rooms() -> Array[RoomInstance]**
   - Returns empty array if no save file exists
   - Parses JSON and validates structure
   - Deserializes each room via RoomInstance.from_dict()
   - Skips invalid entries with warnings
   - Returns empty array on any error (graceful degradation)

3. **has_save_file() -> bool**
   - Simple existence check for save file

4. **delete_save_file() -> bool**
   - For admin reset feature in Phase 9
   - Returns true if file doesn't exist or deletion succeeds

5. **_verify_json_file(path) -> bool**
   - Private helper to validate JSON before atomic rename

## Commits

| Hash | Description |
|------|-------------|
| b933158 | feat(03-02): add RoomSerializer for atomic file I/O |

## Deviations from Plan

None - plan executed exactly as written.

## Atomic Write Pattern

The save operation follows this sequence to prevent corruption on mobile:

```
1. Build save data as Dictionary
2. Convert to JSON string
3. Write to rooms.json.tmp (temp file)
4. Verify temp file parses as valid JSON
5. Delete old rooms.json (if exists)
6. Rename temp to rooms.json (atomic on most filesystems)
```

If app is killed during step 3-4, temp file is incomplete but original save is preserved.
If app is killed during step 5-6, worst case is both files exist (handled on next save).

## Save File Format

```json
{
  "version": 1,
  "saved_at": "2026-01-23T10:30:00",
  "rooms": [
    {
      "schema_version": 1,
      "id": "room_1234",
      "room_type_id": "lobby",
      "bounding_box": {"x": 5, "y": 10, "width": 6, "height": 4},
      "walls": [{"x": 5, "y": 10}, ...],
      "doors": [{"position": {"x": 7, "y": 10}, "direction": 2}],
      "furniture": []
    }
  ]
}
```

## Key Links Verified

- `save_rooms()` calls `room.to_dict()` at line 25
- `load_rooms()` calls `RoomInstance.from_dict()` at line 104

## Next Phase Readiness

**Ready for 03-03:** SaveLoad integration can now:
- Call `RoomSerializer.save_rooms(rooms)` to persist
- Call `RoomSerializer.load_rooms()` to restore

**No blockers identified.**
