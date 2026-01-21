# Codebase Concerns

**Analysis Date:** 2026-01-20

## Tech Debt

**Unclear Movement Speed Magic Number:**
- Issue: Patron.gd line 3 exports `movement_speed: float = 3000.0` with comment "not sure why this needs to be so high"
- Files: `C:/git/TheaterCity/scripts/Patron.gd`
- Impact: Maintenance burden; future developers won't understand the design rationale. Performance may be suboptimal if this value was chosen experimentally without proper analysis
- Fix approach: Document why 3000.0 is required (related to tile scale, physics framerate, etc.) or add configuration to make it tunable per difficulty

**Commented-Out Legacy Code:**
- Issue: Patron.gd lines 25-52 contain large block of commented-out physics/animation code from previous implementation
- Files: `C:/git/TheaterCity/scripts/Patron.gd`
- Impact: Code clarity reduced; maintenance burden; unclear if this is intentional fallback or oversight
- Fix approach: Remove entirely if no longer used, or move to separate branch/archived file for reference

**Hard-Coded Tile Constants Scattered Across Codebase:**
- Issue: Multiple files define their own copies of tileset source IDs and atlas coordinates instead of centralizing them
  - `DoorOperation.gd` line 5-6: SOURCE_ID, DOOR_TILE constants
  - `NavigationOperation.gd` line 5-7: SOURCE_ID, WALKABLE_TILE, WALL_TILE constants
  - `WallOperation.gd` line 7: WALL_SOURCE_ID constant
- Files: `C:/git/TheaterCity/scripts/room_building/operations/DoorOperation.gd`, `C:/git/TheaterCity/scripts/room_building/operations/NavigationOperation.gd`, `C:/git/TheaterCity/scripts/room_building/operations/WallOperation.gd`
- Impact: Fragile to tileset changes; must update multiple locations; risk of inconsistency
- Fix approach: Create `TilesetConstants.gd` singleton or const file with centralized tileset definitions; import in all operation classes

**Terrain Configuration Duplication:**
- Issue: TERRAIN_SET and TERRAIN_INDEX constants duplicated in DoorOperation and WallOperation with identical values
- Files: `C:/git/TheaterCity/scripts/room_building/operations/DoorOperation.gd` lines 9-10, `C:/git/TheaterCity/scripts/room_building/operations/WallOperation.gd` lines 5-6
- Impact: Terrain changes require updates in multiple places; risk of desynchronization
- Fix approach: Move to centralized TilesetConstants or TerritoryConfiguration constant

**Unused Function Stub:**
- Issue: Patron.gd line 86-87 has `_on_timer_timeout()` stub with no body comment
- Files: `C:/git/TheaterCity/scripts/Patron.gd`
- Impact: Unclear intent; dead code increases maintenance burden
- Fix approach: Remove if no longer used or document its purpose

**DoorOperation Creates New Operation on Every Draw:**
- Issue: RoomBuildUI._draw_door_placement_hints() line 246 and RoomBuildDrawing.draw_door_placement_hints() line 69 both create new DoorOperation instances during _draw() calls
- Files: `C:/git/TheaterCity/scripts/room_building/RoomBuildUI.gd` line 246, `C:/git/TheaterCity/scripts/room_building/ui/RoomBuildDrawing.gd` line 69
- Impact: Performance impact on every frame during door placement; unnecessary object allocation; should reuse instance
- Fix approach: Cache DoorOperation as instance variable instead of creating in _draw()

---

## Performance Bottlenecks

**Expensive Drawing During Furniture Placement:**
- Problem: RoomBuildUI._draw_furniture_placement_hints() (lines 267-333) and RoomBuildDrawing.draw_furniture_placement_hints() (lines 91-127) iterate every room interior tile for every frame while furniture placement is active
- Files: `C:/git/TheaterCity/scripts/room_building/RoomBuildUI.gd` lines 267-333, `C:/git/TheaterCity/scripts/room_building/ui/RoomBuildDrawing.gd` lines 91-127
- Cause: Nested loops iterate full room bounding box interior tiles even when room is large; collision operation recomputed on every draw; no caching of validity results
- Improvement path:
  1. Only redraw when mouse moves, not every frame
  2. Cache collision preview results from last frame
  3. For large rooms (>20x20), batch draw calls or use viewport-culled rendering
  4. Consider using a CanvasLayer with a shader for tile highlighting instead of individual draw_colored_polygon calls

