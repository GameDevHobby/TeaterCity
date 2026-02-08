# Features Research: Theater Mechanics

**Domain:** Theater/Venue Simulation - Time Management Game
**Researched:** 2026-02-08
**Confidence:** MEDIUM

Research focused on time management games (Two Point Hospital, Cinema Tycoon, Theme Park) and mobile tycoon patterns to identify features for theater state machine, movie scheduling, and patron flow.

---

## Table Stakes (Must Have)

Features users expect from theater/scheduling mechanics. Missing these makes the system feel incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Theater Room States** | Core state progression (Idle → Scheduled → Playing → Cleaning) is fundamental to venue simulation | Medium | Similar to Two Point Hospital's room workflow: patient → diagnosis → treatment → exit. Theater needs: empty → scheduled → active → cleanup cycle |
| **Movie Selection UI** | Players expect ability to choose content from a catalog | Low | Cinema Tycoon games feature movie databases (1000+ films in Cinema Theater Tycoon). Need simple list/grid picker for v1.1 |
| **Basic Scheduling** | Assign movie to theater at specific time/state trigger | Low | Core mechanic: player selects movie, assigns to theater, triggers state transition from Idle → Scheduled |
| **Duration-Based Showing** | Movie plays for fixed duration, then transitions to next state | Medium | Real cinema games use actual movie durations. Need: movie data has duration property, state timer respects it |
| **Patron Seat Claiming** | Patrons must claim specific seats upon entering theater | Medium | Theme parks track individual guest states and needs. Theater needs: pathfind to theater → claim seat → watch → exit flow |
| **Theater Capacity** | Limited seats per theater, full = no more patrons | Low | Theme park attraction capacity is standard (360-1000 guests/hour typical). Need: max_seats property, track occupied count |
| **State Visual Feedback** | Player can see theater state at a glance | Low | Two Point Hospital shows room status (idle/active/problem). Need: visual indicator on theater (color change, icon, animation) |
| **Cleanup Transition** | After movie ends, theater enters cleanup state before next scheduling | Low | Logical requirement for simulation realism. Prevents instant back-to-back showings, adds strategic timing |

**Priority Order for Implementation:**
1. Theater state machine (Idle/Scheduled/Playing/Cleaning)
2. Movie data structure (title, duration, genre)
3. Basic scheduling UI (pick movie → assign to theater)
4. Patron seat claiming flow
5. Duration-based state transitions
6. Visual state feedback

---

## Differentiators (Nice to Have)

Features that would enhance the experience beyond basic theater mechanics. Not expected, but add depth.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Movie Genre Preferences** | Patrons have genre preferences, higher satisfaction if matched | Medium | RollerCoaster Tycoon tracks "preferred ride intensity" per guest. Could track genre_preference per patron, bonus happiness on match |
| **Preview/Trailer State** | Theater shows trailers before movie starts (Scheduled → Previews → Playing) | Low | Adds realism, creates visible "theater is starting" moment. Simple timer extension before main movie |
| **Multiple Simultaneous Showings** | 2-3 theaters running different movies at once | High | Requires robust state management per theater, patron decision logic ("which movie to watch?"), scheduling conflicts |
| **Time-of-Day Scheduling** | Player sets showtimes (e.g., 2pm, 7pm showings) | High | Requires day/night cycle, clock UI, patron arrival timing. Defer to post-v1.1 unless day/night already exists |
| **Movie Popularity/Rating** | Movies have popularity score affecting patron arrival rate | Medium | Cinema Tycoon uses historical film ratings. Could affect: patron spawn rate, willingness to wait, ticket price tolerance |
| **Ticket Booth Queue** | Patrons queue at ticket booth before entering theater | Medium | Theme parks show 84%+ satisfaction with virtual queues. Could add: ticket_booth entity, queue visualization, purchase interaction |
| **Concessions Stand** | Popcorn/snacks purchase before entering theater | Medium | Cinema Tycoon includes "ticket and popcorn prices." Adds revenue stream, patron satisfaction boost, navigation complexity |
| **Staff Assignment** | Assign projectionist/usher to theater for performance bonus | Medium | Two Point Hospital requires doctors per room. Could add: staff entity, skill modifiers, hiring UI. Significant scope increase |
| **Dynamic Pricing** | Adjust ticket price per showing based on demand/quality | Low | Idle Cinema Tycoon features pricing strategy. Could multiply revenue by price_multiplier (0.5x-2.0x) |
| **Movie Unlocks** | Unlock better movies through progression | Low | Standard idle/tycoon mechanic. Start with low-quality films, unlock blockbusters. Simple progression gate |

