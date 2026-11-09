# ITSD 85 Individual Contribution Log

**Course:** ITSD 85 – Special Topics in Software Development  
**Laboratory Title:** Mobile Game Development with Level Progression and Offline/Online Multiplayer  
**Game Title:** Dead Block: Survival  
**Student Name:** [Your Full Name]  
**Student ID / Email:** [Your ID / Email]  
**Role in Team:** [e.g., Lead Developer / Networking & Gameplay Engineer / UI & Audio Designer]  
**GitHub Account Username:** [@your-github-handle]  
**Repository URL:** https://github.com/[your-team]/[your-repo]  
**Date Submitted:** November 9, 2026  

---

## 1. Summary of Individual Contributions

| Contribution Area | Specific Features / Modules Implemented | Associated Files |
| :--- | :--- | :--- |
| **Core Gameplay & AI** | Built player twin-stick locomotion, tactical dash invulnerability, and offline `BRAVO BOT` companion with kiting and medical heal logic. | `scripts/player.gd`, `scripts/weapon_controller.gd` |
| **Enemy Engineering** | Implemented 14 specialized zombie variants including the apex boss `Necro` (passive healing aura, witch coven), Boomer explosions, and Spitter acid mortars. | `scripts/zombie_basic.gd`, `scenes/actors/zombie_basic.tscn` |
| **Progressive Level Design** | Designed Sectors 1–5 procedural chunk generation, vehicle roadblocks, and blackout plaza generator defense stations. | `scripts/arena_environment.gd`, `scenes/levels/level_01.tscn`..`05.tscn` |
| **Multiplayer Networking** | Built host-authoritative ENet LAN synchronization at 12.5 Hz, client hit verification, squadmate revive, and graceful disconnect recovery. | `autoload/network_manager.gd`, `scenes/ui/lobby.gd` |
| **Testing & CI/CD** | Authored headless test suites (23 Godot suites + Node.js suite) and configured GitHub Actions automated deployment. | `tests/`, `.github/workflows/ci-cd.yml` |
| **Academic Paper** | Authored Sections III (Game Design), IV (Architecture), and V (Methodology) in the IEEE conference paper. | `docs/paper/ieee_paper.md`, `docs/paper.pdf` |

---

## 2. Verified Git Commit Log

*Note: Below are the direct permanent commit URLs verifying my individual authorship on GitHub:*

1. **Commit [Short SHA 1]:** `Add player twin-stick movement, dash iframe cooldown, and HUD controls`  
   *URL:* `https://github.com/[your-repo]/commit/[commit_sha_1]`  
   *Description:* Implemented analog stick drag vector math and dash velocity boost.

2. **Commit [Short SHA 2]:** `Implement host-authoritative ENet zombie synchronization and revive`  
   *URL:* `https://github.com/[your-repo]/commit/[commit_sha_2]`  
   *Description:* Created quantized 12.5 Hz state broadcast and remote client hit validation.

3. **Commit [Short SHA 3]:** `Add Sector 1–5 distinct layouts and interactive perimeter generators`  
   *URL:* `https://github.com/[your-repo]/commit/[commit_sha_3]`  
   *Description:* Built procedural obstacle geometry and diesel fuel truck mechanics.

4. **Commit [Short SHA 4]:** `Implement 14 infected variants and apex Necro boss AI`  
   *URL:* `https://github.com/[your-repo]/commit/[commit_sha_4]`  
   *Description:* Added custom sound triggers, healing aura, and witch escort hierarchy.

5. **Commit [Short SHA 5]:** `Configure GitHub Actions CI/CD workflow and Docker Compose service`  
   *URL:* `https://github.com/[your-repo]/commit/[commit_sha_5]`  
   *Description:* Orchestrated Node.js 24 linting, unit testing, and `/health` verification.

---

## 3. Reflection on Teamwork & Challenges Overcome

During the 5-week development lifecycle, I collaborated actively with my teammates through GitHub feature branches, peer pull request reviews, and physical device playtesting. One of our most significant technical hurdles was mobile network desynchronization, which we resolved by eliminating peer-to-peer client authority and enforcing strict host-authoritative state resolution. Working within Godot's standard GDScript and the Android `gl_compatibility` renderer allowed our team to maintain 60 FPS performance while shipping a complete 5-level vertical slice on zero budget.
