# Phase 12: Movie Data System - Research

**Researched:** 2026-02-08
**Domain:** Movie data model, procedural generation, registry pattern
**Confidence:** HIGH

## Summary

This phase creates a movie data model and procedural generation system for populating the player's available movie pool. The existing codebase provides excellent patterns to follow: `FurnitureResource`/`FurnitureRegistry` and `RoomTypeResource`/`RoomTypeRegistry` demonstrate the established Resource + Registry singleton pattern.

Movies in theater simulation games typically have: title, genre, rating (audience score/quality), duration, and sometimes additional metadata like release popularity or cost to license. For this phase, the core fields are title, genre, rating, and duration as specified in THTR-03.

**Primary recommendation:** Follow the existing registry pattern exactly (Resource class + Registry singleton with lazy-loading), add `to_dict()`/`from_dict()` methods for JSON serialization matching `RoomInstance` patterns, and implement procedural generation using `RandomNumberGenerator` for reproducible movie pools.

## Standard Stack

The established approach uses Godot's built-in systems:

### Core
| Component | Pattern | Purpose | Why Standard |
|-----------|---------|---------|--------------|
| `MovieResource` | `extends Resource` | Static movie definition | Matches FurnitureResource/RoomTypeResource pattern |
| `MovieRegistry` | `extends Resource` with static singleton | Registry access | Matches existing registries |
| `RandomNumberGenerator` | Godot built-in | Procedural generation | PCG32 algorithm, seedable, state-saveable |

### Supporting
| Component | Pattern | Purpose | When to Use |
|-----------|---------|---------|-------------|
| `MoviePool` | `extends RefCounted` | Runtime pool of available movies | For player's schedulable movies |
| `MoviePoolSerializer` | Static methods | JSON persistence | For saving/loading pool state |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Resource-based registry | JSON data files | Resources integrate with Godot editor; JSON loses inspector editing |
| RefCounted MoviePool | Resource MoviePool | RefCounted is lighter weight, no global cache bloat |
| Procedural names | Name database | Procedural is simpler; database gives more thematic control |

**Installation:**
No external packages needed - uses Godot built-in classes only.

## Architecture Patterns

### Recommended Project Structure
```
scripts/
├── data/
│   ├── MovieResource.gd        # Movie data definition (extends Resource)
│   └── MovieRegistry.gd        # Singleton registry (optional, for predefined movies)
├── storage/
│   ├── MoviePool.gd            # Runtime pool of movies (extends RefCounted)
│   └── MoviePoolSerializer.gd  # JSON serialization for pool
└── generation/
    └── MovieGenerator.gd       # Procedural movie generation

data/
├── configs/
│   └── movie_registry.tres     # (Optional) predefined movie definitions
└── movies/                     # (Optional) individual movie .tres files
```

### Pattern 1: Resource + Registry Singleton
**What:** Static data definitions using Resource class with singleton access pattern
**When to use:** Any game data that needs to be defined once and accessed globally
**Example:**
```gdscript
# Source: Existing FurnitureRegistry.gd pattern
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

### Pattern 2: RefCounted with JSON Serialization
**What:** Runtime data using RefCounted with to_dict/from_dict methods
**When to use:** Dynamic runtime data that needs persistence
**Example:**
```gdscript
# Source: Existing RoomInstance.gd, TimerState.gd patterns
class_name MoviePool
extends RefCounted

var available_movies: Array[MovieResource] = []
var _rng_state: int = 0  # For reproducible generation

func to_dict() -> Dictionary:
    var movies_arr: Array = []
    for movie in available_movies:
        movies_arr.append({
            "id": movie.id,
            "title": movie.title,
            "genre": movie.genre,
            "rating": movie.rating,
            "duration": movie.duration
        })
    return {
        "movies": movies_arr,
        "rng_state": _rng_state
    }

static func from_dict(data: Dictionary) -> MoviePool:
    var pool = MoviePool.new()
    for movie_data in data.get("movies", []):
        var movie = MovieResource.new()
        movie.id = movie_data.get("id", "")
        movie.title = movie_data.get("title", "")
        movie.genre = movie_data.get("genre", "")
        movie.rating = movie_data.get("rating", 50)
        movie.duration = movie_data.get("duration", 90)
        pool.available_movies.append(movie)
    pool._rng_state = data.get("rng_state", 0)
    return pool
```

### Pattern 3: Procedural Generation with RandomNumberGenerator
**What:** Generate varied content using seeded RNG for reproducibility
**When to use:** Creating varied game content at runtime
**Example:**
```gdscript
# Source: Godot official documentation
class_name MovieGenerator
extends RefCounted

