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
  - `cloud.gd` - Individual cloud behavior (movement with configurable direction)
  - `cloud_spawner.gd` - Spawns and manages random clouds
  - `cloud_sync.gd` - Synchronized cloud groups with click interactions
  - `prefabs/` - Reusable cloud scene variants (default, oval, vertical)
  - `shapes/` - Complex cloud compositions (e.g., dog shapes)

## Key Features
- **Cloud Spawning System**
  - Initial clouds spawn randomly on screen at game start
  - Continuous spawning from screen edges during gameplay
  - Multiple cloud variants for visual variety (3 types: default, oval, vertical)
  - Automatic cleanup of offscreen clouds

- **Cloud Movement**
  - Each cloud moves at random speed
  - Clouds spawned offscreen always move towards the screen
  - Left-spawned clouds move right, right-spawned clouds move left
  - Configurable speed ranges via exports

- **Interactive Cloud Sync**
  - Synchronized cloud groups with clickable interactions
  - Highlight line appears on hover during specific time windows
  - Click detection within timing window triggers events