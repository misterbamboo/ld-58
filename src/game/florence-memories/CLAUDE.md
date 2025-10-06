# Project Context

## Tech Stack
- **Engine**: Godot Engine 4
- **Language**: GDScript (.gd files)

## Coding Standards
- **Style**: Clean Code principles
  - Small, focused methods (single responsibility)
  - One thing per method
  - Command-Query Separation (CQS)
  - SOLID principles
- **Encapsulation**: Never access internal variables of another class directly
  - Always call public methods to get values (e.g., `get_current_time()` instead of `internal_time`)
  - Prevents coupling to internal implementation details
  - Applies to parent classes, child classes, and any class references
- **Priority**: Functionality over perfection (48h game jam timeline)

## Development Guidelines
- **IMPORTANT**: When implementing new features, always update the "Key Features" section below
- Prefer editing existing files over creating new ones
- Follow the established project structure

## Project Structure
- `autoload/` - Global singletons (autoload scripts)
  - `message_bus.gd` - Global pub/sub system for decoupled communication
- `clouds/` - Cloud assets, scripts, and prefabs
  - `cloud.gd` - Individual cloud with simple time-based movement and position lerping
  - `cloud_alpha.gd` - Sprite2D component handling fade in/out based on parent cloud's time
  - `cloud_squish.gd` - Node2D component handling squish animation and rotation
  - `cloud_spawner.gd` - Unified spawner for both individual clouds and cloud shapes
  - `cloud_shape.gd` - Timer coordinator and position guide for child clouds (forms shapes)
  - `cloud_highlight.gd` - Interactive Line2D for shape hover/click detection with time window
  - `prefabs/` - Reusable cloud scene variants (default, oval, vertical)
  - `shapes/` - Cloud shape compositions (e.g., dog-cloud)

## Key Features

This section documents the major systems that make up "Florence Memories," a meditative cloud-watching game where players collect childhood memories by clicking on cloud formations.

### Game Flow Overview

The complete game cycle follows this progression:

1. **Main Menu** - Player sees title screen with Play and Exit buttons
2. **Tutorial Screen** - Brief instructions explain the gameplay (click to dismiss)
3. **Game Start Event** - `GAME_START` published, enabling CloudShape spawning
4. **Gameplay Loop** - Player watches clouds drift by and clicks on shapes during their highlight window
5. **Memory Collection** - Each clicked shape fades out, spawns a flying sprite, and fills a slot in the memory book
6. **Completion Trigger** - After collecting all 12 memories, `ALL_MEMORIES_COLLECTED` event fires
7. **Ending Animation** - Special "Florence" cloud formation fades in sequentially (clickable when complete)
8. **Credits Screen** - Shows game credits and team information
9. **Reset & Replay** - Clicking anywhere returns to main menu and resets all game state via `GAME_RESET`

### Main Menu & Tutorial System

**File:** `menus/main_menu.gd`

- **Main Menu Screen**:
  - Displays title background with Play and Exit buttons
  - Buttons positioned dynamically relative to background using percentage-based offsets
  - Exit button closes browser tab (web) or quits application (desktop)
  - Responsive to viewport resizing via `_on_viewport_resized()`

- **Tutorial Sequence** (triggered by Play button):
  1. Disable and fade out buttons (1.5s duration)
  2. Cross-fade from menu background to tutorial background (1.5s)
  3. Wait for player to click anywhere (`waiting_for_click = true`)
  4. Fade out tutorial background (1.5s)
  5. Publish `GAME_START` event to enable CloudShape spawning
  6. Hide main menu overlay

- **Credits Screen** (triggered by `GAME_COMPLETED` event):
  - Instantly hides menu and tutorial backgrounds
  - Fades in credits background over 1.5s
  - Waits for player click to dismiss
  - Fades out credits, fades in menu background, re-enables buttons
  - Publishes `GAME_RESET` event to restart the game

