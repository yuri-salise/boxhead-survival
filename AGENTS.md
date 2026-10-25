# AGENTS.md — Project Rules for AI Coding Agents

## 1. Project mission

Build an original, top-down survival shooter inspired by the *gameplay loop* of classic arena zombie shooters such as Boxhead, with a gritty, bleak, post-apocalyptic atmosphere inspired by zombie survival drama. The project must be achievable by a small student team and remain easy to extend with AI coding tools.

**Working title:** Dead Block: Survival  
**Engine:** Godot 4.x Standard edition  
**Language:** GDScript  
**Primary target:** Android  
**Secondary development target:** Desktop for rapid testing  
**Modes:** Offline solo campaign and online two-player co-op  
**Minimum campaign:** Five progressively harder levels

This is an original game. Do not copy Boxhead maps, sprites, sounds, logos, names, or other protected assets. Use original or properly licensed assets. Use a broad survival-horror mood rather than reproducing specific characters or scenes from *The Walking Dead*.

## 2. Non-negotiable priorities

1. **A playable core loop comes first.** The player must move, aim, shoot, damage enemies, take damage, and win or lose before advanced features are added.
2. **Ship a small vertical slice before expanding.** Finish one polished level, then reuse the systems to create levels 2–5.
3. **Offline play must never depend on a server or internet connection.**
4. **Online mode must fail gracefully.** Show a useful message and return to the lobby/menu if hosting, joining, or a connection fails. Never freeze or crash because a peer disconnects.
5. **The host/server is authoritative** for enemy spawning, enemy health, damage, match state, and the final result in multiplayer.
6. **Use Godot's standard GDScript build**, not the .NET edition, unless a documented requirement makes C# necessary.
7. **Keep the project understandable.** Prefer small, focused scripts and explicit scene structure over clever abstractions.
8. **Test on real Android devices early.** Desktop success does not prove touch controls, performance, or networking work on phones.
9. **Protect the schedule.** Do not add crafting, open-world exploration, inventory grids, story cinematics, voice chat, accounts, or dedicated matchmaking until the required game is complete.
10. **Do not claim a feature works without running or describing a test for it.**

## 3. Technical decisions

### Core stack

- Godot 4.x Standard, using a stable version selected at project setup and kept fixed during the project.
- GDScript.
- 2D top-down rendering; use the Compatibility renderer for broad Android device support.
- Godot scenes and nodes for actors, UI, levels, and effects.
- `CharacterBody2D` for player movement.
- `Area2D` or physics queries for hit detection where appropriate.
- `Timer` nodes or carefully managed timers for spawn rates, cooldowns, and level timers.
- `ConfigFile` under `user://` for local progression and settings.
- Git with a Godot `.gitignore`.
- Godot's high-level multiplayer API with `ENetMultiplayerPeer` for the first online implementation.

### Multiplayer scope

**Required first milestone:** two devices on the same Wi-Fi or phone hotspot can host/join one co-op match.

**Optional extension:** internet matchmaking using a self-hosted Nakama server, only after the LAN version is stable. Do not begin with Nakama if the core game is not yet playable.

ENet host/join is not automatically internet matchmaking. Public internet play may require reachable hosting, port forwarding, or a server deployment. Explain the actual supported connection method in the UI and README.

### Art direction

- Gritty, desaturated palette: dirty concrete, faded olive, rust, charcoal, muted blood-red accents.
- Readable silhouettes and strong contrast between player, enemies, bullets, pickups, and hazards.
- Use original simple shapes or licensed assets while prototyping.
- Prefer 2D sprites and restrained lighting over expensive visual effects.
- Keep effects short and mobile-friendly.
- Track every non-original asset in `docs/CREDITS.md`, including its source and license.

## 4. Required gameplay

### Core loop

1. Choose Offline or Online.
2. Select an unlocked campaign level or join/create an online lobby.
3. Survive zombie waves and complete the level objective.
4. Show a clear victory/defeat result.
5. On campaign victory, save progress and unlock the next level.
6. Allow retry, next level, or return to menu.

### Minimum playable feature set

- One controllable survivor.
- Keyboard/mouse controls for desktop testing.
- Touch-friendly on-screen movement and aiming/shooting controls for Android.
- At least one basic zombie type with pursuit behavior.
- Shooting, projectile or hitscan resolution, damage, health, and death.
- Enemy waves and a clear level goal.
- Five levels with a gradual difficulty increase.
- Win and lose states with a result screen.
- Level locking and persistent local progress.
- Offline mode usable in airplane mode.
- Two-player online co-op over the supported network path.
- Host/join lobby with connection status and timeout.
- Disconnect handling.
- Pause/settings UI and sound toggle.
- Credits for assets.

## 5. Suggested repository layout

Keep this structure unless there is a concrete reason to change it:

