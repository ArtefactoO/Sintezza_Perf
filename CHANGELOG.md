# Changelog

## 0.7.0

- Quieted ordinary loading links with flat, faint surfaces and borders. Reserved accent colors for the three longest links and replaced heavy arrows with centered muted chevrons from Theme, with a thin standalone fallback.
- Replaced loading-chain text with compact links sized to their content. Names, inline times and native arrows wrap together; short intervals use milliseconds. The three longest positive event intervals remain highlighted in their chronological positions. Full plain-text copying is preserved, and scrolling does not repaint the chain in Lua.
- Fixed loading reports disappearing after background history churn: the latest ten unpinned loading reports have a separate retention allowance. Chain/Details switching now preserves selection and scroll position without rebuilding the report.
- Added a separate chronological loading chain with bounded marker storage and explicit omitted-marker counts. Plain-text copying preserves the complete stored chain. Legacy reports keep their original intervals.
- Shortened the loading-record picker hint and gave it an explicit title.
- Simplified the loading report footer to one Copy text action, available without prior selection. Event gaps now use spaced paragraphs with duration, Start and End on separate lines in both the window and copied report.
- Replaced the duplicate copy-preparation action with a Copy dialog containing the complete selected loading report, auto-focused and highlighted for Ctrl+C. Added an explanation of event-gap ordering and boundaries to loading reports.
- Preserved Theme's window-raising handlers for the main and login report windows, and hid help tooltips while a choice menu is open. Renamed the header action to Login timing and the report window to Login and reload timing.
- Made the loading report selector compact and replaced unsupported arrow glyphs with portable separators. Added a copy preparation control beside Select text that becomes available after selection and explains the required Ctrl+C shortcut.
- Added a reusable loading-report window with saved report selection. Open or close it with the header Loading button, `/sperf startup` or a right-click on the minimap icon. The icon tooltip describes both mouse actions.
- Added character login and UI reload reports with explicit timing boundaries, startup phases and the longest observed addon-event gaps. `/sperf reload` marks the start of a measured reload, and `/sperf startup` prints the latest loading report.
- Improved standalone button and history-row styling with full-width hover/press states, muted disabled controls and inset row actions.
- Perf uses Theme's subdued surface for metric summaries and report details, including the Load strip and the selected module card.
- Counter reports explain that milliseconds were not recorded and offer a manual Record CPU setup for the selected module. Missing visibility/code labels are distinguished from missing timing; setup descriptions spell out each mode.
- When Theme is installed, all Perf windows/dialogs, inputs, scrolling, tooltips, progress and chart marks use shared Theme providers and palette colors. Dialogs also follow shared scale/opacity/layer preferences. Standalone styling remains available without Theme.
- Added Developer views for registered modules, function timings/allocations, explicit hidden-window/change signals and compatible repeated A/B comparisons. Supports focused single-point captures, bounded persistent reports and export.
- Added optional Sintezza_PerfAPI v1 with stable registration, direct inactive calls, preserved nil-containing returns and propagated errors without retries. Sintezza_UI integration remains a separate task. Added a complete integration guide and copyable bridge.
- Developer collection has duration, operation, point, depth and service-cost limits. Ordinary and developer captures cannot overlap; background collection and memory scans are deferred. No per-call Lua result tables in the CPU path; native allocation mode is separately probed and more expensive. Release version remains unchanged.
- Added light and detailed recordings, next-combat/boss arming with cancellation/expiry, observed frame-time p95/p99, long-frame counts and timestamped context markers.
- Added report tabs for frame/CPU correlation, per-addon detail and bounded session-memory snapshots, plus A/B groups with medians, repeat counts, read-only conditions and text/JSON comparison export.
- Old reports and preferences are preserved. Partial, legacy, missing-data and incompatible recordings cannot produce misleading comparison percentages. Equal addon version numbers are not treated as identical code.
- Frame statistics use a fixed-size numeric histogram, finalized after recording. Light mode reads only combined CPU and Perf per frame; waiting does not sample frames. Existing collector cost guards and safe memory-scan rules remain in place.
- Settings now use named rows, visible explanations, on/off controls and an Automatic / Button only memory choice. Existing preferences are preserved.
- Settings and report dialogs can be dragged by their headers outside combat and keep their position until reload. Added movement and overhead tooltips without new collection timers.
- Added Load, Capture, and History views with capture-local CPU averages and peaks, combined spike intervals, and a separate profiler row included in totals.
- Saved detailed captures and light background episodes across reloads. Added names, pinned reports, bounded retention, delete confirmation, and text/JSON export.
- Kept background collection sparse and disabled by default. Detailed collection runs only for a bounded capture, reuses numeric buffers, and stops early if its measured collector cost exceeds the safety budget.
- Deferred memory scans during combat and captures; recorded snapshot time and age. Removed the speculative FPS-loss estimate and added English/Russian explanations for controls and metrics.
- Preserved minimap behavior and shared window appearance preferences. Dialogs and visible rows are reused.
- Left-clicking the minimap icon opens or closes the window.
- Connected window scale, opacity, and layer to the shared Theme settings.
- Updated the project logo and in-game addon icon.

## 0.6.3

- Chat reports use localized milliseconds and seconds. Command help shows the addon folder placeholder in the current language.

## 0.6.2

- CPU and Memory now share the same summary, table, tooltips, and refresh controls. Each tab opens with its own default sorting.

## 0.6.1

- Added CPU and spike reading timestamps and hover descriptions for metrics, chart elements, and controls.

## 0.6.0

- Memory refreshes every minute while CPU or Memory is visible and reuses recent native snapshots.
- Added side-by-side CPU and memory columns with comparison bars and a guide to reading the spike chart.

## 0.5.1

- Aligned tab actions and added labeled summaries for CPU, spike captures, and memory snapshots. The CPU summary includes measured FPS and estimated FPS cost.

## 0.5.0

- Replaced Overview with a CPU table showing recent and session averages, session peaks, and each addon's share of client frame time.
- Moved the spike timeline and capture controls to Spikes.

## 0.4.0

- Display background spike history and per-addon counters in Overview and Spikes. Use the Background and Capture buttons to switch between reports.
- Replaced font-dependent sort markers with arrow textures.

## 0.3.3

- Added a minimap icon switch to the settings page.

## 0.3.2

- The open background report refreshes with each five-second sample.
- Added a Settings button beside the close button in the main window.

## 0.3.1

- Added a switch and a report for background spike monitoring under Settings → AddOns → Sintezza Perf.

## 0.3.0

- Added opt-in background spike monitoring using the native add-on profiler and a chat report for the six latest spike intervals.
- Made the logo background transparent.

## 0.2.0

- Added a minimap button with a visibility toggle and a standalone performance window.
- Added a clickable spike timeline, per-interval addon attribution, sortable tables, and on-demand memory snapshots.
- Added animated charts and progress with optional Sintezza Theme styling. Hidden windows skip visual updates.

## 0.1.0

- Added on-demand rankings for addon CPU time, peak frame time, spike counts, and Lua memory.
- Added per-addon details and timed captures for frames over 5, 10, and 50 ms.
- Added a timeline for spike windows and a command to repeat the latest report.
