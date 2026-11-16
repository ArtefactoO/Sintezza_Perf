# Changelog

## 0.6.4

- Updated the project logo and in-game addon icon.

### По-русски

- Обновлены логотип проекта и игровая иконка аддона.

## 0.6.3

- Chat reports use localized milliseconds and seconds. Command help shows the addon folder placeholder in the current language.

### По-русски

- В отчетах чата переведены обозначения миллисекунд и секунд. Справка команд показывает подсказку об имени папки аддона на выбранном языке.

## 0.6.2

- CPU and Memory now share the same summary, table, tooltips, and refresh controls. Each tab opens with its own default sorting.

### По-русски

- У CPU и «Памяти» теперь общая сводка, таблица, подсказки и обновление данных. У каждой вкладки своя сортировка по умолчанию.

## 0.6.1

- Added CPU and spike reading timestamps and hover descriptions for metrics, chart elements, and controls.

### По-русски

- Добавлено время последнего чтения CPU и спайков, а также подсказки к показателям, графику и кнопкам.

## 0.6.0

- Memory refreshes every minute while CPU or Memory is visible and reuses recent native snapshots.
- Added side-by-side CPU and memory columns with comparison bars and a guide to reading the spike chart.

### По-русски

- CPU и «Память» обновляют данные о памяти раз в минуту, используя свежий снимок WoW, если он уже есть.
- В таблице CPU и память стоят рядом и снабжены полосами сравнения. У графика спайков появилась подсказка «Как читать».

## 0.5.1

- Aligned tab actions and added labeled summaries for CPU, spike captures, and memory snapshots. The CPU summary includes measured FPS and estimated FPS cost.

### По-русски

- Действия вкладок выровнены справа. В шапке появились подписанные показатели CPU, спайков и памяти. Сводка CPU показывает текущий FPS и расчетное влияние аддонов на FPS.

## 0.5.0

- Replaced Overview with a CPU table showing recent and session averages, session peaks, and each addon's share of client frame time.
- Moved the spike timeline and capture controls to Spikes.

### По-русски

- Вместо «Обзора» появилась вкладка CPU со средним временем работы, пиком за сеанс и долей времени кадра для каждого аддона.
- График и кнопки замера перенесены на вкладку «Спайки».

## 0.4.0

- Display background spike history and per-addon counters in Overview and Spikes. Use the Background and Capture buttons to switch between reports.
- Replaced font-dependent sort markers with arrow textures.

### По-русски

- «Обзор» и «Спайки» показывают фоновую историю и счетчики аддонов. Кнопки «Фон» и «Замер» переключают отчеты.
- Направление сортировки обозначено текстурой стрелки.

## 0.3.3

- Added a minimap icon switch to the settings page.

### По-русски

- В настройки добавлен переключатель «Значок у миникарты».

## 0.3.2

- The open background report refreshes with each five-second sample.
- Added a Settings button beside the close button in the main window.

### По-русски

- Открытый фоновый отчет обновляется раз в пять секунд во время сбора.
- Рядом с крестиком в основном окне появилась кнопка «Настройки».

## 0.3.1

- Added a switch and a report for background spike monitoring under Settings → AddOns → Sintezza Perf.

### По-русски

- В «Настройки → Модификации → Sintezza Perf» добавлены переключатель фонового сбора и отчет по спайкам.

## 0.3.0

- Added opt-in background spike monitoring using the native add-on profiler and a chat report for the six latest spike intervals.
- Made the logo background transparent.

### По-русски

- Добавлен фоновый сбор спайков по штатным счетчикам и отчет в чате за шесть последних интервалов со спайками.
- Убран темный фон логотипа.

## 0.2.0

- Added a minimap button with a visibility toggle and a standalone performance window.
- Added a clickable spike timeline, per-interval addon attribution, sortable tables, and on-demand memory snapshots.
- Added animated charts and progress with optional Sintezza Theme styling. Hidden windows skip visual updates.

### По-русски

- Добавлены окно статистики и кнопка у миникарты с переключателем видимости.
- Появились график спайков с выбором интервала, сортируемые таблицы и снимки памяти по запросу.
- Графики и индикатор замера обновляются плавно в открытом окне. Sintezza Theme задает оформление, если установлена.

## 0.1.0

- Added on-demand rankings for addon CPU time, peak frame time, spike counts, and Lua memory.
- Added per-addon details and timed captures for frames over 5, 10, and 50 ms.
- Added a timeline for spike windows and a command to repeat the latest report.

### По-русски

- Добавлены рейтинги аддонов по времени работы, пиковому времени на кадр, числу спайков и памяти Lua.
- Добавлены подробности по отдельному аддону и замеры кадров за порогами 5, 10 и 50 мс.
- Добавлены отметки времени по спайкам и команда для повторного показа последнего отчета.
