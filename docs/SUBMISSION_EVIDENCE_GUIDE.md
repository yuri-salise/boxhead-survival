# Submission Evidence Guide

What is still missing for the two ITSD 85 labs can only be produced by a person with phones, testers and a GitHub account. This guide lists each item, the exact steps, and the file to put the result in.

Do the sections in this order. Sections 1–4 need the game; section 6 needs the server VM.

| # | Evidence | Lab requirement | Goes in |
| :-: | :--- | :--- | :--- |
| 1 | Build and install the current APK on two phones | Phase 7 | — |
| 2 | Phone test matrix, all rows, two named phones | Checkpoint 7, R9 | `docs/playtest/phone_test_matrix.md` |
| 3 | Two-phone online match + Wi-Fi-off error | Checkpoint 5, R7, R8 | matrix row 6, demo video |
| 4 | Retest with 2+ new testers, per-level completion | Checkpoint 8, Step 8.4–8.5 | `docs/playtest/action_plan.md`, `observation_sheet.md` |
| 5 | Game screenshots on a phone | Checkpoint 6 | `docs/screenshots/` |
| 6 | Pipeline runs: Tests A, B, C + checkpoint screenshots | CI/CD Parts 6–7 | Actions tab, `docs/screenshots/cp*.png`, README Results |
| 7 | Demo video (2–3 min) | Deliverables | Drive / unlisted YouTube link |
| 8 | Freeze and turn in | Step S1–S2 | tag `v1.1`, release, Classroom |

---

## 1. Build and install the current APK

The `v1.0` tag does not contain the latest changes. Test and record with the build you will submit.

1. Commit the working tree, then export:

   ```bash
   Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug "Android" "build/android/DeadBlockSurvival.apk"
   ```

2. Enable **Developer options → USB debugging** on each phone, connect it, and confirm it is listed:

   ```bash
   adb devices
   ```

3. Install. With two phones connected, add `-s <serial>` from the list above:

   ```bash
   adb install -r build/android/DeadBlockSurvival.apk
   ```

4. For a clean first-run test (retest and playtest sessions), reset progress: **Settings → Apps → Dead Block: Survival → Storage → Clear data**.

---

## 2. Phone test matrix

File: `docs/playtest/phone_test_matrix.md`. The lab wants **two different phones** (different screen size or Android version), each with model and OS written in the column header.

1. Replace `Phone 2: Secondary Android (MODEL + OS: TO FILL)` with the real model and Android version. If you cannot get a second phone, borrow one for 20 minutes; do not leave PASS in a column for a phone you did not test.
2. Run every row on **each** phone and write PASS or FAIL plus a short note. The two rows still unrecorded:

   | Row | How to test | What to write |
   | :-- | :--- | :--- |
   | 10 — Touch controls respond correctly | Play Sector 1. Move with the left stick, aim and fire with the right stick, press DASH, FRAG, WEAPON, and USE at a generator or crate. Try with the phone rotated 180°. | PASS / FAIL, and any button that missed a tap |
   | 11 — Battery / heat after 10 minutes | Note the battery % before. Play 10 minutes continuously (Sector 2 or 3). Note the % after and whether the back is cool, warm, or hot. | e.g. `PASS — 84% → 81%, warm` |

3. Re-run the rows that changed in this build: row 8 (UI fits; check the new pause-menu sound buttons and the level-select star icons are not cut off) and row 9 (frame rate at night with the flashlight on).
4. Frame rate: there is no on-screen counter. "Smooth, no visible stutter" judged by eye is what the lab asks for; write a number only if you measured one.
5. Delete the "Open items before submission" list at the bottom once each item is done.

---

## 3. Two-phone online match

The lab checks that **two phones** play one match (not phone + PC).

1. Put both phones on the same Wi-Fi, or turn on one phone's hotspot and join it from the other.
2. Phone A: **Online → Host**. Read the IP shown in the host banner.
3. Phone B: **Online →** type that IP → **Join**.
4. Play Sector 1 to the result screen. Confirm the result screen appears on **both** phones.
5. Error case: on Phone B turn Wi-Fi off, open **Online**, and try to join. Confirm a readable error appears and the game returns to the lobby without freezing.
6. Disconnect case: start another match, then turn Wi-Fi off on Phone B mid-match. Confirm Phone A keeps running and Phone B returns to the lobby with a message.
7. Record steps 2–5 for the demo video (section 7). Update matrix row 6 to name both phones.

