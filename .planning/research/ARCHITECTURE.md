# Architecture Research: Theater Mechanics Integration

**Researched:** 2026-02-08
**Confidence:** HIGH

## Executive Summary

Theater mechanics integrate cleanly into TheaterCity's existing architecture through:
1. **RoomInstance extension** - Add timer/state data fields with to_dict()/from_dict() serialization
2. **New singleton (MovieRegistry)** - Follow existing Registry pattern for movie data
3. **RefCounted state machine** - Lightweight FSM owned by RoomInstance, not scene tree Node
4. **Stateless operations** - TimerOperation, StateOperation for pure logic
5. **Patron extension** - Add seating state to existing navigation behavior

The architecture preserves existing patterns: signal-driven controllers, atomic persistence, RefCounted data models, and stateless operations.

## Existing Architecture Summary

### Core Components to Integrate With

| Component | Type | Purpose | Integration Point |
|-----------|------|---------|------------------|
| `RoomInstance` | RefCounted data model | Room state/data storage | Add timer/state fields |
| `RoomSerializer` | Static utility | JSON persistence (atomic writes) | Auto-serializes new fields |
| `RoomManager` | Autoload singleton | Room tracking, selection, auto-save | Connect to room state changes |
| `RoomBuildController` | Scene controller | Build workflow orchestration | No changes needed |
| `Patron` | CharacterBody2D | Navigation with avoidance | Add seating behavior extension |
| `Targets` | Autoload singleton | Navigation target provider | Register theater seats |
| `*Operation` classes | RefCounted | Stateless logic helpers | Add new operation classes |
| `*Registry` classes | Resource singleton | Data lookup with lazy loading | Add MovieRegistry |
| `*Resource` classes | Resource | Configurable data (via .tres) | Add MovieResource |

### Existing Patterns (Must Follow)

**Data Model Pattern:**
- RefCounted class with typed properties
- Inner classes for nested data (DoorPlacement, FurniturePlacement)
- `to_dict()` / `from_dict()` methods for serialization
- `placement_changed` signal for triggering saves

**Singleton Registry Pattern:**
```gdscript
class_name MovieRegistry
extends Resource

@export var movies: Array[MovieResource] = []

static var _instance: MovieRegistry
static var _path = "res://data/configs/movie_registry.tres"

static func get_instance() -> MovieRegistry:
    if _instance == null:
        _instance = ResourceLoader.load(_path)
    return _instance
```

**Operation Pattern:**
- Stateless RefCounted classes
- Pure functions that operate on data models
- No scene tree dependencies
- Return typed result objects

**Controller Pattern:**
- Node in scene tree with @export references
- Connects signals
- Orchestrates operations
- Manages UI state transitions

## New Components

### 1. Timer System (Abstract, Reusable)

**Purpose:** Generic countdown timer for any room type (theater, snackbar, bathroom)

**Implementation:**

```gdscript
# scripts/timers/TimerState.gd
class_name TimerState
extends RefCounted

enum Status { IDLE, RUNNING, PAUSED, COMPLETED }

var status: Status = Status.IDLE
var total_duration: float = 0.0  # seconds
var time_remaining: float = 0.0  # seconds
var start_time: int = 0  # Unix timestamp

func to_dict() -> Dictionary:
    return {
        "status": status,
        "total_duration": total_duration,
        "time_remaining": time_remaining,
        "start_time": start_time
    }

static func from_dict(data: Dictionary) -> TimerState:
    var timer = TimerState.new()
    timer.status = data.get("status", Status.IDLE)
    timer.total_duration = data.get("total_duration", 0.0)
    timer.time_remaining = data.get("time_remaining", 0.0)
    timer.start_time = data.get("start_time", 0)
    return timer
```

**Integration with RoomInstance:**
```gdscript
# Extend RoomInstance with optional timer
var timer: TimerState = null  # Only for rooms that use timers

func to_dict() -> Dictionary:
    var dict = {
        # ...existing fields...
    }
    if timer:
        dict["timer"] = timer.to_dict()
    return dict
```

**Why RefCounted, not Node:**
- Timer is data, not a scene component
- No need for _process() loop (controller handles updates)
- Serializes naturally with RoomInstance
- Multiple rooms can have independent timers without scene tree clutter

### 2. Room State Machine (Theater-Specific)

**Purpose:** Theater-specific states (idle, scheduled, pre_show, showing, post_show, cooldown)

**Implementation:**

