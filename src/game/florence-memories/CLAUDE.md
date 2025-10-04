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
- `clouds/` - Cloud assets, scripts, and prefabs
  - `cloud.gd` - Individual cloud behavior (movement with configurable direction, squish animation)
  - `cloud_spawner.gd` - Spawns and manages random ambient clouds continuously
  - `cloud_shape.gd` - Base script for organized cloud shapes (lifecycle management)
  - `shape_spawner.gd` - Spawns and manages cloud shape scenes (1-2 at a time)
  - `cloud_highlight.gd` - Interactive Line2D for shape hover/click detection with time window
  - `cloud_sync.gd` - (Legacy) Synchronized cloud groups with click interactions
  - `prefabs/` - Reusable cloud scene variants (default, oval, vertical)
  - `shapes/` - Cloud shape compositions (e.g., dog-cloud)

## Key Features
- **Ambient Cloud System**
  - Individual clouds spawn continuously for background ambiance
  - Initial clouds spawn randomly on screen at game start
  - New clouds spawn from screen edges and move towards screen
  - Multiple cloud variants for visual variety (3 types: default, oval, vertical)
  - Automatic cleanup of offscreen clouds

- **Cloud Shape System**
  - Organized groups of clouds forming recognizable shapes (e.g., dog)
  - Shape spawner manages 1-2 shapes at a time
  - Each shape tracks its sub-clouds lifecycle independently
  - Shapes auto-dispose when all sub-clouds are offscreen
  - Emits `shape_vanished` signal for spawning new shapes
  - Synchronized timing: CloudShape manages shared `internal_time` for all sub-clouds
  - Sub-clouds movement controlled by parent shape, not individually
  - Interactive highlight system shows Line2D outline on mouse hover during time window (±2.5s)
  - CloudHighlight reads parent CloudShape's `internal_time` for synchronized visibility
  - Modular design: CloudShape (lifecycle + timing) + CloudHighlight (interaction) work together

- **Cloud Behavior**
  - Each cloud moves at random speed with configurable direction
  - Subtle squish animation with inverse x/y scale oscillation
  - Gentle rotation synchronized with squish animation
  - Configurable speed ranges, squish duration, and rotation amount via exports

- **Interactive Cloud Sync** (legacy)
  - Synchronized cloud groups with clickable interactions
  - Highlight line appears on hover during specific time windows
  - Click detection within timing window triggers events