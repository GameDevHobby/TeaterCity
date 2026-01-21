# External Integrations

**Analysis Date:** 2026-01-20

## APIs & External Services

**Claude AI (Development Only):**
- Service: Anthropic Claude API via GDAI MCP Plugin
- What it's used for: AI-assisted development tools (MCP protocol)
- SDK/Client: `addons/gdai-mcp-plugin-godot/` (GDExtension)
- Autoload: `GDAIMCPRuntime`
- Status: Development/editor-only integration

**Note:** No production external APIs detected. Game is self-contained.

## Data Storage

**Databases:**
- None - No database integration

**File Storage:**
- Local filesystem only
- Godot resource files (`.tres`, `.tscn`) stored in `res://` directory
- Export: Android APK to `./TheaterCity.apk`

**Caching:**
- Godot's built-in resource cache via ResourceLoader
- `.godot/` directory for editor caching and shader compilation

## Authentication & Identity

**Auth Provider:**
- Not implemented - Single-player game with no multiplayer/account system

## Monitoring & Observability

**Error Tracking:**
- Not integrated - Uses Godot's built-in error logging to console

**Logs:**
- Console output via Godot print() and push_error()
- Visual Studio debugger integration available via addon (optional)

**Debugging:**
- Godot debugger (built-in)
- Optional: Visual Studio debugger via `addons/godot_visualstudio_debugger/`
- Test output via GUT test runner

## CI/CD & Deployment

**Hosting:**
- Not applicable - Mobile game (Android) or self-contained desktop executable

**Build Target:**
- Android APK export via Godot export presets
- Export preset: `export_presets.cfg` (preset 0 = Android)
- Build outputs: `./TheaterCity.apk`

**Version Control:**
- Git repository (`.git/`)
- Main branch is primary development branch

**Build Process:**
- Godot 4.5 handles compilation
- GDScript code compiled to bytecode
- Assets (sprites, sounds, tilesets) bundled into APK/executable

## Environment Configuration

**Required env vars:**
- None detected - Game loads all configuration from project.godot and resource files

**Secrets location:**
- Not applicable - No external services requiring credentials

**Project Configuration File:**
- `project.godot` - Main project settings
  - Application name and version
  - Feature set (4.5, Mobile)
  - Autoload registrations
  - Input mapping
  - Rendering settings

## Android Export Configuration

**Manifest Settings:**
- Package: `com.GameDevHobby.TheaterCity`
- Immersive mode: Enabled (screen/immersive_mode=true)
- Screen support: Small, normal, large, xlarge
- Version code: 5
- Background color: Black (0,0,0,1)

**Architecture:**
- ARM64 only (arm64-v8a=true, others=false)

**Permissions:**
- All permissions disabled - No permissions required for game

**Data & Backup:**
- User data backup: Allowed (user_data_backup/allow=true)

## Webhooks & Callbacks

**Incoming:**
- None detected

**Outgoing:**
- None detected

## Internal Integrations (No External Dependencies)

**Scene Graph:**
- Main scene: `Main.tscn` loads all game content
  - RoomBuildController for build mode
  - PinchPanCamera for viewport control
  - TileMapLayers for rendering
  - Navigation regions for pathfinding

**Signal System:**
- Event-driven architecture via Godot signals:
  - `room_completed` - Room build completion
  - `state_changed` - State transitions
  - `entity_added` - Target registration
  - `navigation_changed` - Pathfinding updates
  - `velocity_computed` - Physics velocity
  - `navigation_finished` - Path completion

**Autoload Singletons:**
- `Targets` (`res://scripts/Targets.gd`) - Manages navigation targets
- `GDAIMCPRuntime` - MCP protocol runtime (development)

**Resource Loading:**
- ResourceLoader for `.tres` and `.tscn` files
- Godot's built-in asset import pipeline

## Third-Party Resources (Bundled)

**Assets:**
- RetroDiner sprite sheets (128x128 tiles)
  - `resources/tiles/RetroDiner_Tiles_128x128/`
  - `resources/tiles/RetroDiner_Walls_128x128/`

**Fonts:**
- Default Godot fonts (no custom font integrations)

---

*Integration audit: 2026-01-20*
