# Game Design Document (GDD) — Dead Block: Survival

**Course:** ITSD 85 — Special Topics in Information Technology  
**Working Title:** Dead Block: Survival  
**Package Identifier:** `com.itsd85.deadblock.survival`  
**Engine:** Godot 4.7.2 Standard Edition (GDScript, `gl_compatibility` renderer)  
**Target Platform:** Android 8.0+ (API 26+, Landscape `1280×720`) & Desktop  

---

## 1. Pitch
*Dead Block: Survival* is a gritty, top-down 2D tactical survival shooter inspired by classic zombie arena defense games where 1–4 survivors battle escalating waves of special infected across five urban quarantine sectors — playable completely offline (solo or with an autonomous AI Survivor Companion) or in real-time online multiplayer via LAN/Hotspot (Option A: ENet) and self-hosted server matchmaking (Option B: Nakama).

## 2. Genre and Target Players
- **Genre:** Top-Down 2D Twin-Stick Arena Survival Shooter (`Action / Cooperative Survival`).
- **Target Players:** Mobile action/arcade gamers and classmates who enjoy short, intense 3–5 minute wave-defense sessions on Android phones, both solo on the go (airplane mode) and in real-time squad co-op over Wi-Fi/Hotspot or a classroom server.

## 3. Core Mechanic
- **Twin-Stick Mobile Controls:** The player drags the **Left Virtual Joystick** for 360-degree movement and drags the **Right Virtual Joystick** to aim their tactical flashlight cone and automatically fire their equipped firearm (`Pistol`, `MP5 SMG`, `12G Shotgun`, `M4A1 Assault Rifle`, `.44 Magnum`).
- **Tactical Actions:** Dedicated thumb buttons trigger **Tactical Dash** (with brief invulnerability frames), **Frag Grenade Throw**, **Weapon Cycle**, and **Context Interact / Squad Revive** (activating emergency diesel generators, looting supply crates, or reviving downed teammates).

## 4. Goal, Win, and Lose Conditions
- **Clear Objective Banner (`R2`):** Displayed at the start of every deployment (`"GOAL: SURVIVE X WAVES IN SECTOR 0Y"` or `"GOAL: SURVIVE ENDLESS WAVES"`).
- **Win Condition:** Eliminate all infected waves in the sector while keeping at least one human survivor alive. Calculates 1–3 Star Rating based on score thresholds and remaining health ratio.
- **Lose Condition:** All human survivors are eliminated (`HP = 0` after bleedout in Co-op, or immediate fatal hit in solo). Displays the Defeat Result Screen with `Retry` and `Main Menu` buttons.

## 5. Level Plan (5-Level Campaign Progression Table)

| Level | Sector Title | Waves | Arena Layout & Obstacles | Enemy Composition & Twist | 2★ / 3★ Score |
| :---: | :--- | :---: | :--- | :--- | :---: |
| **1** | **Quarantine** | 3 Waves | Helipad yard, roadblocks, warning beacons, starter supply caches | Walkers & Runners; Day → Dusk transition; first-time tutorial overlay | `220` / `420` |
| **2** | **The Street** | 4 Waves | North-South highway with staggered vehicle wrecks (`34×66` sedans, `42×108` SWAT vans) creating vertical sightlines | Introduces **Witch** (weeping glass-cannon) & faster spawn intervals | `440` / `840` |
| **3** | **No Exit** | 4 Waves | Tight brick-walled alley choke points (`240×24`), dumpsters, chainlink gates, and movement-slowing toxic puddles (`0.68×` speed) | Introduces **Boomer** (explosive bile splash) & **Tanker** boss | `660` / `1260` |
| **4** | **The Depot** | 5 Waves | Interlocking 20ft/40ft ISO shipping container maze (`120×48` & `48×120`) with 90° blind corners and sodium floodlights | Heavy multi-vector swarms + **Spitter** ranged acid projectiles | `880` / `1680` |
| **5** | **Last Light** | 5 Waves | Open central plaza (`640, 360`) surrounded by 4 cardinal perimeter diesel generator defense stations and sandbag wings | Pitch-black Midnight Blackout requiring flashlight cone & generator floodlights; double Tanker climax | `1100` / `2100` |

## 6. Unlocking Rule & Persistent Save (`user://save.cfg`)
- **Campaign Unlock Rule:** Level 1 is unlocked by default (`unlocked_level = 1`). Clearing Level $N$ in Campaign mode increments `unlocked_level = max(unlocked_level, N + 1)` up to Level 5.
- **Star-Gated Veteran Bonus (`Bonus`):** Earning $\ge 6$ total stars across Campaign sectors unlocks the **Veteran Star Perk** (+50 Kevlar Armor & MP5 SMG at mission start).
- **Persistence:** Saved immediately via Godot `ConfigFile` to `user://save.cfg` (storing `unlocked_level`, per-level `best_score_by_level`, `best_stars_by_level`, `survival_best_wave`, 8 achievements, and all user settings: `sfx_enabled`, `music_enabled`, `ai_companion_enabled`, `vibration_enabled`, `colorblind_mode`, `player_callsign`).

