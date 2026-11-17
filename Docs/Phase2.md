# Phase 2 implementation

The approved phase-2 interface, collection modes, frame statistics, memory trail and A/B comparison are implemented and installed. Lua syntax and 191 mock assertions pass at the 2026-11-17 checkpoint. All 16 RU/EN geometry views were inspected. Version 0.7.0 is preserved; 17 packaged paths were verified by SHA-256.

The user requested implementation, local installation, bounded overhead, tooltips and preparation of the remaining steps. Version stays **0.7.0**; new behavior belongs in `Unreleased`. No release, tag or upload was requested. Baseline copies are in `D:/Games/WoW_addons/.execute-verification/.perf-phase2-verification/baseline`.

## Scope and accepted direction

The accepted reference is `C:/Users/egora/.codex/visualizations/2026/11/16/01a1e676-0cea-7992-a8fc-c9a298447a41/sintezza-perf-phase-two.html`, with `phase-two-*.png` in the same directory. Existing Sintezza Theme owns the palette, fonts and window appearance; the standalone fallback remains available. The implementation retains the improved settings and movable dialogs. No new design identity was introduced.

Antislop `during` is the explicit session choice. The direction is the accepted Sintezza profiler for players inspecting addon cost, with ENERGY 1 / RHYTHM 2 / MOTION 1. Tables prioritize comparison, the capture chart prioritizes the selected interval, and restrained accents identify actions and selection. Spacing separates controls from measured results. The four main tabs follow the user's workflow: Load, Capture, History and Compare.

## Requirements and implementation matrix

| ID | Requirement and owning files | Implementation | Evidence |
| --- | --- | --- | --- |
| P2-01 | Light/detailed bounded capture; observer included (`Perf.lua`) | Implemented. Light mode reads overall CPU and Perf; detailed mode reads all tracked addons. Both keep Perf in the total. | Core and phase-2 mocks cover captures, read counts, missing values and observer inclusion. |
| P2-02 | Next combat/boss, cancellation, expiry and event end (`Perf.lua`) | Implemented. Waiting expires after 300 seconds without frame sampling. Recording is bounded to 120 seconds and stops at the matching event end. | Mocks cover one-shot combat activation, matching/mismatching encounter IDs, cancellation and expiry. Native event delivery is unverified. |
| P2-03 | Frame intervals, p95/p99, long frames and paired CPU (`Analytics.lua`, `Phase2Window.lua`) | Implemented. Fixed histogram, percentiles after stop, and CPU paired with the selected worst observed frame. | Constant/tail distributions and paired-frame mocks pass; capture geometry inspected in both languages. Native tick alignment is unverified. |
| P2-04 | Bounded context/manual markers; no causal verdict (`Analytics.lua`, `Perf.lua`) | Implemented. Whitelisted events and manual marks, at most 80 markers with omissions counted. | Marker-bound and context-change mocks pass; tooltips explain correlation limits. |
| P2-05 | Safe memory trail, gaps and separate sample scope (`Analytics.lua`, `Perf.lua`, `Phase2Window.lua`) | Implemented. At most 30 snapshots, coalesced into fixed one-minute windows; reports copy the available session trail at completion. | Frequent-cache-refresh regression preserves separate minute windows. RU/EN memory geometry inspected. |
| P2-06 | A/B groups, medians, conditions and exclusions (`Analytics.lua`, `Phase2Window.lua`) | Implemented. Read-only conditions, repeat counts, preliminary status and text/JSON copy. Ineligible records and mismatches cannot produce comparison percentages. | Mocks cover medians, profile/duration/context mismatch, unknown conditions, partial exclusion and negative JSON deltas. |
| P2-07 | Preserve old reports/settings and bounded exports (`History.lua`) | Implemented. Schema 2 migration keeps old measurements and settings without inventing frame data. Existing retention/pin/row/interval limits remain. | Baseline migration/retention/export checks and phase-2 legacy/settings checks pass. Actual client persistence is unverified. |
| P2-08 | Accepted layout and RU/EN tooltips (`Window.lua`, `Phase2Window.lua`) | Implemented. Named setup, four main tabs, Smoothness/Addons/Memory report tabs, history groups and comparison actions reuse the existing window kit. | 42 baseline UI assertions with 22 exercised tooltips; 57 phase-2 UI assertions with 27 tooltips; 16 inspected geometry views. |
| P2-09 | Bounded collection cost and reuse (`Perf.lua`, `Analytics.lua`, UI files) | Implemented. Two reads per light frame; N+1 per detailed frame for N tracked addons. Fixed numeric buffers and existing cost guard. | Idle/background budgets pass. Detailed 1000-frame mock: 0.000 KiB steady-state heap growth; light allocation bound passes. Reopening cached setup 100 times adds no widgets. |
| P2-10 | Syntax, mocks, layout, package/install checks and roadmap (`Tests`, docs) | Complete: syntax, mocks, layout, package-filter/TOC/version checks, local installation and remaining-step preparation. | All 17 packaged paths match installed SHA-256; [Roadmap.md](Roadmap.md) prepares later work without implementing phase 3. |