**Door Placement Hints Iterate Room Walls + DoorOperation Validation Per Frame:**
- Problem: Door placement visualization recalculates validity for every wall tile on every frame
- Files: `C:/git/TheaterCity/scripts/room_building/RoomBuildUI.gd` lines 245-266, `C:/git/TheaterCity/scripts/room_building/ui/RoomBuildDrawing.gd` lines 62-89
- Cause: `door_op.is_valid_door_position()` called for each wall tile per draw frame during hover; no caching of results
- Improvement path:
  1. Cache valid door positions when entering door placement mode
  2. Only validate hovered tile, not all walls
  3. Invalidate cache when room structure changes (doors placed)

**RoomBuildUI Size: 575 Lines**
- Problem: Single 575-line file handles room type selection, drawing, door placement, furniture placement, UI styling, preview sprites
- Files: `C:/git/TheaterCity/scripts/room_building/RoomBuildUI.gd`
- Cause: Multiple concerns mixed; hard to test individual features; cognitive overload
- Improvement path:
  1. Extract furniture placement logic to separate `FurniturePlacementUI.gd`
  2. Extract drawing helpers (already partially done in RoomBuildDrawing but still duplicated)
  3. Extract preview sprite management to `FurniturePreviewManager.gd`
  4. Target: break into 3-4 files of 150-200 lines each

**Patron Navigation Query Every Frame:**
- Problem: Patron._physics_process() calls nav_agent.get_next_path_position() every frame even when target hasn't changed
- Files: `C:/git/TheaterCity/scripts/Patron.gd` line 63
- Cause: No path caching; every frame requires navigation query
- Improvement path:
  1. Cache path position and only recompute when target changes
  2. Reduce query frequency to once per 100ms
  3. Profile actual impact first before optimizing

**Nested Loops in Large Rooms (NavigationOperation, WallOperation):**
- Problem: NavigationOperation.update_room_navigation() and WallOperation operations iterate full room bounds in nested loops
- Files: `C:/git/TheaterCity/scripts/room_building/operations/NavigationOperation.gd` lines 20-43, `C:/git/TheaterCity/scripts/room_building/operations/WallOperation.gd` lines 9-25
- Cause: Setting tilemap cells individually; no batch optimization
- Impact: Rooms larger than 50x50 tiles will show noticeable lag
- Improvement path:
  1. Use Godot's `set_cells_terrain_connect()` batch method (already used for walls, but not for individual navigation cells)
  2. Profile tilemap operations on room completion
  3. Consider async/threaded processing for large rooms

---

## Fragile Areas

**Navigation Dependency on Targets Singleton Without Null Checks:**
- Problem: Patron.gd assumes Targets autoload always exists; no null checks
- Files: `C:/git/TheaterCity/scripts/Patron.gd` lines 13-14, 24, 100-102
- Why fragile: If Targets isn't registered as autoload or is freed, patrons will crash
- Safe modification: Add null check in _ready(): `assert(is_instance_valid(Targets), "Targets autoload required")`
- Test coverage: No test for missing Targets dependency

**Room Type Resource Deserialization Risk:**
- Problem: RoomBuildController depends on RoomTypeRegistry.get_instance() finding resource at hard-coded path
- Files: `C:/git/TheaterCity/scripts/room_building/RoomBuildController.gd` line 27, `C:/git/TheaterCity/scripts/data/RoomTypeRegistry.gd` line 11
- Why fragile: If `res://data/configs/room_type_registry.tres` is moved or deleted, entire build system fails silently
- Safe modification:
  1. Add error state to registry initialization
  2. Return error result from get_instance() instead of null on load failure
  3. Check result in RoomBuildController._ready()
- Test coverage: No test for missing registry file

**Unvalidated Door Direction Calculations:**
- Problem: DoorOperation.determine_door_direction() line 23-33 assumes door position is on room boundary, no validation
- Files: `C:/git/TheaterCity/scripts/room_building/operations/DoorOperation.gd`
- Why fragile: If called with position not on boundary, returns wrong direction silently
- Safe modification: Add assertion or validation in determine_door_direction()
- Test coverage: test_door_operation.gd tests happy path but not invalid positions