**Recommended for v1.1:**
- Preview/Trailer state (low complexity, high realism boost)
- Movie genre preferences (adds patron personality depth)
- Movie popularity affecting spawn rate (simple multiplier)

**Defer to post-v1.1:**
- Multiple simultaneous showings (needs robust architecture first)
- Time-of-day scheduling (requires game-wide time system)
- Staff assignment (major scope expansion)

---

## Anti-Features (Don't Build)

Features to explicitly avoid for v1.1. Common mistakes in casual mobile tycoon games.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Complex Movie Budgeting** | Movie production/licensing costs add financial management complexity that distracts from core venue simulation | Keep it simple: movies are unlockable content, not purchased assets. Focus on scheduling/operations, not film acquisition economics |
| **Real-Time Movie Playback** | Showing actual movie content (even placeholder animations) for full duration creates long idle periods, breaks mobile pacing | Use time acceleration or abstracted "movie is playing" state. Mobile games need 5-30 second loops, not 90-minute waits |
| **Patron Complaints System** | Individual patron feedback ("seat uncomfortable," "movie too loud") creates micro-management hell in mobile context | Use aggregate satisfaction score. Theater-wide metrics, not per-patron issue tracking. Two Point Hospital's "patient satisfaction %" not individual complaints |
| **Film Critic Reviews** | Simulating critic reviews/scores adds narrative complexity with minimal gameplay value | Movie quality is intrinsic property (popularity rating). Skip the meta-narrative of reviews, ratings, press |
| **Multi-Screen Complexes** | Managing 5-10 theaters simultaneously in v1.1 creates cognitive overload for casual mobile players | Start with 1-2 theaters. "Feature creep kills games" - mobile casual needs bite-sized loops. Expansion can come later |
| **Seasonal Movie Releases** | Time-gated content ("summer blockbusters unlock in June") adds calendar dependency, hurts offline progression | All movies available based on progression unlock, not real-world calendar. Idle games need "play anytime" flexibility |
| **Projectionist Minigame** | Interactive film reel loading/focusing creates mode-switching that breaks tycoon flow | Fully automated. Staff (if added later) work autonomously. Tycoon games are about strategic decisions, not execution minigames |
| **Detailed Seat Layout Editor** | Custom theater seating arrangements (aisle placement, row spacing) over-complicates room building | Theater has fixed capacity property (e.g., 20 seats). Abstract the layout. Room building already complex enough |
| **Movie Piracy Mechanic** | "Security" stat to prevent revenue loss from piracy adds negative/punishing gameplay | Stay positive. Tycoon games should feel about growth, not loss prevention. Skip anti-piracy simulation |
| **Advanced Scheduling Conflicts** | Double-booking prevention, schedule optimization algorithms, Gantt charts | Keep scheduling manual and simple: "Is theater Idle? Assign movie." No conflict resolution needed if theaters are independent |

**Design Principle:**
Mobile casual tycoon games succeed with **"simple core loop + meta-progression"** (hybrid-casual formula showed 37% YoY IAP revenue growth in 2024). Theater v1.1 should have:
- **Simple core:** Click theater → pick movie → watch it play → collect revenue
- **Meta-progression:** Unlock better movies, build more theaters, upgrade capacity

Avoid: Multiple interconnected systems, real-time complexity, micro-management, negative mechanics.

---

## Feature Dependencies

Understanding what must exist before other features can work:

```
FOUNDATION LAYER (Phase 1)
├─ Theater Room Data Structure (RoomInstance extension)
├─ Movie Data Structure (new MovieResource)
├─ Theater State Machine (Idle/Scheduled/Playing/Cleaning)
└─ Basic State Transitions (timer-based)

SCHEDULING LAYER (Phase 2)
├─ Movie Registry/Database (requires: Movie Data)
├─ Scheduling UI (requires: Movie Registry, Theater State Machine)
├─ Movie Assignment Logic (requires: State Machine, Movie Data)
└─ Duration-Based Timing (requires: Movie Data, State Transitions)

PATRON INTERACTION LAYER (Phase 3)
├─ Seat Claiming System (requires: Theater Room, Patron navigation)
├─ Theater Entry Logic (requires: State Machine in "Playing" state)
├─ Patron Theater Behavior (requires: Seat Claiming, Duration Timing)
└─ Patron Exit Logic (requires: Movie Duration complete)

POLISH LAYER (Phase 4)
├─ Visual State Feedback (requires: State Machine)
├─ Preview/Trailer State (requires: State Machine)
├─ Genre Preferences (requires: Patron data, Movie Data)
└─ Popularity Modifiers (requires: Movie Data, Patron spawning)
```

