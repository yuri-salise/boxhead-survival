# Game Design Document (GDD) — Dead Block: Survival

## 1. Game Overview

**Working Title:** Dead Block: Survival  
**Genre:** Top-Down 2D Zombie Survival Shooter  
**Target Engine:** Godot 4.x Standard Edition (GDScript)  
**Primary Target:** Android Mobile  
**Secondary Target:** Desktop (Windows/macOS/Linux for rapid testing)  
**Design Viewport:** 1280 × 720 (Landscape, `canvas_items` stretch, `expand` aspect)  
**Renderer:** Compatibility (`gl_compatibility`) for broad mobile GPU support  

### High Concept
*Dead Block: Survival* is an intense top-down arena survival shooter inspired by the fast-paced gameplay loop of classic zombie arena games. Set against a gritty, bleak, post-apocalyptic backdrop, players fight to survive escalating waves of the infected across five increasingly dangerous urban quarantine zones, either solo offline or in 2-player local co-op.

---

## 2. Core Gameplay Loop

```
       [ Main Menu ]
             │
      [ Mode / Level Select ]
             │
             ▼
      [ Arena Combat Loop ]
      - 8-directional movement
      - 360-degree aiming & shooting
      - Zombie pursuit AI
      - Wave escalation & survival
             │
      ┌──────┴──────┐
      ▼             ▼
  [ Victory ]   [ Defeat ]
      │             │
  Save Progress  Retry / Menu
  Unlock Level+1
```

1. **Start Match:** Player chooses Offline Campaign or LAN Co-op, selecting an unlocked level.
2. **Survive Waves:** Player maneuvers around the arena, aiming and shooting approaching infected.
3. **Escalation:** Waves increase in count and intensity with clear HUD feedback.
4. **Outcome:**
   - **Victory:** Objective achieved (all waves eliminated). Next level is unlocked and saved to persistent storage (`user://save.cfg`).
   - **Defeat:** All players succumb to zombie attacks. Option to retry immediately or return to menu.

---

## 3. Campaign Level Progression

The minimum campaign consists of five progressively difficult levels:

| Level | Title | Objective | Key Mechanics & Progression |
|---|---|---|---|
| **1** | **Quarantine** | Survive 3 short waves | Teaches core movement, twin-stick aim, shooting, and health management. |
| **2** | **The Street** | Clear 4 waves | Higher zombie volume, shorter spawn intervals between waves. |
| **3** | **No Exit** | Survive 5 waves | Introduces tighter obstacle choke points and durable enemy variants. |
| **4** | **The Depot** | Clear 5 waves | Unpredictable spawn vectors and reduced open maneuvering space. |
| **5** | **Last Light** | Survive the final assault | Maximum horde density, persistent pressure, climax encounter. |

---

## 4. Control Schemes

### Desktop (Development & Rapid Testing)
- **Movement:** `W`, `A`, `S`, `D` or Arrow Keys (8 directions)
- **Aiming:** Mouse Cursor (360° orientation)
- **Firing:** Left Mouse Button (Primary weapon with cooldown)
- **Pause / Menu:** `Escape`

### Android Mobile (Primary Production Target)
- **Left Virtual Joystick:** 8-directional or analog movement.
- **Right Aim & Fire Region:** Touch-drag to aim; tap/hold to shoot.
- **HUD Pause Button:** Top-right corner with ample thumb margin to avoid notch overlap.
- **Responsive Sizing:** Minimum 48–64 dp touch targets for comfortable mobile interaction.

---

## 5. Visual & Audio Direction

- **Palette:** Bleak, grounded, desaturated:
  - Backgrounds: Dirty concrete (`#181a1b`), asphalt, rusted metal (`#4a2e2b`).
  - Player: Muted olive / slate jacket with bright muzzle flash contrast.
  - Zombies: Rotten grey / pale flesh tones with high silhouette contrast.
  - UI: Charcoal slabs with muted blood-red (`#8b2626`) accents and bone-white text.
- **Lighting & FX:** Restrained, performance-friendly 2D effects (muzzle flashes, impact sparks, blood decals) optimized for mobile fill rate.
- **Audio:** Crisp gunshots, dry metallic reloads, tense atmospheric drones, and visceral zombie audio cues.

---

## 6. Architecture & Non-Negotiable Rules

1. **Host-Authoritative Networking:** In multiplayer, the host owns zombie AI, wave progression, damage calculation, and win/loss states.
2. **Offline-First Resilience:** Offline solo play never initializes network sockets or requires connectivity.
3. **Graceful Disconnects:** Online errors notify the user cleanly and return to lobby without hanging or crashing.
4. **Data Integrity:** Save data persists in `user://save.cfg` with safe schema fallbacks.
