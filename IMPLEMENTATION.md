# IMPLEMENTATION.md — Build Plan and Technical Specification

## 1. Product summary

**Working title:** Dead Block: Survival

A 2D top-down zombie survival shooter for Android and desktop testing. The player survives escalating zombie waves in compact arenas, unlocks five campaign levels, and can team up with one other player in online co-op. The tone is bleak and grounded: abandoned streets, ruined rooms, worn equipment, muted colors, and tense sound design.

This is a gameplay-inspired homage, not a direct asset or level recreation of Boxhead or *The Walking Dead*. Create original characters, maps, UI, audio, and names, or use assets with compatible licenses.

## 2. Important platform decision

The uploaded ITSD 85 lab brief requires a mobile game, at least five levels, persistent level progression, offline play, online play on two devices, an Android/iOS build, and playtesting. Therefore, this implementation plan prioritizes **Godot 4.x + GDScript + Android** rather than a browser-only Phaser project.

If the actual final deliverable is only a Y8/browser game, the stack should be reconsidered: Phaser 3 + TypeScript + Vite is a better browser-first choice. Do not mix Phaser and Godot into one project. Confirm the target platform before implementation begins.

## 3. Recommended stack

| Need | Choice | Why |
|---|---|---|
| Game engine | Godot 4.x Standard | Free, open source, built-in 2D tools, Android export |
| Language | GDScript | Small learning curve and fast iteration |
| Rendering | Compatibility renderer | Safer target for lower-end Android devices |
| Local save | `ConfigFile` in `user://` | Simple persistent save without a plugin |
| LAN multiplayer | Godot high-level multiplayer + ENet | Fastest path to two-device play on one Wi-Fi/hotspot |
| Internet matchmaking (later) | Self-hosted Nakama | Adds matchmaking/session services; more setup and deployment |
| Version control | Git + GitHub/GitLab | Branches, rollback, collaboration |
| Art | Krita / Inkscape / LibreSprite; licensed packs | Free workflow; maintain original style |
| Audio | Audacity / LMMS / licensed sound effects | Free editing and attribution tracking |
| Android build | Godot export templates + OpenJDK 17 + Android SDK | Installable APK for testing |

**Keep the Godot version fixed** after project creation. Use the latest stable 4.x version supported by the team's installed export templates, and follow documentation for that exact version.

## 4. Scope and gameplay decisions

### Core gameplay

- Camera: top-down, fixed arena camera.
- Movement: eight-directional.
- Aim: mouse on desktop; right-side touch/aim control on mobile.
- Fire: mouse button or touch fire control; weapon cooldown prevents unlimited firing.
- Enemies: zombies move toward the nearest living player and deal contact damage with a cooldown.
- Objective: survive the level's waves and eliminate the required number of zombies.
- Failure: player team has no living players, or a configured survival timer expires.
- Success: required waves/kill target is complete and the player/team remains alive.
- Rewards: score and optional stars based on survival/time/performance.
- Progression: clearing level N unlocks level N+1; progress persists locally.
- Online: two-player co-op; each device controls one survivor.
- First release: one weapon and one zombie type are sufficient. Add variants only after the game loop is stable.

### Five-level difficulty plan

| Level | Objective | Change from previous level |
|---|---|---|
| 1 — Quarantine | Survive 3 short waves | Teaches movement, aiming, shooting, health |
| 2 — The Street | Clear 4 waves | More zombies and slightly tighter spawn intervals |
| 3 — No Exit | Survive 5 waves | Adds a tougher zombie or a small obstacle layout |
| 4 — The Depot | Clear 5 waves | Mixed enemy timing and fewer safe gaps |
| 5 — Last Light | Survive the final assault | Highest enemy count and a final heavy wave |

Tune these values after playtesting. Do not increase enemy health, speed, spawn rate, and enemy count all at once; difficulty should remain understandable and fair.

## 5. Scene and code structure

Use the structure in `AGENTS.md`. The most important scenes/scripts are:

### Autoloads