- **State Management**:
  - `waiting_for_click`: Boolean flag for tutorial/credits click detection
  - `showing_credits`: Distinguishes between tutorial and credits click handling
  - All transitions use consistent 1.5s fade duration with EASE_IN_OUT/TRANS_SINE

### Cloud Spawning System

**File:** `clouds/cloud_spawner.gd`

- **Dual Spawning Strategy**:
  - **Individual Clouds**: Spawn every 2s (2-3 clouds per interval) for atmospheric background
  - **CloudShapes** (memories): Spawn every 20s, but only after `GAME_START` event
  - Debug mode: Ctrl+A toggles fast spawn (1s intervals for shapes)

- **Dynamic Boundaries**:
  - **CloudShapes**: 10% padding on left/top/right, 25% padding on bottom
  - **Individual Clouds**: Full screen width, can spawn 5% outside right edge for smooth entry
  - Viewport resize detection updates boundaries every frame
  - Existing clouds continue their paths (may drift off-screen if viewport shrinks)

- **Collision Avoidance** (CloudShapes only):
  - `OccupiedRegion` tracks active shape positions with 150px radius
  - `find_non_overlapping_position()` attempts 10 placement tries before fallback
  - Regions released when shape vanishes or is captured

- **Shape Pool Management**:
  - Starts with all 12 shape scenes in `available_shape_scenes` array
  - When shape is captured, it's removed from the pool via `_on_shape_captured()`
  - Prevents duplicate memories from spawning
  - Pool is restored on `GAME_RESET`

- **Initialization**:
  - Individual clouds: `initialize(meet_at_pos, -1, 30s, 0s, 0s, speed_multiplier)`
    - `meet_in_time = 0` means they spawn at their target position
    - Speed inversely proportional to scale (bigger = slower, 1.0 / random_scale)
    - Random scale between 1.0x and 2.5x
  - CloudShapes: `initialize(meet_at_pos, -1, 30s, 15s)`
    - `meet_in_time = lifespan/2` means child clouds converge at midpoint
    - Always move left (direction = -1)

- **Event Subscriptions**:
  - `SHAPE_VANISHED`: Releases occupied region
  - `SHAPE_FULLY_FADED`: Removes captured shape from available pool
  - `GAME_RESET`: Clears all clouds, restores shape pool, disables shape spawning
  - `GAME_START`: Enables CloudShape spawning

### Individual Cloud System

**File:** `clouds/cloud.gd`

- **Time-Based Movement**:
  - Lifespan: 30s (fixed by spawner)
  - Speed: 10-25 px/s base range, modified by scale-based speed multiplier
  - Direction: Always left (-1) in current implementation
  - Position: `lerp(start_pos, end_pos, internal_time / lifespan)`
  - Start/end positions calculated from speed, direction, meet_in_time, and meet_at_pos

- **Depth Perception System**:
  - `calculate_cloud_size()`: Averages sprite texture width and height
  - Large clouds (avg > 600px): z_index = -3 (background layer)
  - Small clouds (avg <= 600px): z_index = -2 (foreground layer)
  - Creates subtle parallax effect when combined with speed variation

- **Dual Mode Operation**:
  - **Individual Mode** (`is_managed_by_shape = false`):
    - Updates own `internal_time` in `_process(delta)`
    - Calculates own world position via lerp
    - Publishes `CLOUD_VANISHED` and calls `queue_free()` when faded out
  - **Managed Mode** (`is_managed_by_shape = true`):
    - Reads `parent_shape.get_internal_time()` for synchronized timing
    - Uses `initial_offset_pos` for local positioning within shape
    - Sets `visible = false` when lifespan ends (parent handles destruction)

- **Fade Control**:
  - `force_fade_in`: Triggered when `internal_time > 0` (after spawn delay)
  - `force_fadeout`: Triggered by parent CloudShape's `trigger_fadeout()`
  - `is_faded_out()`: Checks CloudAlpha child's modulate.a <= 0.01

- **Component Coordination**:
  - CloudAlpha child reads `get_current_time()` for fade timing
  - CloudSquish child respects `should_override_rotation()` for shape formations

