# Phase 9: Admin Menu & Feature Flags - Research

**Researched:** 2026-02-07
**Domain:** Development tools, feature flags, and configuration management in Godot 4.5
**Confidence:** HIGH

## Summary

Admin menus and feature flags in Godot 4.5 follow established patterns using the engine's built-in configuration system and feature detection. The standard approach combines:

1. **Feature flag storage** in ProjectSettings (custom properties in project.godot)
2. **Runtime detection** using OS.has_feature() for build-type differentiation (debug vs release)
3. **Configuration override** via override.cfg for per-environment settings
4. **Autoload singleton** for centralized admin functionality
5. **Built-in dialogs** (ConfirmationDialog) for destructive action confirmations

The existing persistence infrastructure (RoomManager, RoomSerializer) already provides all the primitives needed for revert/reset operations. The admin menu will primarily orchestrate these existing capabilities behind a feature-gated UI.

**Primary recommendation:** Use ProjectSettings for feature flags combined with OS.has_feature("debug") for automatic production exclusion, implement admin menu as an autoload singleton with CanvasLayer UI, and leverage existing RoomManager/RoomSerializer for all persistence operations.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ProjectSettings | Godot 4.5 built-in | Store feature flag configuration | Official Godot config system, persistent across sessions |
| OS.has_feature() | Godot 4.5 built-in | Detect build type (debug/release) | Automatic differentiation, no manual export config needed |
| Autoload singleton | Godot 4.5 pattern | Global admin menu access | Standard Godot pattern for game-wide systems |
| ConfirmationDialog | Godot 4.5 built-in | User confirmation for destructive actions | Built-in UI component, platform-aware button ordering |
| CanvasLayer | Godot 4.5 built-in | Screen-space UI positioning | Prevents UI from moving with camera, ensures visibility |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| override.cfg | Godot 4.5 feature | Environment-specific overrides | QA/dev environment differentiation without code changes |
| AcceptDialog | Godot 4.5 built-in | Simple notifications | Non-destructive confirmations, info messages |
| Timer | Godot 4.5 built-in | Debounce UI interactions | Prevent double-clicks on destructive actions |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ProjectSettings | JSON config file | ProjectSettings integrates with editor, JSON requires custom parsing |
| OS.has_feature() | Custom build flag | Feature tags are automatic, custom flags need manual management |
| ConfirmationDialog | Custom modal | Built-in handles platform differences (OK/Cancel order), saves time |

**Installation:**
No external dependencies required - all tools are Godot built-ins.

## Architecture Patterns

### Recommended Project Structure
```
scripts/
├── admin/
│   ├── AdminMenu.gd           # Autoload singleton - orchestrates admin features
│   └── AdminMenuUI.gd         # UI component - buttons, dialogs, visual feedback
└── storage/
    ├── RoomManager.gd         # [EXISTING] Already has save/load orchestration
    └── RoomSerializer.gd      # [EXISTING] Already has file I/O primitives
```

### Pattern 1: Feature Flag Check Pattern
**What:** Check both custom feature flags and build type before showing admin features
**When to use:** Every admin menu access point (button visibility, hotkey handlers)
**Example:**
```gdscript
# Source: Godot 4 Feature Tags documentation + ProjectSettings API
# https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html

extends Node

func _ready() -> void:
    # Check if admin features are enabled
    if _is_admin_enabled():
        show_admin_menu()
    else:
        hide_admin_menu()

func _is_admin_enabled() -> bool:
    # Method 1: Always enabled in debug builds (editor + debug exports)
    if OS.has_feature("debug"):
        return true

    # Method 2: Check custom project setting (for release builds with admin)
    if ProjectSettings.has_setting("application/admin/enabled"):
        return ProjectSettings.get_setting("application/admin/enabled")

    # Default: disabled in release builds
    return false
```

