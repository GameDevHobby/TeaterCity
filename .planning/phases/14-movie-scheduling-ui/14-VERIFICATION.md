phase: 14
phase_name: Movie Scheduling UI
status: human_needed
verified_at: 2026-02-16
score: 4/5

## Goal

Players can schedule movies through an accessible UI connected to theater rooms.

## Must-Haves Check

1. `Tapping the room-type button on a theater room opens the scheduling panel` - **PASS (code verified)**
   - `Scripts/Main.gd` routes theater room-type action to `TheaterSchedulePanel.show_for_room(...)`.
2. `Scheduling panel displays available movies from the movie pool` - **PASS (code verified)**
   - `Scripts/Main.gd` uses `get_available_movies_for_scheduling()` and injects list into panel.
3. `Each movie shows title, genre, rating, and duration in the list` - **PASS (code verified)**
   - `scripts/room_editing/TheaterSchedulePanel.gd` renders `title | genre | rating | duration` rows and detail panel.
4. `Selecting a movie and confirming triggers Idle -> Scheduled transition` - **PASS (code verified)**
   - `Scripts/Main.gd` confirm handler calls `schedule_theater_movie(...)` which guards idle-only and transitions to `scheduled`.
5. `Selected movie is stored in the theater's state data` - **HUMAN_NEEDED**
   - Code path writes room payload via `RoomInstance.set_scheduled_movie(...)`; runtime verification is required to confirm end-to-end interaction and save/load behavior.

## Automated Verification Limits

- `godot --headless --path . --quit` could not run (`godot: command not found`).
- GUT unit/integration commands could not run for the same reason.
- No GDScript LSP server is configured in this environment.

## Human Verification Checklist

1. Run the game: `godot --path .`.
2. Select a theater room and tap `Theater Schedule`.
3. Confirm centered modal appears and movie rows include title/genre/rating/duration.
4. Tap `Cancel` and confirm state is unchanged.
5. Reopen modal, select a movie, tap `Schedule`, and confirm theater state becomes `scheduled`.
6. Save/reload and confirm selected movie payload persists on that room.

## Route

- If checklist passes: mark phase as approved and continue with roadmap/state completion updates.
- If checklist fails: create gap-closure plans via `/gsd:plan-phase 14 --gaps`.
