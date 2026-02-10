# Phase 11: Timer & State Foundation - Research

**Researched:** 2026-02-08
**Domain:** Offline-capable timers and data-driven state machines for Godot 4.5 mobile game
**Confidence:** HIGH

## Summary

Phase 11 establishes the foundational infrastructure for offline-capable timers and data-driven room state machines. The core challenge is building timers that work when the app is closed (mobile games cannot use Timer nodes for this) and state machines that persist and recalculate correctly after app resume.

The standard approach uses Unix timestamps from `Time.get_unix_time_from_system()` stored as integers (not floats) to track when states began. On app resume, elapsed time is calculated and state transitions are applied. RefCounted classes (not Nodes) provide lightweight, serializable state containers that integrate cleanly with the existing RoomInstance pattern.

TheaterCity already has robust persistence infrastructure (RoomSerializer with atomic writes, RoomManager with NOTIFICATION_APPLICATION_PAUSED handling) that this phase extends rather than replaces. The key additions are TimerState and RoomStateMachine classes that serialize through RoomInstance.to_dict().

**Primary recommendation:** Build TimerState as a RefCounted inner class of RoomInstance, with state machine logic as a separate RefCounted helper class. Leverage existing save infrastructure for persistence. Focus testing on offline scenarios.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **Time (Godot singleton)** | 4.5 | Unix timestamps for offline tracking | Built-in, returns UTC, survives app restart |
| **RefCounted** | 4.5 | Base class for state data objects | Automatic memory management, serializable, matches existing patterns |
| **JSON (Godot singleton)** | 4.5 | State persistence format | Already used by RoomSerializer, human-readable for debugging |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **TextureProgressBar** | 4.5 | Circular progress indicator | Visual feedback for timer countdown |
| **Control (custom draw)** | 4.5 | Alternative progress rendering | If TextureProgressBar is insufficient |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| RefCounted state classes | Node-based states (like LimboHSM) | Nodes visible in editor but harder to serialize, doesn't match RoomInstance pattern |
| JSON persistence | Resource (.tres) files | Resources better for complex types but JSON already working, simpler for timestamps |
| Radial Progress Plugin | Custom shader | Plugin tested on 4.5.1, simpler to install than writing shader |

**Installation:**
```bash
# No external dependencies - all Godot built-ins
# Optional: Radial Progress Indicator plugin from Asset Library (asset ID 2193)
```

## Architecture Patterns

### Recommended Project Structure
```
scripts/
├── storage/
│   ├── RoomInstance.gd        # Existing - extend with timer/state fields
│   ├── RoomSerializer.gd      # Existing - no changes needed
│   └── TimerState.gd          # NEW - standalone timer data class
├── state_machine/
│   ├── RoomStateMachine.gd    # NEW - abstract state machine for rooms
│   └── StateDefinition.gd     # NEW - data class for state configuration
└── ui/
    └── CircularTimerUI.gd     # NEW - visual progress indicator
```

### Pattern 1: Timestamp-Based Offline Timer
**What:** Store Unix timestamp when state starts, calculate elapsed on demand
**When to use:** Any timer that must progress while app is closed
**Example:**
```gdscript
# Source: Godot documentation + v1.1 research pitfalls
class TimerState extends RefCounted:
    var start_time: int = 0      # Unix timestamp (UTC seconds)
    var duration: int = 0        # Duration in seconds
    var is_active: bool = false

    func start(duration_seconds: int) -> void:
        start_time = int(Time.get_unix_time_from_system())  # MUST be int!
        duration = duration_seconds
        is_active = true

    func get_elapsed() -> int:
        if not is_active:
            return 0
        var now = int(Time.get_unix_time_from_system())
        var elapsed = now - start_time
        return maxi(0, elapsed)  # Clamp to prevent negative (clock manipulation)

    func get_remaining() -> int:
        return maxi(0, duration - get_elapsed())

    func is_complete() -> bool:
        return is_active and get_elapsed() >= duration

    func to_dict() -> Dictionary:
        return {
            "start_time": start_time,  # Already int, no scientific notation
            "duration": duration,
            "is_active": is_active
        }

    static func from_dict(data: Dictionary) -> TimerState:
        var timer = TimerState.new()
        timer.start_time = int(data.get("start_time", 0))  # Force int on load
        timer.duration = int(data.get("duration", 0))
        timer.is_active = data.get("is_active", false)
        return timer
```