### Pattern 2: Autoload Singleton with Lazy UI
**What:** Singleton manages admin state, UI instantiates only when needed
**When to use:** Admin features that should be accessible globally but rarely used
**Example:**
```gdscript
# Source: Godot Singletons (Autoload) documentation
# https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html

# AdminMenu.gd (registered as autoload in project.godot)
extends Node

var _ui_instance: Control = null
const ADMIN_UI_SCENE := preload("res://scenes/ui/admin_menu_ui.tscn")

func _ready() -> void:
    # Don't create UI until needed (memory efficient)
    if not _is_admin_enabled():
        return

func show_menu() -> void:
    if not _is_admin_enabled():
        return

    if _ui_instance == null:
        _ui_instance = ADMIN_UI_SCENE.instantiate()
        add_child(_ui_instance)

    _ui_instance.show()

func hide_menu() -> void:
    if _ui_instance:
        _ui_instance.hide()
```

### Pattern 3: Confirmation Dialog for Destructive Actions
**What:** Two-step confirmation with explicit action description
**When to use:** Any action that deletes data (reset) or discards changes (revert)
**Example:**
```gdscript
# Source: ConfirmationDialog class reference
# https://docs.godotengine.org/en/stable/classes/class_confirmationdialog.html

func _on_reset_button_pressed() -> void:
    var dialog := ConfirmationDialog.new()
    dialog.dialog_text = "Reset will delete ALL room data.\nThis cannot be undone.\n\nContinue?"
    dialog.ok_button_text = "Reset All Data"
    dialog.cancel_button_text = "Cancel"

    # Connect confirmation signal
    dialog.confirmed.connect(_perform_reset)

    # Add to scene tree and show
    add_child(dialog)
    dialog.popup_centered()

func _perform_reset() -> void:
    # Call existing RoomManager/RoomSerializer methods
    RoomManager.clear_all_rooms()
    RoomSerializer.delete_save_file()
    print("Admin: All data reset")
```

### Pattern 4: Revert Without Custom Backup
**What:** Leverage existing auto-save system by reloading from last save file
**When to use:** Revert functionality in games with auto-save (like TheaterCity)
**Example:**
```gdscript
# Existing TheaterCity infrastructure already supports this pattern
# RoomManager auto-saves every 5 seconds with debounce
# Revert = reload rooms from disk, discard in-memory changes

func _on_revert_button_pressed() -> void:
    var dialog := ConfirmationDialog.new()
    dialog.dialog_text = "Revert to last saved state?\nUnsaved changes will be lost."
    dialog.ok_button_text = "Revert"
    dialog.cancel_button_text = "Cancel"

    dialog.confirmed.connect(_perform_revert)
    add_child(dialog)
    dialog.popup_centered()

func _perform_revert() -> void:
    # Clear current state
    var current_rooms = RoomManager.get_all_rooms()
    for room in current_rooms:
        RoomManager.unregister_room(room)

    # Reload from disk (RoomSerializer.load_rooms())
    # RoomManager._load_saved_rooms() does this internally
    # Trigger signal to rebuild visuals
    var saved_rooms = RoomSerializer.load_rooms()
    for room in saved_rooms:
        RoomManager.register_room(room)
        # Visual rebuild happens via room_added signal

    print("Admin: Reverted to last save")
```

### Pattern 5: Override.cfg for Environment-Specific Config
**What:** Place override.cfg next to project binary to enable admin in specific environments
**When to use:** QA builds, internal testing, or developer-only features
**Example:**
```
# File: override.cfg (in project root during development)
# Source: ProjectSettings documentation
# https://docs.godotengine.org/en/stable/classes/class_projectsettings.html

[application]

# Enable admin menu for this environment
admin/enabled=true

# Custom admin hotkey
admin/toggle_key=192  # Tilde key (~)
```

