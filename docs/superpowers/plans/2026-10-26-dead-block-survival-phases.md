# Dead Block: Survival Master Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a complete, polished 2D top-down zombie survival shooter inspired by Boxhead and The Walking Dead, featuring an offline 5-level solo campaign, persistent progression saving, mobile dual-stick touch controls, and a host-authoritative 2-player LAN co-op mode.

**Architecture:** Scene and script layout adhering strictly to `AGENTS.md`. Autoloads (`GameState`, `NetworkManager`, `AudioManager`) handle global persistence, peer networking, and audio settings. Combat and level loops are governed by `LevelController` and `WaveDirector`, with modular actors (`Player`, `ZombieBasic`, `WeaponController`, `Projectile`) communicating via signals and validated RPCs.

**Tech Stack:** Godot 4.7 Standard Edition, GDScript (typed), Compatibility Renderer (`gl_compatibility`), 1280 × 720 Landscape Viewport (`canvas_items` stretch, `expand` aspect), `ENetMultiplayerPeer`, `ConfigFile` persistence in `user://save.cfg`.

**Spec:** [`AGENTS.md`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/AGENTS.md) and [`IMPLEMENTATION.md`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/IMPLEMENTATION.md)

---

## Global Constraints

- **Engine Floor:** Godot 4.x Standard (4.7.2 stable) with GDScript only. No .NET or C# dependencies.
- **Renderer Target:** Compatibility renderer (`gl_compatibility`) for both desktop and mobile.
- **Orientation & Design Resolution:** Fixed landscape orientation (`display/window/handheld/orientation=0`) at 1280 × 720 base viewport.
- **Offline Integrity:** Solo play must never initiate network calls, create network sockets, or fail in airplane mode.
- **Multiplayer Authority:** In co-op, the host is 100% authoritative for enemy spawning, health, damage, wave transitions, and match results. Clients only submit input/action requests.
- **Graceful Network Failures:** Peer drops, timeouts, or invalid connection targets must show descriptive UI feedback and cleanly restore `OfflineMultiplayerPeer` without freezing or crashing.
- **No Incomplete Placeholders:** Every button, setting, and menu item must perform an active, testable action.
- **Aesthetic Direction:** Gritty, desaturated post-apocalyptic *The Walking Dead* survival-horror mood using `Bebas Neue` and `Special Elite` typography. All assets must be original or open-license documented in [`docs/CREDITS.md`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/docs/CREDITS.md).

---

## Review Focus

1. **Client Claim Validation:** A compromised or laggy client sends RPCs claiming kills, direct damage to zombies, or premature victory. (Expected: Host ignores unauthorized RPCs and only calculates outcomes locally).
2. **Abrupt Disconnect in Co-op:** Host or client suddenly terminates during wave combat. (Expected: Remaining peer detects disconnect, frees peers, restores `OfflineMultiplayerPeer`, alerts the user, and navigates back to mode select without orphaned nodes).
3. **Save Data Corruption / Absence:** `user://save.cfg` is missing, unreadable, or contains invalid keys. (Expected: `GameState` catches parse failures and safely falls back to defaults with Level 1 unlocked).
4. **Touch Input Drift / Stuck Movement:** A touch drag ends outside the virtual joystick region or during app pause. (Expected: Input abstraction zeroes motion vector on touch release or focus loss).
5. **Simultaneous Zombie Attack Desync:** Multiple zombies contact player on the exact same frame. (Expected: Player damage cooldown prevents single-frame instant death while correctly registering hits).

---

## Phase 1: Core Combat Prototype (Vertical Slice Core)

### Task 1: Projectile System (`Projectile.tscn` & `projectile.gd`)

**Files:**
- Create: [`scripts/projectile.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/projectile.gd)
- Create: [`scenes/actors/projectile.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/actors/projectile.tscn)
- Test: `tests/test_projectile.gd`

**Interfaces:**
- Consumes: Initial position, direction (`Vector2`), speed (`float`), damage (`float`), shooter reference (`Node2D`).
- Produces: `hit_target(target, damage)` signal or direct damage delivery; despawns on contact with walls/enemies or after `lifetime` timer.

- [ ] **Step 1: Write headless unit test `tests/test_projectile.gd`**
  Verify projectile moves along its normalized velocity vector, damages an `Area2D` target on overlap, does not harm its shooter, and self-terminates after expiry.
