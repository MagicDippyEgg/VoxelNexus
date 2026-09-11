# VoxelNexus

A cross-platform voxel sandbox game with physics interactions and LAN multiplayer, built with **Godot 4.4+** (GDScript). Explore procedurally generated dimensional worlds, build structures, trigger explosions, and play with friends over your local network.

## Features

- **Procedural voxel worlds** — infinite, seed-based terrain with 8 biomes: Plains, Desert, Crystal Caves, Floating Islands, Neon City, Void Wastes, Arctic, Volcanic.
- **42 block types** — terrain, glowing crystals, neon building blocks, fluids/hazards (lava, void acid, plasma), gravity sand, conductive metal, portal rift crystals, and more.
- **Chunk streaming** — 16³ blocks per chunk, around-player load/unload, Culled mesh building (only visible faces) with vertex-color shading, concave collision.
- **Physics sandbox** — block-destroying explosions (G key), gravity blocks that fall as rigid bodies, explosives force on nearby physics bodies.
- **LAN multiplayer** (up to 8 players) — ENet/UDP on default port 7777, server-authoritative block edits, seed-synced worlds, player nameplates, chat.
- **Game modes** — Creative (flight, all blocks), Survival (fall damage, health regen, no flight). Team Build / Destruction Derby are selectable sandbox variants with competitive rules on the roadmap.
- **Progression** — XP/levels, block unlocks, achievements, and stats persisted locally (`user://progress.save`).
- **Day/night cycle**, sky shader with stars, FPS/position/biome HUD, crosshair, hotbar, health bar.

## Controls

| Input | Action |
|-------|--------|
| WASD | Move |
| Mouse | Look |
| Left click | Break block |
| Right click | Place block |
| Shift | Sprint |
| Space | Jump |
| R | Toggle flight (Creative) |
| G | Explode (destroys blocks in radius) |
| 1–0 / mouse wheel | Select hotbar block |
| T | Chat |
| Esc | Quit / pause |

## Run from source

1. Install **Godot 4.4+** (Godot 4.4.x stable recommended). The project targets Godot 4.4 features but runs on later 4.x.
2. Open the project folder (`project.godot`) in the Godot editor.
3. Press **F5** (Play) — the project starts in the main menu. Click **Host a Game** (same machine) to enter the sandbox.

Validation used during development (headless, Linux):
```bash
godot --headless --editor --quit        # import/parse check
godot --headless --quit-after 400 res://scenes/game/game.tscn   # boot the game scene
```

### LAN multiplayer

- **Host**: menu → Host a Game → pick a game mode → Host. The host broadcasts the world seed; all clients generate identical terrain locally.
- **Join**: menu → Join a Game → enter the host's LAN IP (port 7777). The host server is authoritative for block edits.

> v1 note: late-joining clients miss block edits made before they joined (no full world-state sync yet); the world itself always matches via seed.

## Project structure

```
VoxelNexus/
├── autoload/                  # network_manager, world_manager, progress_manager,
│                              # audio_manager, game_settings
├── scenes/
│   ├── main_menu/             # main menu (single player / host / join)
│   ├── lobby/                 # LAN host/join + player list + chat
│   ├── game/                  # world setup, spawning, HUD, day/night, sky shader
│   └── ui_theme.gd            # shared label/panel helpers
├── scripts/
│   ├── voxel/
│   │   ├── block_types.gd     # block enum + data (color, hardness, flags)
│   │   ├── world_generator.gd # biome noise, terrain height, caves, features
│   │   ├── chunk.gd           # per-chunk block storage + mesh/collision rebuild
│   │   └── mesh_builder.gd    # face-culled mesh generation with vertex colors
│   └── player/player.gd       # controller, blocks/tools, damage, RPCs
├── export_presets.cfg         # Windows, Linux, macOS (Universal 2), iOS, Android
└── .github/workflows/         # desktop/mobile CI builds + tag releases
```

## Build / CI

GitHub Actions workflows build for **Windows, Linux, macOS (Universal 2), Android (arm64-v8a), and iOS** on every push, and attach binaries to GitHub Releases for `v*` tags. See `.github/workflows/`.

- macOS/iOS exports require signing; use official Godot export templates for your platform.
- Export presets live in `export_presets.cfg` (5 presets).

## Roadmap

See `PLAN.md` for the full design document. Highlights:
- Full Team Build (rounds + community voting) and Destruction Derby (last-team-standing) scoring
- Fall-damage polish, hazards, hunger/energy in Survival
- LAN discovery (mDNS/broadcast) so hosts auto-appear
- Chunk LOD, threaded meshing, object pooling, mobile touch controls
- Sound effects & music, rift portals between worlds

## License

All original code in this project is provided under the MIT License (see `LICENSE`).