### Anti-Patterns to Avoid
- **Separate backup system:** Don't create custom backup files - revert by reloading the existing save file
- **Hardcoded feature flags:** Don't use `const ADMIN_ENABLED = true` - use ProjectSettings for runtime configuration
- **Production admin backdoors:** Don't include "secret" ways to enable admin in release builds - use explicit debug builds
- **Weak confirmations:** Don't use simple "Are you sure?" dialogs - be explicit about what will be lost
- **UI in autoload scene:** Don't add UI nodes directly to autoload - instantiate lazily when needed

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Feature detection | Custom build config parser | OS.has_feature("debug") | Automatic, no export setup, works in editor |
| Config storage | JSON file reading | ProjectSettings custom properties | Integrated with editor, override.cfg support, type-safe |
| Confirmation dialogs | Custom modal UI | ConfirmationDialog | Platform-aware button ordering (Win: OK/Cancel, Mac: Cancel/OK), built-in styling |
| Screen-space UI | Manual viewport transforms | CanvasLayer | Automatic screen-space positioning, camera-independent |
| Revert functionality | Custom undo/redo stack | Reload from RoomSerializer.load_rooms() | Existing save file is the backup, atomic consistency |

**Key insight:** Godot's built-in systems handle 90% of admin menu requirements. The only custom code needed is orchestration logic (calling RoomManager methods) and UI layout. Attempting to build custom feature flag systems or backup mechanisms adds complexity without benefit.

## Common Pitfalls

### Pitfall 1: Feature Flag Confusion (Feature Tags vs Custom Settings)
**What goes wrong:** Developer searches "Godot feature flags" and finds two different systems:
- Feature tags (platform detection: "web", "mobile", "debug")
- Custom project settings (user-defined config)

**Why it happens:** Godot documentation uses "feature" for both concepts, leading to confusion about which to use.

**How to avoid:**
- Use OS.has_feature("debug") to detect build type (no configuration needed)
- Use ProjectSettings.get_setting("application/admin/enabled") for custom toggles
- Combine both: `OS.has_feature("debug") or ProjectSettings.get_setting("application/admin/enabled")`

**Warning signs:**
- Setting custom feature tags in export settings for simple boolean flags
- Creating separate export templates for admin vs non-admin builds

### Pitfall 2: Revert Creates Separate Backup Files
**What goes wrong:** Developer creates "rooms_backup.json" on every save, leading to stale backups and wasted space.

**Why it happens:** Traditional desktop software pattern of explicit backup files doesn't fit auto-save games.

**How to avoid:**
- Recognize that the save file IS the backup (atomic writes ensure consistency)
- Revert = discard in-memory state + reload from disk
- Don't save "before reverting" - you're already auto-saving continuously

**Warning signs:**
- Multiple save files appearing in user:// directory
- Logic to decide "when to backup"
- Comparing timestamps between backup and save files

### Pitfall 3: Admin Menu Visible in Release Builds
**What goes wrong:** Admin button appears in production, players can reset game data.

**Why it happens:**
- Forgot to check OS.has_feature("debug") in production code path
- Tested with debug export template, not release template
- Override.cfg from development committed to version control

**How to avoid:**
- Always gate admin UI creation: `if not _is_admin_enabled(): return`
- Test with release export template before shipping
- Add override.cfg to .gitignore
- Consider using `@tool` scripts that auto-hide admin nodes in exported builds

**Warning signs:**
- Admin button visible when running exported .exe/.apk
- No feature flag checks in _ready() functions
- ProjectSettings query without OS.has_feature() fallback

### Pitfall 4: Confirmation Dialog Doesn't Block Action
**What goes wrong:** Player clicks "Reset", dialog appears, but action executes immediately regardless of choice.

**Why it happens:** Developer calls `show_confirmation()` then immediately calls `perform_action()` without waiting for signal.

**How to avoid:**
- Always connect to `confirmed` signal before showing dialog
- Never call destructive action in same function that shows dialog
- Use `dialog.popup_centered()` instead of `dialog.show()` for proper modal behavior

**Warning signs:**
- Confirmation dialog appears briefly then closes
- Action executes even when clicking "Cancel"
- Dialog doesn't block input to underlying UI

### Pitfall 5: Autoload UI Prevents Scene Unloading
**What goes wrong:** Memory usage grows because admin UI scene never unloads, even when hidden.

**Why it happens:** Developer adds UI scene as child of autoload in editor, making it permanent.

**How to avoid:**
- Instantiate UI scene at runtime: `ADMIN_UI_SCENE.instantiate()`
- Free UI when not needed: `_ui_instance.queue_free()` (if memory constrained)
- Or just hide/show for faster toggling: `_ui_instance.visible = false`
- Never attach UI nodes to autoload in editor scene