### Cloud Shape System (Memory Collectibles)

**File:** `clouds/cloud_shape.gd`

- **Architecture**:
  - Container for multiple Cloud children arranged in recognizable shapes (dog, bear, flower, etc.)
  - Acts as timer coordinator and position guide for child clouds
  - Child clouds marked as "managed" via `set_managed_by_shape(true)`

- **Lifecycle Timeline**:
  - Lifespan: 30s (set by spawner)
  - `internal_time` progresses from 0 to 30s
  - Meeting point at `lifespan / 2 = 15s` (all child clouds converge to shape)
  - Highlight window: 12.5s to 17.5s (2.5s before/after meeting point)

- **Movement & Positioning**:
  - Parent drifts horizontally: `position = lerp(start, end, internal_time / lifespan)`
  - Start/end calculated from drift_speed (8 px/s) and meeting position
  - Child clouds use parent's position + their `initial_offset_pos` for formation

- **Child Cloud Initialization**:
  - Each child gets randomized lifespan: 1.25x min_lifespan to 1.25x parent lifespan
  - Random spawn delay: 0s to child_lifespan/3 (staggered appearance)
  - All children converge at `meet_in_time = lifespan / 2`

- **Interactive Capture**:
  - CloudHighlight child detects mouse hover during highlight window
  - On click during window, publishes `HIGHLIGHT_CLICKED` with shape reference
  - MemoryCollector calls `shape.capture_memory()`:
    1. Stores cloud_image texture and global_position
    2. Publishes `SHAPE_FULLY_FADED` immediately (triggers memory animation)
    3. Calls `start_fadeout()` to fade out all child clouds
    4. Publishes `SHAPE_VANISHED` for spawner cleanup

- **Fadeout Coordination**:
  - `start_fadeout()` calls `cloud.trigger_fadeout()` on all children
  - Waits for `all_clouds_faded()` before destroying shape
  - Managed children set `visible = false`, parent calls `queue_free()`

- **12 Memory Shapes**:
  - Bear, Butterfly, Car, Dino, Dog, Horseshoe (fer), Flower, Rainbow, Rocher Percé, Star, Strawberry, Lucky Clover (trefle)
  - Each shape has unique cloud_image texture exported in scene
  - Scenes located in `clouds/cloud-shapes/*.tscn`

### Memory Collection System

**File:** `memories-book/memory_collector.gd`

- **Memory Book UI**:
  - 12 slots arranged in 2 pages (6 per page) in a book-style TextureRect
  - Initially empty, fills left-to-right, top-to-bottom as memories are collected
  - Can toggle between small (100px) and large (600px) view via click
  - Large view shows tooltips on hover with memory titles and descriptions

- **Collection Flow**:
  1. Player clicks CloudShape during highlight window
  2. `HIGHLIGHT_CLICKED` event received, calls `shape.capture_memory()`
  3. Shape publishes `SHAPE_FULLY_FADED` with texture and position
  4. MemoryCollector waits 1s after fadeout
  5. `spawn_and_animate_memory()` creates flying Sprite2D at shape's position
  6. Sprite flies in parabolic arc to next available memory slot (1.5s duration)
  7. On arrival, `fill_memory_slot()` places texture in book and increments `next_slot_index`
  8. If `next_slot_index >= 12`, publishes `ALL_MEMORIES_COLLECTED`

- **Duplicate Prevention**:
  - `collected_texture_paths` dictionary tracks all collected textures by resource_path
  - `is_memory_already_collected()` checks before spawning animation
  - Race condition protection: Double-check on animation completion

- **Flying Sprite Animation**:
  - Initial scale: Fit within 150px max dimension
  - Arc peak: Min of start/end Y positions minus 100px
  - Two-phase tween: start -> peak (0.75s), peak -> target (0.75s)
  - Parallel scale tween: shrinks to 30% of initial scale
  - Sprite deleted after filling slot

