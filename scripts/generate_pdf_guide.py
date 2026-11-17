import os
import sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        if self._pageNumber == 1:
            return  # Cover page

        self.saveState()
        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#4a5568"))

        # Running Header
        header_text = "DEAD BLOCK: SURVIVAL — Architecture & Lab Defense Manual (v1.1)"
        self.drawString(54, 11 * inch - 36, header_text)
        self.setStrokeColor(colors.HexColor("#cbd5e0"))
        self.setLineWidth(0.5)
        self.line(54, 11 * inch - 40, 8.5 * inch - 54, 11 * inch - 40)

        # Running Footer
        self.setFont("Helvetica", 8)
        footer_text = "ITSD 85: Special Topics in Software Development | Production & Defense Reference"
        self.drawString(54, 34, footer_text)
        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(8.5 * inch - 54, 34, page_str)
        self.setStrokeColor(colors.HexColor("#cbd5e0"))
        self.setLineWidth(0.5)
        self.line(54, 44, 8.5 * inch - 54, 44)

        self.restoreState()

def build_pdf(filename="docs/Dead_Block_Survival_Complete_Guide_and_Defense.pdf"):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=50,
        bottomMargin=50
    )

    styles = getSampleStyleSheet()

    # Color Palette
    c_primary = colors.HexColor("#1a202c")    # Dark Charcoal
    c_secondary = colors.HexColor("#2b6cb0")  # Tactical Blue
    c_accent = colors.HexColor("#9b2c2c")     # Crimson Alert
    c_dark_green = colors.HexColor("#276749") # Olive military
    c_body = colors.HexColor("#2d3748")       # Off-black body
    c_bg_light = colors.HexColor("#f7fafc")   # Card background
    c_border = colors.HexColor("#cbd5e0")     # Light border

    # Custom Typography Styles
    title_style = ParagraphStyle(
        'CoverTitle',
        parent=styles['Title'],
        fontName='Helvetica-Bold',
        fontSize=25,
        leading=31,
        textColor=c_accent,
        alignment=0,
        spaceAfter=6
    )
    subtitle_style = ParagraphStyle(
        'CoverSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=11.5,
        leading=15,
        textColor=c_secondary,
        alignment=0,
        spaceAfter=14
    )
    h1_style = ParagraphStyle(
        'SectionH1',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=14,
        leading=18,
        textColor=c_primary,
        spaceBefore=12,
        spaceAfter=5,
        keepWithNext=True
    )
    h2_style = ParagraphStyle(
        'SectionH2',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=13,
        textColor=c_secondary,
        spaceBefore=7,
        spaceAfter=2,
        keepWithNext=True
    )
    h3_style = ParagraphStyle(
        'SectionH3',
        parent=styles['Heading3'],
        fontName='Helvetica-Bold',
        fontSize=9,
        leading=12,
        textColor=c_accent,
        spaceBefore=7,
        spaceAfter=2,
        keepWithNext=True
    )
    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.2,
        leading=11.5,
        textColor=c_body,
        spaceAfter=4
    )
    bullet_style = ParagraphStyle(
        'BulletText',
        parent=body_style,
        leftIndent=12,
        firstLineIndent=-8,
        spaceAfter=2.5
    )
    code_style = ParagraphStyle(
        'CodeSnippet',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=7,
        leading=9.5,
        textColor=colors.HexColor("#1a202c"),
        backColor=colors.HexColor("#edf2f7"),
        borderColor=colors.HexColor("#cbd5e0"),
        borderWidth=0.5,
        borderPadding=4,
        spaceBefore=3,
        spaceAfter=5
    )

    story = []

    # =========================================================================
    # COVER PAGE
    # =========================================================================
    story.append(Spacer(1, 20))
    story.append(Paragraph("DEAD BLOCK: SURVIVAL", title_style))
    story.append(Paragraph("Comprehensive Technical Architecture, Module Reverse-Engineering, and Academic Defense Handbook", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=2.5, color=c_accent, spaceBefore=3, spaceAfter=14))

    meta_text = """
    <b>Course:</b> ITSD 85 – Special Topics in Software Development<br/>
    <b>Laboratory Focus:</b> Mobile Game Development (Level Progression &amp; Offline/Online Multiplayer) &amp; Automated CI/CD Pipeline<br/>
    <b>Authors / Developers:</b> BSIT Software Development Project Team<br/>
    <b>Game Engine &amp; Language:</b> Godot Engine 4.x Standard Edition | GDScript (GL Compatibility Renderer, Sensor-Landscape)<br/>
    <b>DevOps &amp; Infrastructure:</b> Node.js 24 LTS, Express, Docker Compose (-p itsd85), GitHub Actions (Ubuntu-Latest), Nakama<br/>
    <b>Deployment Targets:</b> Android APK (Hardware Sideload, 1024x1024 App Icon) &amp; Ubuntu Linux Server Container<br/>
    <b>Version &amp; Status:</b> v1.1 Production Release | Updated with Photometric Lighting, UI Icons, Distance Gating &amp; CI/CD Streamlining
    """
    story.append(Paragraph(meta_text, body_style))
    story.append(Spacer(1, 10))

    overview_box = [
        [Paragraph("<b>HOW TO USE THIS REVISED MANUAL FOR YOUR ORAL EXAMINATION &amp; CODE DEFENSE</b>", ParagraphStyle('BoxH', parent=body_style, fontName='Helvetica-Bold', textColor=c_primary))],
        [Paragraph(
            "This updated reference incorporates all recent engineering enhancements across the five architecture pillars: "
            "<b>(1) Photometric Soft Gradient Lighting:</b> Dynamic radial falloff textures and penumbra dithering replacing flat discs; "
            "<b>(2) Custom SVG Iconography:</b> Vector SVG icons resolving missing font glyphs across all menus; "
            "<b>(3) Interactable Distance Gating:</b> Proximity validation (64px) preventing remote interaction exploits; "
            "<b>(4) Off-Screen Spawning &amp; Obstacle Slide Steering:</b> Restricting zombie spawns outside the camera view and eliminating teleports; "
            "<b>(5) Streamlined CI/CD &amp; Docker Security:</b> Cloud-native GitHub Actions deployment on <code>ubuntu-latest</code>, "
            "non-root container execution (<code>USER node</code>), and <code>.dockerignore</code> optimization.<br/>"
            "Sections 7–9 provide verified answers to the official ITSD 85 guide questions, the complete R1–R10 acceptance matrix, "
            "and a minute-by-minute 7-minute live demonstration playbook.",
            body_style
        )]
    ]
    t_overview = Table(overview_box, colWidths=[7.0 * inch])
    t_overview.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#ebf8ff")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#3182ce")),
        ('PADDING', (0,0), (-1,-1), 7),
    ]))
    story.append(t_overview)
    story.append(Spacer(1, 10))

    toc_box = [
        [Paragraph("<b>TABLE OF CONTENTS</b>", ParagraphStyle('TOCHead', parent=body_style, fontName='Helvetica-Bold', textColor=c_secondary))],
        [Paragraph(
            "<b>1. System Overview: Two Interconnected Subsystems</b> (Client Architecture vs Server Infrastructure)<br/>"
            "<b>2. Godot 4 Core Concepts for Beginners</b> (Nodes, Scenes, Scripts, Signals, Autoloads, 60 FPS Physics Loop)<br/>"
            "<b>3. The Visual Architecture: Procedural Vector Graphics &amp; Lighting</b> (Player, 14 Zombies, Dismemberment, LightFX)<br/>"
            "<b>4. Module-by-Module Code Reverse-Engineering</b> (GameState, NetworkManager, Audio, Weapons, Wave Director)<br/>"
            "<b>5. Docker Deep Dive: How It Works &amp; Is It Used?</b> (Node.js API, Nakama, Line-by-Line Dockerfile, .dockerignore)<br/>"
            "<b>6. The Automated CI/CD Pipeline</b> (GitHub Actions, Cloud Runner, Outbound Security, Health Verification)<br/>"
            "<b>7. Lab Defense Guide Questions</b> (Official Q&amp;A for Mobile Game and Automated CI/CD)<br/>"
            "<b>8. Acceptance Criteria Verification Matrix</b> (Formal Checklist: R1 through R10 Compliance Proof)<br/>"
            "<b>9. The 7-Minute Live Demonstration Playbook</b> (Step-by-Step Timed Presentation Script)",
            body_style
        )]
    ]
    t_toc = Table(toc_box, colWidths=[7.0 * inch])
    t_toc.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), c_bg_light),
        ('BOX', (0,0), (-1,-1), 0.5, c_border),
        ('PADDING', (0,0), (-1,-1), 7),
    ]))
    story.append(t_toc)
    story.append(PageBreak())

    # =========================================================================
    # SECTION 1: SYSTEM OVERVIEW
    # =========================================================================
    story.append(Paragraph("1. System Overview: The Two Projects in One Repository", h1_style))
    story.append(Paragraph(
        "A key understanding during architectural review is that this repository contains <b>two distinct, decoupled "
        "subsystems</b> operating within a monorepo, fulfilling the two major laboratory briefs of ITSD 85:",
        body_style
    ))

    dual_sys_data = [
        [
            Paragraph("<b>Dimension</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white)),
            Paragraph("<b>Subsystem 1: Godot Game Client</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white)),
            Paragraph("<b>Subsystem 2: DevOps &amp; Companion Server</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white))
        ],
        [
            Paragraph("<b>Application Role</b>", body_style),
            Paragraph("2D top-down survival horror shooter inspired by Boxhead with 5 campaign sectors, 100% offline play, and 2–4 player LAN co-op.", body_style),
            Paragraph("Automated build/test/deploy pipeline, containerized web portal, mock matchmaking API, and health verification.", body_style)
        ],
        [
            Paragraph("<b>Core Stack</b>", body_style),
            Paragraph("Godot Engine 4.x Standard, GDScript, GL Compatibility renderer, ConfigFile, ENet networking.", body_style),
            Paragraph("Node.js 24 LTS, Express, Docker Engine, Docker Compose, GitHub Actions runner, Nakama / CockroachDB.", body_style)
        ],
        [
            Paragraph("<b>Hardware Target</b>", body_style),
            Paragraph("Android smartphones (compiled APK) and desktop PC (Windows / Linux testing).", body_style),
            Paragraph("Ubuntu Linux 24.04 server (VirtualBox VM or cloud container).", body_style)
        ],
        [
            Paragraph("<b>Networking Model</b>", body_style),
            Paragraph("Peer-to-peer Wi-Fi / Hotspot LAN; strict Host-Authoritative architecture.", body_style),
            Paragraph("Outbound HTTPS (Port 443) Actions runner; Port 8080 host HTTP forward.", body_style)
        ],
        [
            Paragraph("<b>Offline Support</b>", body_style),
            Paragraph("100% playable in Airplane Mode. All progress saved locally in user://save.cfg.", body_style),
            Paragraph("N/A (Server and CI/CD rely on network connectivity).", body_style)
        ]
    ]
    t_dual = Table(dual_sys_data, colWidths=[1.2 * inch, 2.9 * inch, 2.9 * inch])
    t_dual.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_secondary),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('PADDING', (0,0), (-1,-1), 4.5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_light])
    ]))
    story.append(t_dual)
    story.append(Spacer(1, 6))

    # =========================================================================
    # SECTION 2: GODOT 4 CONCEPTS FOR BEGINNERS
    # =========================================================================
    story.append(Paragraph("2. Godot 4 Core Concepts: The Mental Model", h1_style))
    story.append(Paragraph(
        "For students transitioning from standard software engineering or AI-assisted development, Godot "
        "relies on four modular architectural primitives:",
        body_style
    ))

    godot_concepts = [
        "<b>Nodes (Building Blocks):</b> The smallest entity in Godot. Each node handles one focused responsibility: <code>CharacterBody2D</code> manages physical motion and collisions; <code>CollisionShape2D</code> defines boundaries; <code>Timer</code> triggers timed delays; and <code>AudioStreamPlayer</code> emits sounds.",
        "<b>Scenes (.tscn Files):</b> Hierarchies of organized Nodes saved as reusable templates. In <code>scenes/actors/player.tscn</code>, the survivor's physics body, collision boundary, camera, and weapon manager are bundled into a single entity that instantiates cleanly in any sector.",
        "<b>Scripts (.gd Files):</b> GDScript programs attached to nodes to govern behavior. GDScript is high-level, syntactically similar to Python, and compiles to optimized bytecode at runtime.",
        "<b>Signals (Observer Pattern):</b> Decoupled event broadcasting. When an entity takes damage or dies, it emits a signal (e.g., <code>signal player_died()</code>). Other nodes (HUD, camera shake, level referee) listen and respond without direct variable coupling.",
        "<b>Autoloads (Singletons):</b> Persistent background nodes that initialize at engine startup and persist permanently across scene transitions. In this project, <code>GameState</code>, <code>NetworkManager</code>, and <code>AudioManager</code> are Autoloads.",
        "<b>Processing Loops:</b> <code>_process(delta)</code> runs every graphical frame (variable rate, used for UI animations and camera smoothing). <code>_physics_process(delta)</code> runs at a fixed 60 ticks per second, guaranteeing identical bullet trajectories and collision detection on all hardware."
    ]
    for gc in godot_concepts:
        story.append(Paragraph(f"• {gc}", bullet_style))

    story.append(PageBreak())

    # =========================================================================
    # SECTION 3: VISUAL ARCHITECTURE & PROCEDURAL GRAPHICS
    # =========================================================================
    story.append(Paragraph("3. The Visual Architecture: Vector Graphics, Photometric Lighting &amp; Icons", h1_style))
    story.append(Paragraph(
        "A common observation is the near-total absence of PNG character spritesheets in <code>assets/art/</code>. "
        "<b>Dead Block: Survival renders characters, zombies, lighting, and icons entirely through code:</b>",
        body_style
    ))

    story.append(Paragraph("A. The Survivor (Player Character Construction)", h2_style))
    player_visual_points = [
        "<b>Directional Cast &amp; Contact Shadows:</b> In <code>scripts/player.gd</code>, overlapping translucent circles and angled lines (alphas 0.28–0.56) are projected beneath the feet to simulate ground contact and light-source shadow casting.",
        "<b>Animated Stepping Boots:</b> A mathematical sine wave derived from player velocity (<code>sin(walk_cycle) * 6.0</code>) dynamically shifts two dark rectangular soles back and forth, simulating running feet without sprite sheets.",
        "<b>Squad Uniform Identification:</b> The jacket color shifts automatically based on <code>player_index</code> (P1: Tactical Olive <code>#47573d</code>; P2: Navy Blue <code>#385280</code>; P3: Crimson Ops <code>#7a3333</code>; P4: Desert Tan <code>#7a6629</code>).",
        "<b>Dynamic Weapon Display:</b> The equipped firearm model drawn in the survivor's hands dynamically switches based on the active weapon index: drawing an extended pump for the Shotgun, a curved magazine for the SMG, and a polished metallic frame for the .44 Magnum.",
        "<b>Visual Equipment Feedback:</b> Picking up a Kevlar Vest renders a blue tactical ballistic plate over the torso. Picking up a gasoline jerrycan renders a red hazard container strapped to the survivor's backpack."
    ]
    for pvp in player_visual_points:
        story.append(Paragraph(f"• {pvp}", bullet_style))

    story.append(Paragraph("B. Photometric Soft Gradient Lighting &amp; Darkness Shader (NEW in v1.1)", h2_style))
    story.append(Paragraph(
        "In commit <code>ab8639d</code>, flat-alpha discs and 4-point polygon cones were replaced with a realistic photometric lighting engine (<code>scripts/light_fx.gd</code>):<br/>"
        "• <b>Cached Radial Falloff &amp; Beam Textures:</b> Radial-glow textures with exponential falloff curves are cached at boot, delivering smooth, soft-penumbra illumination for the flashlight, turret spotlights, street lamps, generators, fuel truck, pickups, and glowing witch eyes.<br/>"
        "• <b>Darkness Shader:</b> Lit areas dynamically take the color of their light sources; shadow penumbra widens with distance; dithering is applied to eliminate color banding on mobile screens.<br/>"
        "• <b>Day/Night Progression:</b> The flashlight beam is faint during daytime and smoothly strengthens as <code>current_night_factor</code> escalates toward midnight blackout.",
        body_style
    ))

    story.append(Paragraph("C. Original SVG Vector Icon System (NEW in v1.1)", h2_style))
    story.append(Paragraph(
        "To resolve missing symbol glyphs in custom game fonts (Bebas Neue / Special Elite), commit <code>ab8639d</code> introduced an original SVG icon set (<code>assets/art/icons/</code>) managed by <code>scripts/ui_icons.gd</code>. "
        "Crisp vector icons are used for buttons (Pause, Sound FX, Music, Restart), HUD elements, and star ratings (rendered as a clean icon strip on level select and results screens).",
        body_style
    ))

    story.append(Paragraph("D. The 14 Zombie Archetypes &amp; Dismemberment Engine", h2_style))

    zombie_summary_data = [
        [
            Paragraph("<b>Archetype</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white)),
            Paragraph("<b>Base HP / Speed</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white)),
            Paragraph("<b>Visual Profile &amp; Unique Combat Mechanic</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white))
        ],
        [
            Paragraph("<b>Walker</b>", body_style),
            Paragraph("50 HP / 145 px/s", body_style),
            Paragraph("Rotting green torso (1.0× scale). Standard shambling horde hostile.", body_style)
        ],
        [
            Paragraph("<b>Runner</b>", body_style),
            Paragraph("40 HP / 238 px/s", body_style),
            Paragraph("Slightly leaner frame (0.92× scale), rapid arm sway. Aggressive sprinter.", body_style)
        ],
        [
            Paragraph("<b>Boomer</b>", body_style),
            Paragraph("95 HP / 92 px/s", body_style),
            Paragraph("Bloated silhouette (1.35× scale). Detonates on death dealing 40 AoE bile damage.", body_style)
        ],
        [
            Paragraph("<b>Tank</b>", body_style),
            Paragraph("850 HP / 112 px/s", body_style),
            Paragraph("Colossal slate-grey hulk (2.1× scale). Massive knockback, high durability.", body_style)
        ],
        [
            Paragraph("<b>Witch</b>", body_style),
            Paragraph("180 HP / 80/310 px/s", body_style),
            Paragraph("Hunched frame with red warning aura. Weeps until disturbed, then frenzies.", body_style)
        ],
        [
            Paragraph("<b>Necro</b>", body_style),
            Paragraph("320 HP / 105 px/s", body_style),
            Paragraph("Surrounded by glowing green necromantic runes; resurrects fallen corpses.", body_style)
        ]
    ]
    t_zsummary = Table(zombie_summary_data, colWidths=[1.1 * inch, 1.3 * inch, 4.6 * inch])
    t_zsummary.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_accent),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('PADDING', (0,0), (-1,-1), 3.5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_light])
    ]))
    story.append(t_zsummary)
    story.append(Spacer(1, 4))

    story.append(Paragraph(
        "<b>Dismemberment Mechanics:</b> If an arm is severed (<code>has_left_arm = false</code>), <code>_draw_arm_or_stump()</code> renders a bleeding shoulder stump with an exposed white humerus bone. If legs are severed, movement speed drops by 60%, and the animation transitions to a crawling torso dragging exposed femur stumps.",
        body_style
    ))
    story.append(PageBreak())

    # =========================================================================
    # SECTION 4: CODE REVERSE-ENGINEERING & GAMEPLAY
    # =========================================================================
    story.append(Paragraph("4. Module-by-Module Code Reverse-Engineering", h1_style))
    story.append(Paragraph(
        "Below is an architectural review of every major subsystem script, including recent distance-gating and AI fixes:",
        body_style
    ))

    mod_list = [
        ("GameState (autoload/game_state.gd)",
         "<b>Role:</b> Central data persistence singleton.<br/>"
         "<b>How it works:</b> Never unloaded during scene transitions. Serializes campaign progress to <code>user://save.cfg</code> "
         "via Godot's <code>ConfigFile</code> API. Tracks unlocked sectors (1–5), high scores, star ratings (1–3), audio toggles, and achievements "
         "(<i>Untouchable</i>, <i>Anatomy Lesson</i>, <i>Apex Predator</i>). Guarantees offline robustness by initializing safe defaults if "
         "<code>save.cfg</code> is missing on first launch."),

        ("NetworkManager (autoload/network_manager.gd)",
         "<b>Role:</b> Multiplayer coordinator.<br/>"
         "<b>How it works:</b> Uses Godot's <code>ENetMultiplayerPeer</code>. Implements <b>Smart IP Detection</b> "
         "(<code>get_smart_ip_list()</code>) which scores physical Wi-Fi/Hotspot adapters (+100) above virtual adapters (-50 for Docker, Hyper-V, and WSL). "
         "This prevents players from sharing unreachable virtual IPs. Enforces strict <b>Host Authority</b>: the host phone calculates wave spawning, "
         "damage, and scores, while clients send input commands via remote procedure calls (RPCs)."),

        ("AudioManager (autoload/audio_manager.gd) & audio_generator.gd",
         "<b>Role:</b> Procedural audio generation and playback.<br/>"
         "<b>How it works:</b> <code>scripts/audio_generator.gd</code> generates 27 distinct 22,050 Hz 16-bit PCM WAV audio files using "
         "mathematical synthesis (sine sweeps, white noise bursts, exponential decay envelopes). <code>AudioManager</code> maintains "
         "an active pool of 16 <code>AudioStreamPlayer</code> nodes, ensuring simultaneous gunfire, explosions, and groans never clip."),

        ("Player & WeaponController (scripts/player.gd, weapon_controller.gd)",
         "<b>Role:</b> Survivor movement, input handling, and weapon management.<br/>"
         "<b>How it works:</b> Handles 8-directional movement, inertia, and tactical dash (760 px/s with ghost trail motion blur). "
         "<code>WeaponController</code> holds specifications for 5 weapons (Pistol, SMG, Shotgun, M4A1, Magnum) governing fire rate, "
         "ammo capacity, pellet spread, and camera recoil shake. Implements <b>Squad Bleedout</b>: in multiplayer, reaching 0 HP puts "
         "the player into a crawling downed state with a 35-second bleedout timer, allowing squadmates to perform interactive revives (now enabled across ALL co-op modes)."),

        ("Interactable Distance Gating & Caller Validation (NEW in v1.1)",
         "<b>Role:</b> Proximity validation across all interactive map objects.<br/>"
         "<b>How it works:</b> In commit <code>1afc2bb</code>, <code>fuel_truck.gd</code>, <code>generator.gd</code>, <code>sentry_turret.gd</code>, "
         "and <code>supply_crate.gd</code> enforce explicit distance gating (<code>interaction_distance = 64.0</code>). Actions are validated "
         "against the caller's global coordinates (<code>is_caller_in_range(caller)</code>), preventing remote activation exploits."),

        ("ZombieBasic & Off-Screen Spawn Scope (scripts/zombie_basic.gd, level_01.gd)",
         "<b>Role:</b> Hostile artificial intelligence and spawn pacing.<br/>"
         "<b>How it works:</b> Operates an AI state machine supporting wandering, player pursuit, enraged charges, and AoE explosions. "
         "In commit <code>9bd92fd</code>, hostile spawning is strictly restricted to off-screen coordinates outside the camera viewport, "
         "and abrupt teleports were replaced with <b>obstacle slide steering</b> so hostiles navigate cleanly around containers and walls."),

        ("WaveDirector & LevelController (scripts/wave_director.gd, level_controller.gd)",
         "<b>Role:</b> Pacing director and match referee.<br/>"
         "<b>How it works:</b> <code>WaveDirector</code> spawns enemies in pulses, scaling enemy counts and introducing tougher variants as sectors advance. "
         "<code>LevelController</code> monitors win/loss conditions: triggering victory when all waves are cleared, calculating stars, unlocking the next sector "
         "in <code>GameState</code>, and displaying the Result Screen. Features a <b>directional radar indicator</b> pointing to remaining hostiles during sector clear."),

        ("ArenaEnvironment (scripts/arena_environment.gd)",
         "<b>Role:</b> Procedural map generation.<br/>"
         "<b>How it works:</b> Divides the world into 640×640 pixel chunks. Procedurally generates thematic obstacles with dynamic "
         "<code>StaticBody2D</code> colliders across 5 biomes (Quarantine, The Street, No Exit Swamp, The Depot, and Last Light). "
         "Places 5 strategic diesel generators to illuminate blackout plazas and places the fuel truck at a tactical distance.")
    ]

    for title, desc in mod_list:
        story.append(Paragraph(title, h2_style))
        story.append(Paragraph(desc, body_style))
        story.append(Spacer(1, 1.5))

    story.append(PageBreak())

    # =========================================================================
    # SECTION 5: DOCKER: HOW IT WORKS & IS IT USED?
    # =========================================================================
    story.append(Paragraph("5. Docker Deep Dive: How It Works & Is It Used?", h1_style))
    story.append(Paragraph(
        "<b>Direct Answer: Is Docker running the Godot game?</b><br/>"
        "<b>NO.</b> The Godot game client does NOT run inside Docker. Godot compiles natively to an Android APK or desktop executable. "
        "Docker is used exclusively for the <b>backend infrastructure and DevOps deliverables</b> required by the ITSD 85 course:",
        body_style
    ))

    docker_roles = [
        "<b>1. Automated CI/CD Web Service (Dockerfile &amp; compose.yaml):</b> Packages a Node.js companion service (<code>src/app.js</code>). In the CI/CD pipeline, this container is built and deployed automatically whenever code is pushed to <code>main</code>. It serves a public health check endpoint (<code>/health</code>), an online leaderboard API (<code>/api/leaderboard</code>), and a status portal.",
        "<b>2. Nakama Online Game Server (docker-compose.nakama.yml):</b> Runs HeroicLabs Nakama backed by CockroachDB. This represents the optional 'Option B' internet matchmaking backend described in Page 16 of the Mobile Game lab guide, enabling worldwide co-op beyond local Wi-Fi LAN."
    ]
    for dr in docker_roles:
        story.append(Paragraph(f"• {dr}", bullet_style))

    story.append(Spacer(1, 4))
    story.append(Paragraph("Line-by-Line Anatomy of the Production Dockerfile (Updated v1.1)", h2_style))

    dockerfile_code = """FROM node:24-alpine                  # Ultra-lightweight, secure Linux base image
WORKDIR /app                        # Set container working directory
COPY package.json package-lock.json* ./ # Cache dependency layers
RUN npm ci --omit=dev               # Strict, reproducible production install
COPY src ./src                       # Copy web application source code
ARG APP_VERSION=dev                 # Build-time variable injected by GitHub Actions
ENV APP_VERSION=$APP_VERSION        # Set runtime environment variable
ENV NODE_ENV=production PORT=3000   # Configure production port
EXPOSE 3000                         # Document network port
USER node                           # Run process as non-root user for container security
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \\
  CMD wget -qO- http://localhost:3000/health || exit 1 # Native container healthcheck
CMD ["node", "src/server.js"]       # Launch the Express server process"""
    story.append(Paragraph(dockerfile_code.replace("\n", "<br/>").replace(" ", "&nbsp;"), code_style))

    story.append(Paragraph("compose.yaml Architecture &amp; .dockerignore Optimization", h2_style))
    story.append(Paragraph(
        "<code>compose.yaml</code> coordinates container execution with project name <code>-p itsd85</code>. It maps host port "
        "<code>8080</code> to container port <code>3000</code>, ensuring the web API is accessible externally via "
        "<code>http://localhost:8080/health</code>. Commit <code>6cefbb8</code> introduced a dedicated <code>.dockerignore</code> "
        "(excluding <code>.git</code>, <code>tests/</code>, <code>assets/</code>, <code>docs/</code>, and <code>build/</code>), "
        "reducing build context transfer time from seconds to milliseconds. Nakama credentials are separated into gitignored files "
        "(<code>.env.example</code>, <code>nakama_local.cfg.example</code>).",
        body_style
    ))

    story.append(Spacer(1, 6))

    # =========================================================================
    # SECTION 6: THE CI/CD PIPELINE (GITHUB ACTIONS)
    # =========================================================================
    story.append(Paragraph("6. The CI/CD Pipeline: From Commit to Live Server", h1_style))
    story.append(Paragraph(
        "The automated delivery pipeline in <code>.github/workflows/ci-cd.yml</code> enforces automated software quality "
        "gates and zero-touch server deployments:",
        body_style
    ))

    pipeline_steps = [
        "<b>1. Triggers:</b> Pushes to <code>main</code>, pull requests targeting <code>main</code>, and manual triggers via <code>workflow_dispatch:</code>.",
        "<b>2. Quality Gate ('test' Job on Ubuntu Cloud):</b> Runs on <code>ubuntu-latest</code>. Uses <code>actions/checkout@v7</code> and <code>actions/setup-node@v7</code> with <code>cache: npm</code>. Executes <code>npm ci</code>, <code>npm run lint</code> (ESLint), and <code>npm test</code> (Node.js test runner). If a single test fails, the pipeline halts immediately.",
        "<b>3. Deployment Gate ('deploy' Job):</b> Protected by <code>needs: test</code> and <code>if: github.ref == 'refs/heads/main' &amp;&amp; github.event_name == 'push'</code>. Pull requests are never deployed; only verified code merged into <code>main</code> proceeds.",
        "<b>4. Cloud-Native Server Deployment:</b> In commit <code>6cefbb8</code>, the deployment job runs on <code>ubuntu-latest</code> with Docker Compose (<code>docker compose -p itsd85 up -d --build --remove-orphans</code>). This enables cloud-managed CI/CD execution while maintaining self-hosted compatibility.",
        "<b>5. Health Verification Polling Loop:</b> A bash polling loop queries <code>http://localhost:8080/health</code> up to 15 times (30s timeout). The deployment is verified successful only when the endpoint returns <code>status: ok</code> matching the exact Git commit SHA."
    ]
    for ps in pipeline_steps:
        story.append(Paragraph(f"• {ps}", bullet_style))

    story.append(PageBreak())

    # =========================================================================
    # SECTION 7: LAB DEFENSE & ORAL EXAMINATION HANDBOOK
    # =========================================================================
    story.append(Paragraph("7. Lab Defense & Oral Examination Handbook", h1_style))
    story.append(Paragraph(
        "This section prepares you to defend your project before your instructor and examination panel with 100% confidence. "
        "It directly answers all formal guide questions from the official ITSD 85 lab specifications.",
        body_style
    ))

    story.append(Paragraph("PART 1: MOBILE GAME DEFENSE (Lab Guide Page 28)", h2_style))

    qa_game = [
        ("Q1: How does GameState keep offline play working even when the phone has no internet?",
         "<b>Answer:</b> <code>GameState</code> is an Autoload singleton that writes all campaign progression (unlocked levels, star ratings, high scores, achievements) to local device storage at <code>user://save.cfg</code> using Godot's built-in <code>ConfigFile</code> API. On Android, this maps to <code>/data/data/com.itsd85.deadblock.survival/files/save.cfg</code>. When the player selects Offline mode, <code>NetworkManager</code> binds Godot's multiplayer peer to <code>OfflineMultiplayerPeer.new()</code>. No sockets, HTTP requests, or DNS lookups are initiated, ensuring full functionality in Airplane Mode."),

        ("Q2: Where is the save file stored on Android, and what happens if the file is missing on first launch?",
         "<b>Answer:</b> On Android, <code>user://</code> resolves to the application's private, sandboxed internal storage directory. On first launch, <code>ConfigFile.load('user://save.cfg')</code> returns <code>ERR_FILE_NOT_FOUND</code>. <code>GameState.load_progress()</code> catches this error gracefully, initializes safe in-memory defaults (Level 1 unlocked, 0 scores, default audio on), and immediately writes a valid <code>save.cfg</code> upon completion of the first level or settings adjustment."),

        ("Q3: How did you make Level 5 harder than Level 1 without writing a brand-new game script?",
         "<b>Answer:</b> All five campaign levels reuse the exact same modular controller scripts (<code>level_01.gd</code>, <code>wave_director.gd</code>, <code>arena_environment.gd</code>) parameterized via exported inspector properties (<code>@export var level_id: int</code>, <code>@export var custom_waves: Array</code>). Level 1 features 3 short waves of basic Walkers with 1.65-second spawn intervals in an open containment yard. Level 5 (<i>Last Light</i>) escalates to 5 dense waves (up to 24 enemies per wave, 0.70-second spawn rates, guaranteed Witch and Tank boss spawns) set in a blackout urban ruin where visibility is strictly limited to the player's flashlight."),

        ("Q4: In online mode, who decides the winner or score — each client or the host/server — and why?",
         "<b>Answer:</b> The <b>Host (Peer ID 1) is strictly authoritative</b>. In <code>level_controller.gd</code>, the win/loss evaluation functions explicitly verify <code>if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority(): return</code>. Clients only send local stick inputs and hit notifications. The Host validates damage, calculates scores, and broadcasts match results via reliable RPC. If clients decided their own wins, network latency would cause desynchronized states (one phone showing Victory while the other is still fighting), and malicious clients could cheat."),

        ("Q5: What happens in your game if the other player disconnects mid-match? Trace the signal to the UI.",
         "<b>Answer:</b><br/>"
         "1. <i>Transport Layer:</i> ENet detects the dropped packet stream and emits <code>multiplayer.peer_disconnected(id)</code>.<br/>"
         "2. <i>Autoload Layer:</i> <code>NetworkManager</code> catches the signal, removes the ID from <code>connected_peers</code>, emits <code>status_changed('Survivor disconnected')</code>, and resets the peer state.<br/>"
         "3. <i>Scene / UI Layer:</i> In <code>level_01.gd</code>, <code>_on_coop_peer_disconnected()</code> removes the disconnected player's avatar from the scene tree and displays an in-game HUD alert without crashing. If the Host disconnects, the guest is cleanly transitioned back to <code>scenes/ui/lobby.tscn</code> with an error banner ('Host Disconnected')."),

        ("Q6: Compare developing for Android and iOS: what did your platform choice make easier or harder?",
         "<b>Answer:</b> Android was chosen because it allows free, direct sideloading of <code>.apk</code> packages on unlimited devices via USB debugging or Google Drive without expensive Apple Developer accounts ($99/year) or 7-day provisioning profile expiration limits. The challenge of Android was hardware fragmentation (testing varying screen aspect ratios and GPU rendering drivers), which we solved by choosing Godot's GL Compatibility renderer and designing scalable canvas stretch viewports.")
    ]

    for q, a in qa_game:
        story.append(Paragraph(q, h3_style))
        story.append(Paragraph(a, body_style))
        story.append(Spacer(1, 2.5))

    story.append(PageBreak())

    story.append(Paragraph("PART 2: AUTOMATED CI/CD DEFENSE (Lab Guide Page 21)", h2_style))

    qa_cicd = [
        ("Q1: What is the difference between CI, Continuous Delivery, and Continuous Deployment? Which did you build?",
         "<b>Answer:</b><br/>"
         "• <i>Continuous Integration (CI):</i> Automatically merging, building, and running automated tests on code changes.<br/>"
         "• <i>Continuous Delivery (CD):</i> Ensuring every verified build is automatically prepared for release, but requiring a manual approval button to push to production.<br/>"
         "• <i>Continuous Deployment (CD):</i> Automatically deploying every change that passes the test suite directly to the production server with zero manual human intervention.<br/>"
         "• <i>Which we built:</i> We built a <b>Continuous Deployment</b> pipeline: merging a pull request into <code>main</code> automatically deploys the container live to the Linux server."),

        ("Q2: Why does the deploy job use 'needs: test'? What would happen without it?",
         "<b>Answer:</b> <code>needs: test</code> creates an essential quality gate dependency. The deployment job will not execute unless the test job finishes with exit code 0. Without <code>needs: test</code>, the <code>test</code> and <code>deploy</code> jobs would execute concurrently in parallel, deploying broken or untested code to the production server even if unit tests or linters failed."),

        ("Q3: Your server has no public IP address. Explain how GitHub was still able to deploy to it.",
         "<b>Answer:</b> When using a self-hosted runner, the runner daemon on the Ubuntu server initiates an <b>outbound HTTPS long-polling connection (TCP Port 443)</b> to GitHub's Actions API. Because the connection originates from inside the private network out to GitHub, NAT and local firewalls allow the traffic without requiring port forwarding, static public IPs, or open inbound ports. (In our updated pipeline, GitHub-hosted <code>ubuntu-latest</code> runners can also manage deployments directly)."),

        ("Q4: Why does the workflow use 'npm ci' instead of 'npm install'?",
         "<b>Answer:</b> <code>npm ci</code> (Clean Install) strictly installs the exact versions listed in <code>package-lock.json</code> and deletes existing <code>node_modules</code>. In contrast, <code>npm install</code> can update dependencies matching semver ranges (<code>^</code> or <code>~</code>), potentially causing builds to succeed locally but fail in CI due to unexpected upstream package updates."),

        ("Q5: Why is the commit ID used as the application version? Give two benefits.",
         "<b>Answer:</b><br/>"
         "1. <i>Traceability:</i> Visiting <code>/health</code> displays the exact Git commit SHA running in production, eliminating ambiguity over which version is live.<br/>"
         "2. <i>Deterministic Rollbacks:</i> Tagging Docker images with commit SHAs (<code>itsd85-app:7f3a1b2</code>) allows instant, one-command rollbacks to a previous stable container without rebuilding."),

        ("Q6: Compare rollback Method 1 and Method 2. When would you choose each?",
         "<b>Answer:</b><br/>"
         "• <i>Method 1 (Git Revert via Pipeline):</i> Run <code>git revert HEAD</code>, push, and let CI/CD test and redeploy. Best practice because it maintains an honest Git audit history.<br/>"
         "• <i>Method 2 (Emergency Container Rollback):</i> Run <code>docker compose up -d</code> pointing to the previous image tag directly on the server. Achieves recovery in seconds during critical outages, after which the Git commit must still be reverted.")
    ]

    for q, a in qa_cicd:
        story.append(Paragraph(q, h3_style))
        story.append(Paragraph(a, body_style))
        story.append(Spacer(1, 2.5))

    story.append(PageBreak())

    # =========================================================================
    # SECTION 8: ACCEPTANCE CRITERIA MATRIX (R1–R10)
    # =========================================================================
    story.append(Paragraph("8. Acceptance Criteria Verification Matrix (R1–R10)", h1_style))
    story.append(Paragraph(
        "Every requirement from Page 2–3 of the Mobile Game lab guide was verified against the implemented codebase:",
        body_style
    ))

    acceptance_data = [
        [
            Paragraph("<b>Req #</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white)),
            Paragraph("<b>Lab Specification</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white)),
            Paragraph("<b>Implementation Proof &amp; Verification Method</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white)),
            Paragraph("<b>Status</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white))
        ],
        [
            Paragraph("<b>R1</b>", body_style),
            Paragraph("At least 5 levels, each harder or different", body_style),
            Paragraph("Sectors 1–5 feature unique biomes, escalating wave sizes (6 to 24), tighter intervals (1.65s to 0.70s), and guaranteed Tank/Witch boss encounters.", body_style),
            Paragraph("<b>PASSED</b>", ParagraphStyle('Pass', parent=body_style, textColor=c_dark_green, fontName='Helvetica-Bold'))
        ],
        [
            Paragraph("<b>R2</b>", body_style),
            Paragraph("Clear goal per level shown to player on start", body_style),
            Paragraph("Bold objective banner displayed on sector launch (e.g. '★ GOAL: SURVIVE 3 WAVES IN SECTOR 01 ★').", body_style),
            Paragraph("<b>PASSED</b>", ParagraphStyle('Pass', parent=body_style, textColor=c_dark_green, fontName='Helvetica-Bold'))
        ],
        [
            Paragraph("<b>R3</b>", body_style),
            Paragraph("Win/lose result screen with stars, score, Retry/Next/Menu", body_style),
            Paragraph("<code>result_screen.tscn</code> displays performance stars (1–3 SVG icon strip), score counter, and functional Retry, Next Sector, and Main Menu buttons.", body_style),
            Paragraph("<b>PASSED</b>", ParagraphStyle('Pass', parent=body_style, textColor=c_dark_green, fontName='Helvetica-Bold'))
        ],
        [
            Paragraph("<b>R4</b>", body_style),
            Paragraph("Level unlocking: level n+1 locked until n cleared", body_style),
            Paragraph("<code>level_select.gd</code> disables locked buttons and displays lock icons. Completing level n unlocks level n+1 via <code>GameState.complete_level()</code>.", body_style),
            Paragraph("<b>PASSED</b>", ParagraphStyle('Pass', parent=body_style, textColor=c_dark_green, fontName='Helvetica-Bold'))
        ],
        [
            Paragraph("<b>R5</b>", body_style),
            Paragraph("Progress saved on device and survives force-close", body_style),
            Paragraph("Saved to <code>user://save.cfg</code> via <code>ConfigFile</code>. Progress verified persistent across app termination.", body_style),
            Paragraph("<b>PASSED</b>", ParagraphStyle('Pass', parent=body_style, textColor=c_dark_green, fontName='Helvetica-Bold'))
        ],
        [
            Paragraph("<b>R6</b>", body_style),
            Paragraph("Offline mode playable in Airplane Mode", body_style),
            Paragraph("Zero network calls in offline mode; bound to <code>OfflineMultiplayerPeer</code>. Tested 100% operational in Airplane Mode.", body_style),
            Paragraph("<b>PASSED</b>", ParagraphStyle('Pass', parent=body_style, textColor=c_dark_green, fontName='Helvetica-Bold'))
        ],
        [
            Paragraph("<b>R7</b>", body_style),
            Paragraph("Online mode: 2 players on 2 phones play real-time", body_style),
            Paragraph("ENet LAN co-op supporting 2–4 players. Host authority synchronizes positions, shooting, and squad revives (in all co-op modes).", body_style),
            Paragraph("<b>PASSED</b>", ParagraphStyle('Pass', parent=body_style, textColor=c_dark_green, fontName='Helvetica-Bold'))
        ],
        [
            Paragraph("<b>R8</b>", body_style),
            Paragraph("Mode selection with graceful error handling", body_style),
            Paragraph("Lobby displays connection timeout dialogs and clear error messages instead of freezing if an IP is invalid.", body_style),
            Paragraph("<b>PASSED</b>", ParagraphStyle('Pass', parent=body_style, textColor=c_dark_green, fontName='Helvetica-Bold'))
        ],
        [
            Paragraph("<b>R9</b>", body_style),
            Paragraph("Runs on real phone with touch controls", body_style),
            Paragraph("Tested on physical Android devices. Dual virtual touch joysticks handle move and aim/shoot; sensor-landscape locked.", body_style),
            Paragraph("<b>PASSED</b>", ParagraphStyle('Pass', parent=body_style, textColor=c_dark_green, fontName='Helvetica-Bold'))
        ],
        [
            Paragraph("<b>R10</b>", body_style),
            Paragraph("Basic polish: title, pause, sound toggle, readable text", body_style),
            Paragraph("Includes Title Screen, Pause menu with Sound FX and Music toggles, SVG icons, 1024x1024 icon, and CREDITS.md.", body_style),
            Paragraph("<b>PASSED</b>", ParagraphStyle('Pass', parent=body_style, textColor=c_dark_green, fontName='Helvetica-Bold'))
        ]
    ]
    t_acc = Table(acceptance_data, colWidths=[0.55 * inch, 1.75 * inch, 3.9 * inch, 0.8 * inch])
    t_acc.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_secondary),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('PADDING', (0,0), (-1,-1), 3.5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_light]),
        ('ALIGN', (3,0), (3,-1), 'CENTER')
    ]))
    story.append(t_acc)
    story.append(PageBreak())

    # =========================================================================
    # SECTION 9: 7-MINUTE LIVE DEMONSTRATION PLAYBOOK
    # =========================================================================
    story.append(Paragraph("9. The 7-Minute Live Demonstration Playbook", h1_style))
    story.append(Paragraph(
        "Follow this exact script during your live evaluation to hit every rubric requirement within the allocated 7 minutes:",
        body_style
    ))

    demo_schedule = [
        [
            Paragraph("<b>Timestamp</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white)),
            Paragraph("<b>Presentation Focus</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white)),
            Paragraph("<b>Demonstration Actions &amp; Key Dialogue</b>", ParagraphStyle('TH', parent=body_style, fontName='Helvetica-Bold', textColor=colors.white))
        ],
        [
            Paragraph("<b>0:00 – 0:30</b><br/>(30 sec)", body_style),
            Paragraph("<b>The One-Sentence Pitch</b>", body_style),
            Paragraph("<i>'Dead Block: Survival is a gritty, top-down zombie survival shooter built with Godot 4 and GDScript, featuring five progressive campaign sectors, 100% offline airplane-mode play, and two-player Wi-Fi co-op.'</i>", body_style)
        ],
        [
            Paragraph("<b>0:30 – 2:30</b><br/>(2 min)", body_style),
            Paragraph("<b>Level 1 &amp; Progression Unlock</b>", body_style),
            Paragraph("Open Level 1 (Quarantine). Show clear goal banner ('Survive 3 Waves'). Demonstrate touch joystick, firing, and tactical dash. Defeat wave 3. Show Result Screen with 3 stars. Return to Level Select to prove Sector 2 is now unlocked.", body_style)
        ],
        [
            Paragraph("<b>2:30 – 3:30</b><br/>(1 min)", body_style),
            Paragraph("<b>Offline Airplane Mode Test</b>", body_style),
            Paragraph("Swipe down Android quick settings, turn ON Airplane Mode (Wi-Fi &amp; Data OFF). Force-close the game. Reopen. Prove progress persisted from save.cfg. Launch Sector 2 to prove 100% offline capability without freezes.", body_style)
        ],
        [
            Paragraph("<b>3:30 – 5:30</b><br/>(2 min)", body_style),
            Paragraph("<b>2-Player Online Co-op</b>", body_style),
            Paragraph("Phone 1 taps Host. Show the Smart IP display (192.168.x.x). Phone 2 enters IP and joins. Start co-op match. Demonstrate live synchronized shooting and the squad downed/revive mechanic.", body_style)
        ],
        [
            Paragraph("<b>5:30 – 7:00</b><br/>(1.5 min)", body_style),
            Paragraph("<b>Playtest Findings &amp; Changes</b>", body_style),
            Paragraph("Present playtest findings (N=12). Highlight that players initially missed dash controls and were confused by virtual IPs. Show the tutorial hints and 1-tap IP copy features added in response.", body_style)
        ]
    ]
    t_demo = Table(demo_schedule, colWidths=[1.1 * inch, 1.8 * inch, 4.1 * inch])
    t_demo.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), c_dark_green),
        ('GRID', (0,0), (-1,-1), 0.5, c_border),
        ('PADDING', (0,0), (-1,-1), 5),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, c_bg_light])
    ]))
    story.append(t_demo)

    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"[SUCCESS] Generated complete publication-grade PDF: {filename}")

if __name__ == "__main__":
    out_pdf = "docs/Dead_Block_Survival_Complete_Guide_and_Defense.pdf"
    if len(sys.argv) > 1:
        out_pdf = sys.argv[1]
    build_pdf(out_pdf)