### Pattern 2: Data-Driven State Machine
**What:** State machine where states are defined as data, not as Node classes
**When to use:** Room states that need to persist and serialize
**Example:**
```gdscript
# Source: GDQuest FSM pattern + TheaterCity RoomInstance pattern
class_name RoomStateMachine extends RefCounted

signal state_changed(old_state: String, new_state: String)

var current_state: String = ""
var timer: TimerState = null
var states: Dictionary = {}  # state_name -> StateDefinition

class StateDefinition extends RefCounted:
    var name: String
    var duration: int = 0  # 0 = no auto-transition
    var next_state: String = ""  # State to transition to when timer completes

    func _init(p_name: String, p_duration: int = 0, p_next: String = ""):
        name = p_name
        duration = p_duration
        next_state = p_next

func define_state(name: String, duration: int = 0, next_state: String = "") -> void:
    states[name] = StateDefinition.new(name, duration, next_state)

func transition_to(new_state: String) -> void:
    if new_state not in states:
        push_error("Unknown state: %s" % new_state)
        return

    var old_state = current_state
    current_state = new_state

    var state_def = states[new_state]
    if state_def.duration > 0:
        if timer == null:
            timer = TimerState.new()
        timer.start(state_def.duration)
    else:
        if timer:
            timer.is_active = false

    state_changed.emit(old_state, new_state)

func update() -> void:
    """Call on _process or app resume to check for auto-transitions."""
    if timer and timer.is_complete():
        var state_def = states.get(current_state)
        if state_def and state_def.next_state != "":
            transition_to(state_def.next_state)

func recalculate_from_elapsed() -> void:
    """Called on app resume to fast-forward through offline transitions."""
    while timer and timer.is_complete():
        var state_def = states.get(current_state)
        if state_def and state_def.next_state != "":
            # Adjust start_time to account for overflow into next state
            var overflow = timer.get_elapsed() - timer.duration
            transition_to(state_def.next_state)
            if timer and timer.is_active:
                timer.start_time -= overflow  # Back-date to account for overflow
        else:
            break  # No next state, stop

func to_dict() -> Dictionary:
    return {
        "current_state": current_state,
        "timer": timer.to_dict() if timer else null
    }

static func from_dict(data: Dictionary, state_defs: Dictionary) -> RoomStateMachine:
    var sm = RoomStateMachine.new()
    sm.states = state_defs
    sm.current_state = data.get("current_state", "")
    if data.get("timer"):
        sm.timer = TimerState.from_dict(data.timer)
    return sm
```

### Pattern 3: App Lifecycle Save/Resume
**What:** Save immediately on pause, recalculate states on resume
**When to use:** All mobile apps with offline state
**Example:**
```gdscript
# Source: TheaterCity RoomManager (already has this pattern!)
# This pattern already exists in RoomManager._notification()
# Phase 11 extends it to recalculate state machines

func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED:
            # Save immediately - Android may kill app any moment
            _save_all_immediately()
        NOTIFICATION_APPLICATION_RESUMED:
            # Recalculate all room states from elapsed time
            _recalculate_all_room_states()

func _recalculate_all_room_states() -> void:
    for room in _rooms:
        if room.state_machine:
            room.state_machine.recalculate_from_elapsed()
```

### Anti-Patterns to Avoid
- **Timer nodes for offline progress:** Timer nodes stop when app closes. NEVER use Timer.wait_time for state durations.
- **Float timestamps in JSON:** `Time.get_unix_time_from_system()` returns float, which JSON may serialize as scientific notation (1.70796e+09). ALWAYS cast to int.
- **Node-based state machines for data states:** LimboHSM and similar are great for behavior, but room state is data (like furniture placement). Use RefCounted.
- **Storing local time:** `get_datetime_dict_from_system(utc=false)` returns local time. ALWAYS use Unix timestamps (UTC) for calculations.
- **Not recalculating on load:** Loading saved state and not checking elapsed time leaves rooms stuck in wrong state.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Offline time tracking | Custom time diff logic | Unix timestamp pattern above | Edge cases (clock manipulation, timezone) are subtle |
| Circular progress bar | Custom `_draw()` arc rendering | TextureProgressBar or Radial Progress Plugin | Handles antialiasing, theming, animation |
| Atomic file saves | Manual temp-file-rename | Existing RoomSerializer pattern | Already handles verification, backup |
| App pause detection | Custom focus tracking | NOTIFICATION_APPLICATION_PAUSED | Built-in, works on all platforms |

