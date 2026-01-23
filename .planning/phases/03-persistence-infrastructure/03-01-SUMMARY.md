---
phase: 03-persistence-infrastructure
plan: 01
subsystem: persistence
tags: [serialization, json, data-model]

dependency-graph:
  requires:
    - phase-1 (RoomInstance data model)
  provides:
    - RoomInstance serialization (to_dict/from_dict)
    - Schema versioning for future migrations
  affects:
    - 03-02 (SaveManager will use these methods)
    - 03-03 (SaveLoad integration)

tech-stack:
  added: []
  patterns:
    - Dictionary serialization for JSON compatibility
    - Schema versioning with forward compatibility warnings
    - Registry lookup during deserialization

key-files:
  created: []
  modified:
    - Scripts/storage/RoomInstance.gd

decisions:
  - Vector2i as {x,y} objects: JSON.parse_string() handles objects better than arrays
  - Schema version at class level: Enables future migrations without breaking old saves
  - Registry lookup in from_dict: FurniturePlacement restores resource reference by ID
  - Direct array assignment: Avoids placement_changed signals during load

metrics:
  duration: ~2 minutes
  completed: 2026-01-23
---

# Phase 3 Plan 1: RoomInstance Serialization Summary

**One-liner:** Dictionary serialization for RoomInstance with schema versioning and nested class support.

## What Was Done

### Task 1: Inner Class Serialization
Added `to_dict()` and `from_dict()` methods to both inner classes:

**DoorPlacement:**
```gdscript
func to_dict() -> Dictionary:
    return {
        "position": {"x": position.x, "y": position.y},
        "direction": direction
    }

static func from_dict(data: Dictionary) -> DoorPlacement:
    var pos = Vector2i(data.position.x, data.position.y)
    return DoorPlacement.new(pos, data.direction)
```

**FurniturePlacement:**
- Serializes furniture by ID (not full resource)
- Deserializes by looking up resource from FurnitureRegistry
- Gracefully handles missing furniture (null fallback)

### Task 2: RoomInstance Serialization
Added complete serialization support:

**to_dict():** Serializes all properties:
- schema_version, id, room_type_id
- bounding_box as {x, y, width, height}
- walls as array of {x, y} objects
- doors and furniture via inner class to_dict()

**from_dict():** Restores complete RoomInstance:
- Direct array assignment (no signals emitted)
- Uses data.get() with defaults for forward compatibility

### Task 3: Schema Versioning
- `SCHEMA_VERSION := 1` constant
- Version included in serialized output
- Warning logged if loading newer schema version

## Commits

| Hash | Description |
|------|-------------|
| 1de1a46 | feat(03-01): add serialization methods to inner classes |
| 32417d8 | feat(03-01): add serialization methods to RoomInstance |
| 7545b50 | feat(03-01): add schema version for future migrations |

## Deviations from Plan

None - plan executed exactly as written.

## Serialization Format

Example output from `room.to_dict()`:
```json
{
  "schema_version": 1,
  "id": "room_1234",
  "room_type_id": "lobby",
  "bounding_box": {"x": 5, "y": 10, "width": 6, "height": 4},
  "walls": [{"x": 5, "y": 10}, {"x": 6, "y": 10}, ...],
  "doors": [{"position": {"x": 7, "y": 10}, "direction": 2}],
  "furniture": [{"furniture_id": "chair_01", "position": {"x": 6, "y": 11}, "rotation": 0}]
}
```

## Next Phase Readiness

**Ready for 03-02:** SaveManager can now use these methods:
- `RoomInstance.to_dict()` for saving
- `RoomInstance.from_dict(data)` for loading

**No blockers identified.**
