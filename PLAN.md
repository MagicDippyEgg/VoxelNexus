# VoxelNexus - Game Design Document

## Overview
**VoxelNexus** is a cross-platform voxel sandbox game with physics-based interactions and LAN multiplayer. Players explore procedurally generated sci-fi worlds, build structures, and engage in various game modes.

### Target Platforms
- Windows 10+
- Linux (2018+ distros)
- macOS Big Sur (11.0) Intel+ (Universal 2 binary)
- iOS 15+
- Android (API level 24+)

### Core Features
1. **Voxel World**: 3D block-based terrain with physics interactions
2. **LAN Multiplayer**: Up to 8 players via local network
3. **Procedural Generation**: Unique worlds each playthrough
4. **Multiple Game Modes**: Creative, Survival, and competitive modes
5. **Progression System**: Unlockable blocks, tools, and cosmetics
6. **Physics Sandbox**: Explosions, gravity, fluid dynamics, destructible environments

---

## Technical Architecture

### Engine & Tools
- **Engine**: Godot 4.4+ (latest stable)
- **Language**: GDScript (for rapid development and cross-platform)
- **Renderer**: Forward+ (desktop), Mobile (iOS/Android)
- **Physics**: Jolt (default in Godot 4.6+)
- **Networking**: ENetMultiplayerPeer (UDP-based LAN)

### Project Structure
```
voxelnexus/
├── project.godot
├── export_presets.cfg
├── .github/
│   └── workflows/
│       ├── build-desktop.yml
│       ├── build-mobile.yml
│       └── release.yml
├── autoload/
│   ├── network_manager.gd
│   ├── world_manager.gd
│   ├── progress_manager.gd
│   └── audio_manager.gd
├── scenes/
│   ├── main_menu/
│   ├── lobby/
│   ├── game/
│   ├── player/
│   ├── world/
│   ├── ui/
│   └── effects/
├── scripts/
│   ├── voxel/
│   │   ├── chunk.gd
│   │   ├── world_generator.gd
│   │   ├── block_types.gd
│   │   └── mesh_builder.gd
│   ├── physics/
│   │   ├── explosion.gd
│   │   ├── fluid.gd
│   │   └── gravity.gd
│   ├── player/
│   │   ├── player_controller.gd
│   │   ├── inventory.gd
│   │   └── tools.gd
│   └── networking/
│       ├── server.gd
│       ├── client.gd
│       └── sync.gd
├── assets/
│   ├── textures/
│   ├── models/
│   ├── sounds/
│   └── fonts/
└── addons/ (if needed)
```

---

## Game Design

### Theme: Dimensional Rifts
Players discover portals (rifts) that lead to procedurally generated voxel worlds with different biomes and challenges. Each world has unique resources, dangers, and physics properties.

### World Generation
- **Chunk Size**: 16x16x16 blocks
- **World Size**: Infinite (chunk loading/unloading around players)
- **Biomes**: Crystalline Caves, Floating Islands, Neon City, Void Wastes
- **Seed-based**: Same seed = same world (for multiplayer sync)

### Block Types
| Category | Examples | Properties |
|----------|----------|------------|
| Terrain | Stone, Dirt, Crystal | Destructible, buildable |
| Special | Rift Crystal, Plasma | Emit light, affect physics |
| Building | Metal, Glass, Neon | Structural, decorative |
| Hazard | Lava, Void Acid, Electrified | Damage players, destroy blocks |
| Physics | Sand, Water, Floating | Affected by gravity, flow |

### Physics Interactions
- **Explosions**: Destroy blocks in radius, apply force to entities
- **Gravity**: Some blocks fall when unsupported
- **Fluids**: Water/lava flow and fill spaces
- **Destruction**: Blocks break into smaller pieces
- **Electromagnetic**: Metal blocks conduct, attract/repel

### Game Modes

#### 1. Creative Mode
- Unlimited resources
- Fly movement
- No damage
- All blocks unlocked
- Physics sandbox (spawn explosions, test builds)

#### 2. Survival Mode
- Health, hunger, energy systems
- Resource gathering and crafting
- Day/night cycle with danger at night
- Rift portals to new worlds
- Boss encounters in special rifts

#### 3. Team Build Mode (2v2, 4v4)
- Teams compete to build best structure
- Timed rounds (5-10 minutes)
- Score based on creativity, size, complexity
- Voting system for winner

#### 4. Destruction Derby
- Players start with equal terrain
- Use tools to destroy opponent's builds
- Last team standing wins

### Progression System
- **XP Points**: Earned from building, surviving, winning
- **Unlocks**: New block types, tools, cosmetics
- **Achievements**: Milestone rewards
- **Seasons**: Rotating challenges and exclusive rewards