**Key insight:** TheaterCity already has most of the persistence infrastructure. This phase adds timer/state data to existing patterns rather than building new systems.

## Common Pitfalls

### Pitfall 1: Timer Nodes for Offline Progression
**What goes wrong:** Timer nodes only run while app is open. Movie started, app closed 30 min, reopened - 0% progress.
**Why it happens:** Developers assume timers work like native mobile timers with system notifications.
**How to avoid:** Use Unix timestamp stored when state began, calculate elapsed on demand.
**Warning signs:** `var timer: Timer` in state code, `timer.timeout` for state transitions.

### Pitfall 2: Float Timestamp Corruption
**What goes wrong:** Timestamp saved as `1.70796e+09` in JSON, loads incorrectly or loses precision.
**Why it happens:** `Time.get_unix_time_from_system()` returns float, JSON uses scientific notation for large floats.
**How to avoid:** Cast to int: `int(Time.get_unix_time_from_system())`
**Warning signs:** JSON contains `e+` notation, elapsed time wildly incorrect on load.

### Pitfall 3: Missing App Pause Handler
**What goes wrong:** State changes during play, app backgrounded, Android kills app, state lost.
**Why it happens:** Relying on periodic auto-save; Android kills apps without calling `_exit_tree()`.
**How to avoid:** Handle `NOTIFICATION_APPLICATION_PAUSED`, save immediately (no debounce).
**Warning signs:** Lost progress reports on mobile, save file timestamp doesn't match app background time.

### Pitfall 4: State Not Recalculated on Load
**What goes wrong:** Room saved in "Playing" with 10 min left, app closed 30 min, loaded still "Playing".
**Why it happens:** Load code sets state directly from saved value, doesn't check elapsed time.
**How to avoid:** Call `recalculate_from_elapsed()` after loading every room with active timer.
**Warning signs:** Rooms stuck in timed states for hours/days, multiple transitions should have occurred.

### Pitfall 5: Backward Clock Detection Fails
**What goes wrong:** Player sets clock backward, negative elapsed time calculated, undefined behavior.
**Why it happens:** Calculation assumes time only moves forward.
**How to avoid:** Clamp elapsed to `maxi(0, elapsed)`, log warning but don't punish player.
**Warning signs:** Crash or strange behavior after timezone change or DST.

### Pitfall 6: Save File Corruption on Suspend
**What goes wrong:** Save starts during app pause, OS suspends mid-write, file corrupted.
**Why it happens:** File.close() doesn't guarantee disk flush before process suspension.
**How to avoid:** Use atomic save pattern (temp file, verify, rename) - already in RoomSerializer.
**Warning signs:** Truncated JSON, parse errors on next load, partial data.

## Code Examples

Verified patterns from official sources:

### Time API Usage
```gdscript
# Source: Godot Time class documentation
# get_unix_time_from_system() returns UTC float - always cast to int

# Get current Unix timestamp (UTC)
var now: int = int(Time.get_unix_time_from_system())

# Calculate elapsed time
var elapsed: int = now - start_timestamp

# For display (convert to local time)
var local_dict = Time.get_datetime_dict_from_unix_time(now)
var time_str = "%02d:%02d" % [local_dict.hour, local_dict.minute]

# For monotonic timing (in-app only, not for persistence)
var frame_start = Time.get_ticks_msec()
# ... do work ...
var frame_time = Time.get_ticks_msec() - frame_start
```

### Integration with RoomInstance
```gdscript
# Source: TheaterCity RoomInstance pattern + v1.1 research
# Extend existing RoomInstance with state machine

class_name RoomInstance extends RefCounted

# ... existing fields ...

# NEW - State machine (optional, depends on room type)
var state_machine: RoomStateMachine = null

func to_dict() -> Dictionary:
    var dict = {
        # ... existing fields ...
    }

    # Add state machine if present
    if state_machine:
        dict["state_machine"] = state_machine.to_dict()

    return dict

static func from_dict(data: Dictionary) -> RoomInstance:
    var room = RoomInstance.new(data.id, data.room_type_id)
    # ... existing field loading ...

    # Load state machine if present
    if data.has("state_machine"):
        # State definitions depend on room type - defer to room type handler
        room._load_state_machine(data.state_machine)

    # CRITICAL: Recalculate state after loading
    if room.state_machine:
        room.state_machine.recalculate_from_elapsed()

    return room
```

