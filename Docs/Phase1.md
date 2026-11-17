# Perf 0.8.0: phase 1

> Historical context, 2026-11-17: the 0.8.0 validation and installation checkpoint below predates the user's version rollback. Current source and installed version metadata is 0.7.0; the later settings explanations and movable-dialog correction are recorded under `Unreleased`. Ordinary local edits and installation keep that version unchanged, so matching version metadata alone does not establish identical code. The earlier validation history is preserved below.

The collector, history and approved interface are implemented. Static and mock checks pass at the checkpoint below. The final review resolved its three findings. Release-package validation passed, and version 0.8.0 was installed to WoW Forever with all 13 packaged paths verified by SHA-256.

## Scope and existing design

The user approved the interactive Sintezza mockup on 2026-11-17 and requested implementation and installation, bounded profiler overhead and descriptions in tooltips. Antislop `during` is the explicit session choice.

The baseline was source and installed version 0.7.1 with existing edits in `Window.lua`, README, changelog and TOC. The implementation preserves shared window preferences and left-click-only minimap behavior. Baseline copies and installed hashes are under `D:/Games/WoW_addons/.execute-verification/.perf-verification-20261117`.

This extends the existing Sintezza visual system. Shared warm surfaces, palette, fonts and window controls remain owned by Sintezza Theme; Perf retains a standalone fallback. No new design identity or `DESIGN.md` was introduced. The accepted reference is `C:/Users/egora/.codex/visualizations/2026/11/16/01a1e676-0cea-7992-a8fc-c9a298447a41/sintezza-perf-concept.html`, with `perf-desktop.png` and `perf-history.png` in the same directory.

The window has Load, Capture and History tabs, three capture metrics, a combined-spike chart with interval details, a sortable addon table and a separate profiler row. Saved reports support rename, pin, confirmed deletion and text/JSON export. Phase-2 A/B comparisons and automatic boss recording are outside this implementation.

## Requirements and implementation matrix

| ID | Acceptance and files | Implementation | Verification |
| --- | --- | --- | --- |
| REQ-01 | Capture-local mean, peak and frame count; missing readings disclosed (`Perf.lua`) | Implemented. First callback discarded; invalid and secret readings remain unavailable. | Core mocks cover capture-local metrics, missing data and observer inclusion. Native tick timing not run. |
| REQ-02 | Combined spikes retained without individual >5 ms crossings; row counters not added into the overall count (`Perf.lua`, `Window.lua`) | Implemented. Overall metrics and per-addon counts stay separate. Incomplete per-addon readings cannot imply that no individual culprit exists. | Combined-only spike and missing per-addon interval-data regressions pass. |
| REQ-03 | Current CPU and memory with separate scope/timestamps; no estimated FPS-loss claim (`Perf.lua`, `Window.lua`) | Implemented. Live CPU uses the native 60-tick mean; memory keeps its snapshot time. | Source review, live UI mock and RU/EN geometry fixtures. |
| REQ-04 | Bounded history, profile migration, pinned cap and unavailable background metrics (`History.lua`) | Implemented. 20/50/100 regular reports, up to 10 pins; 256 rows and 120 intervals per report. | Migration, repeated migration, retention, pin cap and null export mocks pass. Real client save/reload not run. |
| REQ-05 | Rename, pin, confirmed deletion and selected report export (`History.lua`, `Window.lua`) | Implemented. Empty names rejected; text and JSON can be selected for copying. | UI mocks exercise rename validation, pin, cancel/confirm deletion and export selection; core mocks cover export contents. |
| REQ-06 | Profiler included in totals; bounded capture cost; no idle work or unsafe memory scan (`Perf.lua`) | Implemented. Preallocated capture buffers, cost guard and deferred memory requests. | Idle/background call budgets, guard, secret values and memory deferral pass. Steady-state heap and dialog reuse results below are mock observations. |
| REQ-07 | Accepted layout; RU/EN tooltips; empty, recording, unavailable and stale-memory states (`Window.lua`) | Implemented. Tooltips describe actions, units, scope, missing readings and collector cost. | 33 UI checks pass; 22 visible tooltips exercised. Eight RU/EN layout fixtures rendered. Full client tooltip/layout inspection not run. |
| REQ-08 | Built-in addon settings, existing window/minimap preferences and optional Theme (`Window.lua`) | Implemented. Settings and dialogs reuse widgets; Theme remains optional. | Built-in registration and stored scale preservation pass in mocks. RU Theme-adapter and EN standalone fixtures rendered. Real Theme artwork not rendered by the adapter. |
| REQ-09 | Input/controller assessment and combat-safe behavior (`Window.lua`) | Native cursor operation and text Enter/Escape behavior retained; no protected input interception added. | Source assessment and mocked clicks completed. Full Tab navigation and native directional controller navigation are not implemented. Physical focus acquisition was not tested. |
| REQ-10 | Syntax, mocks, visual comparison, release metadata and installed hashes (`Tests`, docs) | Source and installed version are 0.8.0; TOC loads History, Perf, then Window. | Lua 5.1 syntax, current mocks, package filter/TOC/version/changelog checks and all 13 installed relative-path/SHA-256 checks pass. |

## Target evidence