## Measurement semantics and limits

Frame statistics use the elapsed interval supplied to the observer's `OnUpdate`; they are not a GPU presentation trace or 1% low FPS. The first callback is discarded because native `LastTime` describes the previous tick. The 2,801 preallocated histogram buckets use 0.1 ms steps to 100 ms, 1 ms steps to one second, 10 ms steps to ten seconds, then overflow. p95/p99 are bucket upper bounds computed after recording; the overflow bucket uses the observed maximum. Missing/secret readings remain unavailable and counted.

The collection loop does not sort, format text, save history or walk memory. The guard stops and saves a partial report above 1 ms average collection time over 60 sampled frames, or above 20 ms for one pass. It measures collection, excluding window drawing and report saving. It does not guarantee a particular FPS. No forced garbage collection, `scriptProfile` changes or automatic disabling of other addons is added.

With the window hidden, no active capture and background disabled, there is no redraw ticker, collection callback or memory scan. Visible live CPU refreshes every two seconds; capture display refreshes at most once per second. Memory scans remain manual or at most once per minute on visible Load, outside combat/capture. Starting a capture reuses the previous snapshot with its timestamp and age. The trail preserves actual sample times and gaps, has a separate session time range, and does not interpolate missing values or diagnose a leak. Repeated cache updates replace only the point in the same fixed minute window.

Comparison conditions are recorded at capture start, not continuously sampled proof of an identical environment. Compatibility checks collection profile, scenario, trigger/encounter, measurement definition, client build, zone/map, group size, initial combat state, FPS cap, instance type and difficulty. Actual duration may differ by at most the larger of 0.5 seconds or 2% of the shorter run. Unknown required conditions or a recorded context change block percentages. Map IDs are compared when present; two absent map IDs alone do not reject a run.

Eligible records must be complete captures with at least 60 valid frame samples and no missing frame/CPU readings. Manual/safety stops are partial; old records and background episodes lack the required frame measurements. Groups show medians and counts; fewer than three runs in either group is preliminary. Matching conditions cannot exclude different world activity or background programs, and equal addon versions do not establish identical local code. A/B assignment does not bypass history retention; pin important reports separately.

## Completed checks

Run from `D:/Games/WoW_addons` using Python 3.12 and Lupa 2.6:

```powershell
& 'C:/Program Files/WindowsApps/OpenAI.CodexPrimaryRuntime.v26-1112-611-0_26.1112.611.0_x64__3k8sg7r9htsxt/dependencies/python/python.exe' 'Sintezza_Perf/Tests/run.py' --runtime 'D:/Games/WoW_addons/.execute-verification/.perf-verification-20261117/runtime' --suite all
```

Checkpoint output:

```text
Lua 5.1 syntax: PASS
Collector steady-state heap growth over 1000 frames: 0.000 KiB
Core mocks: PASS (51 checks, Lua Lua 5.1)
Phase2 mocks: PASS (41 checks)
UI mocks: PASS (42 checks, 22 tooltips)
Phase2 UI mocks: PASS (57 checks, 27 tooltips)
```

