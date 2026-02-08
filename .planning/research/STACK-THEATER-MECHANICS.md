# Stack Research: Theater Mechanics with Offline Timers

**Project:** TheaterCity v1.1 — Theater Mechanics
**Researched:** 2026-02-08
**Confidence:** HIGH

## Executive Summary

Theater mechanics require two new patterns: offline-capable timers (track time when app closed) and room state machines (Idle → Scheduled → Playing → Cleaning). Both integrate cleanly with existing RoomInstance/RoomSerializer architecture.

**Core Finding:** Use timestamp-based timers (not Timer nodes) + LimboHSM (already installed). No new dependencies required.

---

## 1. Offline Timer System

### Recommended Approach: Timestamp-Based Timers

**What:** Store Unix timestamps in RoomInstance, calculate elapsed time on app restart.

**Why:** Timer nodes cannot run while app closed. Godot's standard pattern is to:
1. Save `Time.get_unix_time_from_system()` when timer starts
2. Calculate elapsed time on app open by comparing saved timestamp to current time
3. Apply all state changes that would have occurred

**Pattern in Godot 4.5:**

```gdscript
# When movie starts
var start_time := Time.get_unix_time_from_system()
room_instance.movie_start_time = start_time  # Store in RoomInstance

# On app restart (_ready)
var elapsed := Time.get_unix_time_from_system() - room_instance.movie_start_time
if elapsed >= movie_duration:
    # Movie finished while offline, advance to next state
    transition_to_cleaning()
else:
    # Resume where we left off
    remaining_time = movie_duration - elapsed
```

### Integration with Existing Systems

**RoomInstance additions:**
```gdscript
# New fields for theater state tracking
var movie_id: String = ""
var movie_start_time: float = 0.0  # Unix timestamp
var current_state: String = "idle"  # For persistence
var scheduled_movie_time: float = 0.0  # When next movie scheduled

# Add to to_dict() / from_dict() for serialization
```

**RoomSerializer integration:**
- Already handles JSON serialization via `to_dict()` / `from_dict()` (note: project uses JSON, not binary)
- Already has atomic write pattern with temp files
- Just add new fields to RoomInstance serialization
- No changes needed to RoomSerializer itself

### Time API (Godot 4.5)

Use `Time` singleton (autoload, always available):

```gdscript
# Get current Unix timestamp (seconds since 1970)
var now := Time.get_unix_time_from_system()  # Returns float

# WARNING: Subject to user clock changes!
# For precise measurement during active gameplay, use:
var ticks := Time.get_ticks_msec()  # Monotonic, can't go backwards
```

**Important caveat:** `get_unix_time_from_system()` uses system clock, which users can change. This is acceptable for idle game mechanics (users changing clock is their choice), but for frame-accurate timing during active play, use `get_ticks_msec()`.

### Alternative Considered: ConfigFile for Timestamps

Some Godot devs use ConfigFile instead of JSON for timestamp storage:

```gdscript
var config := ConfigFile.new()
config.set_value("theater", "last_check", int(Time.get_unix_time_from_system()))
config.save("user://theater_times.cfg")
```

**Why NOT to use:** TheaterCity already uses JSON via RoomSerializer. Adding a second persistence system creates:
- Two sources of truth for room state
- Synchronization bugs
- More complex save/load logic

**Verdict:** Extend existing JSON serialization, don't introduce ConfigFile.

---

## 2. Room State Machine

### Recommended Approach: LimboHSM (Already Installed)

**What:** LimboAI v1.5.2 hierarchical state machine (supports Godot 4.4-4.5).

**Why:**
- Already installed (`addons/limboai/`) version 1.5.2
- Event-driven transitions (clean decoupling)
- GDScript-friendly (extend `LimboState`)
- Hierarchical (can nest states if needed later)
- Production-ready (unit tested, active maintenance)

### LimboHSM Pattern for Theater States