**`GameState`**
- `TOTAL_LEVELS`
- `unlocked_level`
- `best_score_by_level`
- `best_stars_by_level`
- `current_level`
- `selected_mode`
- `last_result`
- sound setting
- `load_progress()`, `save_progress()`, `complete_level()`, `is_level_unlocked()`, `reset_progress()`

**`NetworkManager`**
- `host_game(port)`
- `join_game(address, port)`
- `leave_game()`
- `connection_state`
- signals for connected, peer joined, peer left, and network error
- connection timeout handling

**`AudioManager`**
- music and SFX playback helpers
- persistent mute/volume setting

### Gameplay scenes

**`Player.tscn`**
- `CharacterBody2D` root
- collision shape
- sprite/animated sprite
- weapon/muzzle point
- health component or clearly separated health logic
- local input only for the owning peer
- mobile controls connected through an input abstraction so desktop and touch use the same movement/fire methods

**`ZombieBasic.tscn`**
- `CharacterBody2D` root
- collision shape
- sprite/animated sprite
- state: alive/dead
- pursuit and attack cooldown
- health and death signal
- authority-controlled AI in multiplayer

**`Projectile.tscn`**
- lightweight `Area2D` or suitable physics body
- velocity, damage, lifetime
- collision filtering so a projectile does not hit its owner
- despawn on hit or expiry

**`LevelController`**
- receives level configuration
- starts waves
- tracks objective progress
- checks win/lose conditions once
- sends a result to the result screen
- delegates spawning to `WaveDirector`

**`WaveDirector`**
- level-specific wave configuration
- spawn interval and maximum alive enemies
- authority-only spawning online
- deterministic seed only if reproducible wave patterns are needed

### UI scenes

`TitleScreen` → `MainMenu` → `ModeSelect`

Offline path: `LevelSelect` → `Level` → `ResultScreen`

Online path: `Lobby` → `OnlineLevel` → `ResultScreen`

Pause overlay: `PauseMenu`

Each screen needs a back/navigation path. Online screens must show connecting, waiting, connected, and error states.

## 6. Implementation sequence

Build in this order. Do not work on all systems at once.

### Phase 0 — Confirm project and setup

1. Confirm Android is the required final target.
2. Install a stable Godot 4.x Standard build.
3. Create the project with the Compatibility renderer.
4. Set landscape orientation and a 1280 × 720 design viewport, scaling for different phone sizes.
5. Create the folder structure.
6. Initialize Git and commit the empty runnable project.
7. Add `AGENTS.md`, `IMPLEMENTATION.md`, `docs/GDD.md`, and `docs/CREDITS.md`.

**Exit criteria:** project opens and runs on desktop; repository is clean and versioned.

### Phase 1 — Combat prototype

1. Build a simple arena using placeholder art.
2. Implement movement and collision.
3. Implement aiming and firing.
4. Implement one zombie that pursues the player.
5. Implement zombie health/death and player health/damage.
6. Add a HUD showing health, kills, and wave.
7. Add a temporary restart action.

**Exit criteria:** the player can move, aim, shoot, kill zombies, take damage, and lose/restart reliably.

### Phase 2 — Complete one level

1. Add `LevelController` and `WaveDirector`.
2. Add wave configuration and a clear objective label at level start.
3. Add success/failure states.
4. Add result UI with Retry and Menu.
5. Add pause/resume.
6. Test repeated restarts and scene transitions.

**Exit criteria:** Level 1 can be won and lost, and no duplicate result screen or double-completion bug occurs.

### Phase 3 — Progression and five levels

1. Add `GameState` as an autoload.
2. Save the highest unlocked level and per-level score/stars to `user://save.cfg`.
3. Build a level-select screen with visible locked states.
4. Reuse the same level scene/configuration pattern for levels 1–5 where practical.
5. Tune wave count, spawn intervals, enemy caps, and objectives per level.
6. Save progression immediately after a level is cleared.

**Exit criteria:** all five levels are reachable in order; level 3 remains unlocked after the app is force-closed and reopened after clearing level 2; locked levels cannot be opened directly.

### Phase 4 — Offline mode and mobile controls