The 191 assertions include tooltip assertions; they are not 191 independent gameplay scenarios. The two review findings are resolved: memory points use fixed minute windows, and the shared Background footer refreshes before the phase-2 view returns. Independent reruns of the 41 phase-2 core and 57 phase-2 UI assertions passed after these fixes.

The source-driven geometry adapter produced 16 inspected images in `D:/Games/WoW_addons/.execute-verification/.perf-phase2-verification/visual`: `{ruRU,enUS}-{capture,history,compare,memory,live,export,settings,setup}.png`. Header alignment and selection-region corrections are included. RU uses a Theme geometry stub; EN uses the standalone path. The adapter reads production layout but uses synthetic data and does not fully represent Theme artwork/icons. These are layout fixtures, not WoW screenshots or UIForever validation. [Tests/README.md](../Tests/README.md) contains reproduction commands.

Target evidence is pinned to Gethe/wow-ui-source `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`, Forever 1.60.1.70938. EncounterInfo declares ordered `ENCOUNTER_START`/`ENCOUNTER_END` payloads; SimpleFrameAPI/SimpleLineAPI declare the line methods used by the chart. Registration is guarded. The source declarations and mocks do not certify runtime event delivery or callback alignment.

## Scoped antislop evidence

These results cover the implemented paths, source and mocks. They are not a full-client delivery-gate PASS.

| Check | Result and evidence |
| --- | --- |
| R-26 / C-2, behavior | PASS in mocks: setup validates a scenario and starts a light capture; tabs switch; mark/stop/export work; history opens records and assigns A/B; rename/pin/delete work; repeat setup inherits the baseline; waiting cancels; conditions open read-only; settings remain available. |
| R-27 / C-5, states | PASS in mocks: missing API/readings, light-mode missing addon detail, waiting, partial records, empty comparison groups and unknown conditions stay explicit. |
| R-17 / R-36 / R-40, claims and cost | PASS for the documented scope: mock-only heap/read-count results, fixed buffers, cached dialog reuse and collection-guard limits are stated without an in-game performance guarantee. |
| R-37 / R-31, direction and purpose | PASS for the implementation scope: approved layout, existing Theme tokens, E1/R2/M1 direction and the control/result hierarchy described above; no new design identity. |
| R-35, visual evidence | PASS for geometry inspection: all 16 RU/EN views inspected against the accepted layout; adapter omissions and game-check restrictions are explicit. |
| R-02 / R-16 / R-38, documentation | PASS for this checkpoint: concrete behavior and check counts, no fabricated gameplay measurements or marketing claims. |

The earlier mock palette measured 6.87:1 for `#cbb3a3` on `#41271c`, 6.57:1 for `#e7a57b` on `#41271c`, and 7.77:1 for `#fff1e5` on `#69432d`. These values do not certify every current native Theme state. Full native contrast, font rendering and user scaling remain unverified. Existing cursor behavior and text-field Enter/Escape remain; full Tab traversal and native directional controller support are not implemented or claimed.

## Package and installation checkpoint

Installation manifest: `D:/Games/WoW_addons/.execute-verification/.perf-phase2-verification/installed.json`. Version 0.7.0, Unreleased, five TOC entries, assets, package exclusions and publication-copy consistency passed validation. All 17 packaged relative paths were copied or already identical and verified by SHA-256. Prior installed files are backed up under `installed-backup` in that work folder. No project file was removed from source, so no installed files were deleted. The source TOC was installed without changing Interface. No new release archive, tag, push or upload was created.

Destination: `D:/Games/World of Warcraft/_forever_/Interface/AddOns/Sintezza_Perf`. The new `Analytics.lua` and `Phase2Window.lua` TOC entries require a game restart after installation. Only the user performs that restart.

Project policy requires static/mocked checks and prohibits launching or controlling WoW. No game client was launched or controlled, and no real WTF/SavedVariables were changed. Real collection overhead, native event/tick alignment, actual reload persistence, combat behavior, full Theme rendering and physical controller/focus checks were not run. The [remaining roadmap](Roadmap.md) keeps these user-run observations separate from phase-3 preparation.
