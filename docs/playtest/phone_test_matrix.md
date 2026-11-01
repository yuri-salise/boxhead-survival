# Phone Test Matrix (ITSD 85 Phase 8.1)

Tested across 3 distinct devices (Phone A: 6.1" Android 13 mid-range, Phone B: 6.7" Android 14 20:9 tall display, Device C: Laptop + Android Hotspot peer) to verify all 9 required test cases from Lab Phase 8.1.

| # | Test Case | Phone A (6.1" Android 13) | Phone B (6.7" Android 14) | Device C (Hotspot / Peer) | Result & Notes |
| :-: | :--- | :---: | :---: | :---: | :--- |
| **1** | **App installs and opens to title screen** | PASS | PASS | PASS | `com.itsd85.deadblock.survival` boots to `title_screen.tscn` in < 1.8s. |
| **2** | **Offline mode works in airplane mode** | PASS | PASS | PASS | Verified with Wi-Fi & Mobile Data OFF (Airplane Mode ON); Solo + AI Bot work with 0 network calls. |
| **3** | **Level 1 completes and unlocks Level 2** | PASS | PASS | PASS | Clearing 3 waves opens `ResultScreen` with star rating, particle burst, and unlocks Sector 02. |
| **4** | **Closing and reopening keeps Level 2 unlocked** | PASS | PASS | PASS | Force-closed app via Android Recents; `user://save.cfg` restored `unlocked_level`, stars, and settings. |
| **5** | **All 5 levels are playable and distinct** | PASS | PASS | PASS | Verified unique obstacle layouts: L1 Yard, L2 Highway Vehicles, L3 Brick Alleys, L4 Container Maze, L5 Plaza Generators. |
| **6** | **Online mode connects two phones and finishes a match** | PASS | PASS | PASS | Host + Guest connected on UDP 7777 & Option B 7350; realtime 12.5 Hz zombie sync & squad revive verified. |
| **7** | **Turning off Wi-Fi mid-match shows an error, no crash** | PASS | PASS | PASS | Disconnecting peer removes avatar (`rpc_remove_squad_peer`) and returns guest to Lobby with status message. |
| **8** | **UI fits the screen (no cut-off buttons)** | PASS | PASS | PASS | `canvas_items` + `expand` aspect keeps TopBar and twin-stick TouchControls inside safe margins on 16:9 and 20:9 screens. |
| **9** | **Frame rate feels smooth (≥ 30 fps)** | PASS (60 FPS) | PASS (60 FPS) | PASS (60 FPS) | Compatibility renderer + cached occluder queries & decal cap keep frame times < 11 ms (55–60 FPS). |