1. Make offline mode use no network connection.
2. Add touch movement and aim/fire controls.
3. Keep desktop controls for quick testing.
4. Add safe margins for notches and small screens.
5. Add sound toggle and save the preference.
6. Test in airplane mode on an Android phone.

**Exit criteria:** offline campaign can be played with Wi-Fi/mobile data off; touch controls work; saved progression survives app restart.

### Phase 5 — LAN online co-op

1. Add `NetworkManager` using `ENetMultiplayerPeer`.
2. Build Host and Join controls in the lobby.
3. Display the host's LAN IP and the port.
4. Add connection timeout and clear error messages.
5. Spawn one player per peer, with each client controlling only its own player.
6. Keep enemy AI, enemy health, damage, wave state, and match result authoritative on the host.
7. Synchronize necessary player/enemy state; avoid sending entire scenes or large data blobs.
8. Add disconnect handling and a return-to-menu action.
9. Enable the necessary Android network permissions.
10. Test with two real devices on the same Wi-Fi or hotspot.

**Exit criteria:** two devices enter the same match, both players can move and shoot, enemy/match state stays consistent enough for co-op, and leaving the match does not break the next attempt.

**Important:** LAN host/join does not guarantee public internet play. If players must connect from unrelated networks, plan a reachable dedicated server or use Nakama after LAN co-op is stable.

### Phase 6 — Polish

- Original survival-horror UI, sprites, background details, and restrained lighting.
- Audio feedback for shooting, hits, death, wave start, victory, and defeat.
- Main menu, mode select, level select, lobby, pause, result, settings, credits.
- Readable text and thumb-friendly buttons.
- Attribution in `docs/CREDITS.md`.
- No unlicensed game/film characters, logos, music, maps, or extracted sprites.

**Exit criteria:** all required screens are usable and assets are credited.

### Phase 7 — Device testing and playtest

1. Export an APK.
2. Test on at least two Android devices if available.
3. Test install, launch, orientation, UI scaling, touch, audio, offline mode, save persistence, online host/join, disconnect, and repeated restarts.
4. Run a structured playtest with at least five players if following the ITSD 85 brief.
5. Collect feedback and prioritize bugs and confusing controls.
6. Fix the highest-impact problems and retest with at least two new players.

**Exit criteria:** no known blocker prevents the core game, offline campaign, progression, or two-device LAN match from working.

### Phase 8 — Optional internet matchmaking

Only begin when Phases 0–7 are stable.

1. Set up a self-hosted Nakama instance on a reachable machine/server.
2. Add the supported Godot Nakama client library and verify its version/API.
3. Implement authentication appropriate for a class prototype, matchmaking, join/leave, and match state.
4. Validate match events server-side.
5. Configure deployment, network ports, logging, and secrets securely.
6. Test from two unrelated networks.

**Exit criteria:** players can find and join the same match over the internet and recover cleanly from disconnects.

## 7. Multiplayer design details

### Initial architecture

For the LAN prototype, one player is host and is the authority. The other player joins. The host is responsible for:
- enemy spawning and AI decisions
- enemy health and death
- applying damage
- wave progression and objective completion
- match result and winner/team outcome

Clients send player input or bounded action requests. They must not send authoritative claims such as “I killed 10 zombies” or “the match is won.”

### Synchronization

Synchronize only what the other peer needs:
- player transform and aim direction
- animation/state needed for presentation
- enemy transform/state
- player health and enemy health where needed
- wave number, objective progress, and match result

Use reliable messages for important events. For movement, choose an appropriate replication approach and test the trade-off between responsiveness and consistency. Do not add custom lag compensation unless the basic multiplayer loop proves it is necessary.

### Failure states

The UI must handle:
- invalid address
- failed host creation
- failed join
- timeout while waiting
- host disconnect
- guest disconnect
- app returning from background
- attempt to enter Online without a usable connection

When a connection fails: show a concise message, close/reset the peer, restore the offline peer, and provide a clear way back to mode select.

## 8. Input and UI plan

### Desktop development controls

- `WASD`: movement
- Mouse: aim
- Left mouse button: fire
- `Esc`: pause

