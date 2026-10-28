# Branding and Splash Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement official branding for *Dead Block: Survival*, including a custom high-contrast game logo, updated app icon, engine boot splash, polished interactive splash/title screen, and main menu branding integration.

**Architecture:** Original SVG/PNG branding assets stored in `res://assets/art/`. `project.godot` configured with boot splash settings and `title_screen.tscn` set as the initial boot scene (`run/main_scene`). `title_screen.gd` coordinates the intro splash sequence (studio watermark, animated logo reveal, skip-on-touch/click/key input, and auto-transition to `main_menu.tscn`).

**Tech Stack:** Godot 4.7.2 Standard Edition, GDScript (typed), Compatibility Renderer, Vector SVG & PNG graphics, `Bebas Neue` & `Special Elite` fonts, `AudioManager`.

**Spec:** [`AGENTS.md`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/AGENTS.md), [`docs/GDD.md`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/docs/GDD.md), and [`docs/IMPLEMENTATION.md`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/docs/IMPLEMENTATION.md).

---

## Global Constraints

- **Engine Floor:** Godot 4.7.2 Standard with GDScript only. No C# or external engine plugins.
- **Renderer Target:** Compatibility renderer (`gl_compatibility`) for desktop and Android.
- **Design Resolution:** 1280 × 720 landscape with `canvas_items` stretch and `expand` aspect.
- **Scene Flow:** `TitleScreen` (`res://scenes/ui/title_screen.tscn`) → `MainMenu` (`res://scenes/ui/main_menu.tscn`) → `ModeSelect`.
- **Aesthetic Direction:** Gritty, desaturated post-apocalyptic survival-horror mood with charcoal `#0d0f11`, dirty concrete `#181a1b`, hazard amber `#d97706`, and muted blood-red `#8b2626` accents.
- **Asset Compliance:** 100% original vector assets; all artwork logged in [`docs/CREDITS.md`](file:///c:/Users/Yuri/Desktop/Game%20Dev/boxhead-survival/docs/CREDITS.md).
- **Responsive & Touch-Friendly:** Splash screen must support tap-to-skip anywhere on mobile screens and any keyboard/mouse button press on desktop.

---

## Review Focus

1. **Input Responsiveness During Splash:** Player taps screen immediately upon launch. (Expected: Scene promptly skips intro delay and immediately transitions to Main Menu without double-transition bugs or audio crashes).
2. **Resolution Scaling & Aspect Ratio:** Viewport rendered on non-16:9 displays (e.g. ultra-wide or 18:9 mobile screens). (Expected: Logo, warning text, and prompts stay centered and within safe margins without clipping).
3. **Asset Loading Validity:** Godot engine boots headless and in GUI mode. (Expected: `ResourceLoader.load()` cleanly parses all SVGs and PNGs without warnings or missing textures).
4. **App Icon Integrity:** Export presets and window taskbar icons reflect the custom Dead Block icon rather than the default Godot robot head. (Expected: `icon.svg` and `icon.png` render valid vector shapes with correct bounds).
5. **Backwards Compatibility:** Automated test suite and all 21 test scenes continue to pass with zero regressions. (Expected: `tests/run_all_tests.gd` and `test_all_scenes_load.gd` pass).

---

## Tasks

### Task 1: Create Branding Assets (Game Logo, Studio Badge, Boot Splash, App Icon)

**Files:**
- Create: `assets/art/dead_block_logo.svg`
- Create: `assets/art/dead_block_logo.png`
- Create: `assets/art/outpost_logo.svg`
- Create: `assets/art/boot_splash.png`
- Modify: `icon.svg`
- Modify: `docs/CREDITS.md`

**Interfaces:**
- Produces: Vector and raster textures importable by Godot's `Texture2D` loader for UI and engine boot splash.

- [ ] **Step 1: Design and generate `assets/art/dead_block_logo.svg` and `assets/art/dead_block_logo.png`**
  - Dimensions: 800 × 260.
  - Visual: Weathered concrete block emblem, dual blood scratches, biohazard/hazard crosshair symbol, stencil typography "DEAD BLOCK" with drop shadow, and sub-banner "SURVIVAL // QUARANTINE PROTOCOL".
- [ ] **Step 2: Design and generate `assets/art/outpost_logo.svg`**
  - Dimensions: 480 × 120.
  - Visual: Stylized transmission radar / hazard triangle with "OUTPOST LABS // ITSD 85 PRESENTATION".
- [ ] **Step 3: Generate `assets/art/boot_splash.png`**
  - Dimensions: 1280 × 720 (crisp RGBA PNG).
  - Visual: Dark textured background (`#0d0f11`), vignette, centered Dead Block logo and subtitle for instant engine-level boot.
- [ ] **Step 4: Update `icon.svg` with the original Dead Block: Survival branding icon**
  - Replace default Godot blue robot head with 512 × 512 high-contrast survival icon (charcoal shield block, crimson biohazard skull mark, crossed hazard tape).
- [ ] **Step 5: Document new branding artwork in `docs/CREDITS.md`**

---

### Task 2: Configure Engine Boot Splash & Main Scene in `project.godot`

**Files:**
- Modify: `project.godot`

**Interfaces:**
- Consumes: `res://assets/art/boot_splash.png`, `res://scenes/ui/title_screen.tscn`.
- Produces: Godot engine startup settings displaying the official boot splash and routing directly into `title_screen.tscn`.

- [ ] **Step 1: Update `project.godot` with boot splash and main scene configurations**
  - `application/run/main_scene="res://scenes/ui/title_screen.tscn"`
  - `application/boot_splash/bg_color=Color(0.06, 0.07, 0.08, 1)`
  - `application/boot_splash/image="res://assets/art/boot_splash.png"`
  - `application/boot_splash/fullsize=true`
  - `application/boot_splash/use_filter=true`

---

### Task 3: Build Interactive Splash / Title Screen Scene & Script

**Files:**
- Create: `scenes/ui/title_screen.tscn`
- Create: `scenes/ui/title_screen.gd`

**Interfaces:**
- Consumes: `res://assets/art/dead_block_logo.svg`, `res://assets/art/outpost_logo.svg`, `res://autoload/audio_manager.gd`.
- Produces: Playable intro sequence, tap/click/key input listener, auto-advance timer, smooth scene transition to `res://scenes/ui/main_menu.tscn`.

- [ ] **Step 1: Write `scenes/ui/title_screen.gd`**
  - Features:
    - Sequence timer: Phase 1 (Studio intro fade in/out), Phase 2 (Game logo reveal with subtle scale & alpha tween), Phase 3 (Pulse prompt "TAP SCREEN OR PRESS ANY KEY").
    - Auto-advance to `res://scenes/ui/main_menu.tscn` after ~3.5s or on `_gui_input` / `_unhandled_input` (touch, mouse click, any key).
    - Audio cue: plays subtle atmospheric stinger on reveal.
    - Prevents double transitions with a guard boolean `is_transitioning`.
- [ ] **Step 2: Build `scenes/ui/title_screen.tscn`**
  - Node hierarchy:
    - `TitleScreen` (`Control`, full rect)
      - `Background` (`ColorRect`, `#0a0b0d`)
      - `Vignette` (`ColorRect` / dark accent gradient)
      - `CenterContainer` (centered layout)
        - `VBoxContainer`
          - `StudioBadge` (`TextureRect` / `Label` for Outpost Labs / ITSD 85)
          - `LogoTexture` (`TextureRect` using `res://assets/art/dead_block_logo.svg`)
          - `SubtitleLabel` ("SURVIVE OR JOIN THEM")
          - `PromptLabel` ("TAP ANYWHERE OR PRESS ANY KEY TO ENTER")
      - `FooterLabel` ("DEAD BLOCK: SURVIVAL · ITSD 85 DIRECTIVE")
      - `FadeOverlay` (`ColorRect` for smooth screen fade)

---

### Task 4: Integrate Logo Branding into Main Menu

**Files:**
- Modify: `scenes/ui/main_menu.tscn`

**Interfaces:**
- Consumes: `res://assets/art/dead_block_logo.svg`.
- Produces: Elevated title header featuring the graphical logo texture above or in place of the plain label, maintaining consistent theme layout.

- [ ] **Step 1: Update `scenes/ui/main_menu.tscn` TitleBox**
  - Add `LogoRect` (`TextureRect`) referencing `res://assets/art/dead_block_logo.svg` with keep-aspect-centered expand mode.
  - Maintain the existing `PreTitle` tag and `SubtitleLabel` for clean visual hierarchy.

---

### Task 5: Verification & Testing

**Files:**
- Create: `tests/test_branding_and_splash.gd`
- Modify: `tests/run_all_tests.gd`

**Interfaces:**
- Consumes: `res://scenes/ui/title_screen.tscn`, `res://assets/art/dead_block_logo.svg`, `res://assets/art/boot_splash.png`, `res://icon.svg`.
- Produces: Automated verification confirming all branding assets exist, validly instantiate, and transition logic functions without errors.

- [ ] **Step 1: Create `tests/test_branding_and_splash.gd`**
  - Verify `icon.svg` is customized.
  - Verify `dead_block_logo.svg` and `boot_splash.png` exist and load as valid `Texture2D`.
  - Verify `title_screen.tscn` instantiates, has `LogoTexture`, `PromptLabel`, and `title_screen.gd` script.
  - Verify transition method `_advance_to_main_menu()` can be triggered safely.
- [ ] **Step 2: Add test to `tests/run_all_tests.gd` and execute suite**
  - Run Godot headless test runner:
    `& "C:\Users\Yuri\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" -s tests/run_all_tests.gd --headless`
  - Run `tests/test_all_scenes_load.gd` to ensure `title_screen.tscn` instantiates cleanly.
- [ ] **Step 3: Verify desktop game launch**
  - Run Godot briefly to confirm startup screen and transition to main menu.