Target: Forever 1.60.1.70938, interface 16001. API evidence is pinned to Gethe/wow-ui-source `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`, resolved 2026-11-17. `AddOnProfilerDocumentation` and `AddOnProfilerConstantsDocumentation` define `LastTime` for the most recent tick, `RecentAverageTime` for 60 ticks, overall/application metrics and cumulative >5/>10/>50 counters. These declarations support the chosen metric meanings; they do not prove runtime delivery or callback timing in the client.

## Collection cost

With no active capture, the window closed and background collection off, Perf has no redraw ticker, collector callback or memory scan. Background collection reads one overall counter every five seconds while unchanged; it reads addon counters after threshold growth and skips checks during a detailed capture.

A detailed capture reads one overall `LastTime` and one `LastTime` per tracked addon per sampled frame. It accumulates into preallocated numeric buffers without sorting, formatting strings, saving history or scanning memory in that loop. The guard saves a partial report if collection costs more than 1 ms on average over 60 sampled frames, or more than 20 ms in a single pass. The measured guard excludes window drawing and report saving; it does not guarantee FPS or total addon cost.

Visible live readings refresh every two seconds; the capture view redraws at most once per second. The hidden window cancels its redraw ticker. Memory snapshots are manual or at most once per minute on the visible Load tab, outside combat and capture. A blocked manual request remains queued until a safe visible memory read and adds no timer. Starting a capture reuses the existing snapshot with its original timestamp and age.

## Completed checks

Run from `D:/Games/WoW_addons` with the existing Python 3.12 and Lupa 2.6 runtime:

```powershell
& 'C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1112-611-0_26.1112.611.0_x64__3k8sg7r9htsxt/dependencies/python/python.exe' 'Sintezza_Perf/Tests/run.py' --runtime 'D:/Games/WoW_addons/.execute-verification/.perf-verification-20261117/runtime' --suite all
```

Checkpoint output on 2026-11-17:

```text
Lua 5.1 syntax: PASS
Collector steady-state heap growth over 1000 frames: 0.000 KiB
Core mocks: PASS (51 checks, Lua Lua 5.1)
UI mocks: PASS (33 checks, 22 tooltips)
```

The UI suite also confirms that reopening settings 100 times creates no additional widgets. These observations concern the isolated Lua mocks, not game benchmarks or all possible allocation paths. [Tests/README.md](../Tests/README.md) describes the runner and fixture generation.

The source-driven geometry adapter produced eight images under `D:/Games/WoW_addons/.execute-verification/.perf-verification-20261117/visual`: `{ruRU,enUS}-{capture,history,live,export}.png`. The RU fixture uses a Theme geometry stub; EN uses the standalone path. The adapter reads production Lua layout but uses synthetic data and omits Theme artwork and icons. Its font-size/clipping defects were corrected during review. These images support geometry and text-layout comparison only; they are neither WoW screenshots nor UIForever validation.

Review corrections include actual-duration chart bounds and proportional interval widths after an early stop, fractional boundaries for short captures, a visible search label, modal close tooltips, and remembered manual memory refreshes after combat/capture. The three final review findings are resolved. The follow-up regression `interval retains missing individual readings for honest explanation` also passes: the chart cannot treat incomplete per-addon data as proof that no individual culprit exists.

## Antislop delivery evidence

The following PASS results cover source and mocks only; they do not certify the whole WoW client:

| Check | Result and evidence |
| --- | --- |
| R-26 / C-2, control behavior | PASS within exercised paths: mock clicks open tabs and dialogs, start/stop recording, rename, pin, confirm/cancel deletion and select export text. |
| R-27 / C-5, states and measurements | PASS within exercised paths: empty capture, missing API, zero-sample data and missing/secret readings remain explicit; background export preserves absent metrics as null. |
| R-17 / R-36 / R-40, performance claims | PASS for this report: every numeric cost result names its mock scope; the guard's measurement excludes UI and saving, and no FPS guarantee is made. |
| R-37, existing direction | PASS for implementation scope: the accepted Sintezza reference and shared Theme remain the visual authority; the adapter's omitted artwork is disclosed. |

Full R-32/C-4 keyboard/controller resilience and real-client contrast/layout are outside the completed checks. This is not a full-client delivery-gate PASS.

## Release checkpoint and checks not run

Installed path: `D:/Games/World of Warcraft/_forever_/Interface/AddOns/Sintezza_Perf`. The installation manifest is `D:/Games/WoW_addons/.execute-verification/.perf-verification-20261117/installed-manifest.json`; it records all 13 packaged relative paths and SHA-256 values. Prior installed files were backed up in that work folder. No installed files were deleted: this release removes no previously owned source files. Tests, hidden paths and packaging metadata are excluded using `Tools/Build-Releases.py` and `.pkgmeta`.

Release archive: `D:/Games/WoW_addons/Sintezza_Perf/.releases/Sintezza_Perf-0.8.0-Forever.zip`. The publication Markdown and HTML copy field were synchronized without uploading or publishing. The added `History.lua` TOC entry requires the user to restart the game after installation.

Project `AGENTS.md` requires static and mock checks and prohibits launching or controlling WoW for verification. No game client was launched or controlled, and no real WTF/SavedVariables were changed. Native event/tick timing, real collection overhead, history persistence across an actual client reload, in-game combat, Theme visuals, physical controller navigation and focus acquisition were not run. These user-run checks remain separate from completed syntax and mock validation.