- [ ] **Step 2: Run test to verify failure**
  Run: `& "C:\Users\Yuri\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" -s tests/test_projectile.gd --headless`
  Expected: FAIL with missing projectile scene.
- [ ] **Step 3: Implement `scripts/projectile.gd` and `scenes/actors/projectile.tscn`**
  - Node: `Area2D` with `CollisionShape2D` (circle r=4), `ColorRect` visual (bright bullet streak `#f0c040`), lifetime timer (1.5s).
  - Methods: `init(pos: Vector2, dir: Vector2, bullet_speed: float, bullet_damage: float, shooter: Node2D) -> void`.
  - Collision masking: layer 3 (projectiles), mask 1 (environment) & 2 (enemies).
- [ ] **Step 4: Run test to verify pass**
  Run: `& "C:\Users\Yuri\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" -s tests/test_projectile.gd --headless`
  Expected: PASS with 0 errors.
- [ ] **Step 5: Commit**
  `git commit -m "feat(combat): implement projectile system with collision filtering"`

---

### Task 2: Player Survivor Actor & Weapon Controller

**Files:**
- Create: [`scripts/weapon_controller.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/weapon_controller.gd)
- Create: [`scripts/player.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/player.gd)
- Create: [`scenes/actors/player.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/actors/player.tscn)
- Test: `tests/test_player.gd`

**Interfaces:**
- Consumes: Input vectors (`move_vector`, `aim_point`, `is_firing`), projectile scene.
- Produces: `health_changed(current, max)`, `player_died()`, `CharacterBody2D` velocity movement.

- [ ] **Step 1: Write headless unit test `tests/test_player.gd`**
  Verify player responds to directional input, rotates toward target aim point, enforces weapon cooldown rate between shots, takes damage, and emits `player_died` when health reaches 0.
- [ ] **Step 2: Run test to verify failure**
  Expected: FAIL with missing player scene.
- [ ] **Step 3: Implement `WeaponController` and `Player`**
  - `weapon_controller.gd`: Exported `fire_rate: float = 0.2`, `damage: float = 25.0`, `projectile_speed: float = 850.0`, muzzle position marker.
  - `player.gd`: `max_health = 100.0`, `current_health`, `speed = 280.0`, `take_damage(amount: float) -> void`.
  - `scenes/actors/player.tscn`: `CharacterBody2D` with circular collision (r=18), stylized 2D survivor visual (slate jacket `#3d4538`, red headband accent, gun muzzle node).
- [ ] **Step 4: Run test to verify pass**
  Expected: PASS.
- [ ] **Step 5: Commit**
  `git commit -m "feat(player): implement survivor CharacterBody2D and weapon controller"`

---

### Task 3: Basic Zombie Enemy Actor (`ZombieBasic`)

**Files:**
- Create: [`scripts/zombie_basic.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/zombie_basic.gd)
- Create: [`scenes/actors/zombie_basic.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/actors/zombie_basic.tscn)
- Test: `tests/test_zombie.gd`

**Interfaces:**
- Consumes: Target player reference (`Node2D`), damage events from projectiles.
- Produces: `zombie_killed(zombie)`, contact damage to player on proximity attack timer.

- [ ] **Step 1: Write headless unit test `tests/test_zombie.gd`**
  Verify zombie computes direction to nearest living player, advances via `move_and_slide()`, decrements health on `take_damage()`, triggers attack cooldown on contact, and emits `zombie_killed` once on death.
- [ ] **Step 2: Run test to verify failure**
  Expected: FAIL.
- [ ] **Step 3: Implement `scripts/zombie_basic.gd` and `scenes/actors/zombie_basic.tscn`**
  - `CharacterBody2D` with collision radius 16, collision layer 2 (enemies).
  - Health: 50.0. Speed: 140.0. Contact damage: 15.0 with 0.8s attack cooldown timer.
  - Silhouette: Distressed pale grey/decay flesh `#687063` with bloodied hands, distinct silhouette contrast against floor.
- [ ] **Step 4: Run test to verify pass**
  Expected: PASS.
- [ ] **Step 5: Commit**
  `git commit -m "feat(zombie): implement basic pursuing zombie actor with attack cooldown"`

---

### Task 4: Arena Combat Testbed Integration (`Level 01` Prototype)

**Files:**
- Modify: [`scenes/levels/level_01.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/levels/level_01.tscn)
- Modify: [`scenes/levels/level_01.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/levels/level_01.gd)
- Test: `tests/test_arena_combat.gd`

**Interfaces:**
- Consumes: Player, Zombie spawner test timer, HUD health & kill display.
- Produces: Fully playable combat sandbox where player moves with WASD, aims with mouse, shoots, kills zombies, takes damage, and can restart or return to menu.

- [ ] **Step 1: Write integration test `tests/test_arena_combat.gd`**
  Verify arena spawns player at center, confines movement inside arena walls, spawns test zombie, resolves bullet-zombie collisions, and updates kill counter.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Update `level_01.tscn` with StaticBody2D boundaries, Player instance, dynamic zombie spawner, and HUD (Health Bar, Kills counter)**
- [ ] **Step 4: Run test to verify pass and manually verify desktop playability**
- [ ] **Step 5: Commit**
  `git commit -m "feat(combat): integrate playable combat prototype vertical slice into level 1"`

---

## Phase 2: Complete Level Architecture & Wave Director

### Task 5: Wave Director & Dynamic Spawning

**Files:**
- Create: [`scripts/wave_director.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/wave_director.gd)
- Test: `tests/test_wave_director.gd`

**Interfaces:**
- Consumes: Wave configurations `Array[Dictionary]` (`total_enemies`, `spawn_interval`, `max_concurrent`).
- Produces: `wave_started(wave_num, total_waves)`, `enemy_spawn_requested(spawn_point, enemy_type)`, `wave_completed(wave_num)`.

- [ ] **Step 1: Write unit test `tests/test_wave_director.gd`**
  Test wave start, interval timing between spawns, enforcement of `max_concurrent` alive zombies, and progression to next wave when all zombies in wave are dead.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `scripts/wave_director.gd` as a Node**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**
  `git commit -m "feat(wave): implement WaveDirector state machine and concurrency controls"`

---

### Task 6: Level Controller & Objective Resolution

**Files:**
- Create: [`scripts/level_controller.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/level_controller.gd)
- Test: `tests/test_level_controller.gd`

**Interfaces:**
- Consumes: Player signals (`player_died`), `WaveDirector` signals (`wave_completed`), level config (`level_id`, `waves_to_win`).
- Produces: `level_won(score, stars)`, `level_lost(reason)`.

- [ ] **Step 1: Write unit test `tests/test_level_controller.gd`**
  Verify all waves completed triggers `level_won` once; player death triggers `level_lost` once.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `scripts/level_controller.gd`**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**
  `git commit -m "feat(level): implement authoritative LevelController objective tracking"`

---

### Task 7: Result Screen & Pause Overlay

**Files:**
- Create: [`scenes/ui/result_screen.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/ui/result_screen.tscn)
- Create: `scenes/ui/result_screen.gd`
- Create: [`scenes/ui/pause_menu.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/ui/pause_menu.tscn)
- Create: `scenes/ui/pause_menu.gd`
- Test: `tests/test_ui_results.gd`

**Interfaces:**
- Consumes: Match outcome (Victory / Defeat), score, kills, current level.
- Produces: Navigation actions: `retry_level()`, `next_level()`, `return_to_menu()`, `resume_game()`.

- [ ] **Step 1: Write test `tests/test_ui_results.gd`**
  Verify result screen displays VICTORY or OUTPOST OVERRUN with score and kills, Next Level button visible only on victory, and Pause menu freezes gameplay tree (`process_mode = PROCESS_MODE_WHEN_PAUSED`).
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement result screen and pause menu using Walking Dead theme**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**
  `git commit -m "feat(ui): add result screen and pause menu with retry/menu routing"`

---

## Phase 3: Progression & 5-Level Campaign

### Task 8: `GameState` Autoload & `ConfigFile` Persistence

**Files:**
- Create: [`autoload/game_state.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/autoload/game_state.gd)
- Modify: [`project.godot`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/project.godot) (register autoload `GameState`)
- Test: `tests/test_game_state.gd`

**Interfaces:**
- Produces: `unlocked_level: int`, `best_scores: Dictionary`, `complete_level(level_id, score, stars)`, `is_level_unlocked(level_id) -> bool`, `save_progress()`, `load_progress()`, `reset_progress()`.
- Persists to: `user://save.cfg`.

- [ ] **Step 1: Write test `tests/test_game_state.gd`**
  Verify default unlocked level is 1, completing Level 1 unlocks Level 2 and saves to disk, force-reload reads Level 2 as unlocked, and corrupt/missing file recovers cleanly.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `autoload/game_state.gd` with safe `ConfigFile` error handling**
- [ ] **Step 4: Register `GameState` in `project.godot` under `[autoload]`**
- [ ] **Step 5: Run test to verify pass**
- [ ] **Step 6: Commit**
  `git commit -m "feat(save): implement GameState autoload with persistent ConfigFile storage"`

---

### Task 9: Level Select & Mode Select Screens

**Files:**
- Create: [`scenes/ui/mode_select.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/ui/mode_select.tscn)
- Create: `scenes/ui/mode_select.gd`
- Create: [`scenes/ui/level_select.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/ui/level_select.tscn)
- Create: `scenes/ui/level_select.gd`
- Modify: [`scenes/ui/main_menu.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/ui/main_menu.gd) (connect Play to Mode Select)
- Test: `tests/test_level_select.gd`

**Interfaces:**
- Consumes: `GameState.unlocked_level`, `GameState.best_scores`.
- Produces: Disabled states for locked levels (Levels 2–5 initially locked), level launch actions for unlocked levels.

- [ ] **Step 1: Write test `tests/test_level_select.gd`**
  Verify Level 1 button is enabled, Level 2 button is disabled when `unlocked_level == 1`, and clicking Level 1 changes scene to `level_01.tscn`.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Build `mode_select.tscn` (Solo Campaign vs LAN Co-op) and `level_select.tscn` (Levels 1-5 grid with padlock icons and star ratings)**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**
  `git commit -m "feat(ui): implement mode select and progressive level select screens"`

---

### Task 10: Levels 2 to 5 Arena Scenes & Difficulty Tuning

**Files:**
- Create: [`scenes/levels/level_02.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/levels/level_02.tscn)
- Create: [`scenes/levels/level_03.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/levels/level_03.tscn)
- Create: [`scenes/levels/level_04.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/levels/level_04.tscn)
- Create: [`scenes/levels/level_05.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/levels/level_05.tscn)
- Test: `tests/test_campaign_levels.gd`

**Level Difficulty Specifications:**
- **Level 1 (Quarantine):** 3 waves, 15 total zombies, 2.5s spawn rate, wide arena.
- **Level 2 (The Street):** 4 waves, 28 total zombies, 2.0s spawn rate, street layout with barricades.
- **Level 3 (No Exit):** 5 waves, 42 total zombies, 1.8s spawn rate, tight industrial warehouse.
- **Level 4 (The Depot):** 5 waves, 55 total zombies, 1.5s spawn rate, container yard with multiple spawn points.
- **Level 5 (Last Light):** 6 waves, 75 total zombies, 1.2s spawn rate, final fortress assault with heavy horde.

- [ ] **Step 1: Write test `tests/test_campaign_levels.gd`**
  Verify all 5 level scenes exist, can be instantiated, have valid `LevelController` and `WaveDirector` setups, and load their respective wave configs.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Assemble scenes `level_02.tscn` through `level_05.tscn` with obstacle layouts and progressive tuning**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**
  `git commit -m "feat(campaign): build and tune levels 2 through 5 arenas and wave scaling"`

---

## Phase 4: Mobile On-Screen Controls & Audio Settings

### Task 11: Dual Virtual Joysticks & Touch Input Abstraction

**Files:**
- Create: [`scenes/ui/touch_controls.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/ui/touch_controls.tscn)
- Create: `scripts/touch_controls.gd`
- Modify: [`scripts/player.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/player.gd) (support unified input abstraction)
- Test: `tests/test_touch_controls.gd`

**Interfaces:**
- Produces: Left virtual stick -> `move_vector: Vector2`, Right aim pad -> `aim_direction: Vector2`, `is_firing: bool`.
- Responsive: Only visible on mobile (`OS.has_feature("mobile")`) or when forced in test mode.

- [ ] **Step 1: Write test `tests/test_touch_controls.gd`**
  Simulate touch events on left stick and right aim zone; verify corresponding move and aim vectors are normalized and bounded.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `touch_controls.gd` with touch area clamps, deadzones, and thumb-friendly sizing (64dp minimum)**
- [ ] **Step 4: Integrate into player actor without breaking desktop WASD/Mouse input**
- [ ] **Step 5: Run test to verify pass**
- [ ] **Step 6: Commit**
  `git commit -m "feat(mobile): add dual virtual stick touch controls and unified input abstraction"`

---

### Task 12: `AudioManager` Autoload & Settings Persistence

**Files:**
- Create: [`autoload/audio_manager.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/autoload/audio_manager.gd)
- Modify: [`project.godot`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/project.godot) (register autoload `AudioManager`)
- Modify: [`scenes/ui/main_menu.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/ui/main_menu.gd) (wire real audio toggles to `AudioManager`)
- Test: `tests/test_audio_manager.gd`

**Interfaces:**
- Produces: `play_sfx(sound_name)`, `play_music(track_name)`, `set_sfx_enabled(bool)`, `set_music_enabled(bool)`.
- Persists: Audio preferences via `GameState`.

- [ ] **Step 1: Write test `tests/test_audio_manager.gd`**
  Verify toggling sound and music updates AudioServer bus volume or muting, and setting persists across simulate restart.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `AudioManager` and link with Settings menu**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**
  `git commit -m "feat(audio): implement AudioManager autoload and persistent bus volume settings"`

---

## Phase 5: Two-Player LAN Co-op Multiplayer

### Task 13: `NetworkManager` Autoload & Peer Session Lifecycle

**Files:**
- Create: [`autoload/network_manager.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/autoload/network_manager.gd)
- Modify: [`project.godot`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/project.godot) (register `NetworkManager`)
- Test: `tests/test_network_manager.gd`

**Interfaces:**
- Produces: `host_game(port: int) -> Error`, `join_game(address: String, port: int) -> Error`, `leave_game() -> void`, signals: `connection_succeeded`, `connection_failed`, `peer_connected(id)`, `peer_disconnected(id)`, `server_disconnected`.
- Safety: Releases peer and sets `multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()` on disconnect.

- [ ] **Step 1: Write test `tests/test_network_manager.gd`**
  Verify host creates ENet server, invalid IP throws timeout error without crashing, and `leave_game()` cleans up state to `OfflineMultiplayerPeer`.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement `autoload/network_manager.gd` with 10-second connection timeout timer**
- [ ] **Step 4: Register `NetworkManager` in `project.godot`**
- [ ] **Step 5: Run test to verify pass**
- [ ] **Step 6: Commit**
  `git commit -m "feat(net): implement NetworkManager ENet session lifecycle and timeout recovery"`

---

### Task 14: Host/Join Lobby UI & Network Status Screen

**Files:**
- Create: [`scenes/ui/lobby.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/ui/lobby.tscn)
- Create: `scenes/ui/lobby.gd`
- Test: `tests/test_lobby_ui.gd`

**Interfaces:**
- UI: Display local IP address (for Wi-Fi/hotspot sharing), Port input (default 7777), Host Button, Join IP text input, Join Button, Status Label, Error Dialog.

- [ ] **Step 1: Write test `tests/test_lobby_ui.gd`**
  Verify lobby displays local IP, updates status to "Waiting for Peer...", shows error modal on failed connection with a Return button.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Build `lobby.tscn` using Walking Dead theme**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**
  `git commit -m "feat(ui): implement host/join co-op lobby with connection state feedback"`

---

### Task 15: Multiplayer Co-op Replication & Authority Validation

**Files:**
- Modify: [`scripts/player.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/player.gd) (peer ownership and input synchronization)
- Modify: [`scripts/level_controller.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/level_controller.gd) (two-player spawn, host authority for enemies & damage)
- Test: `tests/test_multiplayer_gameplay.gd`

**Safety Rules:**
- Host spawns Player 1 (Peer 1) and Player 2 (Client Peer ID).
- Client only sends `@rpc("any_peer", "call_local", "unreliable") func sync_player_input(move_vec, aim_angle, firing)`.
- Host calculates zombie collisions and broadcasts health changes via `@rpc("authority", "call_local", "reliable")`.
- Victory occurs when all waves cleared and at least one player lives. Defeat occurs when both players die.

- [ ] **Step 1: Write headless two-peer test `tests/test_multiplayer_gameplay.gd`**
  Simulate two peers connecting locally on port 7778; verify both players spawn, client input moves client avatar, host authoritative damage applies to both peers, and match ends correctly.
- [ ] **Step 2: Run test to verify failure**
- [ ] **Step 3: Implement RPC sync and authority validation**
- [ ] **Step 4: Run test to verify pass**
- [ ] **Step 5: Commit**
  `git commit -m "feat(net): implement host-authoritative co-op replication and damage validation"`

---

## Phase 6: Polish, Audio Assets & Visual FX

### Task 16: Sound Effects & Atmospheric Audio

**Files:**
- Create: Original / licensed CC0/MIT audio assets in [`assets/audio/`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/assets/audio/)
  - `sfx_gunshot.wav`, `sfx_dry_fire.wav`, `sfx_zombie_groan.wav`, `sfx_zombie_hit.wav`, `sfx_player_hurt.wav`, `sfx_wave_start.wav`, `sfx_victory.wav`, `sfx_defeat.wav`.
- Modify: [`autoload/audio_manager.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/autoload/audio_manager.gd) (preload SFX stream dictionaries)
- Modify: [`docs/CREDITS.md`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/docs/CREDITS.md) (document all sound sources and licenses)
- Test: `tests/test_audio_playback.gd`

- [ ] **Step 1: Add sound assets and update `docs/CREDITS.md`**
- [ ] **Step 2: Wire audio triggers into `WeaponController`, `ZombieBasic`, `Player`, and `LevelController`**
- [ ] **Step 3: Verify all audio hooks trigger without missing resource errors**
- [ ] **Step 4: Commit**
  `git commit -m "feat(audio): add sound effects for combat, zombies, and match transitions"`

---

### Task 17: Visual FX, Muzzle Flashes & Hit Decals

**Files:**
- Create: [`scenes/effects/muzzle_flash.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/effects/muzzle_flash.tscn)
- Create: [`scenes/effects/blood_splatter.tscn`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scenes/effects/blood_splatter.tscn)
- Modify: [`scripts/player.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/player.gd) and [`scripts/zombie_basic.gd`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/scripts/zombie_basic.gd)
- Test: `tests/test_vfx_lifecycle.gd`

- [ ] **Step 1: Write test verifying VFX nodes auto-free after emission**
- [ ] **Step 2: Build lightweight 2D particles / sprite flashes optimized for mobile fill rate**
- [ ] **Step 3: Verify performance and absence of memory leaks**
- [ ] **Step 4: Commit**
  `git commit -m "feat(vfx): add muzzle flashes and blood impact decals"`

---

## Phase 7: Android Export & Device Playtesting

### Task 18: Android Export Presets & Permissions

**Files:**
- Create: `export_presets.cfg`
- Modify: [`project.godot`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/project.godot)
- Test: Export validation check

**Export Settings:**
- Target: Android APK.
- Orientation: Landscape.
- Permissions: `android.permission.INTERNET`, `android.permission.ACCESS_NETWORK_STATE` (for LAN co-op).
- Architecture: `arm64-v8a` (standard modern Android devices).

- [ ] **Step 1: Configure `export_presets.cfg` for Android and Windows desktop**
- [ ] **Step 2: Validate headless export syntax**
- [ ] **Step 3: Document APK install and test instructions in `README.md`**
- [ ] **Step 4: Commit**
  `git commit -m "chore(export): configure Android export presets and network permissions"`

---

### Task 19: Full End-to-End Checklist Verification

**Files:**
- Modify: [`docs/IMPLEMENTATION.md`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/docs/IMPLEMENTATION.md) (check off deliverables)
- Test: Run master verification test suite `tests/run_all_tests.gd`

- [ ] **Step 1: Run comprehensive headless verification suite**
  - Verify offline campaign can complete levels 1 to 5 in order.
  - Verify progression saves and survives simulated reload.
  - Verify 2-peer LAN co-op connects, plays, and handles disconnect cleanly.
  - Verify zero Godot engine parse errors or resource leaks.
- [ ] **Step 2: Update documentation and release notes**
- [ ] **Step 3: Final Phase Commit**
  `git commit -m "release: Dead Block: Survival MVP completion and playtest sign-off"`