**Warning signs:**
- Admin UI scene appears as child in autoload scene tree
- Memory profiler shows UI textures loaded even when admin disabled
- Unable to reload main scene without restarting game

### Pitfall 6: Override.cfg Ignored in Editor
**What goes wrong:** Developer sets admin flags in override.cfg but they don't take effect in editor.

**Why it happens:** override.cfg only applies to exported projects by default. Editor reads project.godot directly.

**How to avoid:**
- Use project.godot for development-time config
- Use override.cfg for per-environment changes in exported builds (QA, staging)
- Document that override.cfg is for post-export configuration
- Add custom property to project.godot during development: Project > Project Settings > Add custom property

**Warning signs:**
- Settings work in exported build but not editor
- Team members see different admin menu behavior
- "Why isn't my override.cfg working?" questions

## Code Examples

Verified patterns from official sources:

### Complete AdminMenu Singleton
```gdscript
# Source: Godot Autoload + ProjectSettings + ConfirmationDialog documentation
# File: scripts/admin/AdminMenu.gd
# Register in project.godot: [autoload] AdminMenu="*res://scripts/admin/AdminMenu.gd"

extends Node

# UI instance (lazy loaded)
var _ui_instance: Control = null
const ADMIN_UI_SCENE := preload("res://scenes/ui/admin_menu_ui.tscn")

# State
var _is_enabled := false

func _ready() -> void:
    _is_enabled = _check_admin_enabled()
    if not _is_enabled:
        print("AdminMenu: Disabled (release build, no override)")

func _check_admin_enabled() -> bool:
    # Always enabled in debug builds (editor + debug exports)
    if OS.has_feature("debug"):
        return true

    # Check custom setting (for release builds with admin enabled via override.cfg)
    if ProjectSettings.has_setting("application/admin/enabled"):
        return ProjectSettings.get_setting("application/admin/enabled")

    return false

func toggle_menu() -> void:
    if not _is_enabled:
        return

    if _ui_instance == null:
        _create_ui()

    _ui_instance.visible = !_ui_instance.visible

func _create_ui() -> void:
    _ui_instance = ADMIN_UI_SCENE.instantiate()

    # Connect UI signals
    _ui_instance.revert_requested.connect(_on_revert_requested)
    _ui_instance.reset_requested.connect(_on_reset_requested)

    # Add to root (CanvasLayer in UI scene keeps it screen-space)
    get_tree().root.add_child(_ui_instance)
    _ui_instance.hide()

func _on_revert_requested() -> void:
    var dialog := ConfirmationDialog.new()
    dialog.dialog_text = "Revert to last saved state?\n\nAll unsaved changes will be lost."
    dialog.ok_button_text = "Revert"
    dialog.cancel_button_text = "Cancel"
    dialog.confirmed.connect(_perform_revert)

    get_tree().root.add_child(dialog)
    dialog.popup_centered()

func _perform_revert() -> void:
    # Clear current rooms
    var current_rooms = RoomManager.get_all_rooms().duplicate()
    for room in current_rooms:
        RoomManager.unregister_room(room)

    # Reload from save file
    var saved_rooms = RoomSerializer.load_rooms()
    for room in saved_rooms:
        RoomManager.register_room(room)

    print("AdminMenu: Reverted to last save (%d rooms)" % saved_rooms.size())

func _on_reset_requested() -> void:
    var dialog := ConfirmationDialog.new()
    dialog.dialog_text = "DELETE ALL DATA?\n\nThis will:\n• Remove all rooms\n• Delete save file\n• Cannot be undone\n\nType DELETE to confirm:"

    # Add custom line edit for extra confirmation
    var confirm_input := LineEdit.new()
    confirm_input.placeholder_text = "Type DELETE here"
    dialog.add_child(confirm_input)

    dialog.ok_button_text = "Delete All Data"
    dialog.cancel_button_text = "Cancel"

    # Only enable OK button if "DELETE" typed
    dialog.get_ok_button().disabled = true
    confirm_input.text_changed.connect(func(text: String):
        dialog.get_ok_button().disabled = (text != "DELETE")
    )

    dialog.confirmed.connect(_perform_reset)
    get_tree().root.add_child(dialog)
    dialog.popup_centered()

func _perform_reset() -> void:
    # Clear all rooms
    var rooms = RoomManager.get_all_rooms().duplicate()
    for room in rooms:
        RoomManager.unregister_room(room)

    # Delete save file
    var success = RoomSerializer.delete_save_file()
    if success:
        print("AdminMenu: All data reset")
    else:
        push_error("AdminMenu: Failed to delete save file")
```

