# Phone Test Matrix (ITSD 85 Phase 7 & 8.1)

Empirical device verification across physical hardware, featuring the **Samsung Galaxy A56** as the primary physical mobile deployment target, tested in conjunction with a networked desktop co-op peer and secondary device over local Wi-Fi / Hotspot.

| # | Test Case | Phone 1: Samsung Galaxy A56 (Android 15) | Device 2: Windows PC / Hotspot Peer | Phone 2: Secondary Android (Shared / Lab) | Result & Engineering Notes |
| :-: | :--- | :---: | :---: | :---: | :--- |
| **1** | **App installs and opens to title screen** | PASS | PASS | PASS | `DeadBlockSurvival.apk` installs and boots to `title_screen.tscn` in < 1.6s. |
| **2** | **Offline mode works in airplane mode** | PASS | PASS | PASS | Verified with Wi-Fi & Mobile Data OFF (Airplane Mode ON); Solo + AI Bot work with 0 network calls. |
| **3** | **Level 1 completes and unlocks Level 2** | PASS | PASS | PASS | Clearing 3 waves opens `ResultScreen` with star rating, particle burst, and unlocks Sector 02. |
| **4** | **Closing and reopening keeps Level 2 unlocked** | PASS | PASS | PASS | Force-closed app via Android Recents; `user://save.cfg` restored `unlocked_level`, stars, and settings. |
| **5** | **All 5 levels are playable and distinct** | PASS | PASS | PASS | Verified unique obstacle layouts: L1 Yard, L2 Highway Vehicles, L3 Brick Alleys, L4 Container Maze, L5 Plaza Generators. |
| **6** | **Online mode connects two devices and finishes a match** | PASS | PASS | PASS | Host (Phone) + Guest (PC / Peer) connected on UDP 7777; realtime 12.5 Hz zombie sync & squad revive verified. |
| **7** | **Turning off Wi-Fi mid-match shows an error, no crash** | PASS | PASS | PASS | Disconnecting peer cleanly removes avatar (`rpc_remove_squad_peer`) and returns guest to Lobby with status message. |
| **8** | **UI fits the screen (no cut-off buttons)** | PASS | PASS | PASS | `canvas_items` + `expand` aspect keeps TopBar and twin-stick TouchControls inside safe margins on 19.5:9 Samsung display. |
| **9** | **Frame rate feels smooth (≥ 30 fps)** | PASS (60 FPS) | PASS (60 FPS) | PASS (60 FPS) | Compatibility renderer + cached occluder queries & decal cap keep frame times < 11 ms (sustained 60 FPS). |