- **Memory Data System** (`memory_tooltip.gd`):
  - 12 MemoryData entries with title and description
  - Descriptions are nostalgic, first-person childhood memories
  - Example: "A teddy bear cloud that reminds me of my favorite teddy — the one I took everywhere..."
  - `get_memory_data_for_texture()` matches texture path keywords to configs

- **Tooltip Display**:
  - Only visible in large book mode
  - Custom VBoxContainer with Panel, title Label, description Label
  - Positioned left or right of mouse based on which page (0-5 = right, 6-11 = left)
  - Auto-wraps text with 250px width constraint

- **Game Reset Handling**:
  - Clears `next_slot_index`, `collected_texture_paths`, memory arrays
  - Removes textures from all UI slots
  - Ready for new playthrough

### Ending Cloud Animation System

**Files:** `ending-cloud/ending-cloud-control.gd`, `ending-cloud/ending-cloud.gd`

- **Trigger**: Subscribes to `ALL_MEMORIES_COLLECTED` event

- **EndingCloudControl (Parent Node)**:
  - Manages global timer for sequential cloud fade-in
  - Counts child Sprite2D nodes (represents Florence's face made of clouds)
  - Total fade time: `cloud_count * 0.1s` (each cloud fades in over 0.1s, staggered)
  - Waits until `timer >= total_fade_time`, then sets `all_faded_in = true`

- **Centering System**:
  - Calculates virtual bounds of all child cloud positions
  - Computes virtual center of formation
  - Smoothly lerps parent position to center formation on screen (LERP_SPEED = 2.0)
  - Updates every frame for responsive window resizing

- **Click Detection**:
  - When `all_faded_in && !is_fading_out`, listens for left mouse clicks
  - `is_point_in_virtual_bounds()` checks if click is within formation bounds
  - On valid click, calls `fade_out_all_clouds()`

- **EndingCloud (Individual Cloud Sprite)**:
  - Static coordination: All instances register in shared `clouds` array
  - Each cloud gets sequential `cloud_index` based on scene tree order
  - Fade-in start time: `cloud_index * 0.1s` (creates wave effect)
  - After fade-in, applies gentle sin-wave animation (scale and rotation)
  - Randomized animation parameters for organic movement

- **Fade Out & Completion**:
  - `start_fade_out()` called on all clouds simultaneously
  - All fade out over 1.0s duration
  - After fadeout completes, publishes `GAME_COMPLETED` event
  - Stops timer and waits for next `ALL_MEMORIES_COLLECTED` to restart

- **Reset Support**:
  - `reset_state()` clears timer, flags, and calls `init()` on all child clouds
  - Ready for replay without reloading scene

### Memory Book Toggle System

**File:** `memories-book/toggle-size-book.gd`

- **Two Size Modes**:
  - Small: 100px book in bottom-right corner (default, always visible)
  - Big: 600px book centered on screen (for viewing collected memories)

- **Toggle Trigger**:
  - Small mode: Click anywhere on book (ClickZone covers entire book)
  - Big mode: Click anywhere outside book bounds to close

- **Animation** (0.3s duration, EASE_IN_OUT/TRANS_SINE):
  - TextureRect offset animates to expand/contract from bottom-right anchor
  - ClickZone offsets mirror TextureRect for accurate hit detection
  - HBoxContainer (memory container) scales and repositions within book
  - GridContainer children (individual slots) resize custom_minimum_size
  - Grid separation adjusts for proper spacing at each scale

- **Layout Constants**:
  - Small: 100px book, 12px slots, 5/4px grid separation, 16/26px container offset
  - Big: 600px book, 72px slots, 23/22px grid separation, 96/156px container offset

- **Mouse Filter Management**:
  - Small mode: ClickZone uses MOUSE_FILTER_PASS (captures all clicks)
  - Big mode: ClickZone uses MOUSE_FILTER_IGNORE (allows hover on memory slots)
  - All parent containers (HBox, GridContainers) use MOUSE_FILTER_PASS for event propagation

### Game Reset & Replay Flow

**Event:** `GAME_RESET` (published when player clicks during credits)

All major systems subscribe to this event and reset their state:

1. **CloudSpawner**:
   - Calls `queue_free()` on all active clouds and shapes
   - Restores `available_shape_scenes` to full 12-shape pool
   - Clears `occupied_regions` collision tracking
   - Clears `pending_clouds` and `pending_shapes` queues
   - Resets timers to spawn immediately
   - Sets `game_started = false` (waits for next GAME_START)

2. **MemoryCollector**:
   - Resets `next_slot_index = 0`
   - Clears `collected_texture_paths` dictionary
   - Clears and resizes `memory_slots` and `memory_data_list` arrays
   - Removes textures from all 12 UI slots (sets `texture = null`)

3. **EndingCloudControl**:
   - Implicitly handled by `_on_all_memories_collected()` which calls `reset_state()`
   - Resets timer, flags, and reinitializes all child clouds to invisible state

After reset completes, the game returns to the main menu, and the player can press Play to start a fresh playthrough.

### Component Self-Management Pattern

- **CloudAlpha** (Sprite2D component):
  - Reads `cloud.get_current_time()`, `cloud.get_lifespan()` for fade timing
  - Normal fade: First 3s fade in, last 3s fade out
  - Force fade in: When `cloud.is_force_fade_in()` is true
  - Force fadeout: When `cloud.is_force_fadeout()` is true (for captured shapes)

- **CloudSquish** (Node2D component):
  - Independent squish animation (sin wave on scale/rotation)
  - Respects `cloud.should_override_rotation()` for formations

- **CloudHighlight** (Line2D component):
  - Precomputes line bounds on `_ready()` for efficient mouse detection
  - Visible only when: mouse over AND in time window AND not captured
  - Publishes `HIGHLIGHT_CLICKED` on valid click
  - Sets `is_captured = true` to prevent duplicate clicks

### MessageBus System

**File:** `autoload/message_bus.gd`

Global autoload singleton providing decoupled event communication across all systems.

- **API**:
  - `publish(topic: String, data: Dictionary)` - Emit event with payload
  - `subscribe(topic: String, callback: Callable)` - Register listener
  - `unsubscribe(topic: String, callback: Callable)` - Remove listener

- **Implementation**:
  - Topic-based pub/sub pattern (replaces direct signals)
  - Callbacks stored in `_subscribers` dictionary (topic -> Array[Callable])
  - All publishes print to console for debugging

- **All Events** (from `clouds/cloud_events.gd`):
  - `CLOUD_VANISHED`: Individual cloud finished lifespan and faded out
  - `HIGHLIGHT_CLICKED`: Player clicked on CloudShape during highlight window
  - `SHAPE_VANISHED`: CloudShape finished lifespan or was captured (triggers spawner cleanup)
  - `SHAPE_FULLY_FADED`: CloudShape was captured (triggers memory animation with texture + position)
  - `SHAPE_SPAWNED`: New CloudShape instantiated by spawner
  - `ALL_MEMORIES_COLLECTED`: Player collected all 12 memories (triggers ending animation)
  - `GAME_COMPLETED`: Ending animation finished (triggers credits screen)
  - `GAME_RESET`: Player clicked during credits (resets all game state)
  - `GAME_START`: Tutorial dismissed, enables CloudShape spawning

- **Event Flow Examples**:
  - Shape Capture: `HIGHLIGHT_CLICKED` -> `capture_memory()` -> `SHAPE_FULLY_FADED` + `SHAPE_VANISHED`
  - Memory Collection: `SHAPE_FULLY_FADED` -> memory animation -> slot fill -> `ALL_MEMORIES_COLLECTED`
  - Game Completion: `ALL_MEMORIES_COLLECTED` -> ending animation -> `GAME_COMPLETED` -> credits
  - Replay: Credits click -> `GAME_RESET` -> main menu -> Play -> `GAME_START` -> gameplay