const GENRES := ["Action", "Comedy", "Drama", "Horror", "Sci-Fi", "Romance", "Thriller", "Animation"]
const TITLE_ADJECTIVES := ["The Great", "Dark", "Lost", "Final", "Secret", "Eternal", "Hidden", "Last"]
const TITLE_NOUNS := ["Journey", "Mystery", "Kingdom", "Storm", "Heart", "Shadow", "Legend", "Dawn"]

var rng: RandomNumberGenerator

func _init() -> void:
    rng = RandomNumberGenerator.new()

func generate_movie() -> MovieResource:
    var movie = MovieResource.new()
    movie.id = _generate_id()
    movie.title = _generate_title()
    movie.genre = GENRES[rng.randi_range(0, GENRES.size() - 1)]
    movie.rating = rng.randi_range(30, 100)  # 30-100 rating scale
    movie.duration = rng.randi_range(80, 180)  # 80-180 minutes
    return movie

func _generate_title() -> String:
    var adj = TITLE_ADJECTIVES[rng.randi_range(0, TITLE_ADJECTIVES.size() - 1)]
    var noun = TITLE_NOUNS[rng.randi_range(0, TITLE_NOUNS.size() - 1)]
    return "%s %s" % [adj, noun]

func _generate_id() -> String:
    return "movie_%d" % rng.randi()
```

### Anti-Patterns to Avoid
- **Using global randi() for generation:** Use RandomNumberGenerator instance for reproducible results and testability
- **Storing MovieResource references in save data:** Store movie data as dictionaries; Resources may change between versions
- **Creating new MovieResource in _init() without defaults:** Always provide safe defaults for all fields

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Random selection from array | Manual index calculation | `array.pick_random()` | Built-in, cleaner, correct |
| Integer range random | `randi() % n + offset` | `rng.randi_range(min, max)` | Avoids modulo bias |
| Shuffling arrays | Manual Fisher-Yates | `array.shuffle()` | Built-in, optimized |
| UUID generation | Custom algorithm | `hash()` + timestamp | Good enough for game IDs |
| JSON parsing | Manual string manipulation | `JSON.parse()` / `JSON.stringify()` | Handles edge cases |

**Key insight:** Godot 4 has excellent built-in random utilities; procedural generation should use `RandomNumberGenerator` for isolation and reproducibility.

## Common Pitfalls

### Pitfall 1: Float Precision in JSON
**What goes wrong:** Large numbers become scientific notation in JSON, corrupting on reload
**Why it happens:** JSON spec allows scientific notation; Godot's JSON.stringify uses it for large numbers
**How to avoid:** Use int for all numeric fields; rating as 0-100 int, duration as minutes int
**Warning signs:** Numbers like `1.7e9` appearing in save files

### Pitfall 2: Resource Caching Surprises
**What goes wrong:** Modifying a Resource affects all references to it
**Why it happens:** Godot caches Resources globally; same path = same instance
**How to avoid:** For runtime-modified data, use RefCounted or duplicate() Resources
**Warning signs:** Changing one movie affects others; unexpected shared state

### Pitfall 3: Empty Array Type Loss
**What goes wrong:** `Array[MovieResource]` becomes untyped `Array` after JSON round-trip
**Why it happens:** JSON doesn't preserve GDScript typed array information
**How to avoid:** Clear and re-append to typed arrays in from_dict(), as shown in RoomInstance.gd
**Warning signs:** Type errors when accessing array elements after load

### Pitfall 4: Missing ID Validation
**What goes wrong:** Duplicate movie IDs cause lookup bugs
**Why it happens:** Procedural generation without uniqueness checking
**How to avoid:** Include timestamp or counter in generated IDs; validate uniqueness
**Warning signs:** Wrong movie returned from get_movie(); pool contains duplicates

### Pitfall 5: Genre/Rating Correlation Ignored
**What goes wrong:** Horror movies with 100 rating don't feel right; comedies always low-rated
**Why it happens:** Independent random generation ignores thematic expectations
**How to avoid:** Consider weighted generation or genre-specific rating ranges (optional enhancement)
**Warning signs:** Generated movies feel random/disconnected from their genre

## Code Examples

Verified patterns from the existing codebase:

### MovieResource Definition
```gdscript
# Following FurnitureResource.gd pattern
class_name MovieResource
extends Resource

@export var id: String
@export var title: String
@export var genre: String
@export var rating: int = 50  # 0-100 scale
@export var duration: int = 90  # Minutes

