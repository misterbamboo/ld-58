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
- **Priority**: Functionality over perfection (48h game jam timeline)

## Development Guidelines
- **IMPORTANT**: When implementing new features, always update the "Key Features" section below
- Prefer editing existing files over creating new ones
- Follow the established project structure

## Project Structure
- `autoload/` - Global singletons (autoload scripts)
  - `message_bus.gd` - Global pub/sub system for decoupled communication
- `clouds/` - Cloud assets, scripts, and prefabs
  - `cloud.gd` - Individual cloud behavior with pre-computed phase system, drift support for shape sub-clouds
  - `cloud_phase.gd` - CloudPhase enum definition (FADE_IN, MOVING_IN, MOVING_OUT, FADE_OUT, VANISHED)
  - `cloud_spawner.gd` - Unified spawner for both individual clouds and cloud shapes
  - `cloud_shape.gd` - Pre-computed phase-based shape lifecycle with drift system
  - `cloud_highlight.gd` - Interactive Line2D for shape hover/click detection with time window
  - `prefabs/` - Reusable cloud scene variants (default, oval, vertical)
  - `shapes/` - Cloud shape compositions (e.g., dog-cloud)

## Key Features
- **Unified Cloud Spawner System**
  - Single spawner handles both individual clouds and cloud shapes
  - **Unified Limit**: Single `max_clouds` limit (default 10) for both types combined
    - CloudShape counts as 1 cloud (regardless of sub-cloud count)
    - Individual cloud counts as 1 cloud
  - **Spawning Strategy**: Hybrid (timer + event-driven)
    - Timer-based: spawns every 2-6s intervals if below max
    - Event-driven: spawns replacement when any entity vanishes (via MessageBus)
    - **Priority**: If no shapes on screen, spawn CloudShape next (ensures 1+ shapes always present)
  - **Spawn Behavior**: All entities spawn on-screen
    - Random x position (0 to screen_width)
    - Random y position (spawn_y_min to spawn_y_max)
    - **Direction based on spawn position:**
      - Left half (x < screen_width/2): move RIGHT (direction = 1)
      - Right half (x >= screen_width/2): move LEFT (direction = -1)
      - Always moves through screen center
  - **Individual Clouds**:
    - Phase system: FADE_IN → MOVING_IN → MOVING_OUT → FADE_OUT (no STABLE phase)
    - MOVING_IN duration: 0s (already at target)
    - MOVING_OUT duration: remaining time after fades (drifts across screen)
    - Lifespan: 30-90s, Speed: 2.0-3.0 px/s (consistent movement feel)
  - **Cloud Shapes**:
    - Phase system: FADE_IN → MOVING_IN → MOVING_OUT → FADE_OUT (same as individual clouds)
    - First shape pre-progressed to -lifespan/4 for immediate visibility
    - Highlight window: -2.5s to +2.5s around time 0 (independent of phases)
    - Lifespan: 30-90s, Speed: 2.0-3.0 px/s (inherited from sub-clouds)
  - Export groups: Individual Clouds, Cloud Shapes, Spawn Limits, Spawn Settings

- **Individual Cloud System (Pre-computed Phases)**
  - **CloudPhase Enum**: FADE_IN → MOVING_IN → MOVING_OUT → FADE_OUT → VANISHED
  - All phases pre-computed at `_ready()` based on durations and target positions
  - **No STABLE phase** - movement is continuous throughout lifecycle
  - **Lifespan: 30-90s** (total duration, distributed across phases)
  - **Speed: 2.0-3.0 px/s** (narrow range for consistent movement feel)
  - **Phase Durations**:
    - FADE_IN: 3-8s (gradual alpha increase at spawn position)
    - MOVING_IN: 0s (already at target position)
    - MOVING_OUT: Remaining time after fades (drifts across screen)
    - FADE_OUT: 3-8s (gradual alpha decrease while drifting)
  - **Movement System**:
    - Pre-computed start/target/end positions based on speed, direction, durations
    - Continuous linear interpolation (no acceleration, no pauses)
    - If managed by CloudShape: follows parent's drift offset
    - If individual: uses static pre-computed positions
  - **Event System**: Publishes "cloud_vanished" event when disposed (triggers replacement spawn)
  - Multiple cloud variants for visual variety (3 types: default, oval, vertical)
  - Auto-dispose at VANISHED phase