---

## 4. Retest and per-level data

The first round (12 testers) is recorded, and six fixes were made. What is missing is the **retest with at least 2 new testers** and the **per-level completion rate and attempts**.

### 4.1 Prepare

- 2 or more people who did **not** take part in round one. Give them codes `R1`, `R2`, … (no names, per the Data Privacy Act note in the lab).
- Ask for consent before they play. A tester under 18 needs a parent's or guardian's consent.
- A phone with a fresh install (clear data, section 1 step 4) and a second phone for the online match.
- Say only: *"Please play as you normally would and say out loud what you are thinking."* Do not explain controls or goals.

### 4.2 Run (15–20 minutes each)

Each tester plays Sectors 1–3 offline, then one online match with you. Stay silent; help only after 2 minutes stuck and write down that you helped.

Fill one block per tester and add it to `docs/playtest/observation_sheet.md` under a new heading `## Retest round`:

| Tester | Level | Attempts to clear | Time to clear (min:sec) | Cleared? | Where they got stuck | Quotes | Bugs seen |
| :-: | :-: | :-: | :-: | :-: | :--- | :--- | :--- |
| R1 | 1 | | | | | | |
| R1 | 2 | | | | | | |
| R1 | 3 | | | | | | |
| R1 | Online | | | | | | |

Then have each tester fill the same 15-item feedback form and add their rows to `docs/playtest/feedback_responses.csv` with IDs `R1`, `R2`.

### 4.3 Check each fix

While they play, watch specifically for the six issues. This is what goes in the **Result after retest** column of `docs/playtest/action_plan.md`:

| # | Fix | What to watch for | Example result |
| :-: | :--- | :--- | :--- |
| 1 | Larger aim stick, spaced buttons | Does the aiming thumb hit DASH/FRAG by accident? | `2 of 2 aimed without mis-taps` |
| 2 | Host IP banner | Does the joiner type the right IP first try? | `2 of 2 joined on first attempt` |
| 3 | Zombie sync, revive | Do both phones show the same zombies? Can a revived player move? | `Revive worked 3 of 3 times` |
| 4 | Distinct sector layouts, ambience | Do they comment that sectors feel different? | `2 of 2 described Sector 3 as different` |
| 5 | AI squadmate, Back gesture pauses | Does swiping Back open the pause menu? | `2 of 2 paused with Back` |
| 6 | Goal banner at level start | Can they say the goal without asking? | `2 of 2 stated the goal unprompted` |

Write the real counts, including failures. If a fix did not work for a tester, say so and note what you would change.

### 4.4 Per-level numbers (Step 8.4)

From the retest rows compute, per level:

- **Completion rate** = testers who cleared ÷ testers who tried.
- **Average attempts** = total attempts ÷ testers who tried.

Add them as a table at the bottom of `action_plan.md` and replace the sentence that says they were not recorded. A level under 60% completion or over 4 average attempts is "probably too hard" by the lab's rule (the final level is exempt).

The round-one sheet has no per-level attempts, so report these numbers for the retest round only and say so.

---

## 5. Game screenshots (Checkpoint 6)

The lab asks for a screenshot of **every screen, taken on a phone**. Open each screen, then capture it from the PC:

```bash
adb exec-out screencap -p > docs/screenshots/01-title.png
```

Repeat with these file names:

| File | Screen |
| :--- | :--- |
| `01-title.png` | Title screen |
| `02-main-menu.png` | Main menu |
| `03-settings.png` | Settings dialog |
| `04-credits.png` | Credits dialog |
| `05-mode-select.png` | Offline / Online selection |
| `06-level-select.png` | Level select with locked sectors and star icons |
| `07-gameplay-day.png` | Sector 1 in play, goal banner visible |
| `08-gameplay-night.png` | A night sector with the flashlight on |
| `09-pause.png` | Pause menu (shows the sound toggles) |
| `10-result-win.png` | Result screen after clearing a sector |
| `11-result-lose.png` | Result screen after dying |
| `12-lobby.png` | Online lobby while hosting |
| `13-online-error.png` | Join error with Wi-Fi off |