**Critical Path:**
Theater State Machine → Movie Data → Scheduling UI → Patron Seat Claiming

Everything else builds on these four foundations.

---

## MVP Recommendation

For v1.1 milestone (theater mechanics introduction), prioritize:

### Must-Have (Core Loop)
1. **Theater State Machine** - Idle → Scheduled → Playing → Cleaning states with timer-based transitions
2. **Movie Data** - Simple resource with: title (string), duration (float in minutes), genre (enum)
3. **Scheduling UI** - Modal panel: "Select Movie" button on idle theater → shows movie list → assigns to theater
4. **Patron Seat Claiming** - Patrons pathfind to theater in "Playing" state, claim random available seat, wait for duration, exit
5. **Visual State Indicator** - Theater sprite/icon changes color or shows simple icon per state

**Success Criteria:**
- Player can build theater (existing room system)
- Player can schedule movie on idle theater
- Theater progresses through states automatically
- Patrons enter, sit, watch, leave
- Theater becomes idle again after cleanup

### Nice-to-Have (If Time Permits)
1. **Preview State** - 30-second preview period before main movie (easy timer addition)
2. **Genre Preferences** - Patrons have favorite genre, +happiness if matched (simple data property)
3. **Movie Popularity** - High-popularity movies attract 1.5x patron spawn rate (simple multiplier)

### Explicitly Defer
- Multiple simultaneous showings (needs architectural validation first)
- Ticket booth/queuing (adds navigation complexity)
- Staff/projectionist (major scope expansion)
- Time-of-day scheduling (needs game-wide time system)
- Concessions (separate system entirely)

**Why This MVP Works:**
- Focused on single feature loop (schedule → watch → repeat)
- Uses existing systems (room building, patron navigation)
- Adds new systems incrementally (state machine, movie data, UI)
- Delivers "theater feel" without overwhelming complexity
- Aligns with mobile casual "simple core + meta" principle

---

## Complexity Analysis

Estimating implementation effort for theater mechanics:

| Component | Complexity | Effort | Risk |
|-----------|------------|--------|------|
| Theater State Machine | Medium | 2-3 days | Low - standard FSM pattern |
| Movie Data Structure | Low | 0.5 days | None - simple resource type |
| Movie Registry | Low | 0.5 days | None - mirrors existing registries |
| Scheduling UI | Medium | 2-3 days | Low - similar to furniture placement UI |
| Patron Seat Claiming | Medium | 3-4 days | Medium - navigation + state coordination |
| Duration-Based Timing | Low | 1 day | Low - timer + signal system |
| Visual State Feedback | Low | 1-2 days | None - sprite/shader changes |
| Preview State | Low | 0.5 days | None - extends existing state machine |
| Genre Preferences | Low | 1 day | Low - patron data extension |
| Multiple Showings | High | 5-7 days | High - requires patron decision logic |
| Time-of-Day Scheduling | High | 7-10 days | High - game-wide time system dependency |

**Total MVP Estimate:** 10-15 days (Theater FSM + Movie Data + Scheduling UI + Patron Claiming + Polish)

**With Nice-to-Haves:** 13-18 days (+Preview +Genre +Popularity)

---

## Reference Games Analysis

What we can learn from existing time management/venue simulation games:

### Two Point Hospital (2018, PC/Console/Mobile)
**What it does well:**
- Room state workflow: patient flow through diagnosis → treatment cycles
- Visual clarity: room status immediately visible (idle/active/problem icons)
- Staff automation: doctors work autonomously once assigned
- Progressive complexity: early levels simple, later levels add interconnected systems

**Applicable to TheaterCity:**
- Theater states mirror treatment rooms (idle → active → cleanup)
- Visual state indicators critical for mobile
- Keep patron behavior autonomous (not player-controlled)
- v1.1 should be simple; complexity comes in later milestones

### Cinema Tycoon Series (2005-2024, Mobile/PC)
**What it does well:**
- Movie database: extensive film catalogs (1000+ titles in Cinema Theater Tycoon)
- Film scheduling: core mechanic of matching content to venues
- Era progression: unlock films from different time periods
- Pricing strategy: ticket price affects demand and revenue

