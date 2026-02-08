# Pitfalls Research: Offline Timers & Mobile State

**Domain:** Real-time progression for theater rooms (movies, cleaning) in mobile game
**Researched:** 2026-02-08
**Confidence:** HIGH (Godot-specific issues verified, Android lifecycle documented, mobile game patterns researched)

## Executive Summary

Implementing offline timers (timers that progress when the app is closed) and mobile state recovery for TheaterCity presents several high-risk pitfalls. The core challenge: maintaining accurate state transitions for rooms (Playing → Cleaning → Available) when the app may be suspended, killed, or have its system clock manipulated. This research identifies critical mistakes that cause state desync, data loss, and cheating vulnerabilities.

**Key risks:**
1. **State desynchronization** - App resumes in wrong state after long suspension
2. **System clock cheating** - Players manipulate device time to skip timers
3. **Save file corruption** - Race conditions during app suspension
4. **Timezone confusion** - UTC vs local time causing incorrect elapsed time
5. **Process death** - Android kills app without saving state

---

## Critical Pitfalls

Mistakes that cause data loss, broken gameplay, or require architectural rewrites.

### Pitfall 1: Using Timer Nodes for Offline Progression

**Risk:** Timer nodes only count down while the app is running. When app closes, timers stop. Player starts 30-minute movie → closes app for 30 minutes → reopens → movie still at 0% progress.

**Why it happens:**
- Common misunderstanding: Timer nodes cannot run while app is closed
- Godot's Timer class is frame-based (`_process` driven) and pauses when app is not running
- Developers familiar with native mobile timers (iOS Local Notifications) assume Godot has similar capability
- Tutorial examples use Timer for in-game countdowns, not offline progression

**Consequences:**
- Real-time progression completely broken
- Movies never complete if player closes app
- Theater mechanic is non-functional
- Must rewrite time system after discovering issue in production

**Warning Signs:**
- Timer node used for room state duration tracking
- No Unix timestamp saved for state start time
- Code uses `Timer.wait_time` and `Timer.timeout` signal for long-duration events (>5 minutes)
- State machine transitions trigger on `timeout` signal only

**Prevention:**

```gdscript
# WRONG - Timer nodes don't run when app is closed:
class RoomState:
    var timer: Timer

    func start_movie() -> void:
        timer.wait_time = 1800  # 30 minutes
        timer.start()  # Stops when app closes!

# CORRECT - Store Unix timestamp, calculate elapsed on resume:
class RoomState:
    var state_name: String  # "Playing", "Cleaning", "Available"
    var state_started_at: int  # Unix timestamp in seconds
    var state_duration: int  # Duration in seconds

    func start_movie() -> void:
        state_name = "Playing"
        state_started_at = Time.get_unix_time_from_system()
        state_duration = 1800  # 30 minutes
        # Save to persistence immediately
        _save_room_state()

    func update_state() -> void:
        # Called on app resume and periodically during play
        if state_name == "Playing" or state_name == "Cleaning":
            var current_time = Time.get_unix_time_from_system()
            var elapsed = current_time - state_started_at

            if elapsed >= state_duration:
                _transition_to_next_state()
```

**Phase to address:** Phase 1 (Theater Room State Machine) must establish timestamp-based system from the start. Do NOT use Timer nodes for state duration tracking.

**Testing:**
- Start movie → kill app process → wait 30 minutes → relaunch → verify movie completed
- Start cleaning → close app → change device time forward 10 minutes → reopen → verify cleaning completed