### Multiplayer Architecture
```
Server (Host)
├── World Generation (authoritative)
├── Physics Simulation
├── Game State Management
├── Player Authentication
└── Anti-cheat Validation

Client (Players)
├── Input Handling
├── Local Prediction
├── Server Reconciliation
├── Entity Interpolation
└── UI Rendering
```

### Network Protocol
- **Transport**: ENet (UDP) for low-latency LAN
- **Port**: 7777 (configurable)
- **Sync**: 
  - Chunk data (RPC on demand)
  - Player state (MultiplayerSynchronizer)
  - Physics events (RPC reliable)
  - Chat (RPC reliable)

---

## Build System

### GitHub Actions Workflows

#### Desktop Build (Windows, Linux, macOS)
```yaml
name: Build Desktop
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        preset: ["Windows Desktop", "Linux/X11", "macOS"]
    steps:
      - uses: actions/checkout@v4
      - name: Build
        uses: mlm-games/godot-build-action@v1
        with:
          EXPORT_PRESET_NAME: ${{ matrix.preset }}
      - uses: actions/upload-artifact@v4
        with:
          name: ${{ matrix.preset }}
          path: build/
```

#### Mobile Build (iOS, Android)
```yaml
name: Build Mobile
on: [push, pull_request]
jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Android
        uses: mlm-games/godot-build-action@v1
        with:
          EXPORT_PRESET_NAME: "Android"
  
  build-ios:
    runs-on: macos-latest  # Required for iOS
    steps:
      - uses: actions/checkout@v4
      - name: Build iOS
        uses: mlm-games/godot-build-action@v1
        with:
          EXPORT_PRESET_NAME: "iOS"
```

#### Release Workflow
```yaml
name: Release
on:
  push:
    tags:
      - 'v*'
jobs:
  release:
    strategy:
      matrix:
        preset: ["Windows Desktop", "Linux/X11", "macOS", "Android", "iOS"]
    steps:
      - uses: actions/checkout@v4
      - name: Build
        uses: mlm-games/godot-build-action@v1
        with:
          EXPORT_PRESET_NAME: ${{ matrix.preset }}
      - name: Upload to Release
        uses: softprops/action-gh-release@v2
        with:
          files: build/*
```

### Export Configuration
- **macOS**: Universal 2 (Intel x86_64 + ARM64)
- **iOS**: ARM64 only (requires Xcode, code signing)
- **Android**: ARM64 + ARMv7 (universal APK)
- **Windows**: x86_64
- **Linux**: x86_64

---

## Development Roadmap

### Phase 1: Core Engine (Week 1-2)
- [ ] Project setup in Godot 4.4+
- [ ] Voxel chunk system implementation
- [ ] Basic world generation (single biome)
- [ ] Player controller (movement, camera)
- [ ] Block placement/destruction
- [ ] Basic physics (gravity for blocks)

### Phase 2: Multiplayer (Week 3-4)
- [ ] Network manager (host/join)
- [ ] Player synchronization
- [ ] World sync (chunk loading)
- [ ] Basic lobby UI
- [ ] LAN discovery/broadcast

### Phase 3: Game Modes (Week 5-6)
- [ ] Creative mode implementation
- [ ] Survival mode (health, hunger, crafting)
- [ ] Team Build mode
- [ ] Destruction Derby mode

### Phase 4: Content (Week 7-8)
- [ ] Multiple biomes
- [ ] Block types and materials
- [ ] Tools and items
- [ ] Sound effects and music
- [ ] UI polish

### Phase 5: Polish & Release (Week 9-10)
- [ ] Performance optimization
- [ ] Bug fixes
- [ ] Tutorial/onboarding
- [ ] Achievement system
- [ ] Release builds

---

## Risk Mitigation

### Known Issues & Solutions
1. **Voxel Tools GDExtension instability** → Use custom implementation with SurfaceTool
2. **Jolt joint limitations** → Avoid complex joint physics, use rigid body stacking
3. **iOS requires macOS** → Use macos-latest runner in GitHub Actions (10x cost)
4. **macOS single-arch broken** → Always export as Universal 2
5. **No built-in LAN discovery** → Implement broadcast/mDNS manually

### Performance Considerations
- Chunk LOD system for distant terrain
- Multithreaded mesh generation
- Frustum culling
- Object pooling for physics entities
- Network compression for chunk data

---

## Success Metrics
- 60 FPS on mid-range hardware (desktop)
- 30 FPS on mobile devices
- <100ms LAN latency
- <500ms world load time
- Positive playtest feedback
- Successful cross-platform builds in CI