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

### Unified Cloud Spawner System
- Single spawner handles both individual clouds and cloud shapes
- **Initial Spawn**: 1 shape + 9 individual clouds on scene start
- **Continuous Spawning**: Timer-based (2-6s intervals)
  - Default: spawns individual clouds
  - Shape replacement: When shape vanishes, flag is set to spawn shape on next interval
- **Spawn Behavior**: Target positions on left side, clouds fade in from right
  - **Target position** (`meet_at_pos`): Random x (0 to screen_width/2), random y (spawn_y_min to spawn_y_max)
  - **Direction**: All clouds move LEFT (direction = -1)
  - Clouds start off-screen right and fade in while traveling toward left target
- **Collision Avoidance** (CloudShapes only):
  - `OccupiedRegion` class tracks active shape positions with radius (150px)
  - `find_non_overlapping_position()` attempts 10 tries to find non-overlapping spawn
  - Regions released when shape vanishes
  - Individual clouds can overlap (no tracking)
- **Unified Initialization**: `initialize(meet_at_pos, direction, lifespan, meet_in_time)`
  - Same signature for Cloud and CloudShape
  - Individual clouds: `meet_in_time = 0` (spawn at meeting point)
  - Cloud shapes: `meet_in_time = lifespan/2` (converge at middle of lifetime)
  - First shape: Special `set_first_shape_time()` called to set `internal_time = -lifespan/4` (pre-progressed for immediate visibility)

### Individual Cloud System (Time-Based Movement)
- **No phase enum** - components self-manage based on cloud's timer
- **Lifespan: 30-90s**, **Speed: 2.0-3.0 px/s** (randomized per cloud in `initialize()`)
- **Size-Based Depth Perception System**:
  - `calculate_cloud_size()`: Calculates average of sprite width and height
  - **Large clouds (avg dimension > 600px)**:
    - Background layer (z_index = -1)
    - Slower speed (0.5x multiplier) - appear farther away
  - **Small clouds (avg dimension ≤ 600px)**:
    - Foreground layer (z_index = 1)
    - Faster speed (1.5x multiplier) - appear closer
  - Creates realistic depth perception with parallax effect
- **Movement System**:
  - Calculates `start_position` and `end_position` based on speed, direction, and meeting time
  - `position = lerp(start_position, end_position, (current_time - start_time) / lifespan)`
  - Smooth continuous movement across screen
- **Component-Based Architecture**:
  - `CloudAlpha`: Fades in (first 3s), stays visible, fades out (last 3s)
  - `CloudSquish`: Handles subtle squish animation and rotation
  - Components call `cloud.get_current_time()` for coordination
- **Dual Behavior**:
  - **Individual mode** (`is_managed_by_shape = false`):
    - Updates own `internal_time` in `_process(delta)`
    - Uses own position calculated via lerp
    - Publishes `cloud_vanished` event and calls `queue_free()` when lifespan ends
  - **Managed mode** (`is_managed_by_shape = true`):
    - Uses parent CloudShape's `internal_time` via `get_current_time()`
    - Position set to `parent_shape.position` (parent already calculated meeting point)
    - Sets `visible = false` when lifespan ends (parent handles destruction)

### Cloud Shape System (Timer Coordinator + Position Guide)
- **Simple Architecture**: CloudShape = timer provider + position guide (no phase management)
- **Lifespan: 30-90s**, **Drift Speed: 4.0 px/s**
- **Timeline**:
  - Starts at `internal_time = -lifespan/2`
  - **First shape exception**: `set_first_shape_time()` sets `internal_time = -lifespan/4` (pre-progressed)
  - **Time 0 = Meeting Point**: All child clouds converge to their local positions
  - **Highlight window: -2.5s to +2.5s** around time 0
  - Ends at `internal_time = lifespan/2`
- **Movement**:
  - CloudShape drifts across screen: `position = lerp(start_position, end_position, lifetime_progress)`
  - Child clouds positioned at `parent_shape.position` (in managed mode)
  - Creates organic moving formation
- **Child Cloud Coordination**:
  - Each child has `initial_position` (local offset in shape scene)
  - Child initialized with: `cloud.initialize(cloud.get_initial_position(), direction, child_lifespan, meet_in_time)`
  - Randomized child lifespans (0.7 × min_lifespan to 1.0 × shape lifespan) for staggered fading
  - Children marked as managed: `cloud.set_managed_by_shape(true)`
- **Event System**:
  - `shape_spawned` published when shape appears
  - `shape_vanished` published when `internal_time >= lifespan/2`
  - Spawner subscribes to `shape_vanished` to flag next spawn as shape
- **Interactive Highlight**: Line2D outline on hover during highlight window (-2.5s to +2.5s)

### Component Self-Management Pattern
- **CloudAlpha** (Sprite2D component):
  - Reads `cloud.get_current_time()`, `cloud.get_start_time()`, `cloud.get_lifespan()` for fade timing
  - Calculates `time_elapsed = current_time - start_time`
  - Fade in: First 3s, Fade out: Last 3s
- **CloudSquish** (Node2D component):
  - Independent squish animation (sin wave on scale/rotation)
  - Respects `cloud.should_override_rotation()` → uses `cloud.get_target_rotation()` if true
- **CloudHighlight** (Line2D component):
  - Reads `parent_shape.get_internal_time()` for visibility window
  - Visible only when mouse over AND within time window (-2.5s to +2.5s)
  - Publishes `highlight_clicked` event on mouse click during window

### MessageBus System
- Global autoload singleton for decoupled event communication
- Topic-based pub/sub pattern replaces signals
- `MessageBus.publish(topic, data)` - Emit events with dictionary payload
- `MessageBus.subscribe(topic, callback)` - Listen to topics
- `MessageBus.unsubscribe(topic, callback)` - Stop listening
- **Events in use**:
  - `cloud_vanished` - Individual cloud reached end of lifespan
  - `shape_vanished` - CloudShape reached end of lifetime (triggers shape replacement)
  - `shape_spawned` - New CloudShape instantiated
  - `highlight_clicked` - User clicked on shape highlight during time window