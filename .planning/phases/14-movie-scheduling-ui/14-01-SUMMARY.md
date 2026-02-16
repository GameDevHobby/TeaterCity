# 14-01 Summary - Scheduling Data Plumbing

## Completed

- Added persistent theater scheduled-movie payload to `RoomInstance` with explicit helpers:
  - `set_scheduled_movie(movie: MovieResource)`
  - `clear_scheduled_movie()`
  - `has_scheduled_movie()`
- Extended room serialization/deserialization with `scheduled_movie` payload (`id`, `title`, `genre`, `rating`, `duration`) and safe defaults for legacy saves.
- Wired runtime movie-pool bootstrap in `Main.gd`:
  - load with `MoviePoolSerializer.load_pool()`
  - generate fallback via `MovieGenerator` when missing/empty
  - persist generated pool via `MoviePoolSerializer.save_pool()`
- Added centralized scheduling API in `Main.gd`:
  - `get_available_movies_for_scheduling()`
  - `schedule_theater_movie(room, movie_id)` with theater + state-machine + idle + movie-exists guards
  - valid scheduling sets selected movie payload before `idle -> scheduled` transition

## Files

- `Scripts/storage/RoomInstance.gd`
- `Scripts/Main.gd`

## Verification

Attempted:

- `godot --headless --path . --quit`

Result:

- Could not execute in this environment: `godot: command not found`.