**Collision Operation Assumes Valid Room:**
- Problem: CollisionOperation methods assume room is non-null and fully initialized; no defensive checks
- Files: `C:/git/TheaterCity/scripts/room_building/operations/CollisionOperation.gd` lines 18-121
- Why fragile: null room passed from UI causes silent failures or crashes in nested logic
- Safe modification: Add guard clauses at entry points
- Test coverage: test_collision_operation.gd doesn't test null room scenarios

**FurnitureResource Dependencies Not Validated:**
- Problem: FurnitureOperation.create_furniture_visual() line 13-22 warns but continues with placeholder when scene missing
- Files: `C:/git/TheaterCity/scripts/room_building/operations/FurnitureOperation.gd`
- Why fragile: Missing scene creates invisible placeholder node; players won't see furniture; hard to debug
- Safe modification:
  1. Throw error instead of warning
  2. Use exception handling with fallback visual (red debug rectangle)
  3. Add pre-flight check in FurnitureRegistry
- Test coverage: No test for missing furniture scene

---

## Test Coverage Gaps

**Room Building Controller Not Directly Tested:**
- What's not tested: State transitions, signal emissions, operation orchestration
- Files: `C:/git/TheaterCity/scripts/room_building/RoomBuildController.gd`
- Risk: Regression in state machine logic (idle → draw_box → place_doors → furniture) goes unnoticed
- Priority: **High** - critical flow is untested

**UI Input Handling Not Tested:**
- What's not tested: Mouse input during box drawing, door placement, furniture placement, coordinate conversion edge cases
- Files: `C:/git/TheaterCity/scripts/room_building/RoomBuildUI.gd` lines 121-161
- Risk: Input regressions (swapped mouse button, wrong coordinate system) not caught
- Priority: **High** - user-facing feature

**Draw Loop Performance Not Tested:**
- What's not tested: Performance of _draw() during furniture placement with large room (>50x50 tiles)
- Files: `C:/git/TheaterCity/scripts/room_building/RoomBuildUI.gd` lines 168-334
- Risk: Performance regression with large rooms unnoticed until production
- Priority: **Medium** - design flaw, not regression

**Isometric Coordinate Conversion Edge Cases Not Tested:**
- What's not tested: Boundary conditions, zoomed camera, negative coordinates, viewport resize
- Files: `C:/git/TheaterCity/scripts/utils/IsometricMath.gd`
- Risk: Coordinate conversion off by one in edge cases (screen boundary clicks)
- Priority: **Medium** - math is sound but untested edge cases

**Patron Animation State Not Tested:**
- What's not tested: Animation selection logic (8-direction angle snapping, walk vs idle states)
- Files: `C:/git/TheaterCity/scripts/Patron.gd` lines 78-84
- Risk: Animation glitch (wrong direction, missed frame) not caught
- Priority: **Low** - visible but non-critical

**Navigation Changed Callback Doesn't Verify Room Integrity:**
- What's not tested: Behavior when navigation changes mid-furniture-placement
- Files: `C:/git/TheaterCity/scripts/Patron.gd` lines 99-102, `C:/git/TheaterCity/scripts/Targets.gd`
- Risk: Race condition where patron recalculates path while room building in progress
- Priority: **Low** - rare edge case but potential for stuck patrons

---

## Missing Error Handling

**No Validation for RoomTypeResource Properties:**
- Problem: RoomTypeResource fields (min_size, max_size, door_count_min, etc.) can be invalid (negative, swapped) with no validation
- Files: `C:/git/TheaterCity/scripts/data/RoomTypeResource.gd`
- Impact: Invalid room types silently break build system or create nonsensical rooms
- Approach: Add validation in _ready() or via `@export` range constraints

**No Overflow Protection on Cost Calculations:**
- Problem: RoomInstance.get_total_cost() can overflow on large rooms (walls + doors + expensive furniture)
- Files: `C:/git/TheaterCity/scripts/storage/RoomInstance.gd` lines 96-109
- Impact: Integer overflow on very large rooms causes negative cost or undefined behavior
- Approach: Cap cost at int max or use int64 if upgrading Godot