```gdscript
# theater_state_machine.gd (attach to Room scene node)
extends Node

@onready var hsm: LimboHSM = $LimboHSM
@onready var idle: LimboState = $LimboHSM/IdleState
@onready var scheduled: LimboState = $LimboHSM/ScheduledState
@onready var previews: LimboState = $LimboHSM/PreviewsState
@onready var playing: LimboState = $LimboHSM/PlayingState
@onready var cleaning: LimboState = $LimboHSM/CleaningState

var room_instance: RoomInstance  # Reference to data model

func _ready() -> void:
    # Define transitions (event-driven)
    hsm.add_transition(idle, scheduled, "movie_scheduled")
    hsm.add_transition(scheduled, previews, "previews_start")
    hsm.add_transition(previews, playing, "movie_start")
    hsm.add_transition(playing, cleaning, "movie_end")
    hsm.add_transition(cleaning, idle, "cleaning_done")

    hsm.initialize(self)
    hsm.set_active(true)

    # Restore state from RoomInstance
    _restore_state_from_persistence()

func _restore_state_from_persistence() -> void:
    # Check timestamps, advance states that completed offline
    var elapsed := Time.get_unix_time_from_system() - room_instance.movie_start_time
    if elapsed >= movie_duration:
        hsm.dispatch("movie_end")  # Jump to cleaning state
```

### State Implementation Pattern

```gdscript
# playing_state.gd (extends LimboState)
extends LimboState

var remaining_time: float = 0.0

func _enter() -> void:
    # Called when state becomes active
    var movie_duration := MovieRegistry.get_movie(agent.room_instance.movie_id).duration
    var elapsed := Time.get_unix_time_from_system() - agent.room_instance.movie_start_time
    remaining_time = max(0.0, movie_duration - elapsed)

    print("Playing movie, %d seconds remaining" % remaining_time)

func _update(delta: float) -> void:
    # Called each frame while active
    remaining_time -= delta
    if remaining_time <= 0:
        dispatch("movie_end")  # Trigger transition

func _exit() -> void:
    # Called when state is deactivated
    agent.room_instance.movie_start_time = 0.0  # Clear timestamp
```

### Alternatives Considered

| Approach | Why Not |
|----------|---------|
| **Simple enum + setter** | No event system, state logic scattered across controllers. Would work for simple cases but theater states need lifecycle (_enter/_exit for timers). |
| **Custom FSM plugin** | LimboAI already installed, battle-tested, and maintained. Don't introduce a second state machine system. |
| **Manual state management** | Match statements in _process() quickly become brittle. Hard to visualize, debug, and test. |
| **Node-based states (GDQuest pattern)** | LimboState already provides this with better event system. |

---

## 3. Data Model Extensions

### RoomInstance Additions

Extend existing `RoomInstance` class (RefCounted, already has JSON serialization):

```gdscript
# Add to class_name RoomInstance (room_instance.gd)

# Theater state fields
var theater_state: String = "idle"  # Persisted state name
var scheduled_movie_id: String = ""  # What movie is scheduled
var scheduled_start_time: float = 0.0  # When movie will start
var movie_start_time: float = 0.0  # When movie actually started
var current_movie_id: String = ""  # What's currently playing

# Add to to_dict() serialization
func to_dict() -> Dictionary:
    return {
        # ... existing serialization ...
        "theater_state": theater_state,
        "scheduled_movie_id": scheduled_movie_id,
        "scheduled_start_time": scheduled_start_time,
        "movie_start_time": movie_start_time,
        "current_movie_id": current_movie_id,
    }
```

**Why extend RoomInstance:**
- Already has JSON persistence via RoomSerializer
- Already emits `placement_changed` signal for auto-save
- Follows existing pattern (furniture, doors are in RoomInstance)
- RefCounted = lightweight, no scene tree overhead

**What NOT to add:**
- Runtime state (remaining_time, patron_count) → keep in state machine node
- Visual nodes (Timer, Label) → keep in scene
- Business logic → keep in operations or state classes

### Movie Data Model

Create new `MovieResource` (follows existing registry pattern):

```gdscript
# movie_resource.gd
class_name MovieResource
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var duration: int = 300  # Seconds (5 minutes default)
@export var genre: String = "action"
@export var ticket_price: int = 10
@export var preview_duration: int = 30  # Seconds
@export var cleaning_duration: int = 60  # Seconds
```

Create `MovieRegistry` singleton (follows FurnitureRegistry pattern):

```gdscript
# movie_registry.gd
extends Node

const MOVIE_DIR := "res://data/resources/configs/movies/"
var _movies: Dictionary = {}  # id -> MovieResource

func get_movie(movie_id: String) -> MovieResource:
    if not _movies.has(movie_id):
        _load_movie(movie_id)
    return _movies.get(movie_id)
```