## 7. Offline Mode (Airplane-Mode Verified + AI Companion)
- **Zero Network Dependency (`R6`):** Offline Campaign and Offline Endless Survival run using `OfflineMultiplayerPeer` with zero socket or HTTP calls, working 100% in Airplane Mode.
- **Offline AI Survivor Companion (`Rubric: Excellent Tier`):** Players can toggle the **Offline AI Squadmate (`BRAVO BOT`)** on the Mode Select screen. The AI bot autonomously navigates around obstacles, targets and shoots approaching zombies, and provides emergency field-medic healing (`+30 HP`) when the player's health drops below 38%.

## 8. Online Mode (Option A: ENet LAN/Hotspot + Option B: Nakama Server)
- **Option A — ENet LAN / Wi-Fi Hotspot (`autoload/network_manager.gd`):**
  - Host creates an `ENetMultiplayerPeer` server on UDP port `7777` (up to 4 players: Host + 3 clients).
  - Lobby auto-detects and highlights the Host's primary Wi-Fi/Hotspot IPv4 address (`192.168.x.x`) with one-tap copy.
  - **Host-Authoritative Real-Time Sync:** Host controls `WaveDirector`, spawns zombies with unique `net_id`s, broadcasts 12.5 Hz batched zombie transforms (`rpc_sync_zombies`), validates client weapon hits (`rpc_client_hit_zombie`), and synchronizes squad revives (`rpc_sync_downed`).
- **Option B — Self-Hosted Nakama Server & Leaderboard (`docker-compose.nakama.yml` & `src/app.js`):**
  - Lobby provides a 1-tap **Option B: Nakama Server Matchmake (Port 7350)** button that authenticates the device via `/v2/account/authenticate/device?create=true` with a 15-second timeout (`NAKAMA_TIMEOUT_SEC = 15.0`), issues matchmaking tickets using opcodes `OP_MOVE = 1`, `OP_SCORE = 2`, `OP_GAME_OVER = 3`, and queries the top survivor leaderboard.
- **Graceful Disconnect & Timeout Handling (`R8`):**
  - 8-second ENet connection timeout and 15-second Nakama timeout automatically reset `multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()` and display a clear diagnostic banner in the Lobby without freezing or crashing.

## 9. Screens List & Navigation Flow
1. **`title_screen.tscn`** — Animated studio & game splash screen with audio sting and tap-to-skip.
2. **`main_menu.tscn`** — Main navigation hub (`Play`, `Settings` modal with SFX/Music/Graphics/Resolution/Vibration/Colorblind/Callsign, `Credits` modal).
3. **`mode_select.tscn`** — Select `Offline Campaign`, `Offline AI Companion Toggle`, `Endless Survival Mode`, or `Online Co-op Lobby`.
4. **`level_select.tscn`** — 5 Sector buttons showing lock status, star ratings (`★ 1–3`), best scores, total star counter (`★ X/15`), and medal badges.
5. **`lobby.tscn`** — Online Co-op Lobby supporting Option A (ENet Host/Join IP + Port), Option B (Nakama Matchmake + Leaderboard), Campaign vs. Survival mode toggle, and Sector selector.
6. **`level_01.tscn` – `level_05.tscn`** — Playable combat arenas with `TouchControls`, `PauseMenu` (`pause_menu.tscn`), and `ResultScreen` (`result_screen.tscn`).

## 10. Art and Sound Style + Asset Licenses
- **Visual Style:** Procedural 2D vector canvas rendering (`_draw()`) with a bleak post-apocalyptic palette (`#181a1b` asphalt, `#4a2e2b` rust, `#8b2626` blood-red accents), dynamic flashlight shadow occlusion (`horror_vignette.gd`), and permanent ground blood/limb decals.
- **Audio:** 19 procedural 16-bit PCM WAV sound effects + 2 seamless `LOOP_FORWARD` ambient horror tracks (`ambient_menu.wav`, `ambient_combat.wav`) synthesized via `scripts/audio_generator.gd` (100% original CC0).
- **Fonts:** `BebasNeue-Regular.ttf` and `SpecialElite-Regular.ttf` (OFL-1.1 / Apache-2.0, documented in [`docs/CREDITS.md`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/docs/CREDITS.md)).

## 11. Risks & Fallback Plan
- **Risk 1 — Public School Wi-Fi AP Client Isolation:** Campus routers often block peer-to-peer UDP packets between phones.
  - **Fallback:** Use one phone's **Mobile Wi-Fi Hotspot** (zero router isolation) for Option A, or connect to the laptop's Dockerized Option B server.
- **Risk 2 — Mobile GPU Fill-Rate Drops During Massive Hordes:**
  - **Fallback:** Built-in 3-tier Graphics Quality toggle (`LOW / MED / HIGH`), resolution scaler (`75% / 100% / 125%`), and automatic blood decal ring-buffer capping (`48` decals in Survival, `75` in Campaign).