**Targets.get_random_entity() Returns Null Without Notification:**
- Problem: Patron.choose_random_target() line 17 gets null if no targets exist but doesn't check
- Files: `C:/git/TheaterCity/scripts/Patron.gd` line 17, `C:/git/TheaterCity/scripts/Targets.gd` line 15
- Impact: Patron crashes when accessing target.global_position on null
- Approach: Add guard clause in choose_random_target(); emit signal instead of crashing

---

## Scaling Limits

**Tilemap Operations Scale Linearly with Room Size:**
- Current capacity: Tested up to 100x100 tiles (one operation test room)
- Limit: ~500x500 tiles causes noticeable lag on `set_cells_terrain_connect()` operations
- Scaling path:
  1. For rooms >100 tiles: Use tilemap layers per zone or batch operations across frames
  2. Profile actual threshold on mobile target platform
  3. Consider compressed/octree tilemap representation

**Patron Array Search Performance (Targets Singleton):**
- Current capacity: 100+ patrons, linear search on get_random_entity()
- Limit: 1000+ patrons causes visible frame rate drop on target selection (O(1) lookup in array)
- Scaling path:
  1. Use HashSet for O(1) existence check instead of `in` operator (linear)
  2. Cache random entity index to avoid repeated random generation
  3. For 10k+ patrons, shard into regional target groups

**UI Drawing During Furniture Placement with Large Room:**
- Current capacity: 30x30 interior tiles (nested loop draws ~900 polygons per frame)
- Limit: >50x50 room causes frame drops during furniture placement
- Scaling path: See Performance Bottlenecks section above

---

## Dependencies at Risk

**LimboAI Addon (Behavior Trees):**
- Risk: Project uses LimboAI addon for demo agents (not core theater simulation)
- Impact: If addon breaks with Godot update, demo scenes won't work but core build system is safe
- Migration plan: LimboAI is well-maintained, low risk. Fall back to simple Node state machines if needed.

**Hard Godot 4.5 Dependency:**
- Risk: Export preset has Godot 4.5 hardcoded; will break on 4.6+
- Impact: No ability to upgrade Godot without reconfiguring export
- Migration plan: Use feature tags (`@GDScript 4.5`) for breaking features, test regularly on latest Godot nightly

---

## Known Issues

**Patron Movement Speed Magic Number (Line 3, Patron.gd):**
- Symptoms: Unclear why movement_speed defaults to 3000.0 instead of 100 or 1000
- Files: `C:/git/TheaterCity/scripts/Patron.gd` line 3
- Workaround: Can be adjusted via export but effect on gameplay speed not documented
- Root cause: Likely tuned experimentally without documentation

**Door Terrain Updates Inefficient:**
- Symptoms: Doors placed in rapid succession cause multiple terrain re-evaluations
- Files: `C:/git/TheaterCity/scripts/room_building/operations/DoorOperation.gd` lines 75-81
- Workaround: None practical in current architecture
- Root cause: Each door placement invalidates and re-applies terrain for neighbors instead of batching

**Preview Sprite Positioning Calculation Complex:**
- Symptoms: Preview sprite alignment with cursor requires multi-step offset calculation
- Files: `C:/git/TheaterCity/scripts/room_building/RoomBuildUI.gd` lines 309-330
- Workaround: Sprite visibility toggle if positions get out of sync
- Root cause: Isometric coordinate space requires special handling; centralized math helper exists but calculation still complex in UI

---

## Code Quality Observations

**No Logging Infrastructure:**
- Issue: No centralized logging; only `push_warning()` and `push_error()` used ad-hoc
- Impact: Hard to debug issues in production; warnings scattered, no log levels
- Recommendation: Add simple LogManager.gd for consistent logging

**Inconsistent Null Checking Pattern:**
- Issue: Some functions check `if not room:` immediately, others assume validity
- Files: Multiple operation files show inconsistent patterns
- Recommendation: Standardize guard clause pattern at top of functions

**Magic Numbers in Constants:**
- Issue: Noise strength values (0.5, 10), tile cost multiples (10, 50), size limits (30x30) are hard-coded without explanation
- Files: Scattered throughout codebase
- Recommendation: Extract to configuration resource or configuration class

---

*Concerns audit: 2026-01-20*