func to_dict() -> Dictionary:
    return {
        "id": id,
        "title": title,
        "genre": genre,
        "rating": rating,
        "duration": duration
    }

static func from_dict(data: Dictionary) -> MovieResource:
    var movie = MovieResource.new()
    movie.id = data.get("id", "")
    movie.title = data.get("title", "Unknown")
    movie.genre = data.get("genre", "Drama")
    movie.rating = data.get("rating", 50)
    movie.duration = data.get("duration", 90)
    return movie
```

### Pool Generation with Configurable Size
```gdscript
# Following technical notes: Pool size should be configurable (default: 5-8 movies)
func generate_pool(count: int = 0) -> Array[MovieResource]:
    var pool: Array[MovieResource] = []
    var actual_count = count if count > 0 else rng.randi_range(5, 8)

    for i in actual_count:
        pool.append(generate_movie())

    return pool
```

### Serializer Following RoomSerializer Pattern
```gdscript
# Following RoomSerializer.gd atomic write pattern
class_name MoviePoolSerializer
extends RefCounted

const SAVE_PATH := "user://saves/movie_pool.json"
const TEMP_PATH := "user://saves/movie_pool.json.tmp"
const SAVE_DIR := "user://saves"

static func save_pool(pool: MoviePool) -> bool:
    if not DirAccess.dir_exists_absolute(SAVE_DIR):
        var err = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
        if err != OK:
            push_error("MoviePoolSerializer: Failed to create save directory")
            return false

    var save_data := {
        "version": 1,
        "saved_at": Time.get_datetime_string_from_system(),
        "pool": pool.to_dict()
    }

    var json_string := JSON.stringify(save_data, "  ")
    # ... atomic write pattern continues as in RoomSerializer
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `rand_range()` | `randf_range()` | Godot 4.0 | Function renamed |
| Manual array random | `array.pick_random()` | Godot 4.0 | Convenience method added |
| Global `randomize()` | `RandomNumberGenerator` instance | Godot 3.x → 4.x | Better isolation, testability |

**Deprecated/outdated:**
- `rand_range()`: Renamed to `randf_range()` in Godot 4
- Global `randi()`/`randf()` for game logic: Use `RandomNumberGenerator` for reproducibility

## Open Questions

Things that couldn't be fully resolved:

1. **Movie title generation complexity**
   - What we know: Simple adjective + noun works for MVP
   - What's unclear: Whether more sophisticated generation (genre-appropriate titles) is wanted
   - Recommendation: Start simple; can enhance in future phase

2. **Whether MovieRegistry is needed**
   - What we know: Procedural generation means no predefined movies
   - What's unclear: Whether we want some "classic" predefined movies
   - Recommendation: Skip MovieRegistry initially; MoviePool handles runtime movies. Add registry later if predefined movies are desired.

3. **Rating interpretation**
   - What we know: Rating is 0-100 int per THTR-03
   - What's unclear: Does rating affect gameplay (revenue, popularity)?
   - Recommendation: Store rating; gameplay effects are future phase scope

## Sources

### Primary (HIGH confidence)
- Existing codebase patterns:
  - `FurnitureResource.gd`, `FurnitureRegistry.gd` - Resource/Registry pattern
  - `RoomInstance.gd` - RefCounted with to_dict/from_dict serialization
  - `TimerState.gd` - Simple RefCounted serialization
  - `RoomSerializer.gd` - Atomic JSON file I/O pattern
- [Godot RandomNumberGenerator documentation](https://docs.godotengine.org/en/stable/classes/class_randomnumbergenerator.html)
- [Godot Random number generation tutorial](https://docs.godotengine.org/en/stable/tutorials/math/random_number_generation.html)

### Secondary (MEDIUM confidence)
- [Weighted Random Selection With Godot](http://kehomsforge.com/tutorials/single/weighted-random-selection-godot/) - Weighted selection patterns
- [Godot Ref Serializer](https://github.com/KoBeWi/Godot-Ref-Serializer) - RefCounted serialization patterns

### Tertiary (LOW confidence)
- [Cinema Simulator games research](https://store.steampowered.com/app/3098070/Cinema_Simulator_2025/) - Domain understanding, not directly applicable to code

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Uses established codebase patterns verbatim
- Architecture: HIGH - Follows existing registry/serialization patterns
- Pitfalls: HIGH - Documented from existing codebase issues and Godot docs
- Generation patterns: MEDIUM - Based on Godot docs, not project-specific precedent

**Research date:** 2026-02-08
**Valid until:** 2026-03-08 (30 days - stable domain, established patterns)