- **Cloud Shape System (Pre-computed Phase System with Drift)**
  - Organic shape lifecycle with lifespan-based timing (30-90s, same as individual clouds)
  - **Architecture: Pre-computed Phases (Clean Code)**
    - All phase boundaries calculated once at `_ready()`
    - Target positions set BEFORE phase computation for sub-clouds
    - Phase data structure stores: type, t_start, t_end, duration, start/end alpha/position
    - Runtime: Simple phase lookup + linear lerp based on progress
    - Small methods (4-10 lines), Single Responsibility Principle, CQS
    - Guaranteed continuity: each phase's end values = next phase's start values
  - **Phase-Based Timeline:**
    - Lifespan randomly chosen (e.g., 50s)
    - internal_time starts at -lifespan/2 (e.g., -25s) for normal shapes
    - **First shape starts at -lifespan/4** (pre-progressed for immediate visibility)
    - **Time 0 = PERFECT CONVERGENCE**: alpha=1, rotation=0, position=initial_position + drift
    - **Highlight window: -2.5s to +2.5s** (time-based, not phase-based)
  - **Drift System (Organic Movement)**:
    - Shape slowly drifts in its movement direction (configurable drift_speed, default 0.5 px/s)
    - Drift offset accumulates over time: `drift_offset += Vector2(drift_speed * direction, 0) * delta`
    - All sub-clouds follow parent's drift offset: `position = base_position + drift`
    - Creates gentle, organic movement during highlight window and all phases
    - Sub-clouds stay synchronized relative to drifting shape center
  - **Sub-cloud Phase Management:**
    - FADE_IN phase: 8s duration with randomized start offsets (staggered appearance + movement)
    - MOVING_IN phase: Continuous lerp toward zero position while following drift
    - MOVING_OUT phase: Continuous lerp away from zero position while following drift
    - FADE_OUT phase: 8s duration with randomized start offsets (staggered disappearance + movement)
    - VANISHED: Shape disposed when all sub-clouds invisible
    - **No STABLE phase** - movement is continuous, highlight window is just a time range
  - **Guaranteed Time 0 Convergence:**
    - Within 0.1s of time 0, all clouds forced to initial_position (+ drift offset)
    - Rotation override active: sets rotation=0
    - Alpha always 1.0 during highlight window
  - **Linear Interpolation (No Acceleration):**
    - Progress = (internal_time - t_start) / duration
    - All lerps use clamped progress (0.0 to 1.0)
    - Duration-normalized: longer phases don't move faster
  - **Natural Camouflage:**
    - Shapes blend seamlessly with ambient clouds (both use CloudPhase system)
    - Player cannot distinguish shape formation from ambient cloud spawning
  - **Event System:**
    - `shape_spawned` event published when new shape appears
    - `shape_vanished` event published when shape fully disappears
  - Synchronized timing: CloudShape manages shared `internal_time` for all sub-clouds
  - Sub-clouds inherit movement from parent (drift) while executing their own phases
  - Interactive highlight system shows Line2D outline on mouse hover during time window
  - Modular design: CloudShape (lifecycle + timing + drift) + CloudHighlight (interaction)

- **Cloud Behavior**
  - Pre-computed movement phases (start → target → end positions)
  - Subtle squish animation with inverse x/y scale oscillation
  - Gentle rotation synchronized with squish animation
  - Configurable speed ranges, squish duration, and rotation amount via exports
  - Dual behavior mode:
    - **Individual clouds**: Static pre-computed phases
    - **Shape sub-clouds**: Pre-computed phases + parent drift offset

- **MessageBus System**
  - Global autoload singleton for decoupled event communication
  - Topic-based pub/sub pattern replaces signals
  - `MessageBus.publish(topic, data)` - Emit events with dictionary payload
  - `MessageBus.subscribe(topic, callback)` - Listen to topics
  - `MessageBus.unsubscribe(topic, callback)` - Stop listening
  - Used for: `cloud_vanished`, `shape_vanished`, `shape_spawned`, `highlight_clicked` events