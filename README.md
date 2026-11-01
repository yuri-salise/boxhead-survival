# Dead Block: Survival – ITSD 85 Lab

**Team:** Dead Block Squad | **Section:** ITSD 85 | **Platform:** Android 8.0+ (API 26+) & Desktop

## About the game
**Dead Block: Survival** is an original top-down 2D tactical zombie survival shooter built in **Godot 4.7.2 Standard Edition (GDScript)** using the mobile-optimized `gl_compatibility` renderer. Inspired by the intense arena combat loop of classic zombie defense games and a bleak post-apocalyptic survival-horror atmosphere, players fight through escalating waves of six distinct infected archetypes (`Walker`, `Runner`, `Boomer`, `Spitter`, `Witch`, and `Tanker`) across five progressively harder urban quarantine sectors. It supports **Offline Solo / AI Companion Campaign**, **Endless Survival Mode**, and **Real-Time 2–4 Player Online Squad Co-op** over Wi-Fi/Hotspot (Option A: ENet) and self-hosted server matchmaking (Option B: Nakama).

![Main Menu & Tactical UI](docs/screenshots/screenshot_menu.png)
![Co-op & Arena Combat](docs/screenshots/screenshot_gameplay.png)

## How to play
- **Controls (Android Touch HUD):**
  - **Left Virtual Joystick:** 360° survivor movement.
  - **Right Virtual Joystick:** Aim tactical flashlight cone and automatically fire equipped weapon.
  - **DASH Button:** High-speed evasive burst with brief invulnerability frames (`1.4s` cooldown).
  - **FRAG Button:** Throw explosive frag grenade (`135 px` blast radius).
  - **WEAPON Button:** Cycle unlocked firearms (`9mm Pistol`, `MP5 SMG`, `12G Shotgun`, `M4A1 Rifle`, `.44 Magnum`).
  - **USE / REVIVE Button:** Context-sensitive button to start perimeter diesel generators, open supply crates, or revive downed squadmates.
  - **Android Back Gesture:** Toggles the Pause Menu in combat or navigates back in menus.
- **Goal:** Eliminate all zombie waves in the selected sector (or survive as many waves as possible in Endless Survival Mode) without all human survivors dying.
- **How Levels Unlock:** Level 1 (*Quarantine*) is unlocked by default. Completing Level $N$ saves progress to `user://save.cfg` and unlocks Level $N + 1$ (up to Level 5: *Last Light*). Earning **$\ge 6$ total stars** unlocks the **Veteran Star Perk** (`+50 Kevlar Armor` & `MP5 SMG` on deployment).

## Offline and online modes
- **Offline Mode (Airplane-Mode Ready + AI Companion):**
  - Select **Play → Offline Campaign** or **Endless Survival**.
  - Toggle **Offline AI Squadmate (`BRAVO BOT`)** on the Mode Select screen to deploy with an autonomous AI companion that fights zombies and provides field-medic healing (`+30 HP`). Works 100% in Airplane Mode with zero network calls.
- **Online Mode — Option A (ENet LAN / Wi-Fi Hotspot Co-op):**
  1. Connect 2–4 phones to the same Wi-Fi network or one phone's **Mobile Wi-Fi Hotspot**.
  2. On Phone 1, open **Play → Online Co-op Lobby** and tap **Host Co-op Match**. Note the displayed Wi-Fi IPv4 address (e.g., `192.168.x.x`, port `7777`).
  3. On Phone 2–4, enter the Host's IP address and tap **Join**.
  4. The Host selects **Campaign Mission** or **Endless Survival Swarms**, picks a Sector (1–5), and taps **Launch Squad Mission**.
- **Online Mode — Option B (Self-Hosted Nakama Server & Leaderboard):**
  1. Start the server stack with `docker compose -f docker-compose.nakama.yml up -d` (or `docker compose up -d` for the CI/CD Node 24 service on port `8080`/`7350`).
  2. In the Lobby, enter the server IP and tap **Option B: Nakama Server Matchmake (Port 7350)** or **Leaderboard**.

## How to build
1. **Requirements:** Godot Engine **v4.7.2-stable Standard Edition** (GDScript), Android SDK (Platform 34, Build-Tools 34.0.0), OpenJDK 17, and Godot 4.7.2 export templates.
2. **Run Automated Test Suites (24 Headless Suites):**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/run_all_tests.gd
   ```
3. **Export Signed Android APK:**
   ```powershell
   Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug "Android" "build/android/DeadBlockSurvival.apk"
   ```
4. **Automated CI/CD Pipeline & Docker Deployment (ITSD 85 Lab 2):**
   ```bash
   npm install && npm run lint && npm test
   APP_VERSION=$(git rev-parse --short HEAD) docker compose up -d --build
   curl -s http://localhost:8080/health
   ```

## Download
- **Release v1.0 Android APK:** [Download `DeadBlockSurvival.apk` from GitHub Releases (v1.0)](../../releases/tag/v1.0) *(Package ID: `com.itsd85.deadblock.survival`)*.

## Playtest results
From our structured 3-device Phone Test Matrix and 15-item Likert playtest evaluation ($N = 12$ testers, overall satisfaction $\mu = 4.58 / 5.00$), the top 3 findings and implemented engineering fixes were:
1. **Right Aim/Fire Joystick Overlap & Sizing on 6.1" Screens:** Increased virtual joystick radius (`88 px` base, `36 px` knob) and repositioned action buttons into an ergonomic arc with zero overlap (`scripts/touch_controls.gd`).
2. **Multi-Adapter LAN IP Confusion (Virtual WSL/Docker vs. Wi-Fi IP):** Built `get_smart_ip_list()` in [`autoload/network_manager.gd`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/autoload/network_manager.gd) to prioritize physical Wi-Fi/Hotspot adapters and display a high-contrast Host IP banner with one-tap clipboard copy (`scenes/ui/lobby.gd`).
3. **Co-op Zombie Desynchronization & Downed Revive Lockup:** Implemented host-authoritative 12.5 Hz batched zombie state replication (`rpc_sync_zombies`), client hit validation (`rpc_client_hit_zombie`), and full movement/weapon unlock upon squadmate revive (`scenes/levels/level_01.gd`, `scripts/player.gd`).

Full playtest artifacts: [`docs/playtest/`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/docs/playtest/).

## Credits
All gameplay scripts, procedural 2D character/environment art (`_draw()`), and 21 synthesized WAV audio assets are original work by the team. Open-source fonts (`Bebas Neue`, `Special Elite`) are properly licensed. See [`docs/CREDITS.md`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/docs/CREDITS.md) for the complete asset and license table.

## Paper
- **IEEE Two-Column Research Paper:** [`docs/paper/ieee_paper.md`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/docs/paper/ieee_paper.md) & LaTeX source [`docs/paper/ieee_paper.tex`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/docs/paper/ieee_paper.tex)
- **Lab Guide Questions (Game Lab 1 & CI/CD Lab 2):** [`docs/GUIDE_QUESTIONS.md`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/docs/GUIDE_QUESTIONS.md)