**Applicable to TheaterCity:**
- Movie selection should feel like meaningful choice (not random)
- Progression through movie unlocks (start with B-movies, unlock blockbusters)
- Duration matters: short films vs feature films affects theater utilization
- Keep pricing simple or defer (avoid complex demand curves for v1.1)

### Idle Cinema Tycoon (2024, Mobile)
**What it does well:**
- Offline progression: cinema runs while app closed
- Simple loop: schedule → earn → upgrade → repeat
- Expansion: unlock more halls as you grow
- Idle manager: automates operations when away

**Applicable to TheaterCity:**
- Mobile-first design: quick sessions, progress while offline
- Don't require constant player attention
- Theater scheduling should be "set it and forget it" until movie ends
- Expansion path: 1 theater → 2 theaters → 3 theaters over time

### Theme Park/RollerCoaster Tycoon (1999-2024, PC/Mobile)
**What it does well:**
- Guest state tracking: hunger, thirst, nausea, happiness per individual
- Attraction capacity: rides have throughput limits (360-1000 guests/hour)
- Queue management: virtual queues showed 84% satisfaction improvement
- Ride ratings: excitement/intensity/nausea affect guest selection

**Applicable to TheaterCity:**
- Patron state system: needs, preferences, satisfaction
- Theater capacity limits create strategic decisions
- Genre preferences similar to ride intensity preferences
- Don't need physical queue visualization (abstract it)

### Lessons - What NOT to Do

From postmortems and community discussions:

1. **Two Point Hospital diagnosis loop frustration:** Patients cycling GP → diagnosis → GP → diagnosis creates congestion. **Lesson:** Theater patrons should have single path: enter → claim seat → watch → exit. No backtracking.

2. **Cinema Tycoon complexity creep:** Advanced settings, screen ratios, projection tech overwhelms casual players. **Lesson:** Theater v1.1 keeps it abstract. Capacity number, not seat layouts.