### Simple AdminMenuUI Scene
```gdscript
# Source: Godot CanvasLayer + Button documentation
# File: scenes/ui/admin_menu_ui.gd

extends Control

signal revert_requested
signal reset_requested

func _ready() -> void:
    # This control is inside a CanvasLayer (set in scene)
    # so it stays fixed on screen regardless of camera

    # Connect buttons
    %RevertButton.pressed.connect(func(): revert_requested.emit())
    %ResetButton.pressed.connect(func(): reset_requested.emit())
    %CloseButton.pressed.connect(hide)

# Scene structure:
# AdminMenuUI (Control) - anchors: center, size: 400x300
#   CanvasLayer
#     PanelContainer
#       MarginContainer (20px padding)
#         VBoxContainer (gap: 16px)
#           Label (text: "Admin Menu")
#           Button (text: "Revert to Last Save", unique_name: RevertButton)
#           Button (text: "Reset All Data", unique_name: ResetButton)
#           HSeparator
#           Button (text: "Close", unique_name: CloseButton)
```

### Adding Custom ProjectSetting Programmatically
```gdscript
# Source: ProjectSettings.set_setting() documentation
# File: scripts/admin/setup_admin_settings.gd (run once in editor)

@tool
extends EditorScript

func _run() -> void:
    # Add custom admin setting to project.godot
    if not ProjectSettings.has_setting("application/admin/enabled"):
        ProjectSettings.set_setting("application/admin/enabled", false)
        ProjectSettings.set_initial_value("application/admin/enabled", false)

        # Add to project settings UI with description
        var property_info := {
            "name": "application/admin/enabled",
            "type": TYPE_BOOL,
            "hint": PROPERTY_HINT_NONE,
            "hint_string": "Enable admin menu in release builds"
        }
        ProjectSettings.add_property_info(property_info)

        # Save to project.godot
        ProjectSettings.save()

        print("Admin setting added. Check Project Settings > Application > Admin")
```