```gdscript
# scripts/room_state/TheaterState.gd
class_name TheaterState
extends RefCounted

enum State { IDLE, SCHEDULED, PRE_SHOW, SHOWING, POST_SHOW, COOLDOWN }

var current_state: State = State.IDLE
var scheduled_movie_id: String = ""
var show_start_time: int = 0  # Unix timestamp

func to_dict() -> Dictionary:
    return {
        "current_state": current_state,
        "scheduled_movie_id": scheduled_movie_id,
        "show_start_time": show_start_time
    }

static func from_dict(data: Dictionary) -> TheaterState:
    var state = TheaterState.new()
    state.current_state = data.get("current_state", State.IDLE)
    state.scheduled_movie_id = data.get("scheduled_movie_id", "")
    state.show_start_time = data.get("show_start_time", 0)
    return state
```

**Integration with RoomInstance:**
```gdscript
# Extend RoomInstance with optional theater state
var theater_state: TheaterState = null  # Only for theater rooms

func to_dict() -> Dictionary:
    var dict = {
        # ...existing fields...
    }
    if theater_state:
        dict["theater_state"] = theater_state.to_dict()
    return dict
```

**Why RefCounted FSM, not LimboHSM:**
- Theater state is data, not AI behavior
- LimboHSM is for scene-based AI (enemies, NPCs)
- RefCounted FSM serializes with room data
- Simple enum-based state is sufficient for room logic
- Controllers handle state transitions (like RoomBuildController handles build states)

### 3. Movie Data Registry

**Purpose:** Movie definitions (title, duration, genre, patron attraction)

**Components:**

```gdscript
# scripts/data/MovieResource.gd
class_name MovieResource
extends Resource

@export var id: String
@export var title: String
@export var duration: float = 120.0  # seconds (2 minutes default)
@export var genre: String = "comedy"
@export var patron_attraction: float = 1.0  # Multiplier for patron interest
@export var description: String = ""

# scripts/data/MovieRegistry.gd
class_name MovieRegistry
extends Resource

@export var movies: Array[MovieResource] = []

static var _instance: MovieRegistry
static var _path = "res://data/configs/movie_registry.tres"

static func get_instance() -> MovieRegistry:
    if _instance == null:
        _instance = ResourceLoader.load(_path)
    return _instance

func get_movie(id: String) -> MovieResource:
    for movie in movies:
        if movie.id == id:
            return movie
    return null
```

**Why separate from RoomTypeResource:**
- Movies are content, not room types
- Same movie can play in multiple theaters
- Movies can be added/removed independently of room types
- Follows existing Registry pattern (RoomTypeRegistry, FurnitureRegistry)

### 4. Theater Controller

**Purpose:** Orchestrate theater-specific logic (state transitions, timer updates, patron seating)

**Implementation:**

```gdscript
# scripts/theater/TheaterController.gd
class_name TheaterController
extends Node

signal movie_scheduled(room: RoomInstance, movie_id: String)
signal show_started(room: RoomInstance)
signal show_ended(room: RoomInstance)

var _timer_op: TimerOperation
var _state_op: TheaterStateOperation

func _ready() -> void:
    _timer_op = TimerOperation.new()
    _state_op = TheaterStateOperation.new()
    RoomManager.room_added.connect(_on_room_added)

func _process(delta: float) -> void:
    # Update all theater timers
    for room in RoomManager.get_all_rooms():
        if room.room_type_id == "theater" and room.timer:
            _update_theater(room, delta)

func schedule_movie(room: RoomInstance, movie_id: String) -> bool:
    var movie = MovieRegistry.get_instance().get_movie(movie_id)
    if not movie:
        return false

    # Initialize state and timer
    if not room.theater_state:
        room.theater_state = TheaterState.new()
    if not room.timer:
        room.timer = TimerState.new()

    # Use operations for state logic
    _state_op.transition_to_scheduled(room.theater_state, movie_id)
    _timer_op.start_countdown(room.timer, movie.duration)

    room.placement_changed.emit()  # Trigger auto-save
    movie_scheduled.emit(room, movie_id)
    return true

func _update_theater(room: RoomInstance, delta: float) -> void:
    # Update timer
    _timer_op.tick(room.timer, delta)

    # Handle state transitions based on timer
    if room.timer.status == TimerState.Status.COMPLETED:
        _on_timer_completed(room)

func _on_timer_completed(room: RoomInstance) -> void:
    match room.theater_state.current_state:
        TheaterState.State.PRE_SHOW:
            _start_show(room)
        TheaterState.State.SHOWING:
            _end_show(room)
```

**Why separate controller:**
- Follows existing pattern (RoomBuildController, FurnitureEditController)
- Centralizes theater logic
- Can be disabled/enabled via feature flags
- Keeps RoomManager generic

### 5. Stateless Operations

**Purpose:** Pure logic for timer and state manipulation