The README's "Visual Showcase" uses `screenshot_gameplay.png` and `screenshot_menu.png`; replace those two with fresh captures so they show the current lighting and icons.

---

## 6. Pipeline runs (CI/CD lab Parts 5–7)

### 6.1 Before you start

1. Push the current `main`. The workflow now uses `npm ci`, `actions/*@v7`, a manual **Run workflow** button, and the compose project name `itsd85`.
2. Start the VM. On the server check the runner: `cd ~/actions-runner && sudo ./svc.sh status` should say `active (running)`. On GitHub, **Settings → Actions → Runners** should list it as **Idle** with the label `deploy`.
3. One-time cleanup, because the project name changed: on the server run `docker rm -f itsd85-web`. Without this the first deploy can fail with "container name already in use".
4. **Settings → Actions → General →** *Require approval for all external contributors* (lab Part 3 step 4).
5. **Settings → Rules → Rulesets → New branch ruleset** named `protect-main`: Active, target the default branch, tick *Require a pull request before merging* (0 approvals), *Require status checks to pass* → add `Lint and Unit Tests`, and *Block force pushes*.

   The check is called `Lint and Unit Tests` here, not `test`, because that is the job's display name in this repository.

After step 5 you can no longer push straight to `main`; everything below goes through pull requests, which is what the lab wants to see.

### 6.2 Checkpoint screenshots

Save in `docs/screenshots/` with these names:

| File | What it shows |
| :--- | :--- |
| `cp1-versions.png` | `git --version`, `node --version`, `npm --version`, and the `ssh -T git@github.com` success line |
| `cp2-tests-local.png` | `npm test` showing all tests passing, and the browser at `http://localhost:3000` showing version `dev` |
| `cp3-repo-files.png` | The repository file list on GitHub |
| `cp4-ci-green.png` | A green `Lint and Unit Tests` job with the "Run tests" step expanded |
| `cp5-server-manual.png` | `docker run --rm hello-world` output and the browser showing the manually deployed version |
| `cp6a-runner-idle.png` | The runner listed as Idle |
| `cp6b-deploy-green.png` | A green test → deploy run |
| `cp6c-version-live.png` | `http://localhost:8080` showing the commit ID, beside the same commit on GitHub |

### 6.3 Test A — a good change deploys by itself

```bash
git switch main
```

```bash
git pull
```

```bash
git switch -c feature/greeting
```

In `src/app.js` change the `<h1>` text to end with your name. Then:

```bash
npm test
```

```bash
npm run lint
```

```bash
git commit -am "Personalize status page title"
```

```bash
git push -u origin feature/greeting
```

On GitHub: **Compare & pull request → Create pull request**. Screenshot the PR showing the test job running and **deploy skipped**. Click **Merge pull request** and note the time. When the deploy job turns green, open `http://localhost:8080`, confirm the new title and commit ID, and screenshot it.

Push-to-live time = merge until the health-check step passes. Read it from the job durations in the Actions run.

### 6.4 Test B — a broken change is blocked

```bash
git switch main
```

```bash
git pull
```

```bash
git switch -c bug/broken-add
```

In `src/app.js`, in the `/api/add` route, change `sum: a + b` to `sum: a - b`. Do not run the tests. Then:

```bash
git commit -am "Introduce a bug on purpose"
```

```bash
git push -u origin bug/broken-add
```

Open a pull request. Screenshot the **red** test job (`GET /api/add adds two numbers` fails) and the **blocked Merge button**. Open `http://localhost:8080/health` and screenshot that the version is still the one from Test A. Close the pull request **without merging**. Do not delete the failed run — the instructor looks for it.

### 6.5 Test C — roll back a bad release

First ship a "bad" release: branch `feature/broken-release`, change the `<h1>` to `ITSD 85 BROKEN RELEASE`, open a PR, merge, let it deploy, and screenshot it live.