```text
res://
├── autoload/
│   ├── game_state.gd
│   ├── audio_manager.gd
│   └── network_manager.gd
├── scenes/
│   ├── ui/
│   │   ├── title_screen.tscn
│   │   ├── main_menu.tscn
│   │   ├── mode_select.tscn
│   │   ├── level_select.tscn
│   │   ├── lobby.tscn
│   │   ├── pause_menu.tscn
│   │   └── result_screen.tscn
│   ├── levels/
│   │   ├── level_01.tscn
│   │   ├── level_02.tscn
│   │   ├── level_03.tscn
│   │   ├── level_04.tscn
│   │   └── level_05.tscn
│   ├── actors/
│   │   ├── player.tscn
│   │   ├── zombie_basic.tscn
│   │   ├── projectile.tscn
│   │   └── pickup.tscn
│   └── effects/
├── scripts/
│   ├── player.gd
│   ├── zombie_basic.gd
│   ├── weapon_controller.gd
│   ├── projectile.gd
│   ├── wave_director.gd
│   └── level_controller.gd
├── assets/
│   ├── art/
│   ├── audio/
│   └── fonts/
└── docs/
    ├── GDD.md
    ├── IMPLEMENTATION.md
    └── CREDITS.md
```

Use `snake_case` for file names and variables, `PascalCase` for scene/node class names where applicable, and clear signal names such as `health_changed` and `level_completed`.

## 6. Architecture rules

- `GameState` owns campaign progress, selected mode, selected level, settings, and last result. It must not own active enemy AI or per-frame combat logic.
- `NetworkManager` owns peer creation, host/join/leave, connection state, and network error signals. It must not contain level-specific enemy behavior.
- `LevelController` owns the level objective, wave state, completion/failure decisions, and match result.
- `WaveDirector` owns enemy spawn timing and wave composition. In online mode, only the authority should decide when and where enemies spawn.
- `Player` owns local input, movement, and presentation. In multiplayer, validate gameplay actions on the authority; never accept a client's claimed damage or victory as truth.
- `Zombie` owns its state and movement. The authority decides its target, movement outcome, health, and death.
- `WeaponController` owns weapon cooldown, ammo if used, and firing requests.
- UI scripts should call public methods or respond to signals; they should not directly edit another scene's private variables.
- Avoid global variables. Use autoloads only for genuinely global state/services.
- Avoid large “manager” scripts that own unrelated features.

## 7. Multiplayer safety and correctness

- Use the host as the authority for a two-player co-op match in the first version.
- Assign each connected player a stable peer ID for the match.
- Spawn player avatars through a consistent authority-controlled path.
- Synchronize only necessary state: player position/aim, enemy state, health, wave/score, and match status. Do not broadcast the whole scene every frame.
- Use reliable RPCs for important events (match start, wave start, death, result); use suitable lower-overhead synchronization for frequent movement updates.
- Validate sender identity with `multiplayer.get_remote_sender_id()` when accepting client RPCs.
- Never trust a client to report enemy kills, damage amounts, or the final winner without server/host validation.
- Handle host exit, guest exit, timeout, failed connection, and invalid address.
- On disconnect, release the peer and restore `OfflineMultiplayerPeer` so stale sessions do not contaminate later attempts.
- Do not allow online mode to alter offline unlocks unless that rule is deliberately documented and tested.
- Do not put passwords, private keys, or server secrets in source control.

## 8. Coding standards for AI agents

Before editing:
1. Read this file and `docs/IMPLEMENTATION.md`.
2. Inspect the existing project and current scene/script conventions.
3. Identify the smallest complete change that meets the requested milestone.
4. State assumptions if requirements are ambiguous; prefer a safe, simple default.

While editing:
- Make focused changes. Do not rewrite unrelated files.
- Use typed GDScript where it improves clarity.
- Use descriptive names and short functions.
- Prefer signals for decoupled communication.
- Use exported properties for per-level tuning.
- Avoid unnecessary plugins and dependencies.
- Do not invent APIs. Check Godot's documentation for version-specific methods and RPC annotations.
- Do not leave placeholder buttons that look functional but do nothing.
- Do not add fake online support that only simulates another player locally.
- Add comments for non-obvious networking or gameplay decisions, not every line.
- Keep asset licensing and credits accurate.

After editing:
1. Run Godot's project parse/import check where available.
2. Launch the project and test the changed flow.
3. Test relevant edge cases, especially death, scene changes, and disconnects.
4. Report exactly what changed, what was tested, and what remains unverified.
5. If a test cannot be run, say so plainly and provide the exact manual test steps.

## 9. Definition of done

A task is done only when:
- It meets the requested acceptance criteria.
- The project opens without parse errors.
- The relevant screen/scene can be reached and used.
- It does not break offline play.
- Multiplayer changes have been tested with two peers where practical.
- Failures show useful feedback instead of a crash or indefinite loading.
- Documentation is updated if behavior, controls, setup, or architecture changes.

## 10. Out of scope until the MVP is complete

Do not implement these before the minimum checklist passes:

- Dedicated public matchmaking or player accounts.
- Ranked modes or leaderboards.
- Voice/text chat.
- Large open-world maps.
- Complex inventory/crafting/base building.
- Multiple playable classes.
- Procedural campaigns.
- Cosmetic shops or monetization.
- Advanced ragdolls or expensive post-processing.
