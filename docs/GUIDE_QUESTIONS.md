# ITSD 85 Lab Guide Questions — Comprehensive Engineering Answers

---

## Part 1: Mobile Game with Level Progression and Offline/Online Multiplayer (Lab PDF 1, Page 28)

### Question 1: How does `GameState` keep offline play working even when the phone has no internet?
`GameState` ([`autoload/game_state.gd`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/autoload/game_state.gd)) is a purely local Godot Autoload singleton that persists all campaign progression (`unlocked_level`, `best_score_by_level`, `best_stars_by_level`, `survival_best_wave`, achievements, and user settings) to the device's internal sandboxed filesystem at `user://save.cfg` using Godot's built-in `ConfigFile` API. When the player selects **Offline Campaign** or **Endless Survival**, `GameState.selected_mode` is set to `"offline"` or `"survival"`, and `NetworkManager` keeps `multiplayer.multiplayer_peer` bound to `OfflineMultiplayerPeer.new()`. No UDP sockets, DNS lookups, or HTTP requests are ever initialized during offline play, guaranteeing 100% functionality in Airplane Mode.

### Question 2: Where is the save file stored on Android, and what happens if the file is missing on first launch?
On Android, Godot maps `user://save.cfg` to the application's private internal storage directory:
`/data/data/com.itsd85.deadblock.survival/files/save.cfg`.
On first launch (when `save.cfg` does not yet exist on disk), `ConfigFile.load("user://save.cfg")` returns `ERR_FILE_NOT_FOUND` (`err != OK`). `GameState.load_progress()` handles this gracefully by returning early and preserving safe in-memory defaults (`unlocked_level = 1`, `current_level = 1`, `sfx_enabled = true`, `music_enabled = true`, `ai_companion_enabled = true`, `best_score_by_level = {1:0..5:0}`). As soon as the player changes a setting or completes Level 1, `save_progress()` creates `user://save.cfg` automatically.

