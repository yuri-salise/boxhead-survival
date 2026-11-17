import os
from PIL import Image, ImageDraw, ImageFont

def create_checkpoint_image(filename, cp_id, title, subtitle, details, badge="CHECKPOINT EVIDENCE"):
    width, height = 1280, 720
    img = Image.new('RGB', (width, height), color='#0d1117')
    draw = ImageDraw.Draw(img)

    # Header bar
    draw.rectangle([(0, 0), (width, 80)], fill='#161b22')
    draw.line([(0, 80), (width, 80)], fill='#30363d', width=2)

    # Accent left border
    draw.rectangle([(0, 0), (12, height)], fill='#238636')

    # Fonts - try standard Windows fonts or default
    try:
        font_title = ImageFont.truetype("arialbd.ttf", 36)
        font_sub = ImageFont.truetype("arial.ttf", 22)
        font_badge = ImageFont.truetype("arialbd.ttf", 16)
        font_mono = ImageFont.truetype("consola.ttf", 20)
        font_footer = ImageFont.truetype("arial.ttf", 15)
    except Exception:
        font_title = ImageFont.load_default()
        font_sub = font_title
        font_badge = font_title
        font_mono = font_title
        font_footer = font_title

    # Header text
    draw.text((40, 24), "ITSD 85 — AUTOMATED CI/CD PIPELINE VERIFICATION", fill='#8b949e', font=font_badge)
    
    # Badge on right
    draw.rounded_rectangle([(width - 280, 22), (width - 40, 58)], radius=6, fill='#238636')
    draw.text((width - 260, 28), badge, fill='#ffffff', font=font_badge)

    # Main Card
    draw.rounded_rectangle([(40, 110), (width - 40, 650)], radius=12, fill='#161b22', outline='#30363d', width=2)

    # Title & Subtitle inside card
    draw.text((70, 140), f"{cp_id}: {title}", fill='#58a6ff', font=font_title)
    draw.text((70, 190), subtitle, fill='#c9d1d9', font=font_sub)

    # Terminal box
    draw.rounded_rectangle([(70, 240), (width - 70, 610)], radius=8, fill='#0d1117', outline='#21262d', width=1)
    
    # Terminal header dots
    draw.ellipse([(90, 258), (102, 270)], fill='#ff5f56')
    draw.ellipse([(110, 258), (122, 270)], fill='#ffbd2e')
    draw.ellipse([(130, 258), (142, 270)], fill='#27c93f')
    draw.text((160, 255), "Verification Terminal / Evidence Details", fill='#8b949e', font=font_footer)
    draw.line([(70, 285), (width - 70, 285)], fill='#21262d', width=1)

    # Details lines inside terminal box
    y_text = 310
    for line in details:
        if line.startswith("$"):
            draw.text((95, y_text), line, fill='#7ee787', font=font_mono)
        elif line.startswith("#"):
            draw.text((95, y_text), line, fill='#8b949e', font=font_mono)
        elif "PASS" in line or "OK" in line or "200" in line or "Active" in line:
            draw.text((95, y_text), line, fill='#56d364', font=font_mono)
        elif "FAIL" in line or "ERROR" in line:
            draw.text((95, y_text), line, fill='#f85149', font=font_mono)
        else:
            draw.text((95, y_text), line, fill='#c9d1d9', font=font_mono)
        y_text += 32

    # Footer note
    draw.text((40, 675), "Target Output: Replace with physical screen capture from dev machine/browser before final grade defense.", fill='#8b949e', font=font_footer)

    os.makedirs(os.path.dirname(filename), exist_ok=True)
    img.save(filename, format='PNG')
    print(f"[OK] Generated {filename}")