3. **Theme Park guest pathfinding issues:** Guests get lost, stuck, frustrated. **Lesson:** Theater must have clear entry/exit points, reliable pathfinding, failsafe (patron leaves if can't find seat).

4. **Mobile idle games requiring constant attention:** Defeats purpose of idle/tycoon genre. **Lesson:** Scheduling should be set-and-forget. Player checks in periodically, not babysits.

---

## Mobile-Specific Considerations

TheaterCity targets mobile platforms - features must respect mobile constraints:

### Screen Real Estate
- **Challenge:** Limited screen space for UI
- **Implication:** Scheduling UI must be simple modal, not complex calendar grid
- **Solution:** Single-screen movie picker, list or grid of 6-10 movies max at once

### Touch Input
- **Challenge:** Finger occlusion, imprecise targeting
- **Implication:** Theater state indicators must be large, clear, high-contrast
- **Solution:** Bold icons/colors per state, tap theater to open scheduling panel

### Session Length
- **Challenge:** Mobile sessions average 3-7 minutes
- **Implication:** Movie durations can't be real-time (90 minutes = absurd)
- **Solution:** Accelerated time (1 game-minute = 1 real-second → 90-second movies) OR abstract timing (movie = 30-second state)

### Performance
- **Challenge:** Lower-end devices, battery concerns
- **Implication:** State machine shouldn't poll every frame
- **Solution:** Timer-based transitions with signals, not continuous state checks

### Offline Progression
- **Challenge:** Players expect progress while app closed (idle genre staple)
- **Implication:** Theater must simulate "time passed" on app open
- **Solution:** Track last_open timestamp, fast-forward state machine, grant accumulated revenue

---

## Confidence Assessment

| Research Area | Confidence | Reason |
|---------------|------------|--------|
| **State Machine Patterns** | HIGH | Well-documented FSM patterns in game dev, Godot LimboAI already in project |
| **Time Management Game Flow** | MEDIUM | Community guides/discussions found, but not official design docs. Pattern clear from player descriptions |
| **Cinema Tycoon Mechanics** | MEDIUM | Multiple games identified with scheduling mechanics, but specific implementation details limited |
| **Mobile Casual Best Practices** | HIGH | 2026 mobile gaming trends well-documented, hybrid-casual formula proven (37% YoY growth) |
| **Patron Behavior in Theaters** | LOW | No specific theater-seating games found. Extrapolating from theme park guest systems and restaurant sims |
| **Offline Progression** | HIGH | Standard idle game mechanic, well-established patterns in Idle Miner Tycoon and similar |

**Overall Research Confidence: MEDIUM**

Strong understanding of:
- State machine implementation
- Time management game loops
- Mobile casual design principles
- Idle/tycoon progression systems

Weaker understanding of:
- Specific theater seat-claiming mechanics (no direct precedent found)
- Optimal movie duration pacing for mobile
- Player expectations for theater simulation (niche genre)

**Recommendation:** Proceed with MVP, playtest theater loop early to validate seat-claiming UX and timing feel.

---

## Open Questions for Testing

Research cannot answer these - need playtesting:

1. **Movie Duration Feel:** Does 30 seconds feel too fast? 90 seconds too slow? (Test: try 30s, 60s, 90s with playtesters)

2. **Scheduling Frequency:** How often should player schedule movies? Every 2 minutes? Every 5 minutes? (Affects engagement loop pacing)

3. **Capacity Satisfaction:** Do players feel good with 10-seat theater? 20-seat? 50-seat? (Affects sense of "full theater" satisfaction)

4. **State Visibility:** Can player understand theater state at a glance while zoomed out? (Test: color-only vs icon-only vs both)

5. **Cleanup Duration:** How long should cleanup state last? 10 seconds? 30 seconds? (Balance: realism vs annoying wait time)

6. **Genre Preference Impact:** If patrons prefer Action but watch Comedy, how much happiness penalty? -10%? -25%? (Affects importance of genre matching)

7. **Idle Theater Frustration:** Does empty idle theater feel like wasted potential (drives scheduling) or relaxing downtime? (Player psychology test)

---

## Sources

### Time Management Game Mechanics
- [Two Point Hospital Beginner's Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1632044281) - Room mechanics, patient flow
- [Two Point Hospital FAQ](https://www.neoseeker.com/two-point-hospital/faqs/3048828-walkthrough.html) - Patient treatment cycle
- [Two Point Hospital Patient Management](https://www.neoseeker.com/two-point-hospital/Patient_Management) - Workflow and diagnosis loop
- [RollerCoaster Tycoon - Wikipedia](https://en.wikipedia.org/wiki/RollerCoaster_Tycoon) - Guest tracking, attraction capacity

### Cinema Tycoon Games
- [Cinema Theater Tycoon on Steam](https://store.steampowered.com/app/3433110) - Film scheduling, historical eras
- [Movierooms - Cinema Management](https://store.steampowered.com/app/2473820/Movierooms__Cinema_Management/) - Movie scheduling, staff management
- [Idle Cinema Tycoon](https://www.crazygames.com/game/idle-cinema-tycoon) - Mobile idle mechanics, offline progression

### Theme Park Queue Systems
- [Queue Management System for Theme Parks - Wavetec](https://www.wavetec.com/blog/queue-management/theme-parks/) - Virtual queuing, capacity management
- [Theme Park Virtual Queuing - Attractions.io](https://attractions.io/feature-library/virtual-queuing) - 84% satisfaction statistic
- [Analysis of Queue Management in Theme Parks - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC10362101/) - Guest flow analysis

### Mobile Game Design (2026)
- [2026 Predictions for Mobile Games - Gamesforum](https://www.globalgamesforum.com/features/predictions-for-mobile-games-in-2026) - Bite-sized hybrid-casual trends
- [Casual Games Market 2026 - Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/casual-games) - 37% YoY IAP growth, hybrid-casual formula
- [Best Idle Games Mobile 2026 - Udonis](https://www.blog.udonis.co/mobile-marketing/mobile-games/best-idle-games) - Offline progression patterns
- [Beating Feature Creep - Gamedeveloper.com](https://www.gamedeveloper.com/business/beating-feature-creep) - Avoiding complexity creep

### Game State Machines
- [Make a Finite State Machine in Godot 4 - GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/) - FSM implementation patterns
- [State Pattern - Game Programming Patterns](https://gameprogrammingpatterns.com/state.html) - State machine design theory
- [Finite State Machine for Game Developers](https://gamedevelopertips.com/finite-state-machine-game-developers/) - FSM best practices

**Research Confidence Summary:**
- HIGH confidence: State machines, mobile casual design, idle progression
- MEDIUM confidence: Time management loops, cinema tycoon patterns
- LOW confidence: Theater-specific seat claiming mechanics (limited precedent)