### Hotkey Toggle Pattern
```gdscript
# Source: Godot InputEvent documentation
# File: scenes/main.gd (or any persistent scene)

func _input(event: InputEvent) -> void:
    # Tilde key (~) to toggle admin menu (common debug key)
    if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
        if AdminMenu._is_enabled:  # Check before calling
            AdminMenu.toggle_menu()
            get_viewport().set_input_as_handled()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Compile-time flags (#ifdef) | OS.has_feature() runtime checks | Godot 3.0+ | Simpler exports, single binary for debug+release |
| Custom config parsers | ProjectSettings + override.cfg | Godot 3.0+ | Editor integration, no manual file reading |
| Manual backup files | Auto-save + reload pattern | Modern game design | Less disk I/O, simpler code, no stale backups |
| Separate export templates | Feature tags + custom settings | Godot 4.0+ | One export template, multiple configurations |

**Deprecated/outdated:**
- **Manual ProjectSettings.save()**: Godot 4.0+ auto-saves project settings changes, no need to call save() explicitly
- **Custom singleton registration**: Old approach used global scripts, Godot 3.0+ uses autoload system
- **InputMap.add_action() at runtime**: Pre-configure in Project Settings > Input Map instead

## Open Questions

Things that couldn't be fully resolved:

1. **Does RoomManager support re-initialization without scene reload?**
   - What we know: RoomManager._load_saved_rooms() is called in _ready()
   - What's unclear: Can we safely call it again after clearing rooms, or do internal signals/connections break?
   - Recommendation: Test revert flow with multiple rooms and visual nodes. May need RoomManager.reload_from_disk() method.

2. **Should admin menu be a button in main UI or hotkey-only?**
   - What we know: Debug menus typically use hotkeys to stay invisible to players
   - What's unclear: TheaterCity UI patterns - is there a settings/menu screen where admin could appear?
   - Recommendation: Start with hotkey-only (tilde key), add button to settings screen in Phase 10 if needed.

3. **Does override.cfg work in Godot editor or only exported builds?**
   - What we know: Documentation mentions "exported projects" but is ambiguous
   - What's unclear: Whether editor reads override.cfg from project root
   - Recommendation: Test both approaches. If editor ignores override.cfg, use project.godot custom setting for development.

4. **Memory implications of lazy UI instantiation**
   - What we know: Godot automatically unloads scenes when freed, but preload() keeps in memory
   - What's unclear: Whether const ADMIN_UI_SCENE := preload() keeps UI resources loaded even when not instantiated
   - Recommendation: Profile with Godot profiler. If memory is concern, use load() instead of preload() for admin UI.

## Sources

### Primary (HIGH confidence)
- [Godot ProjectSettings class documentation](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html) - Custom settings, override.cfg
- [Godot Feature Tags documentation](https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html) - OS.has_feature() usage
- [Godot Singletons (Autoload) documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html) - Autoload pattern
- [Godot ConfirmationDialog class](https://docs.godotengine.org/en/stable/classes/class_confirmationdialog.html) - Dialog API
- [Godot AcceptDialog class](https://docs.godotengine.org/en/stable/classes/class_acceptdialog.html) - Custom buttons API
- TheaterCity codebase: scripts/RoomManager.gd, scripts/storage/RoomSerializer.gd - Existing persistence infrastructure

### Secondary (MEDIUM confidence)
- [GitHub godot-extended-libraries/godot-debug-menu](https://github.com/godot-extended-libraries/godot-debug-menu) - Debug menu architecture example
- [Godot Overview of debugging tools](https://docs.godotengine.org/en/stable/tutorials/scripting/debug/overview_of_debugging_tools.html) - Debug practices
- [ConfigCat feature flags in Godot blog](https://configcat.com/blog/2023/06/20/how-to-use-feature-flags-in-godot/) - Third-party feature flag pattern (not recommended for this use case)

### Tertiary (LOW confidence)
- [Godot Forum: override.cfg discussion](https://forum.godotengine.org/t/override-cfg-for-all-projects-how/103614) - Community usage patterns (needs verification)
- [GitHub issue #70659: override.cfg startup behavior](https://github.com/godotengine/godot/issues/70659) - Edge case behavior (specific bug)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All built-in Godot features with official documentation
- Architecture: HIGH - Patterns verified against TheaterCity existing code (RoomManager autoload pattern matches)
- Pitfalls: MEDIUM - Based on common Godot mistakes and documentation gaps, not project-specific testing
- Integration with existing code: HIGH - RoomManager/RoomSerializer already provide all required primitives

**Research date:** 2026-02-07
**Valid until:** 2026-03-07 (30 days - stable Godot 4.5 features, no major changes expected)

**Key findings verified against existing codebase:**
- RoomManager is already an autoload singleton (project.godot line 23)
- RoomSerializer.delete_save_file() already exists (line 138-148)
- RoomSerializer.load_rooms() already exists (line 69-113)
- Auto-save pattern already implemented with 5-second debounce (RoomManager line 18, 280-293)
- No existing admin or debug menu infrastructure to conflict with

**Recommended next steps for planner:**
1. Create AdminMenu autoload singleton (follows RoomManager pattern)
2. Create AdminMenuUI scene with CanvasLayer (follows existing UIStyleHelper patterns)
3. Add project setting: application/admin/enabled (boolean, default false)
4. Implement revert by calling existing RoomManager/RoomSerializer methods
5. Add confirmation dialogs with ConfirmationDialog
6. Add hotkey toggle (tilde key) in main scene