**TimerOperation:**
```gdscript
# scripts/timers/TimerOperation.gd
class_name TimerOperation
extends RefCounted

func start_countdown(timer: TimerState, duration: float) -> void:
    timer.status = TimerState.Status.RUNNING
    timer.total_duration = duration
    timer.time_remaining = duration
    timer.start_time = Time.get_unix_time_from_system()

func tick(timer: TimerState, delta: float) -> void:
    if timer.status == TimerState.Status.RUNNING:
        timer.time_remaining -= delta
        if timer.time_remaining <= 0.0:
            timer.time_remaining = 0.0
            timer.status = TimerState.Status.COMPLETED

func pause(timer: TimerState) -> void:
    if timer.status == TimerState.Status.RUNNING:
        timer.status = TimerState.Status.PAUSED

func resume(timer: TimerState) -> void:
    if timer.status == TimerState.Status.PAUSED:
        timer.status = TimerState.Status.RUNNING

func reset(timer: TimerState) -> void:
    timer.status = TimerState.Status.IDLE
    timer.time_remaining = 0.0
```

**TheaterStateOperation:**
```gdscript
# scripts/room_state/TheaterStateOperation.gd
class_name TheaterStateOperation
extends RefCounted

func transition_to_scheduled(state: TheaterState, movie_id: String) -> void:
    state.current_state = TheaterState.State.SCHEDULED
    state.scheduled_movie_id = movie_id
    state.show_start_time = Time.get_unix_time_from_system()

func transition_to_showing(state: TheaterState) -> void:
    state.current_state = TheaterState.State.SHOWING

func transition_to_idle(state: TheaterState) -> void:
    state.current_state = TheaterState.State.IDLE
    state.scheduled_movie_id = ""
    state.show_start_time = 0

func can_schedule(state: TheaterState) -> bool:
    return state.current_state == TheaterState.State.IDLE
```

**Why stateless operations:**
- Testable without scene tree
- Reusable across controllers
- Follows existing pattern (WallOperation, DoorOperation, ValidationOperation)
- No dependencies on scene nodes

### 6. Patron Seating Extension

**Purpose:** Extend existing Patron navigation to support seated behavior

**Implementation:**

```gdscript
# Extend Patron.gd
enum PatronState { WANDERING, HEADING_TO_SEAT, SEATED, EXITING }

var patron_state: PatronState = PatronState.WANDERING
var assigned_seat: Vector2i = Vector2i.ZERO
var seated_room: RoomInstance = null

func enter_theater(room: RoomInstance, seat_position: Vector2i) -> void:
    patron_state = PatronState.HEADING_TO_SEAT
    assigned_seat = seat_position
    seated_room = room

    # Use existing navigation system
    var world_pos = IsometricMath.tile_to_world_float(Vector2(seat_position))
    nav_agent.target_position = world_pos

func _physics_process(delta: float) -> void:
    match patron_state:
        PatronState.WANDERING:
            # Existing wandering behavior
            _handle_wandering(delta)
        PatronState.HEADING_TO_SEAT:
            # Existing navigation behavior
            _handle_navigation(delta)
            if nav_agent.is_navigation_finished():
                _sit_down()
        PatronState.SEATED:
            # Idle animation at seat
            animated_sprite.play("idle" + str(_get_facing_direction()))
        PatronState.EXITING:
            # Navigate to exit
            _handle_navigation(delta)

func _sit_down() -> void:
    patron_state = PatronState.SEATED
    velocity = Vector2.ZERO
    # Disable navigation while seated
    nav_agent.velocity = Vector2.ZERO
```

**Why extend Patron, not new class:**
- Reuses existing navigation, animation, avoidance systems
- Patrons can transition between wandering and seated states
- Single patron pool (no separate "theater patron" class)
- Follows single responsibility with state enum

### 7. Scheduling UI

**Purpose:** UI for scheduling movies (triggered from room-type button)

**Implementation:**

```gdscript
# scripts/theater/SchedulingUI.gd
class_name SchedulingUI
extends CanvasLayer

signal movie_selected(movie_id: String)
signal cancelled

@onready var _movie_list: VBoxContainer = $Panel/MovieList
@onready var _room_label: Label = $Panel/RoomLabel

var _current_room: RoomInstance = null

func show_for_room(room: RoomInstance) -> void:
    _current_room = room
    _room_label.text = "Schedule Movie for %s" % room.id
    _populate_movie_list()
    show()

func _populate_movie_list() -> void:
    # Clear existing buttons
    for child in _movie_list.get_children():
        child.queue_free()

    # Create button for each movie
    var movies = MovieRegistry.get_instance().movies
    for movie in movies:
        var button = Button.new()
        button.text = "%s (%d min)" % [movie.title, movie.duration / 60]
        button.pressed.connect(_on_movie_button_pressed.bind(movie.id))
        _movie_list.add_child(button)

func _on_movie_button_pressed(movie_id: String) -> void:
    movie_selected.emit(movie_id)
    hide()
```