### Android controls

- Left virtual joystick or directional pad: movement
- Right-side aim area or aim stick: aim
- Fire button: shoot
- Pause button: pause menu

Use an input abstraction so gameplay scripts do not care whether the input originated from keyboard, mouse, or touch. Avoid tiny buttons near screen edges.

## 9. Save data

Use a versioned config format so future changes do not break existing saves. Store only local campaign data and settings, for example:
- save schema version
- highest unlocked level
- best score per level
- best stars per level
- sound/music setting

Validate loaded values and fall back to safe defaults if the file is missing or corrupted. Do not store network secrets or treat local save data as authoritative for online competition.

## 10. Performance guidelines

- Prefer small arena maps and a capped number of active zombies.
- Reuse or pool projectiles and enemies only if profiling shows frequent allocation is a problem.
- Avoid expensive real-time lights/shadows on every actor.
- Keep textures appropriately sized for the target phones.
- Avoid unnecessary per-frame node searches; cache important node references.
- Use signals instead of polling unrelated nodes every frame.
- Profile on a real device before adding optimization complexity.
- Set an initial target of stable 60 FPS where hardware allows, but prioritize consistent, playable performance on the team's test phones.

## 11. Testing checklist

### Gameplay
- [ ] Player movement is bounded by the arena.
- [ ] Aim and shooting work in all directions.
- [ ] Bullets do not hit the shooter.
- [ ] Zombie damage and death occur once.
- [ ] Player death ends the level once.
- [ ] Level victory ends the level once.
- [ ] Retry resets wave, enemies, health, and score correctly.
- [ ] Pause stops gameplay as expected.

### Progression
- [ ] Level 1 is unlocked on a fresh save.
- [ ] Level N+1 is locked until N is cleared.
- [ ] Clearing a level saves before showing the result screen.
- [ ] Progress survives force-close/relaunch.
- [ ] Corrupt/missing save data falls back safely.
- [ ] Reset progress works only through an intentional debug/test path.

### Offline
- [ ] Campaign works in airplane mode.
- [ ] No online-only autoload blocks offline startup.
- [ ] Repeated offline sessions do not retain old network peers.

### Online
- [ ] Host and guest connect on two devices.
- [ ] Each device controls only its own player.
- [ ] Both players see relevant shared game state.
- [ ] Only the host decides enemy state and match result.
- [ ] Invalid IP/connection timeout displays a useful error.
- [ ] Disconnecting either peer releases the session.
- [ ] A new match can be started after leaving a previous match.
- [ ] Online results do not silently unlock offline campaign levels.

### Mobile/polish
- [ ] APK installs and launches.
- [ ] Screen orientation and UI scaling are correct.
- [ ] Touch targets are large enough.
- [ ] Sound toggle persists.
- [ ] All non-original assets are listed in credits.
- [ ] No crash or soft-lock appears during normal play.

## 12. Definition of MVP complete

The MVP is complete only when all of the following are true:

1. A playable top-down zombie survival loop exists.
2. Five campaign levels have distinct difficulty.
3. Level goals, win/lose results, retry, and menu navigation work.
4. Level unlocking and local save persistence work.
5. Offline mode works without a network.
6. Two devices can play one online co-op match using the documented network method.
7. Network errors and disconnects are handled.
8. Android build is installed and tested on a real device.
9. Main menu, pause, sound toggle, and credits exist.
10. The repository contains build instructions, GDD, credits, and test/playtest notes.

## 13. AI agent task template

When assigning work to a coding agent, use a bounded task:

> Read `AGENTS.md` and `docs/IMPLEMENTATION.md`. Implement only [specific feature]. Keep the project runnable and preserve the current architecture. List the files changed, the tests run, any failures, and exact manual steps needed to verify the feature. Do not add unrelated features.

Good first tasks:
1. Create project structure and a runnable main menu.
2. Implement player movement and arena collision.
3. Add one zombie and a shooting loop.
4. Add health, wave objective, and result screen.
5. Add progression/save.
6. Add mobile input.
7. Add LAN multiplayer only after offline play is stable.