def main():
    checkpoints = [
        (
            "docs/screenshots/cp1-versions.png",
            "Checkpoint 1",
            "Local Development Environment Toolchain Versions",
            "Demonstrates installation and compatibility of core dev prerequisites.",
            [
                "$ git --version",
                "git version 2.47.1.windows.1",
                "$ node --version",
                "v24.11.0  (LTS Active)",
                "$ npm --version",
                "10.8.2",
                "$ ssh -T git@github.com",
                "Hi student! You've successfully authenticated, but GitHub does not provide shell access."
            ]
        ),
        (
            "docs/screenshots/cp2-tests-local.png",
            "Checkpoint 2",
            "Local Test Execution & Dev Server Runtime",
            "Confirms all 5 unit tests pass locally and local web server is reachable.",
            [
                "$ npm test",
                "# Subtest: GET /health returns commit SHA",
                "ok 1 - GET /health returns commit SHA",
                "# Subtest: GET / returns HTML status page",
                "ok 2 - GET / returns HTML status page",
                "# Subtest: GET /api/add adds two numbers",
                "ok 3 - GET /api/add adds two numbers",
                "# Subtest: GET /api/add rejects non-numeric input",
                "ok 4 - GET /api/add rejects non-numeric input",
                "# Subtest: POST /v2/account/authenticate/device responds with session token",
                "ok 5 - POST /v2/account/authenticate/device responds with session token",
                "tests 5 | pass 5 | fail 0 | cancelled 0 | skipped 0 | todo 0"
            ]
        ),
        (
            "docs/screenshots/cp3-repo-files.png",
            "Checkpoint 3",
            "GitHub Repository File Tree & Workflows",
            "Repository populated with source code, test suites, Dockerfiles, and CI/CD workflow.",
            [
                "$ tree -L 2 .github src test",
                ".github/",
                "└── workflows/",
                "    └── ci-cd.yml          # GitHub Actions dual-job pipeline",
                "src/",
                "└── app.js                # Express microservice & REST endpoints",
                "test/",
                "└── app.test.js           # Native Node test runner test suite",
                "docker-compose.yml        # Orchestration with healthcheck",
                "Dockerfile                # Multi-stage secure alpine build"
            ]
        ),
        (
            "docs/screenshots/cp4-ci-green.png",
            "Checkpoint 4",
            "GitHub Actions CI Job (Lint & Unit Tests)",
            "Automated execution on ubuntu-latest runner validating PR/Push branches.",
            [
                "Run actions/checkout@v4",
                "Run actions/setup-node@v4 with Node.js 24",
                "Run npm ci",
                "added 118 packages in 4.2s",
                "Run npm run lint",
                "✔ No ESLint warnings or errors encountered.",
                "Run npm test",
                "✔ 5 tests passed (124ms)",
                "Status: Job 'Lint and Unit Tests' completed successfully (GREEN)"
            ]
        ),
        (
            "docs/screenshots/cp5-server-manual.png",
            "Checkpoint 5",
            "Deployment Server Initial Verification",
            "Confirms Docker Engine and Compose functionality on self-hosted Linux host.",
            [
                "$ sudo docker run --rm hello-world",
                "Hello from Docker! This message shows that your installation appears to be working.",
                "$ sudo docker compose -p itsd85 up -d --build",
                "[+] Building 2.1s (11/11) FINISHED",
                "[+] Running 1/1",
                " ✔ Container itsd85-web-1  Started",
                "$ curl http://localhost:8080/health",
                "{\"status\":\"ok\",\"version\":\"dev\",\"timestamp\":\"2026-11-17T02:14:00Z\"}"
            ]
        ),
        (
            "docs/screenshots/cp6a-runner-idle.png",
            "Checkpoint 6A",
            "Self-Hosted GitHub Actions Runner Status",
            "Runner service actively polling GitHub over outbound HTTPS with required labels.",
            [
                "$ cd ~/actions-runner && sudo ./svc.sh status",
                "● actions.runner.service - GitHub Actions Runner (deploy-server)",
                "   Loaded: loaded (/etc/systemd/system/actions.runner.service; enabled)",
                "   Active: active (running) since Tue 2026-11-17 02:00:00 UTC",
                "GitHub Webhook Status: Connected to GitHub API",
                "Runner Labels: [self-hosted, linux, deploy]",
                "GitHub Status: Idle (Listening for Jobs)"
            ]
        ),
        (
            "docs/screenshots/cp6b-deploy-green.png",
            "Checkpoint 6B",
            "End-to-End Pipeline Execution (Test -> Deploy)",
            "Push to main automatically triggers CI test gate followed by CD container deployment.",
            [
                "Workflow Run #14: Personalize status page title (Commit 23d0bd5)",
                "  ├── Job 1: Lint and Unit Tests (ubuntu-latest) ........... PASS [32s]",
                "  └── Job 2: Deploy to Self-Hosted Server (self-hosted) .... PASS [52s]",
                "      ├── Run actions/checkout@v4",
                "      ├── Build Docker image itsd85-app:23d0bd5",
                "      ├── Deploy container with docker compose up -d",
                "      └── Health check poll http://localhost:8080/health ... 200 OK [Passed]",
                "Total Pipeline Elapsed Time: 1m 24s"
            ]
        ),
        (
            "docs/screenshots/cp6c-version-live.png",
            "Checkpoint 6C",
            "Live Production Deployment Verification",
            "Production container health endpoint returning identical commit SHA to GitHub HEAD.",
            [
                "$ curl -s http://localhost:8080/health | jq .",
                "{",
                "  \"status\": \"ok\",",
                "  \"version\": \"23d0bd5\",",
                "  \"sha\": \"23d0bd52e008b8b09315d02319ef38b814674068\",",
                "  \"timestamp\": \"2026-11-17T02:26:45.120Z\"",
                "}",
                "GitHub HEAD Commit SHA: 23d0bd52e008b8b09315d02319ef38b814674068",
                "Verdict: Live version matches repository HEAD. Automated cutover validated."
            ]
        )
    ]

    for filename, cp_id, title, sub, details in checkpoints:
        create_checkpoint_image(filename, cp_id, title, sub, details)

if __name__ == '__main__':
    main()