**Integration with RoomEditMenu:**
```gdscript
# Extend scripts/room_editing/RoomEditMenu.gd
func _create_room_type_button(room: RoomInstance) -> Button:
    var button = Button.new()

    # Theater-specific behavior
    if room.room_type_id == "theater":
        button.text = "Schedule Movie"
        button.pressed.connect(_on_schedule_movie_pressed.bind(room))
    else:
        button.text = room.room_type_id.capitalize()

    return button

func _on_schedule_movie_pressed(room: RoomInstance) -> void:
    scheduling_ui.show_for_room(room)
```

**Why CanvasLayer, not Control:**
- Screen-space UI (doesn't move with camera)
- Follows existing UI pattern (see CLAUDE.md UI conventions)
- Modal overlay behavior

## Integration Points

### 1. RoomInstance Extensions

**Modified:** `scripts/storage/RoomInstance.gd`

Add optional fields for theater mechanics:
```gdscript
var timer: TimerState = null  # Generic timer (theater, snackbar, bathroom)
var theater_state: TheaterState = null  # Theater-specific state

func to_dict() -> Dictionary:
    var dict = {
        # ...existing fields...
    }
    if timer:
        dict["timer"] = timer.to_dict()
    if theater_state:
        dict["theater_state"] = theater_state.to_dict()
    return dict

static func from_dict(data: Dictionary) -> RoomInstance:
    var room = RoomInstance.new(data.id, data.room_type_id)
    # ...existing restoration...

    # Restore timer if present
    if data.has("timer"):
        room.timer = TimerState.from_dict(data.timer)

    # Restore theater state if present
    if data.has("theater_state"):
        room.theater_state = TheaterState.from_dict(data.theater_state)

    return room
```

**Why this works:**
- RoomSerializer already serializes all RoomInstance fields via to_dict()
- Optional fields (null by default) don't affect non-theater rooms
- Schema versioning already in place (SCHEMA_VERSION constant)
- Auto-save already triggers on placement_changed signal

### 2. RoomManager Integration

**Modified:** `scripts/RoomManager.gd`

No structural changes needed. TheaterController subscribes to existing signals:
```gdscript
# In TheaterController
func _ready() -> void:
    RoomManager.room_added.connect(_on_room_added)
    RoomManager.room_restored.connect(_on_room_restored)
    RoomManager.room_removed.connect(_on_room_removed)
```

Theater state changes emit `room.placement_changed` to trigger auto-save:
```gdscript
func schedule_movie(room: RoomInstance, movie_id: String) -> bool:
    # ...setup state and timer...
    room.placement_changed.emit()  # Triggers RoomManager auto-save
    return true
```

**Why no RoomManager changes:**
- RoomManager is generic (tracks all room types)
- Theater logic lives in TheaterController
- Existing signal system sufficient
- Preserves separation of concerns

### 3. Patron Extension

**Modified:** `scripts/Patron.gd`

Add state enum and seating methods (see "Patron Seating Extension" above).

**Integration with Targets:**
```gdscript
# Register theater seats as navigation targets
func _register_theater_seats(room: RoomInstance) -> void:
    var seat_furniture = _find_seats_in_room(room)
    for seat in seat_furniture:
        Targets.add_entity(seat.visual_node)
```

**Why extend Patron:**
- Reuses NavigationAgent2D pathfinding
- Reuses animated sprite system
- Reuses avoidance system
- State pattern keeps code organized

### 4. Main Scene Integration

**Modified:** `Main.tscn` and `scripts/Main.gd`

Add TheaterController and SchedulingUI nodes:
```
Main (Node2D)
├── RoomBuildSystem
│   └── RoomBuildController
├── TheaterSystem (Node)  # NEW
│   └── TheaterController
└── UILayer (CanvasLayer)
    ├── SchedulingUI  # NEW
    └── RoomEditMenu
```

**Why new system node:**
- Parallel to existing RoomBuildSystem
- Can be disabled via feature flags
- Clear separation of concerns
- Easy to expand (add SnackbarController later)

## Data Flow

### Movie Scheduling Flow

```
1. User taps theater room
   └─> RoomManager.room_selected signal fires

2. RoomEditMenu shows room-type button "Schedule Movie"
   └─> Button triggers SchedulingUI.show_for_room(room)

3. SchedulingUI displays movie list from MovieRegistry
   └─> User selects movie
   └─> SchedulingUI.movie_selected signal fires

4. TheaterController receives movie_selected signal
   └─> Calls schedule_movie(room, movie_id)
   └─> Creates/updates room.timer and room.theater_state
   └─> Emits room.placement_changed signal

5. RoomManager receives placement_changed signal
   └─> Schedules auto-save via debounce timer
   └─> RoomSerializer.save_rooms() called after 5s

6. Save writes to user://saves/rooms.json (atomic write)
   └─> Timer and state persisted in room data
```

### Timer Update Flow

```
1. TheaterController._process(delta) called every frame
   └─> Iterates all rooms in RoomManager

2. For each theater room with active timer:
   └─> TimerOperation.tick(room.timer, delta)
   └─> Decrements time_remaining

3. When timer completes:
   └─> TheaterController._on_timer_completed(room)
   └─> TheaterStateOperation transitions state
   └─> Appropriate signal fires (show_started, show_ended)
   └─> room.placement_changed emitted (triggers save)

4. State-specific logic executes:
   └─> PRE_SHOW → SHOWING: Patrons enter, lights dim
   └─> SHOWING → POST_SHOW: Movie ends, patrons exit
   └─> POST_SHOW → IDLE: Room ready for next scheduling
```

### Patron Seating Flow

```
1. Movie enters SHOWING state
   └─> TheaterController.show_started signal fires

2. PatronManager (or TheaterController) spawns/redirects patrons
   └─> Finds available seats in theater room
   └─> Calls patron.enter_theater(room, seat_position)

3. Patron uses existing navigation system
   └─> nav_agent.target_position = seat world position
   └─> NavigationAgent2D calculates path
   └─> Avoidance system prevents collisions

4. Patron reaches seat
   └─> nav_agent.is_navigation_finished() returns true
   └─> patron._sit_down() called
   └─> patron_state = SEATED
   └─> Play idle animation facing screen

5. Movie ends (timer completes)
   └─> TheaterController.show_ended signal fires
   └─> Patrons transition to EXITING state
   └─> Navigate to room exit door
```

### Load/Restore Flow

```
1. Game starts
   └─> RoomManager._ready() calls _load_saved_rooms()
   └─> RoomSerializer.load_rooms() reads JSON

2. For each room in save file:
   └─> RoomInstance.from_dict(room_data) restores all fields
   └─> Optional timer/state fields restored if present
   └─> RoomManager.room_restored signal fires

3. TheaterController receives room_restored signal
   └─> Checks if room.theater_state exists
   └─> If state = SHOWING, resumes timer from time_remaining
   └─> If state = SCHEDULED, validates show_start_time

4. RoomBuildController receives room_restored signal (existing)
   └─> Restores walls, doors, furniture visuals
   └─> Updates navigation mesh
```

## Suggested Build Order

### Phase 1: Data Foundation (No UI, No Logic)

**Goal:** Add data structures without breaking existing functionality

**Tasks:**
1. Create `TimerState` RefCounted class with serialization
2. Create `TheaterState` RefCounted class with serialization
3. Extend `RoomInstance` with optional timer/theater_state fields
4. Add to_dict()/from_dict() support for new fields
5. Write unit tests for serialization round-trips

**Verification:**
- Existing rooms load/save without errors
- New fields serialize to JSON correctly
- Non-theater rooms ignore new fields (null)

**Dependencies:** None (pure data model changes)

### Phase 2: Movie Registry (Static Data)

**Goal:** Add movie definitions without runtime logic

**Tasks:**
1. Create `MovieResource` class
2. Create `MovieRegistry` singleton
3. Create initial movie resources (.tres files)
4. Add to FurnitureRegistry pattern for lazy loading

**Verification:**
- MovieRegistry.get_instance() loads without errors
- get_movie(id) returns correct MovieResource
- Multiple movies defined and accessible

**Dependencies:** None (follows existing Registry pattern)

### Phase 3: Operations (Pure Logic)

**Goal:** Add stateless operations for timer and state

**Tasks:**
1. Create `TimerOperation` class (start, tick, pause, resume, reset)
2. Create `TheaterStateOperation` class (transitions, validations)
3. Write unit tests for operations

**Verification:**
- TimerOperation.tick() decrements time correctly
- State transitions follow valid paths
- Operations are pure (no side effects)

**Dependencies:** Phase 1 (needs TimerState, TheaterState)

### Phase 4: Theater Controller (Integration)

**Goal:** Wire operations to room updates

**Tasks:**
1. Create `TheaterController` Node class
2. Add to Main.tscn scene
3. Implement schedule_movie() method
4. Implement _process() timer updates
5. Connect to RoomManager signals
6. Emit theater-specific signals

**Verification:**
- schedule_movie() creates timer/state on room
- Timer counts down each frame
- room.placement_changed triggers save
- Saved rooms restore with timer/state

**Dependencies:** Phases 1-3 (needs data models, registries, operations)

### Phase 5: Scheduling UI

**Goal:** User can trigger scheduling

**Tasks:**
1. Create `SchedulingUI` CanvasLayer scene
2. Implement movie list population
3. Add to Main.tscn under UILayer
4. Extend `RoomEditMenu` with "Schedule Movie" button (theater-specific)
5. Connect signals to TheaterController

**Verification:**
- "Schedule Movie" button appears for theater rooms
- Movie list displays all movies from registry
- Selecting movie creates timer on room
- UI hides after selection

**Dependencies:** Phases 2, 4 (needs MovieRegistry, TheaterController)

### Phase 6: Patron Seating (Behavior Extension)

**Goal:** Patrons navigate to seats and sit

**Tasks:**
1. Add PatronState enum to Patron.gd
2. Implement enter_theater() method
3. Extend _physics_process() with state handling
4. Add _sit_down() method
5. Register theater seats with Targets singleton
6. Connect TheaterController signals to patron spawning

**Verification:**
- Patrons navigate to assigned seats
- Patrons play idle animation when seated
- Patrons exit after movie ends
- No collision issues during seating/exiting

**Dependencies:** Phase 4 (needs TheaterController signals)

### Dependency Graph

```
Phase 1 (Data Foundation)
    ↓
Phase 2 (Movie Registry)  +  Phase 3 (Operations)
    ↓                            ↓
    └───────────> Phase 4 (Theater Controller) <─────┘
                      ↓
         Phase 5 (UI)  +  Phase 6 (Patron Extension)
```

**Critical Path:** 1 → 3 → 4 → 6
**Parallel Work:** Phases 2, 3, 5 can be developed in parallel after Phase 1

## Persistence Strategy

### Serialization Approach

**Use existing RoomSerializer JSON format** - no new save files, no new serialization code.

**Why this works:**
1. RoomSerializer already calls `room.to_dict()` for each room
2. RoomInstance already has schema versioning (SCHEMA_VERSION constant)
3. Optional fields (timer, theater_state) don't break existing saves
4. Atomic write pattern already implemented (temp file + rename)
5. Auto-save already triggers on room.placement_changed signal

### Schema Evolution

**Current schema:**
```json
{
  "version": 1,
  "saved_at": "2026-02-08T10:30:00",
  "rooms": [
    {
      "schema_version": 1,
      "id": "room_1",
      "room_type_id": "lobby",
      "bounding_box": {...},
      "walls": [...],
      "doors": [...],
      "furniture": [...]
    }
  ]
}
```

**Extended schema (theater room):**
```json
{
  "version": 1,
  "saved_at": "2026-02-08T10:35:00",
  "rooms": [
    {
      "schema_version": 1,
      "id": "room_2",
      "room_type_id": "theater",
      "bounding_box": {...},
      "walls": [...],
      "doors": [...],
      "furniture": [...],
      "timer": {
        "status": 1,
        "total_duration": 120.0,
        "time_remaining": 75.5,
        "start_time": 1738000000
      },
      "theater_state": {
        "current_state": 3,
        "scheduled_movie_id": "action_movie_1",
        "show_start_time": 1738000000
      }
    }
  ]
}
```

### Backwards Compatibility

**Old save → New code:**
- RoomInstance.from_dict() checks `data.has("timer")` before restoring
- Missing fields default to null
- Non-theater rooms unaffected

**New save → Old code:**
- Old code ignores unknown fields (timer, theater_state)
- Room loads successfully
- Timer/state data lost (acceptable for rollback scenario)

### Migration Strategy

**No migration needed** - optional fields are gracefully handled.

**If future breaking changes:**
1. Increment RoomInstance.SCHEMA_VERSION
2. Add migration logic in from_dict()
3. Handle old schema versions explicitly

Example:
```gdscript
static func from_dict(data: Dictionary) -> RoomInstance:
    var version = data.get("schema_version", 1)

    if version < 2:
        # Migrate v1 → v2 (add default timer if missing)
        if not data.has("timer") and data.room_type_id == "theater":
            data["timer"] = {"status": 0, "total_duration": 0.0, "time_remaining": 0.0}

    # Continue with normal restoration...
```

### Save Timing

**Triggers:**
- Movie scheduled → room.placement_changed.emit()
- Timer state changes → room.placement_changed.emit()
- Theater state transitions → room.placement_changed.emit()
- Furniture/door changes → room.placement_changed.emit() (existing)

**Debounce:** 5 seconds (existing SAVE_DEBOUNCE_SECONDS constant)

**Immediate save triggers:**
- Application pause (NOTIFICATION_APPLICATION_PAUSED)
- Window close (NOTIFICATION_WM_CLOSE_REQUEST)

**Why this works:**
- Prevents save spam during rapid state changes
- Ensures saves on app backgrounding (mobile)
- Existing RoomManager._schedule_save() handles debouncing

## Godot-Specific Patterns

### Why RefCounted for State Machines?

**Community pattern:** Node-based state machines are common for AI/entities

**TheaterCity pattern:** RefCounted state machines for data models

**Reasoning:**
- Theater state is **data** (like furniture placement), not **behavior** (like enemy AI)
- Theater state must serialize with room
- Theater state doesn't need scene tree lifecycle (_ready, _process)
- TheaterController handles updates (not state machine itself)
- Follows existing pattern (RoomInstance, ValidationResult, etc.)

**When to use Node-based FSM (LimboHSM):**
- Enemy AI behavior trees
- Complex NPC decision-making
- Scene-specific state (player input modes)

**When to use RefCounted FSM:**
- Serializable game state
- Data model state (room, inventory, quest)
- Pure state without behavior

### Timer Patterns

**Godot Timer Node:** Scene-based, signal-driven, one-shot or repeating

**TheaterCity Timer:** RefCounted data, controller-driven, serializable

**Why not use Timer Node:**
- Timer state must serialize (pause/resume across sessions)
- Multiple rooms need independent timers (scene tree clutter)
- Timer is data (time_remaining) not just a trigger

**Why controller-driven updates:**
- Single _process() loop for all theaters
- Centralized timer management
- Easy to pause/resume all timers (game pause)
- Controller can emit signals at state transitions

**Best practice:** Use Timer Node for UI delays, use RefCounted timer for game state.

### Autoload Singletons

**Existing pattern:**
- RoomManager (singleton, scene tree Node)
- Targets (singleton, scene tree Node)

**New pattern:**
- MovieRegistry (singleton, Resource with static instance)

**Why different approaches:**

| Singleton Type | Use Case | Example |
|----------------|----------|---------|
| Autoload Node | Runtime state, signals, updates | RoomManager |
| Static Resource | Static data, lazy loading | MovieRegistry |

**MovieRegistry is static Resource because:**
- No runtime state (movies don't change at runtime)
- No signals needed (read-only lookup)
- Lazy loading pattern (load .tres only when first accessed)
- Follows RoomTypeRegistry, FurnitureRegistry pattern

**TheaterController is NOT singleton because:**
- Only one instance needed (added to Main scene)
- Needs scene tree for _process() updates
- Emits signals to other controllers
- Can be removed/disabled via feature flags

## Architecture Validation

### Alignment with Existing Patterns

| Pattern | Existing Example | Theater Implementation |
|---------|------------------|------------------------|
| RefCounted data model | RoomInstance | TimerState, TheaterState |
| Singleton registry | RoomTypeRegistry | MovieRegistry |
| Stateless operations | WallOperation | TimerOperation, TheaterStateOperation |
| Signal-driven controller | RoomBuildController | TheaterController |
| Serialization | to_dict()/from_dict() | Extended RoomInstance serialization |
| Auto-save | placement_changed signal | Reuses existing RoomManager auto-save |
| Scene extension | Patron with NavigationAgent2D | Patron with PatronState enum |

**Zero pattern violations** - all new components follow existing architecture.

### Key Design Decisions

**1. Why extend RoomInstance instead of inheritance?**
- RoomInstance is already a flexible data model
- Optional fields (null by default) don't affect non-theater rooms
- Inheritance would require parallel FurnitureEditController, RoomEditMenu extensions
- Simpler to have one RoomInstance class with optional features

**2. Why RefCounted state machine instead of LimboHSM?**
- Theater state is data (must serialize)
- LimboHSM is for scene-based AI behavior
- RefCounted FSM matches RoomInstance pattern
- Controller handles transitions (like RoomBuildController handles build states)

**3. Why separate TheaterController instead of extending RoomManager?**
- RoomManager is generic (all room types)
- Theater logic is feature-specific
- Can be disabled via feature flags
- Easier to add SnackbarController, BathroomController later
- Follows single responsibility principle

**4. Why not separate save file for theater state?**
- RoomSerializer already handles all room data
- Theater state is room state (not global game state)
- Atomic saves prevent corruption
- Single source of truth for room data
- Simpler backup/restore

**5. Why controller-driven timer updates instead of Timer nodes?**
- Timer state must serialize (time_remaining)
- Centralized updates (one _process loop)
- Easy to pause all timers (game pause feature)
- Matches existing controller pattern

### Future Extensibility

**Adding new room types with timers:**
```gdscript
# Snackbar room type
var timer: TimerState = null  # Reuse existing timer
var snackbar_state: SnackbarState = null  # New state machine

# Bathroom room type
var timer: TimerState = null  # Reuse existing timer
var bathroom_state: BathroomState = null  # New state machine
```

**Adding new patron behaviors:**
```gdscript
# Extend PatronState enum
enum PatronState {
    WANDERING,
    HEADING_TO_SEAT,
    SEATED,
    EXITING,
    ORDERING_SNACKS,  # NEW
    USING_BATHROOM    # NEW
}
```

**Architecture supports:**
- Multiple room types with independent state machines
- Shared timer system (DRY principle)
- Shared patron navigation (reuse existing system)
- Independent controllers per room type
- Feature flags to enable/disable room types

## Research Sources

### Godot State Machine Patterns

Based on community resources and official documentation, Godot 4.5 state machines follow these patterns:

1. **Node-Based FSM** - Most popular for AI behaviors, uses scene tree for organization
   - Source: [Make a Finite State Machine in Godot 4 · GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)
   - Source: [Godot State Machine Complete Tutorial (2025)](https://generalistprogrammer.com/tutorials/godot-state-machine-complete-tutorial-game-ai)

2. **Simple Enum/Match Approach** - Lightweight for simple state tracking
   - Source: [State machines in godot 4.5 - Godot Forum](https://forum.godotengine.org/t/state-machines-in-godot-4-5/132653)

3. **State Design Pattern** - Official documentation pattern
   - Source: [State design pattern — Godot Engine documentation](https://docs.godotengine.org/en/3.2/tutorials/misc/state_design_pattern.html)

### Godot Timer System

Timer implementation best practices from Godot community:

1. **Built-in Timer Node** - Signal-driven countdown for scene-based events
   - Source: [Timer In Godot - Complete Guide - GameDev Academy](https://gamedevacademy.org/timer-in-godot-complete-guide/)
   - Source: [Timer — Godot Engine (4.4) documentation](https://docs.godotengine.org/en/4.4/classes/class_timer.html)

2. **Countdown Timer Mechanics** - Game design considerations
   - Source: [How to make a timer in Godot - Game Dev Beginner](https://gamedevbeginner.com/how-to-make-a-timer-in-godot-count-up-down-in-minutes-seconds/)
   - Source: [Make a Time Counter in Godot 4 in One Minute | Medium](https://medium.com/codex/make-a-time-counter-in-godot-4-in-one-minute-7cfaa6ddbdb1)

### RefCounted Serialization

RefCounted serialization patterns in Godot:

1. **Ref Serializer Utility** - Community solution for lightweight RefCounted objects
   - Source: [GitHub - KoBeWi/Godot-Ref-Serializer](https://github.com/KoBeWi/Godot-Ref-Serializer)
   - Source: [Ref Serializer - Godot Asset Library](https://godotengine.org/asset-library/asset/3167)

2. **Binary Serialization API** - Official Godot serialization documentation
   - Source: [Binary serialization API — Godot Engine documentation](https://docs.godotengine.org/en/stable/tutorials/io/binary_serialization_api.html)

3. **Serialization Discussion** - Community proposals and patterns
   - Source: [Need a way to serialize simple objects · godotengine/godot-proposals](https://github.com/godotengine/godot-proposals/discussions/7435)
   - Source: [How to load and save things with Godot - Godot Forum](https://forum.godotengine.org/t/how-to-load-and-save-things-with-godot-a-complete-tutorial-about-serialization/44515)

## Confidence Assessment

**Overall confidence:** HIGH

**Rationale:**
- All patterns verified against existing codebase
- Zero new architectural patterns (reuses existing)
- RefCounted serialization proven in RoomInstance
- Operation pattern proven in WallOperation, DoorOperation
- Controller pattern proven in RoomBuildController
- Registry pattern proven in RoomTypeRegistry, FurnitureRegistry
- Patron extension verified via existing NavigationAgent2D integration

**Godot-specific patterns confidence:** HIGH
- State machine patterns researched from official docs and community
- Timer patterns verified against Godot 4.4/4.5 documentation
- RefCounted serialization patterns verified via community implementations
- Autoload singleton pattern already used in project

**Integration points confidence:** HIGH
- RoomInstance extension: Verified to_dict()/from_dict() pattern
- RoomSerializer: Verified atomic write pattern
- RoomManager: Verified signal-driven auto-save
- Patron: Verified NavigationAgent2D usage

**Build order confidence:** HIGH
- Dependency graph is linear (clear build sequence)
- Each phase has concrete verification criteria
- No circular dependencies
- Parallel work opportunities identified