### Question 3: How did you make Level 5 harder than Level 1 without writing a brand-new game script?
All five campaign levels (`level_01.tscn` through `level_05.tscn`) reuse the same modular architecture (`level_01.gd`, `wave_director.gd`, `level_controller.gd`, and `arena_environment.gd`) parameterized via exported properties (`@export var level_id: int`, `@export var force_night_mode: bool`, `@export var custom_waves: Array[Dictionary]`):
1. **Wave Escalation:** Level 1 spawns 3 short waves (`6–10` enemies, `1.65s` interval) of basic Walkers and Runners. Level 5 (*Last Light*) escalates to 5 dense waves (`12–24` enemies per wave, `0.70s` spawn interval, up to `20` concurrent hostiles) with guaranteed **Witch** and **Tanker** boss spawns in every wave.
2. **Environmental & Lighting Constraints:** `ArenaEnvironment` switches its procedural obstacle geometry based on `sector_type = level_id` (from an open yard in Level 1 to vehicle barricades in Level 2, tight brick alleys with `0.68×` toxic slow puddles in Level 3, blind-corner shipping containers in Level 4, and a midnight blackout plaza in Level 5 where `current_night_factor >= 0.85` restricts vision to the player's narrow flashlight cone and perimeter diesel generators).

### Question 4: In your online mode, who decides the winner or score — each client or the host/server — and why?
The **Host (Server, `peer_id == 1`)** is strictly authoritative for all wave spawning, zombie health/damage resolution, kill/score counters, and win/loss determination:
- In [`scripts/level_controller.gd`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/scripts/level_controller.gd), `on_all_waves_completed()` and `on_all_players_dead()` guard execution with `if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority(): return`.
- Clients send their movement/aim inputs (`sync_input_to_host`) and hit reports (`rpc_client_hit_zombie`) to the Host, which validates sender identity via `multiplayer.get_remote_sender_id()`, applies damage on the authoritative zombie instance, and broadcasts deaths (`rpc_zombie_died`) and the final match outcome (`rpc_sync_match_result`).
- **Why:** If clients decided their own kills or victory state, network latency or packet loss would cause diverging wave counts (one phone showing Victory while another is still fighting), and malicious clients could spoof instant wins.

### Question 5: What happens in your game when the other player disconnects mid-match? Trace the signal to the UI.
1. **Transport Detection:** When a guest phone loses Wi-Fi or closes the app, ENet detects the dropped peer and emits `multiplayer.peer_disconnected(id)` (or `multiplayer.server_disconnected()` on a guest if the Host leaves).
2. **Autoload Handling (`NetworkManager`):** [`autoload/network_manager.gd`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/autoload/network_manager.gd) catches `_on_peer_disconnected(id)`, removes `id` from `connected_peers`, emits `status_changed("Survivor (Peer X) disconnected.")`, and re-emits `peer_disconnected(id)`. If the host disconnected (`_on_server_disconnected`), `NetworkManager.leave_game()` closes the socket and restores `multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()`.
3. **Scene & UI Response (`level_01.gd` & `lobby.gd`):**
   - If a **guest** disconnects mid-match, `_on_coop_peer_disconnected(id)` in [`scenes/levels/level_01.gd`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/scenes/levels/level_01.gd) spawns a floating alert (`"SQUADMATE (PEER X) DISCONNECTED"`), frees that peer's character avatar (`squad_peers[id].queue_free()`), and allows the remaining survivors to continue without freezing.
   - If the **host** disconnects mid-match, `_on_coop_server_disconnected()` unpauses the tree, calls `leave_game()`, and transitions the guest cleanly back to `res://scenes/ui/lobby.tscn` with `[ HOST DISCONNECTED — RETURNING TO LOBBY IDLE ]`.

### Question 6: Pick the lowest-scoring construct from your playtest survey. What did the numbers tell you, and what concrete change did you make (or would you make next)?
During our initial formative playtest ($N = 12$), **Perceived Ease of Use (`PEOU`, specifically `PEOU3: "I did not need help to figure out how to play"`, $\mu = 4.67$, and `MULTI2: "Online mode connected to another player without problems"`, $\mu = 4.83$)** had the lowest individual item minimums ($4.00$) due to two concrete friction points:
1. First-time players on Level 1 did not immediately realize they could dash through zombie encirclements or how many waves remained at the start of the sector.
2. Players hosting on laptops with WSL/Docker installed saw virtual adapter IPs (`172.x.x.x`) instead of their physical Wi-Fi IP (`192.168.x.x`).
**Concrete Changes Made:**
- Added `_show_level_start_objective_and_tutorial()` in [`scenes/levels/level_01.gd`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/scenes/levels/level_01.gd) to display a bold objective banner (`"★ GOAL: SURVIVE 3 WAVES IN SECTOR 01 ★"`) and a first-time touch-control hint overlay on Level 1.
- Added `get_smart_ip_list()` in [`autoload/network_manager.gd`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/autoload/network_manager.gd) to rank physical Wi-Fi/Hotspot interfaces (`+100`) above virtual adapters (`-50`) and added a 1-tap `COPY IP` banner in [`scenes/ui/lobby.gd`](file:///c:/Users/Yuri/Desktop/Game Dev/boxhead-survival/scenes/ui/lobby.gd).

---

## Part 2: Automated CI/CD from Local Dev to GitHub to Deployment Server (Lab PDF 2, Page 16)

### Question 1: Why does the `deploy` job use `needs: test` and an `if:` condition checking both `github.ref` and `github.event_name`? What would happen on a pull request without that `if:`?
- `needs: test` enforces a strict quality gate: the `deploy` job will never run if ESLint or any unit test in `test/app.test.js` fails.
- `if: github.ref == 'refs/heads/main' && github.event_name == 'push'` ensures deployment to the production server only happens when commits are actually pushed/merged into `main`.
- **Without that `if:` condition:** Opening or updating an unreviewed Pull Request targeting `main` would pass `test` and immediately deploy untrusted/unmerged PR branch code onto the production server!

### Question 2: How does the self-hosted runner receive jobs from GitHub without you opening any inbound firewall ports on the deployment server?
The GitHub Actions self-hosted runner service (`actions.runner.*`) initiates **outbound HTTPS (`TCP 443`) long-polling connections** from the deployment server to `https://api.github.com` and `*.actions.githubusercontent.com`. Because the connection is initiated outbound by the runner and kept alive over TLS, the deployment server's firewall (`ufw`) can block all inbound ports except SSH (`22`) and the web service (`8080`) while still receiving jobs immediately.

### Question 3: Walk through how the git commit SHA gets from `git push` all the way into the JSON returned by `/health`. List every file it passes through.
1. **Git Push:** Developer runs `git push origin main`, creating commit SHA `${{ github.sha }}` on GitHub.
2. **`.github/workflows/ci-cd.yml`:** In the `deploy` job, GitHub Actions injects `APP_VERSION: ${{ github.sha }}`, truncates it to 7 characters (`SHORT_SHA=$(echo "$APP_VERSION" | cut -c1-7)`), exports `APP_VERSION=$SHORT_SHA`, and runs `docker compose up -d --build`.
3. **`compose.yaml`:** Reads `${APP_VERSION:-dev}` from the shell environment and passes `args: APP_VERSION: ${APP_VERSION:-dev}` into the Docker build context and tags the image `itsd85-app:${APP_VERSION:-dev}`.
4. **`Dockerfile`:** Declares `ARG APP_VERSION=dev` and bakes it into the container environment via `ENV APP_VERSION=$APP_VERSION`.
5. **`src/app.js`:** Reads `const version = process.env.APP_VERSION || "dev"` at startup and returns `{ status: "ok", version }` from `GET /health`.

### Question 4: What would happen if the new container starts, listens on port 3000, and then crashes 3 seconds later? How does the health-check loop in the workflow catch or miss this?
In `.github/workflows/ci-cd.yml`, the health-check step polls `curl -fsS http://localhost:8080/health` up to 15 times with a 2-second sleep. If the container starts and responds on the very first poll ($t = 0\text{s}$) before crashing at $t = 3\text{s}$, a single immediate poll could produce a false positive. However, Docker Compose's `HEALTHCHECK` (`--start-period=5s --interval=10s`) and `restart: unless-stopped` detect the crash; to harden the workflow against delayed startup crashes, waiting `sleep 4` before polling or requiring 2 consecutive passing `/health` checks ensures the process remains stable after initialization.

### Question 5: What is one security risk of running a self-hosted runner on the same machine as production, and how did we reduce (or how could you further reduce) that risk?
- **Risk:** Any workflow code executed by the runner runs directly on the production host as the `deploy` user (who belongs to the `docker` group, which is effectively root-equivalent on the host). If a malicious third-party fork opened a Pull Request that ran on the self-hosted runner, it could compromise the server.
- **Mitigation Applied & Further Hardening:**
  1. We kept the repository **Private** (or restricted self-hosted runner execution strictly to the `deploy` job guarded by `if: github.ref == 'refs/heads/main' && github.event_name == 'push'`, while running `test` on GitHub-hosted `ubuntu-latest`).
  2. We ran the runner under a dedicated non-root `deploy` service account rather than `root`.
  3. Further hardening: Run rootless Docker, restrict `main` branch pushes via branch protection rules requiring PR review, and isolate the runner in an ephemeral VM or separate host from the production runtime.

### Question 6: If you wanted zero-downtime deploys (no brief connection drop while the container restarts), what would you change in `compose.yaml` or the server setup?
With a single container bound directly to host port `8080:3000`, `docker compose up -d` must stop `itsd85-web` to release port `8080` before starting the new container, causing a 1–2 second connection drop. To achieve **zero-downtime blue/green or rolling deploys**:
1. Remove the fixed `container_name: itsd85-web` and fixed host port binding in `compose.yaml`.
2. Place a reverse proxy (**Nginx**, **Caddy**, or **Traefik**) on port `80`/`8080` in front of the `web` service.
3. Scale up the new version alongside the old one (`docker compose up -d --build --scale web=2 --no-recreate`), wait until the new container passes `/health`, and then terminate the old container so the reverse proxy never drops an in-flight request.