**Sources:**
- [Let a timer still run if the game is closed - Godot Forum](https://godotengine.org/qa/67347/let-a-timer-still-run-if-the-game-is-closed)
- [Can you set a timer to run when the program is off? - Godot Forum](https://forum.godotengine.org/t/can-you-set-a-timer-to-run-when-the-program-is-off/10909)
- [How can I measure the time since the game was last opened? - Godot Forum](https://forum.godotengine.org/t/how-can-i-measure-the-time-since-the-game-was-last-opened/16843)

---

### Pitfall 2: Storing Timestamps as Float → Scientific Notation Corruption

**Risk:** Unix timestamp saved as `1.70796e+09` in JSON → parsing fails or loses precision → state calculation breaks.

**Why it happens:**
- `Time.get_unix_time_from_system()` returns float (has decimal component for sub-second precision)
- `JSON.stringify()` formats large floats in scientific notation
- When loading, scientific notation string may parse incorrectly or lose precision
- `ConfigFile` (`.ini` format) also has this issue with floats

**Consequences:**
- Timestamp reads as 0 or wildly incorrect value on load
- Elapsed time calculation produces negative values or massive numbers
- Rooms stuck in "Playing" state forever
- Save file appears valid (no JSON parse errors) but data is corrupted

**Warning Signs:**
- JSON save file contains values like `"state_started_at": 1.70796e+09`
- Loaded timestamp differs from saved timestamp by orders of magnitude
- Console errors: "Negative elapsed time calculated"
- Rooms never transition from Playing to Cleaning

**Prevention:**

```gdscript
# WRONG - Float stored in JSON becomes scientific notation:
func save_room(room: RoomState) -> Dictionary:
    return {
        "state_started_at": Time.get_unix_time_from_system()  # Returns float!
    }

# CORRECT - Convert to int before saving:
func save_room(room: RoomState) -> Dictionary:
    return {
        "state_started_at": int(Time.get_unix_time_from_system())  # Force integer
    }

# Also validate on load:
func load_room(data: Dictionary) -> RoomState:
    var room = RoomState.new()

    # Ensure timestamp is integer
    if typeof(data.state_started_at) == TYPE_FLOAT:
        room.state_started_at = int(data.state_started_at)
    else:
        room.state_started_at = data.state_started_at

    # Sanity check - timestamp should be recent-ish
    var current_time = int(Time.get_unix_time_from_system())
    if room.state_started_at < 1600000000 or room.state_started_at > current_time + 86400:
        push_error("Invalid timestamp detected: %d" % room.state_started_at)
        return null

    return room
```

**Phase to address:** Phase 2 (Offline Timer Implementation) - enforce integer timestamps in serialization.

**Testing:**
- Save room with active timer → manually edit JSON to use scientific notation → load → verify error handling
- Check JSON save file format - timestamps should be plain integers like `1738963200`, not `1.73896e+09`

**Sources:**
- [Problems with ConfigFile and Time.get_unix_time_from_system() - Godot Forum](https://forum.godotengine.org/t/problems-with-configfile-and-time-get-unix-time-from-system/47617)
- [Issue with Unixtime - Godot Forum](https://forum.godotengine.org/t/issue-with-unixtime/65648)

---

### Pitfall 3: System Clock Manipulation (Time Cheating)

**Risk:** Player changes device time forward 30 minutes → reopens app → all movies instantly complete → game economy broken.

**Why it happens:**
- `Time.get_unix_time_from_system()` reads device clock, which user controls
- No server-side validation (TheaterCity is offline single-player)
- Calculation uses `current_system_time - saved_timestamp` without validation
- Mobile games are notorious for time manipulation cheats (common in farming/idle games)

**Consequences:**
- Players skip all wait times by changing device clock
- Progression trivialised - no incentive to play over time
- Game economy broken (if timers gate revenue generation)
- Undermines game design intent

**Warning Signs:**
- Elapsed time calculated > 1 year (player set clock way forward)
- Elapsed time is negative (player set clock backwards after state started)
- Multiple rooms complete instantly on single app open
- Saved timestamp is in the future compared to last known good time

**Prevention:**

```gdscript
# Store last known system time and detect cheating:
var _last_known_system_time: int = 0
const MAX_REASONABLE_ELAPSED := 86400 * 7  # 7 days max offline

func _on_app_resumed() -> void:
    var current_time = int(Time.get_unix_time_from_system())

    # Detect time manipulation
    if _last_known_system_time > 0:
        var system_elapsed = current_time - _last_known_system_time

        if system_elapsed < 0:
            # Clock moved backwards - likely cheat or timezone change
            push_warning("System clock moved backwards, possible cheat")
            _handle_time_cheat()
            return

        if system_elapsed > MAX_REASONABLE_ELAPSED:
            # Clock jumped forward unreasonably - likely cheat
            push_warning("System clock jumped %d seconds, possible cheat" % system_elapsed)
            _handle_time_cheat()
            return

    # Time seems legitimate, update states
    _last_known_system_time = current_time
    _update_all_room_states()

func _handle_time_cheat() -> void:
    # Option 1: Cap elapsed time to reasonable maximum
    # (player gets some progress but not full cheat benefit)
    var capped_elapsed = mini(MAX_REASONABLE_ELAPSED, calculated_elapsed)

    # Option 2: Pause all timers until clock returns to normal
    # (harsh but prevents cheating)
    push_warning("Timers paused due to system clock anomaly")

    # Option 3: Use monotonic time (get_ticks_msec) for runtime
    # + stored timestamps for offline, validate they're consistent
```

**Alternative approaches:**

1. **Monotonic time hybrid:**
   - Use `Time.get_ticks_msec()` for in-app progression (can't be manipulated)
   - Only use `get_unix_time_from_system()` for offline elapsed calculation
   - Detect when player closes app normally vs killed/crashed
   - If closed normally, store both monotonic and system time
   - On resume, compare monotonic delta vs system delta - if differ significantly, flag as cheat

2. **Server time validation (requires online):**
   - Not applicable to TheaterCity (offline-first design)

3. **Tolerance-based approach:**
   - Accept some time manipulation as "timezone changes" or "daylight savings"
   - Only flag extreme cases (>24 hour jumps)
   - For single-player game, this may be acceptable tradeoff

**Phase to address:** Phase 3 (Anti-Cheat & Validation) - implement after basic offline timers work, but before public release.

**Recommendation for TheaterCity:** Use tolerance-based approach. Cap maximum offline progression to 24 hours per session. Single-player game doesn't need aggressive anti-cheat.

**Testing:**
- Normal scenario: Close app → wait 5 minutes → reopen → verify 5 minutes elapsed
- Cheat scenario: Close app → set device clock +1 hour → reopen → verify capped to reasonable maximum or warning displayed
- Backwards scenario: Close app → set device clock -1 hour → reopen → verify handles gracefully (no negative time)
- Timezone scenario: Close app → travel to different timezone → reopen → verify doesn't false-positive as cheat

**Sources:**
- [Prevent cheat in a Time Based System - GameSalad Forums](https://forums.gamesalad.com/discussion/42725/prevent-cheat-in-a-time-based-system)
- [Hacking Time: Speed Up Game Clocks on Android - Gadget Hacks](https://smartphones.gadgethacks.com/how-to/hacking-time-speed-up-game-clocks-your-android-device-for-faster-farming-0140383/)
- [Simple anti Time Cheating on Android/iOS - Unity Discussions](https://discussions.unity.com/t/simple-anti-time-cheating-on-android-ios/674418)

---

### Pitfall 4: UTC vs Local Time Confusion → Wrong Elapsed Time

**Risk:** Player in timezone UTC-8 starts movie → app saves timestamp in local time → calculation uses UTC → elapsed time is 8 hours off.

**Why it happens:**
- `Time.get_unix_time_from_system()` returns UTC (always)
- `Time.get_datetime_dict_from_system(utc: false)` returns local time (default)
- Developer mixes local and UTC timestamps in calculation
- Godot 4's Time class has known timezone issues (see GitHub #66695)
- `Time.get_datetime_string_from_unix_time()` returns UTC without "Z" indicator

**Consequences:**
- Movies complete 8 hours early or late depending on timezone
- Rooms transition at wrong times
- Players in different timezones experience different progression rates
- Bug reports are timezone-specific and hard to reproduce

**Warning Signs:**
- Elapsed time differs from expected by exactly N hours (where N is timezone offset)
- Bug reports mention specific timezones (PST, EST, etc.)
- Timers work correctly in UTC timezone but fail elsewhere
- Save file contains mix of local and UTC times

**Prevention:**

```gdscript
# ALWAYS use Unix timestamps (UTC seconds since epoch):
class RoomState:
    var state_started_at: int  # Unix timestamp (UTC)

    func start_state(state: String, duration: int) -> void:
        state_name = state
        state_duration = duration

        # CORRECT - get_unix_time_from_system() always returns UTC
        state_started_at = int(Time.get_unix_time_from_system())

        # WRONG - don't use datetime dicts with utc parameter
        # var dict = Time.get_datetime_dict_from_system(false)  # Local time!
        # state_started_at = Time.get_unix_time_from_datetime_dict(dict)

    func get_elapsed_seconds() -> int:
        var current_time = int(Time.get_unix_time_from_system())
        return current_time - state_started_at  # Both UTC, math is correct

    func is_complete() -> bool:
        return get_elapsed_seconds() >= state_duration

# For display purposes (showing local time to user):
func format_time_for_display(unix_timestamp: int) -> String:
    # Convert UTC timestamp to local datetime for display only
    var local_dict = Time.get_datetime_dict_from_unix_time(unix_timestamp)
    return "%02d:%02d:%02d" % [local_dict.hour, local_dict.minute, local_dict.second]
```

**Key principle:** Store and calculate in UTC always. Only convert to local time for display to user.

**Phase to address:** Phase 2 (Offline Timer Implementation) - establish UTC-only policy immediately.

**Testing:**
- Change device timezone to UTC-8, UTC+5, UTC+0 → verify timers progress at same rate
- Start timer in one timezone → change timezone → reopen app → verify elapsed time is correct
- Manually verify saved timestamps are UTC (compare against known UTC time source)

**Sources:**
- [Time.get_datetime_string_from_unix_time wrong timezone - GitHub Issue #66695](https://github.com/godotengine/godot/issues/66695)
- [Add UTC parameter to Time.*_from_unix_time() methods - GitHub Proposal #5515](https://github.com/godotengine/godot-proposals/issues/5515)
- [Time class documentation - Godot 4.4](https://docs.godotengine.org/en/4.4/classes/class_time.html)

---

### Pitfall 5: Not Saving State on NOTIFICATION_APPLICATION_PAUSED

**Risk:** Player starts movie → receives phone call (app paused) → Android kills app for memory → state not saved → movie progress lost.

**Why it happens:**
- Developer relies on auto-save timer (every 60 seconds)
- Android/iOS can kill backgrounded apps immediately without calling `_exit_tree()`
- `NOTIFICATION_APPLICATION_PAUSED` fires when app goes to background - last chance to save
- On Android, notification timing can be unreliable during debugging (GitHub #85265)
- Developer tests by closing app normally (calls `_exit_tree()`) but production kills are sudden

**Consequences:**
- Player loses up to 60 seconds of progress on every backgrounding
- On memory-constrained devices, app killed frequently → constant progress loss
- Negative reviews: "Game doesn't save my progress"

**Warning Signs:**
- Auto-save only implemented via Timer node (periodic saves)
- No `_notification()` handler for APPLICATION_PAUSED
- Bug reports: "Lost progress when phone call came in"
- Testing only done via "close app" button, not via backgrounding

**Prevention:**

```gdscript
# In main game controller or room manager:
func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED:
            # iOS/Android: App entering background
            push_warning("App paused, saving all state immediately")
            _save_all_rooms_immediately()

        NOTIFICATION_APPLICATION_RESUMED:
            # iOS/Android: App returning to foreground
            push_warning("App resumed, updating room states")
            _update_all_room_states()

        NOTIFICATION_WM_CLOSE_REQUEST:
            # Desktop: Window close button
            _save_all_rooms_immediately()

func _save_all_rooms_immediately() -> void:
    # Save without debounce/delay - app may be killed any moment
    var start_time = Time.get_ticks_msec()

    var save_data = {
        "last_known_system_time": int(Time.get_unix_time_from_system()),
        "rooms": []
    }

    for room in _all_rooms:
        save_data.rooms.append(room.to_dict())

    # Use atomic save (write to temp, verify, rename)
    var success = _save_atomic(save_data)

    var elapsed = Time.get_ticks_msec() - start_time
    if elapsed > 100:
        push_warning("Save took %d ms during app pause" % elapsed)

    if not success:
        push_error("CRITICAL: Failed to save during app pause")
```

**Important platform differences:**

| Platform | NOTIFICATION_APPLICATION_PAUSED | Timing | Guaranteed Save Time |
|----------|--------------------------------|--------|---------------------|
| iOS | Fires reliably | Immediate | ~5 seconds before suspension |
| Android | Fires reliably (but see #85265) | Can be delayed during debug | ~1-2 seconds before kill |
| Desktop | Not fired | N/A | Use WM_CLOSE_REQUEST instead |

**Phase to address:** Phase 2 (Offline Timer Implementation) - implement immediately alongside basic save system.

**Testing:**
- Start movie → press home button (background app) → verify console shows "App paused, saving"
- Check save file modified timestamp matches when app was backgrounded
- Use Android Debug Bridge (ADB) to kill app process: `adb shell am kill com.yourcompany.theatercity`
- Verify save file contains latest state before kill

**Sources:**
- [Android lifecycle notifications not triggering right away - GitHub Issue #85265](https://github.com/godotengine/godot/issues/85265)
- [Improve Android and iOS Focus/Unfocus MainLoop Notifications - GitHub Proposal #8453](https://github.com/godotengine/godot-proposals/issues/8453)
- [iOS & Android App Background/Foreground Events - Godot Forum](https://forum.godotengine.org/t/ios-android-app-background-foreground-events/57665)

---

### Pitfall 6: Race Condition in File Write During App Suspension

**Risk:** App paused → save starts writing → OS suspends app mid-write → file corrupted → all progress lost.

**Why it happens:**
- Godot's `FileAccess` writes to temp file then renames (atomic save pattern)
- BUT: File contents must be flushed to disk before rename
- On power loss, app kill, or fast suspension, rename happens before flush
- Result: Temp file renamed to save file but contains partial/corrupted data
- Issue exists since Godot 2.x, confirmed in 4.3+ (GitHub #98360)
- USB drives and slow storage make race condition easier to hit

**Consequences:**
- Save file corrupted after app suspension
- Player loses all theater progress
- JSON parse fails on next load
- No recovery mechanism - permanent data loss

**Warning Signs:**
- Save file exists but JSON.parse_string() returns null
- File size is smaller than expected
- File contains partial JSON (ends mid-object)
- Issue reports after app crashes or battery death

**Prevention:**

```gdscript
# Current RoomSerializer likely has this issue if using FileAccess directly
# Add explicit flush before file operations:

func save_atomic(data: Dictionary, final_path: String) -> bool:
    var temp_path = final_path + ".tmp"
    var backup_path = final_path + ".bak"

    # Step 1: Write to temp file
    var file = FileAccess.open(temp_path, FileAccess.WRITE)
    if not file:
        push_error("Failed to open temp file: %s" % temp_path)
        return false

    var json_string = JSON.stringify(data, "\t")
    file.store_string(json_string)

    # Step 2: CRITICAL - Flush before closing
    file.flush()  # Ensure data written to disk
    file.close()

    # Step 3: Verify temp file is valid
    var verify_file = FileAccess.open(temp_path, FileAccess.READ)
    if not verify_file:
        push_error("Temp file disappeared after write")
        return false

    var verify_content = verify_file.get_as_text()
    verify_file.close()

    var verify_parse = JSON.parse_string(verify_content)
    if not verify_parse:
        push_error("Temp file contains invalid JSON")
        DirAccess.remove_absolute(temp_path)
        return false

    # Step 4: Backup existing save (if exists)
    if FileAccess.file_exists(final_path):
        # Keep one backup generation
        if FileAccess.file_exists(backup_path):
            DirAccess.remove_absolute(backup_path)
        DirAccess.rename_absolute(final_path, backup_path)

    # Step 5: Move temp to final
    var err = DirAccess.rename_absolute(temp_path, final_path)
    if err != OK:
        push_error("Failed to rename temp to final: %d" % err)
        # Restore from backup if rename failed
        if FileAccess.file_exists(backup_path):
            DirAccess.rename_absolute(backup_path, final_path)
        return false

    return true

# On load, attempt recovery from backup:
func load_with_recovery(final_path: String) -> Dictionary:
    var backup_path = final_path + ".bak"

    # Try primary save file first
    if FileAccess.file_exists(final_path):
        var result = _try_load_json(final_path)
        if result:
            return result
        push_warning("Primary save corrupted, trying backup")

    # Try backup if primary failed
    if FileAccess.file_exists(backup_path):
        var result = _try_load_json(backup_path)
        if result:
            push_warning("Recovered from backup save file")
            # Restore backup as primary
            DirAccess.copy_absolute(backup_path, final_path)
            return result

    push_error("Both primary and backup saves are corrupted")
    return {}

func _try_load_json(path: String) -> Variant:
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return null

    var content = file.get_as_text()
    file.close()

    return JSON.parse_string(content)
```

**Phase to address:** Phase 2 (Offline Timer Implementation) - integrate with existing save system in same phase.

**Note:** TheaterCity already has persistence tests (`test_persistence_flow.gd`) but may not test corruption scenarios. Add tests for:
- Save interrupted mid-write (simulate by not calling flush)
- Backup recovery when primary corrupted
- Both primary and backup corrupted (new game scenario)

**Testing:**
- Start movie → trigger save → kill app power during write (hard to automate)
- Manually corrupt save file → verify backup recovery works
- Delete save file → verify graceful new game start
- Fill device storage to 99% → attempt save → verify error handling

**Sources:**
- [Corruption of files during power loss or crash - GitHub Issue #98360](https://github.com/godotengine/godot/issues/98360)
- [Allow Godot to handle corrupted files - GitHub Proposal #10684](https://github.com/godotengine/godot-proposals/issues/10684)
- [Safe save fails too often - GitHub Issue #40366](https://github.com/godotengine/godot/issues/40366)

---

### Pitfall 7: State Machine Transitions Not Recalculated on Load

**Risk:** Room state saved as "Playing" with 15 minutes elapsed → app closed for 30 minutes → on load, room still in "Playing" state (should have transitioned to "Cleaning").

**Why it happens:**
- Load code deserializes state directly: `room.state_name = saved_data.state_name`
- No recalculation of elapsed time on load
- No check if state should have transitioned during offline period
- State machine expects `_process()` to drive transitions, but process didn't run while app closed

**Consequences:**
- Rooms stuck in wrong state after offline period
- Movies show as "Playing" for hours/days
- Cleaning never starts
- Gameplay feels broken - timers don't progress offline

**Warning Signs:**
- Load code only sets state fields, no calculation logic
- State transitions only happen in `_process()` or Timer callbacks
- Bug reports: "Left movie playing, came back next day, still playing"

**Prevention:**

```gdscript
# Room state machine with offline-aware loading:
class RoomState:
    var state_name: String
    var state_started_at: int
    var state_duration: int

    # State transitions:
    # Available -> (start movie) -> Playing -> (movie ends) -> Cleaning -> (cleaning done) -> Available

    func update_state_from_elapsed_time() -> void:
        # Calculate actual current state based on elapsed time
        if state_name == "Available":
            return  # No time-based transition from Available

        var current_time = int(Time.get_unix_time_from_system())
        var elapsed = current_time - state_started_at

        # Process state transitions that should have happened
        while elapsed >= state_duration:
            _transition_to_next_state()

            # Recalculate elapsed for new state
            current_time = int(Time.get_unix_time_from_system())
            elapsed = current_time - state_started_at

            # Prevent infinite loop if state machine is broken
            if state_name == "Available":
                break

    func _transition_to_next_state() -> void:
        match state_name:
            "Playing":
                # Movie finished, start cleaning
                state_name = "Cleaning"
                state_started_at = state_started_at + state_duration  # Continue time from when movie ended
                state_duration = 600  # 10 minutes cleaning

            "Cleaning":
                # Cleaning finished, room available
                state_name = "Available"
                state_started_at = 0
                state_duration = 0

            "Available":
                # No automatic transition from Available
                pass

# In load code:
func load_rooms() -> Array[RoomState]:
    var data = _load_json("user://save.json")
    var rooms: Array[RoomState] = []

    for room_data in data.rooms:
        var room = RoomState.new()

        # Deserialize saved state
        room.state_name = room_data.state_name
        room.state_started_at = room_data.state_started_at
        room.state_duration = room_data.state_duration

        # CRITICAL: Recalculate state based on elapsed time
        room.update_state_from_elapsed_time()

        rooms.append(room)

    return rooms

# Also call on app resume:
func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_RESUMED:
        for room in _all_rooms:
            room.update_state_from_elapsed_time()
            _update_room_visuals(room)
```

**Edge case:** What if multiple transitions should have happened? Example:
- Room saved in "Playing" state with 1 minute remaining
- App closed for 3 hours
- On load: Playing → Cleaning → Available all need to happen

Solution: Loop in `update_state_from_elapsed_time()` continues transitioning until elapsed time is accounted for.

**Phase to address:** Phase 4 (State Persistence) - this is core to offline timer functionality, not optional.

**Testing:**
- Start movie (30 min) → close app → wait 5 minutes → reopen → verify movie at 5 min progress, still "Playing"
- Start movie (30 min) → close app → wait 35 minutes → reopen → verify room is "Cleaning" (not "Playing")
- Start movie → close app → wait 45 minutes → reopen → verify room is "Available" (transitioned through Playing → Cleaning → Available)
- Room with 1 second left in "Playing" → close app → wait 1 hour → verify didn't get stuck in transition

**Sources:**
- [Persisting State in Godot - Developer Aspirations](https://developeraspirations.com/dev/2023/11/14/persisting-state-godot.html)
- [Saving and restoring AnimationNodeStateMachine works unreliably - GitHub Issue #84068](https://github.com/godotengine/godot/issues/84068)
- [How to use state machines for modeling - Time-controlled triggering - Itemis Blog](https://blogs.itemis.com/en/how-to-use-state-machines-for-your-modelling-part-2-time-controlled-triggering-of-state-transitions)

---

## Moderate Pitfalls

Mistakes that cause bugs, poor UX, or technical debt but are recoverable.

### Pitfall 8: No Visual Indicator of Offline Progress

**Risk:** Player starts movie → closes app for 30 minutes → reopens → room instantly changes to "Cleaning" with no indication that time passed offline.

**Why it happens:**
- Offline progress is functional but not communicated to player
- Room state updates instantly on load
- No "fast forward" animation or progress summary
- Player feels confused - "why did my room change?"

**Consequences:**
- Player doesn't understand offline progression system
- Appears like a bug (sudden state change)
- Reduces satisfaction from time investment

**Prevention:**
- Show "Welcome back! While you were away:" summary screen
- Display elapsed time: "3 movies completed, 2 rooms cleaned"
- Animate state transitions on load (condensed time-lapse effect)
- Particle effects or sound for completed states

```gdscript
func _on_app_resumed() -> void:
    var offline_summary = {
        "movies_completed": 0,
        "rooms_cleaned": 0,
        "elapsed_seconds": 0
    }

    for room in _all_rooms:
        var old_state = room.state_name
        room.update_state_from_elapsed_time()

        if old_state == "Playing" and room.state_name != "Playing":
            offline_summary.movies_completed += 1
        if old_state == "Cleaning" and room.state_name == "Available":
            offline_summary.rooms_cleaned += 1

    var total_elapsed = int(Time.get_unix_time_from_system()) - _last_known_system_time
    offline_summary.elapsed_seconds = total_elapsed

    if total_elapsed > 60:  # More than 1 minute offline
        _show_offline_progress_summary(offline_summary)
```

**Phase to address:** Phase 5 (Polish & Feedback) - implement after core offline timers work.

---

### Pitfall 9: Memory Leak from Persistent Timer State

**Risk:** Each room stores its state → 100 rooms with timers → memory usage grows unbounded.

**Why it happens:**
- Room state objects never freed (registered in global manager)
- Each room has signals connected
- RefCounted objects kept alive by signal connections
- Mobile devices have limited RAM (2-4GB)

**Prevention:**
- Use weak references where possible
- Disconnect signals when rooms are not active
- Don't store unnecessary data in room state (e.g., full resource references)
- Periodically audit memory usage: `Performance.get_monitor(Performance.MEMORY_STATIC)`

**Phase to address:** Phase 6 (Performance Optimization) - test with 100+ rooms on mobile device.

---

### Pitfall 10: No Handling of Daylight Saving Time Changes

**Risk:** Player starts movie before DST change → clock shifts 1 hour → elapsed time calculation off by 1 hour.

**Why it happens:**
- DST changes system clock by 1 hour (forward in spring, back in fall)
- `Time.get_unix_time_from_system()` is NOT affected by DST (uses UTC)
- BUT: User perception is affected (clock on device shows different time)
- If mixing local time and UTC, DST causes bugs

**Consequences:**
- Timers appear to progress wrong by 1 hour (twice per year)
- Bug reports are seasonal and timezone-specific
- Hard to reproduce if developer not in same timezone

**Prevention:**
- Use Unix timestamps (UTC) exclusively for calculation - DST doesn't affect UTC
- Only convert to local time for display purposes
- Warn player if large time jump detected (could be DST or cheat)

**Phase to address:** Phase 3 (Anti-Cheat & Validation) - add DST detection to time jump validator.

**Testing:**
- Change device timezone to region with DST (e.g., US/Pacific)
- Manually adjust clock forward 1 hour (simulate DST)
- Verify timers still progress correctly

**Sources:**
- [Getting DST-aware wall date and time from timestamp - Godot Forum](https://forum.godotengine.org/t/getting-dst-aware-wall-date-and-time-from-timestamp/126240)

---

### Pitfall 11: State Machine Doesn't Emit Signals on Offline Transitions

**Risk:** UI listens for `state_changed` signal to update visuals → offline transitions don't emit signal → UI shows wrong state.

**Why it happens:**
- State transitions during load happen silently (no signal emission)
- UI expects signals for all state changes
- Load code directly sets `state_name` field without calling transition method

**Prevention:**

```gdscript
# Emit signals after offline state recalculation:
func update_state_from_elapsed_time() -> void:
    var old_state = state_name

    # Calculate and apply transitions...
    _apply_offline_transitions()

    # Emit signal if state changed
    if old_state != state_name:
        state_changed.emit(old_state, state_name)

# UI can then react normally:
func _on_room_state_changed(old_state: String, new_state: String) -> void:
    _update_room_visual(room)
    _play_transition_effect(old_state, new_state)
```

**Phase to address:** Phase 4 (State Persistence) - ensure signal consistency.

---

### Pitfall 12: Battery Drain from Frequent Background Saves

**Risk:** Auto-save fires every 10 seconds → app keeps waking up in background → drains battery.

**Why it happens:**
- Overly aggressive auto-save frequency
- Background processes on mobile drain battery significantly
- Timer continues running in background (before suspension)

**Prevention:**
- Save only on meaningful state changes, not periodically
- Save on `NOTIFICATION_APPLICATION_PAUSED` (going to background)
- Don't run timers in background (they'll pause when app suspends anyway)

**Phase to address:** Phase 5 (Polish & Feedback) - test battery impact on real device.

---

## Minor Pitfalls

Mistakes that cause polish issues but are easily fixable.

### Pitfall 13: Timestamp Display Shows UTC Instead of Local Time

**Risk:** UI shows "Movie started at 14:30" but player started it at 6:30 AM local → confusing.

**Why it happens:**
- Stored timestamp is UTC
- Display code shows timestamp directly without conversion

**Prevention:**

```gdscript
func format_timestamp(unix_timestamp: int) -> String:
    var local_dict = Time.get_datetime_dict_from_unix_time(unix_timestamp)
    return "%02d:%02d" % [local_dict.hour, local_dict.minute]
```

**Phase to address:** Phase 5 (Polish & Feedback) - display formatting.

---

### Pitfall 14: No "Time Until Next Completion" UI

**Risk:** Player can't see when movie will finish without mental calculation.

**Why it happens:**
- State stores start time and duration, but no "time remaining" calculation

**Prevention:**

```gdscript
func get_time_remaining() -> int:
    if state_name == "Available":
        return 0

    var elapsed = int(Time.get_unix_time_from_system()) - state_started_at
    return maxi(0, state_duration - elapsed)

# UI update:
func _process(_delta: float) -> void:
    if room.state_name in ["Playing", "Cleaning"]:
        var remaining = room.get_time_remaining()
        label.text = "Time remaining: %s" % format_seconds_as_mmss(remaining)
```

**Phase to address:** Phase 5 (Polish & Feedback) - QoL feature.

---

### Pitfall 15: Negative Elapsed Time Not Handled

**Risk:** System clock moves backwards → elapsed time is negative → state machine breaks.

**Why it happens:**
- Calculation: `current_time - state_started_at` assumes time moves forward
- If clock adjusted backwards, result is negative
- Code doesn't check for negative elapsed time

**Prevention:**

```gdscript
func get_elapsed_seconds() -> int:
    var current_time = int(Time.get_unix_time_from_system())
    var elapsed = current_time - state_started_at

    if elapsed < 0:
        push_warning("Negative elapsed time detected, possible clock adjustment")
        return 0  # Clamp to 0

    return elapsed
```

**Phase to address:** Phase 3 (Anti-Cheat & Validation) - add bounds checking.

---

## Android Process Death (Additional Context)

**Android kills backgrounded apps aggressively** to free memory. TheaterCity must handle:

### When Process Death Happens

- User presses Home button → app backgrounded → Android low on memory → app killed
- Phone call comes in → app paused → call ends → app may or may not be killed
- Device reboot → all apps killed
- User force-closes app in settings → immediate kill

### What Gets Saved

- `onSaveInstanceState` (Android lifecycle) is called for Activities
- Godot's `NOTIFICATION_APPLICATION_PAUSED` is the equivalent
- You have **~1-2 seconds** to save before suspension (Android)
- iOS gives ~5 seconds

### What Doesn't Get Saved

- In-memory state (objects, variables) → all lost
- Timer nodes → stopped, not resumed
- Queued signals → lost
- Resource references → may be reloaded differently

### Recovery Requirements

1. Save state on `NOTIFICATION_APPLICATION_PAUSED`
2. Load state on app start (check if save file exists)
3. Recalculate offline progress based on timestamps
4. Reconstruct runtime state (timers, signals, connections)

**Testing process death:**

```bash
# Android Debug Bridge - simulate process death:
adb shell am kill com.yourcompany.theatercity

# Or in Developer Options:
# Settings > Developer Options > Background process limit > No background processes
```

**Sources:**
- [Understanding Process Death in Android - Android Engineers](https://androidengineers.substack.com/p/understanding-process-death-in-android)
- [Save UI states - Android Developers](https://developer.android.com/topic/libraries/architecture/saving-states)
- [How to make your Android app resilient to process death - BlaBlaCar Medium](https://medium.com/blablacar/how-to-make-your-android-app-resilient-to-process-death-bdd3fbcfbf9e)

---

## Integration with Existing TheaterCity Systems

### Existing Save System

TheaterCity has `RoomSerializer` with JSON persistence for room building. Offline timers must integrate:

```gdscript
# Extend RoomInstance with state machine fields:
class RoomInstance:
    # Existing fields:
    var id: String
    var room_type_id: String
    var bounding_box: Rect2i
    var walls: Array[Vector2i]
    var doors: Array[DoorPlacement]
    var furniture: Array[FurniturePlacement]

    # NEW - Theater state fields:
    var theater_state: String = "Available"  # Available, Playing, Cleaning
    var state_started_at: int = 0  # Unix timestamp
    var state_duration: int = 0  # Seconds
    var current_movie_id: String = ""  # Which movie is playing (if any)

# Extend to_dict() serialization:
func to_dict() -> Dictionary:
    var dict = {
        # ... existing fields ...
        "theater_state": theater_state,
        "state_started_at": state_started_at,
        "state_duration": state_duration,
        "current_movie_id": current_movie_id
    }
    return dict

# Extend from_dict() deserialization:
static func from_dict(data: Dictionary) -> RoomInstance:
    var room = RoomInstance.new(data.id, data.room_type_id)
    # ... existing field loading ...

    # Load theater state (with defaults for old saves)
    room.theater_state = data.get("theater_state", "Available")
    room.state_started_at = data.get("state_started_at", 0)
    room.state_duration = data.get("state_duration", 0)
    room.current_movie_id = data.get("current_movie_id", "")

    # CRITICAL: Recalculate state after loading
    room.update_state_from_elapsed_time()

    return room
```

### Existing Test Suite

`test_persistence_flow.gd` tests room save/load. Extend with offline timer tests:

```gdscript
func test_offline_timer_progression() -> void:
    var room = _create_test_room("theater_1", Rect2i(0, 0, 10, 10))

    # Start movie (30 minutes)
    room.theater_state = "Playing"
    room.state_started_at = int(Time.get_unix_time_from_system()) - 1800  # Started 30 min ago
    room.state_duration = 1800

    # Save
    RoomSerializer.save_rooms([room])

    # Simulate app restart
    var loaded_rooms = RoomSerializer.load_rooms()
    var loaded_room = loaded_rooms[0]

    # Should have transitioned to "Cleaning" (30 minutes elapsed)
    assert_eq(loaded_room.theater_state, "Cleaning", "Room should be cleaning after 30 min")
```

---

## Phase Implementation Plan

| Phase | Focus | Critical Pitfalls to Address |
|-------|-------|------------------------------|
| **Phase 1: Theater Room State Machine** | Basic state transitions (Available → Playing → Cleaning → Available) | Pitfall 1 (no Timer nodes for offline) |
| **Phase 2: Offline Timer Implementation** | Unix timestamp storage, elapsed time calculation | Pitfalls 2 (float format), 4 (UTC/local), 5 (app pause save) |
| **Phase 3: Anti-Cheat & Validation** | Time jump detection, negative elapsed handling | Pitfall 3 (clock manipulation), 10 (DST) |
| **Phase 4: State Persistence** | Save/load with state recalculation | Pitfalls 6 (file corruption), 7 (transition recalc), 11 (signals) |
| **Phase 5: Polish & Feedback** | Offline progress summary, time remaining UI | Pitfalls 8 (progress indicator), 14 (time until completion) |
| **Phase 6: Performance Optimization** | Memory management, battery usage | Pitfalls 9 (memory leak), 12 (battery drain) |

---

## Testing Checklist (Mobile-Specific)

**Must test on physical Android device** (emulator doesn't accurately simulate process death and memory pressure):

- [ ] Start movie → close app normally → wait 5 minutes → reopen → verify 5 minutes of progress
- [ ] Start movie → close app → wait 35 minutes → reopen → verify room is "Cleaning"
- [ ] Start movie → press Home (background) → wait for Android to kill app → reopen → verify state preserved
- [ ] Start movie → kill app via ADB (`adb shell am kill`) → reopen → verify state preserved
- [ ] Start movie → change device time forward 1 hour → reopen → verify cheat detection or capped progress
- [ ] Start movie → change device time backwards 1 hour → reopen → verify handles gracefully (no crash)
- [ ] Change device timezone (UTC to UTC+5) → verify timer progression rate unchanged
- [ ] Fill device storage to 95% → start movie → trigger save → verify error handling
- [ ] Start movie → receive phone call → end call → verify movie still progressing
- [ ] Start movie → enable airplane mode → close app → wait 10 minutes → reopen → verify offline progression works
- [ ] Create 50 rooms with timers → check memory usage → should stay <300MB on mobile
- [ ] Play for 2 hours with active timers → check battery drain → should be <10% per hour

**Automated tests to add:**

```gdscript
# In test suite:
func test_unix_timestamp_is_integer_in_json() -> void:
    var room = _create_test_room("test", Rect2i(0, 0, 5, 5))
    room.state_started_at = int(Time.get_unix_time_from_system())

    RoomSerializer.save_rooms([room])

    # Read raw JSON
    var file = FileAccess.open("user://save.json", FileAccess.READ)
    var json_text = file.get_as_text()
    file.close()

    # Verify no scientific notation
    assert_false(json_text.contains("e+"), "Timestamp should not use scientific notation")

func test_negative_elapsed_time_clamped() -> void:
    var room = _create_test_room("test", Rect2i(0, 0, 5, 5))
    room.state_started_at = int(Time.get_unix_time_from_system()) + 3600  # 1 hour in future
    room.state_duration = 1800

    var elapsed = room.get_elapsed_seconds()
    assert_true(elapsed >= 0, "Elapsed time should never be negative")

func test_multiple_state_transitions_offline() -> void:
    var room = _create_test_room("test", Rect2i(0, 0, 5, 5))

    # Started Playing 45 minutes ago (30 min movie + 10 min clean + 5 min extra)
    room.theater_state = "Playing"
    room.state_started_at = int(Time.get_unix_time_from_system()) - 2700
    room.state_duration = 1800  # 30 min movie

    # Should transition: Playing → Cleaning → Available
    room.update_state_from_elapsed_time()

    assert_eq(room.theater_state, "Available", "Should have completed both transitions")
```

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| Timer implementation pattern | HIGH | Multiple Godot forum threads confirm Timer nodes don't work offline, Unix timestamp is standard approach |
| Float/scientific notation issue | HIGH | Verified in Godot forum with specific issue reports and solutions |
| System clock cheating | HIGH | Common pattern in mobile games, multiple sources document prevention methods |
| UTC/timezone handling | HIGH | Official Godot documentation and GitHub issues confirm Time class behavior |
| App pause/resume notifications | HIGH | Official Godot proposals and Android documentation confirm behavior |
| File corruption race condition | HIGH | Recent GitHub issue (#98360) with detailed reproduction and explanation |
| State machine persistence | MEDIUM | General patterns verified, but Godot-specific state machine persistence has issues (GitHub #84068) |
| Android process death | HIGH | Well-documented Android behavior with official developer documentation |

---

## Summary

**Highest-risk pitfalls:**

1. **Using Timer nodes for offline progression** (Pitfall 1) - Breaks core mechanic entirely
2. **Not saving on NOTIFICATION_APPLICATION_PAUSED** (Pitfall 5) - Data loss on every background
3. **Not recalculating state on load** (Pitfall 7) - Rooms stuck in wrong state

**Most subtle pitfalls:**

1. **Float timestamps → scientific notation** (Pitfall 2) - Save file looks valid but data is wrong
2. **UTC vs local time confusion** (Pitfall 4) - Bug is timezone-specific, hard to reproduce
3. **File write race condition** (Pitfall 6) - Rare but catastrophic data loss

**TheaterCity-specific concerns:**

- Existing `RoomInstance` and `RoomSerializer` need extension for theater state
- Existing test suite in `test_persistence_flow.gd` provides good foundation
- Mobile-first design means testing on real Android device is critical
- Offline-first design means no server validation - must implement client-side cheat mitigation

**Recommendation:** Address Pitfalls 1, 2, 4, 5, 7 in first implementation phase. These are architectural decisions that are expensive to retrofit. Pitfall 3 (anti-cheat) and 6 (file corruption) can be added in subsequent phases but should not be deferred past MVP.

---

## Sources

### Godot-Specific Issues
- [Let a timer still run if the game is closed - Godot Forum](https://godotengine.org/qa/67347/let-a-timer-still-run-if-the-game-is-closed)
- [Can you set a timer to run when the program is off? - Godot Forum](https://forum.godotengine.org/t/can-you-set-a-timer-to-run-when-the-program-is-off/10909)
- [How can I measure the time since the game was last opened? - Godot Forum](https://forum.godotengine.org/t/how-can-i-measure-the-time-since-the-game-was-last-opened/16843)
- [Problems with ConfigFile and Time.get_unix_time_from_system() - Godot Forum](https://forum.godotengine.org/t/problems-with-configfile-and-time-get-unix-time-from-system/47617)
- [Issue with Unixtime - Godot Forum](https://forum.godotengine.org/t/issue-with-unixtime/65648)
- [Time.get_datetime_string_from_unix_time wrong timezone - GitHub Issue #66695](https://github.com/godotengine/godot/issues/66695)
- [Add UTC parameter to Time.*_from_unix_time() methods - GitHub Proposal #5515](https://github.com/godotengine/godot-proposals/issues/5515)
- [Android lifecycle notifications not triggering right away - GitHub Issue #85265](https://github.com/godotengine/godot/issues/85265)
- [Improve Android and iOS Focus/Unfocus MainLoop Notifications - GitHub Proposal #8453](https://github.com/godotengine/godot-proposals/issues/8453)
- [iOS & Android App Background/Foreground Events - Godot Forum](https://forum.godotengine.org/t/ios-android-app-background-foreground-events/57665)
- [Corruption of files during power loss or crash - GitHub Issue #98360](https://github.com/godotengine/godot/issues/98360)
- [Allow Godot to handle corrupted files - GitHub Proposal #10684](https://github.com/godotengine/godot-proposals/issues/10684)
- [Safe save fails too often - GitHub Issue #40366](https://github.com/godotengine/godot/issues/40366)
- [Saving and restoring AnimationNodeStateMachine works unreliably - GitHub Issue #84068](https://github.com/godotengine/godot/issues/84068)
- [Persisting State in Godot - Developer Aspirations](https://developeraspirations.com/dev/2023/11/14/persisting-state-godot.html)
- [Getting DST-aware wall date and time from timestamp - Godot Forum](https://forum.godotengine.org/t/getting-dst-aware-wall-date-and-time-from-timestamp/126240)
- [Time class documentation - Godot 4.4](https://docs.godotengine.org/en/4.4/classes/class_time.html)

### Mobile Game Patterns
- [Prevent cheat in a Time Based System - GameSalad Forums](https://forums.gamesalad.com/discussion/42725/prevent-cheat-in-a-time-based-system)
- [Hacking Time: Speed Up Game Clocks on Android - Gadget Hacks](https://smartphones.gadgethacks.com/how-to/hacking-time-speed-up-game-clocks-your-android-device-for-faster-farming-0140383/)
- [Simple anti Time Cheating on Android/iOS - Unity Discussions](https://discussions.unity.com/t/simple-anti-time-cheating-on-android-ios/674418)

### Android Platform
- [Understanding Process Death in Android - Android Engineers](https://androidengineers.substack.com/p/understanding-process-death-in-android)
- [Save UI states - Android Developers](https://developer.android.com/topic/libraries/architecture/saving-states)
- [How to make your Android app resilient to process death - BlaBlaCar Medium](https://medium.com/blablacar/how-to-make-your-android-app-resilient-to-process-death-bdd3fbcfbf9e)
- [The activity lifecycle - Android Developers](https://developer.android.com/guide/components/activities/activity-lifecycle)

### State Machine Timers
- [How to use state machines for modeling - Time-controlled triggering - Itemis Blog](https://blogs.itemis.com/en/how-to-use-state-machines-for-your-modelling-part-2-time-controlled-triggering-of-state-transitions)