**Why registry pattern:**
- Matches existing FurnitureRegistry, RoomTypeRegistry
- Lazy-loading from `.tres` resources
- Centralized access via singleton
- Designer-friendly (edit resources in Godot editor)

---

## 4. Integration Architecture

### Data Flow

```
User schedules movie
    ↓
RoomInstance.scheduled_movie_id = "movie_01"
RoomInstance.scheduled_start_time = Time.get_unix_time_from_system() + 300
RoomInstance.placement_changed.emit()  # Triggers auto-save
    ↓
RoomSerializer.save_rooms() called (debounced 5 seconds)
    ↓
App closes
    ↓
App reopens
    ↓
RoomSerializer.load_rooms()
    ↓
RoomManager.room_restored.emit(room)
    ↓
TheaterStateMachine._restore_state_from_persistence()
    ↓
Check timestamps, dispatch events to jump to correct state
    ↓
LimboHSM transitions to current state
```

### Signal Architecture (Follows Existing Pattern)

```gdscript
# RoomManager (singleton) - already has signals
signal room_added(room: RoomInstance)
signal room_restored(room: RoomInstance)  # Already used for load
signal room_removed(room: RoomInstance)

# NEW: Theater-specific signals (add to RoomManager or separate TheaterManager)
signal movie_scheduled(room: RoomInstance, movie: MovieResource)
signal movie_started(room: RoomInstance, movie: MovieResource)
signal movie_ended(room: RoomInstance)
signal theater_state_changed(room: RoomInstance, state_name: String)
```

**Pattern:** RoomManager emits high-level events, state machines listen and react.

### Node Tree Structure

```
Main (Node2D)
├── RoomManager (autoload singleton - already exists)
├── MovieRegistry (autoload singleton - NEW)
└── RoomVisuals (Node2D)
    └── Room_Theater_01
        ├── TileMap (walls, floor)
        ├── Furniture (visual nodes)
        └── TheaterStateMachine (Node)
            └── LimboHSM
                ├── IdleState (LimboState)
                ├── ScheduledState (LimboState)
                ├── PreviewsState (LimboState)
                ├── PlayingState (LimboState)
                └── CleaningState (LimboState)
```

**Each room instance gets its own state machine node** (instantiated when room created, cleaned up when room deleted).

---

## 5. Testing Considerations

### GUT Integration (Already Used)

Existing test framework: GUT (Godot Unit Test addon at `addons/gut/`).

**Test strategy:**

```gdscript
# test_theater_timers.gd
extends GutTest

func test_offline_movie_completion():
    var room := RoomInstance.new("test_room", "theater")
    room.movie_start_time = Time.get_unix_time_from_system() - 400  # 400 seconds ago
    room.current_movie_id = "short_movie"  # 300 second movie

    # Simulate app restart
    var elapsed := Time.get_unix_time_from_system() - room.movie_start_time
    assert_gt(elapsed, 300, "Movie should have finished")

func test_timestamp_serialization():
    var room := RoomInstance.new("test_room", "theater")
    room.movie_start_time = 1738972800.0

    var dict := room.to_dict()
    var restored := RoomInstance.from_dict(dict)

    assert_eq(restored.movie_start_time, 1738972800.0, "Timestamp should survive serialization")
```

**Time manipulation for tests:**
- Use dependency injection for time source
- Mock `Time.get_unix_time_from_system()` return value
- Or: Add `theater_debug_time_offset` for testing (offset all calculations)

### LimboHSM Testing

LimboAI states are unit-tested by the addon itself. Test state transitions:

```gdscript
func test_state_transitions():
    var hsm := LimboHSM.new()
    var idle := IdleState.new()
    var scheduled := ScheduledState.new()

    hsm.add_transition(idle, scheduled, "movie_scheduled")
    hsm.initialize(self)

    assert_eq(hsm.get_active_state(), idle)
    hsm.dispatch("movie_scheduled")
    assert_eq(hsm.get_active_state(), scheduled)
```

---

## 6. What NOT to Add

### Avoid These:

**System notifications (push notifications):**
- Requires native mobile plugins
- Platform-specific (iOS vs Android)
- Adds complexity to testing
- Not needed for MVP (users open app voluntarily)

**Real-time multiplayer synchronization:**
- Theater is single-player
- No need for server-side validation of timers
- Offline-first architecture is correct