### Circular Progress Indicator
```gdscript
# Source: Godot TextureProgressBar docs + practical pattern
# Simple circular timer display

extends Control

@onready var progress_bar: TextureProgressBar = $TextureProgressBar
@onready var time_label: Label = $TimeLabel

var timer_state: TimerState = null

func set_timer(timer: TimerState) -> void:
    timer_state = timer
    visible = timer != null and timer.is_active

func _process(_delta: float) -> void:
    if not timer_state or not timer_state.is_active:
        return

    var remaining = timer_state.get_remaining()
    var total = timer_state.duration

    # Update circular progress (0-100)
    progress_bar.value = (float(remaining) / total) * 100.0

    # Update time label (MM:SS format)
    var minutes = remaining / 60
    var seconds = remaining % 60
    time_label.text = "%d:%02d" % [minutes, seconds]
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Timer nodes for all timing | Unix timestamps for offline | Always (offline never worked) | Core architecture |
| Float timestamps | Integer timestamps | Godot 4.0+ JSON issues | Prevents corruption |
| Node-based FSM for data | RefCounted data FSM | TheaterCity v1.0 patterns | Matches existing architecture |
| Periodic-only saves | Pause handler + periodic | Android lifecycle changes | Prevents data loss |

**Deprecated/outdated:**
- `OS.get_unix_time()` - Godot 3.x, replaced by `Time.get_unix_time_from_system()` in Godot 4
- Storing datetime dict - Timezone issues, use Unix timestamp instead

## Open Questions

Things that couldn't be fully resolved:

1. **Radial Progress Indicator plugin vs TextureProgressBar**
   - What we know: Both work in Godot 4.5, plugin has more options
   - What's unclear: Performance on mobile, theming integration
   - Recommendation: Start with TextureProgressBar (built-in), switch to plugin if insufficient

2. **State machine definitions per room type**
   - What we know: Different room types need different states (theater vs bathroom vs snackbar)
   - What's unclear: Best place to define state configurations (room type resource, separate registry, code)
   - Recommendation: Start with code-defined states in Phase 11, refactor to data if pattern stabilizes

3. **Progress indicator positioning**
   - What we know: Should appear above selected room
   - What's unclear: World-space vs screen-space, handling camera zoom
   - Recommendation: Start with world-space (child of room visual), adjust based on testing

## Sources

### Primary (HIGH confidence)
- [Godot Time class documentation](https://docs.godotengine.org/en/4.4/classes/class_time.html) - API reference for timestamp methods
- [Godot TextureProgressBar documentation](https://docs.godotengine.org/en/stable/classes/class_textureprogressbar.html) - Radial progress display
- TheaterCity `RoomSerializer.gd` - Existing atomic save pattern (verified in codebase)
- TheaterCity `RoomManager.gd` - Existing NOTIFICATION_APPLICATION_PAUSED handling (verified in codebase)
- TheaterCity `RoomInstance.gd` - Existing RefCounted data pattern (verified in codebase)
- `.planning/research/PITFALLS_OFFLINE_TIMERS.md` - Comprehensive pitfall research (verified in project)

### Secondary (MEDIUM confidence)
- [GDQuest FSM Tutorial](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/) - State machine patterns
- [Godot Forum: RefCounted State Machines](https://godotforums.org/d/38465-statemachine-using-states-derived-from-refcounted) - RefCounted FSM discussion
- [Radial Progress Indicator Plugin](https://godotengine.org/asset-library/asset/2193) - Tested on Godot 4.5.1
- [Godot Forum: Float timestamp issues](https://forum.godotengine.org/t/problems-with-configfile-and-time-get-unix-time-from-system/47617) - Scientific notation problem

### Tertiary (LOW confidence)
- [Godot Forum: Idle Game Background Progress](https://forum.godotengine.org/t/idle-game-background-progress/105645) - Community patterns (not verified)
- [Saving/Loading Data - Godot Recipes](https://kidscancode.org/godot_recipes/4.x/basics/file_io/index.html) - General patterns

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All Godot built-ins, extensively documented
- Architecture: HIGH - Extends proven TheaterCity patterns
- Pitfalls: HIGH - Comprehensive prior research in project, verified with official sources
- UI patterns: MEDIUM - TextureProgressBar documented but specific use case not tested

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (30 days - patterns are stable)