**Method 1 — through the pipeline:**

```bash
git switch main
```

```bash
git pull
```

```bash
git switch -c revert/broken-release
```

```bash
git revert --no-edit HEAD
```

If `HEAD` is a merge commit, use `git revert --no-edit -m 1 HEAD` instead.

```bash
git push -u origin revert/broken-release
```

Open a PR, wait for green, merge, and time it until the old title is live under a **new** commit ID.

**Method 2 — on the server, no rebuild.** Deploy the broken release once more (or do this before Method 1), then on the server:

```bash
docker image ls itsd85-app
```

Pick the previous tag (7-character commit ID) and start it with a stopwatch running:

```bash
cd ~/actions-runner/_work/boxhead-survival/boxhead-survival && APP_VERSION=<previous-tag> docker compose -p itsd85 up -d --no-build
```

```bash
curl http://localhost:8080/health
```

The version must be the previous tag. Afterwards still revert in Git (Method 1), or the next deploy brings the bad code back.

### 6.6 Record the results

1. Fill the four rows of the **Results** table in `README.md` (CI/CD section) with the actual result and the push-to-live time.
2. The paper needs **at least 5 measured deploys** with mean and range. Tests A and C give three; make two more small PRs (for example a wording change on the status page) and time them.
3. The Actions tab must end up showing: one green test → deploy run, the red Test B run, and the Test C rollback run.

---

## 7. Demo video (2–3 minutes)

Record the phone screen with the phone's built-in screen recorder (it captures game audio). `adb shell screenrecord /sdcard/demo.mp4` also works but records no sound and stops at 3 minutes. For the two-phone part, film both phones side by side with a third device.

| Time | Shot | Must be visible |
| :-- | :--- | :--- |
| 0:00–0:15 | Title screen → main menu → mode select | Offline / Online buttons |
| 0:15–0:35 | Level select on a fresh install | Sector 1 open, Sectors 2–5 locked |
| 0:35–1:05 | Clear Sector 1 | Goal banner, result screen with stars, "Sector 02 unlocked" |
| 1:05–1:15 | Back to level select | Sector 2 now open |
| 1:15–1:35 | Die on purpose in Sector 2 | Defeat result screen, Retry button |
| 1:35–1:55 | Swipe down, turn on **airplane mode**, play offline, force-close, reopen | Airplane icon in the status bar; Sector 2 still unlocked |
| 1:55–2:35 | Two phones: host, join, play, result on both | Both screens in frame |
| 2:35–2:50 | Wi-Fi off → try Online | The error message, no crash |

Sectors 4–5 must appear in the video (the instructor only plays 1–3). If the cut above runs long, show a few seconds of each from an unlocked save instead of the level-select return.

Upload to Google Drive (*Anyone in your school with the link can view*) or unlisted YouTube, and add the link to the README under **Download**.

---

## 8. Freeze and turn in

1. Commit all evidence files. Re-check that no `.env`, keystore, runner token or `nakama_local.cfg` is staged.
2. Update the paper: the game lab needs **5–7 pages** (the current PDF is 4) and the retest results; the CI/CD lab asks for its **own** 4–6 page paper with the Test A/B/C table and deploy-time chart. Ask the instructor whether one combined paper is acceptable before relying on it.
3. Tag and release. `v1.0` already exists, so the lab's resubmission rule applies:

   ```bash
   git tag -a v1.1 -m "ITSD 85 Lab final submission"
   ```

   ```bash
   git push origin v1.1
   ```

   On GitHub: **Releases → Draft a new release →** tag `v1.1` → attach the `.apk` and `paper.pdf` → **Publish**.
4. Repository name: the labs ask for `itsd85-lab<no>-<section>-<team>` (game) and `itsd85-cicd-lab` (CI/CD). This repository is `boxhead-survival`. Rename it under **Settings → General**, or confirm with the instructor that the current name is accepted. After a rename, update the links in `README.md` and the Method 2 path in section 6.5.
5. Google Classroom: repository link, release link, video link, paper PDF, contribution log PDF, and the private comment (name, latest commit ID, phone models tested).