**Complex scheduling algorithms:**
- Start simple: one movie at a time per theater
- Don't build queuing system until needed
- YAGNI principle

**Database instead of JSON:**
- RoomSerializer already works with JSON
- JSON is human-readable (debugging)
- SQLite adds dependency + migration complexity
- Current scale doesn't need database performance

---

## 7. Mobile Considerations

### App Lifecycle Hooks (Already Implemented)

RoomManager already handles app pause/close via `_notification()`:

```gdscript
func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED:
            # App going to background (mobile) - save immediately
            if _save_pending:
                _save_debounce_timer.stop()
                _perform_save()
```

**This already saves timestamps when app backgrounds.** No changes needed.

### Battery/Performance

Timer calculations happen:
1. On app resume (once)
2. During active gameplay (_process)

No background processing = no battery drain.

---

## 8. Migration Path

Since this is v1.1 adding features to v1.0:

**Safe migration:**
1. Add new fields to RoomInstance with defaults (empty strings, 0.0)
2. `from_dict()` uses `.get()` with defaults (already does this pattern)
3. Old save files load without theater fields
4. New save files have theater fields
5. Schema version can stay at 1 (backward compatible addition)

**Example:**
```gdscript
static func from_dict(data: Dictionary) -> RoomInstance:
    # ... existing code ...
    room.theater_state = data.get("theater_state", "idle")  # Default if missing
    room.movie_start_time = data.get("movie_start_time", 0.0)
```

---

## Sources

### Official Godot Documentation (HIGH confidence)
- [Time class (Godot 4.4)](https://docs.godotengine.org/en/4.4/classes/class_timer.html)
- [Time class (Godot stable)](https://docs.godotengine.org/en/stable/classes/class_time.html)
- [RefCounted class](https://docs.godotengine.org/en/stable/classes/class_refcounted.html)

### LimboAI Documentation (HIGH confidence)
- [LimboAI GitHub Repository](https://github.com/limbonaut/limboai)
- [LimboAI Creating HSM Guide](https://limboai.readthedocs.io/en/stable/hierarchical-state-machines/create-hsm.html)
- [LimboAI Asset Library](https://godotengine.org/asset-library/asset/3787)

### Community Resources (MEDIUM confidence)
- [Godot Forum: Continue countdown timer](https://forum.godotengine.org/t/how-to-continue-a-countdown-timer/10600)
- [Godot Forum: Timer when program off](https://forum.godotengine.org/t/can-you-set-a-timer-to-run-when-the-program-is-off/10909)
- [Godot Forum: Refill life system offline](https://forum.godotengine.org/t/make-a-refill-life-system-and-keep-the-timer-active-even-when-game-is-closed/18679)
- [Godot Forum: Idle game background progress](https://forum.godotengine.org/t/idle-game-background-progress/105645)
- [GDQuest: Finite State Machine in Godot 4](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)
- [Godot Forum: State machines in Godot 4.5](https://forum.godotengine.org/t/state-machines-in-godot-4-5/132653)
- [Sandro Maglione: State Machine Pattern in Godot](https://www.sandromaglione.com/articles/how-to-implement-state-machine-pattern-in-godot)

### Timestamp Implementation (MEDIUM confidence)
- [Godot Forum: Compare time when game left vs current](https://forum.godotengine.org/t/how-to-compare-the-time-of-when-i-leaved-the-last-time-the-game-with-the-current-time/2528)
- [Godot Forum: Get elapsed time](https://forum.godotengine.org/t/is-there-anyway-you-can-get-the-elasped-time/14091)

---

## Confidence Assessment

| Component | Confidence | Rationale |
|-----------|------------|-----------|
| Timestamp timers | HIGH | Documented Godot pattern, widely used in idle games, verified in official Time docs |
| LimboHSM | HIGH | Already installed v1.5.2, supports Godot 4.5, unit tested, active maintenance |
| RoomInstance integration | HIGH | Extending existing pattern, JSON serialization already working |
| Mobile lifecycle | HIGH | Already implemented in RoomManager NOTIFICATION_APPLICATION_PAUSED |
| Time.get_unix_time_from_system | HIGH | Official Godot 4 API, verified in stable docs |

**Overall Confidence: HIGH**

All recommendations use existing systems or standard Godot patterns. No experimental techniques or new dependencies required.
