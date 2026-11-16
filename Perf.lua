local addonName, ns = ...
local theme = Sintezza_Theme
local function Text(russian, english)
    local locale = theme and theme:GetLocale() or GetLocale()
    return locale == "ruRU" and russian or english
end
ns.Text = Text

local api = C_AddOnProfiler
local metric = Enum and Enum.AddOnProfilerMetric
local addons = C_AddOns
local thresholds = { "CountTimeOver5Ms", "CountTimeOver10Ms", "CountTimeOver50Ms" }
local topModes = {
    recent = { "RecentAverageTime", Text("Недавнее среднее, мс", "Recent average, ms"), "%.3f" },
    peak = { "PeakTime", Text("Пик с начала сеанса, мс", "Session peak, ms"), "%.3f" },
    spikes = { "CountTimeOver5Ms", Text("Кадры >5 мс за сеанс", "Session frames >5 ms"), "%d" },
    memory = { false, Text("Память, МиБ", "Memory, MiB"), "%.2f" },
}
local active, last, loader
local background, settings
local backgroundInterval, backgroundWindows = 5, 6
local memoryScannedAt, memoryUpdated

local function MarkMemoryScan()
    local now = GetTime()
    if memoryScannedAt == now then return end
    memoryScannedAt, memoryUpdated = now, date("%H:%M:%S")
end

if type(hooksecurefunc) == "function" and type(UpdateAddOnMemoryUsage) == "function" then
    hooksecurefunc("UpdateAddOnMemoryUsage", MarkMemoryScan)
end

local function Print(message)
    print("|cffabd3edSintezza Perf|r " .. message)
end

local function ReadNumber(fn, ...)
    if not fn then return end
    local ok, value = pcall(fn, ...)
    if ok and (not issecretvalue or not issecretvalue(value)) and type(value) == "number"
        and value >= 0 and value < math.huge then return value end
end

local function Read(name, key)
    local id = metric and metric[key]
    if id == nil or not api then return end
    if name then return ReadNumber(api.GetAddOnMetric, name, id) end
    return ReadNumber(api.GetOverallMetric, id)
end

local function RecentTimes()
    local id = metric and metric.RecentAverageTime
    return Read(nil, "RecentAverageTime"), id and api and ReadNumber(api.GetApplicationMetric, id)
end

local function FrameShare(time, frame)
    if time and frame and frame > 0 and time <= frame then return time / frame * 100 end
end

local function EstimateFPSCost(time, fps)
    if not (time and fps and fps > 0) then return end
    local frame = 1000 / fps
    if time < frame then return math.max(0, 1000 / (frame - time) - fps) end
end

local function AddOnsAvailable()
    return addons and addons.GetNumAddOns and addons.GetAddOnInfo and type(addons.IsAddOnLoaded) == "function"
end

local function Available()
    return api and api.GetAddOnMetric and metric and metric.CountTimeOver5Ms ~= nil
        and (not api.IsEnabled or api.IsEnabled())
        and AddOnsAvailable()
end
ns.Available = Available

local function LoadedAddons()
    local names = {}
    for index = 1, addons.GetNumAddOns() do
        local name, _, _, _, _, security = addons.GetAddOnInfo(index)
        local loading, loaded = addons.IsAddOnLoaded(index)
        if type(name) == "string" and (not issecretvalue or not issecretvalue(name))
            and (loaded or loaded == nil and loading) and security ~= "SECURE" and not name:match("^Blizzard_") then
            names[#names + 1] = name
        end
    end
    return names
end

local function Order(left, right)
    if left.value ~= right.value then return left.value > right.value end
    return left.name < right.name
end

local function Top(mode)
    local spec = topModes[mode]
    if not spec then
        Print(Text("Режимы top: recent, peak, spikes, memory.", "Top modes: recent, peak, spikes, memory."))
        return
    end
    if mode == "memory" then
        if not (UpdateAddOnMemoryUsage and GetAddOnMemoryUsage) then
            Print(Text("Счетчики памяти недоступны.", "Memory counters unavailable."))
            return
        end
        UpdateAddOnMemoryUsage()
    end
    local ranked = {}
    for _, name in ipairs(LoadedAddons()) do
        local value
        if mode == "memory" then
            local kib = ReadNumber(GetAddOnMemoryUsage, name)
            value = kib and kib / 1024
        else
            value = Read(name, spec[1])
        end
        if value and value > 0 then ranked[#ranked + 1] = { name = name, value = value } end
    end
    table.sort(ranked, Order)
    Print(spec[2])
    if mode == "recent" then
        local overall, frame = RecentTimes()
        if overall and frame then
            Print(Text(("Все аддоны %.3f мс · клиент %.3f мс"):format(overall, frame),
                ("All addons %.3f ms · client %.3f ms"):format(overall, frame)))
        end
    end
    for index = 1, math.min(8, #ranked) do
        local row = ranked[index]
        Print(("%d. %s  " .. spec[3]):format(index, row.name, row.value))
    end
    if #ranked == 0 then Print(Text("Пока нет ненулевых значений.", "No nonzero values yet.")) end
end

local function Counts(name)
    return Read(name, thresholds[1]), Read(name, thresholds[2]), Read(name, thresholds[3])
end

function ns.Snapshot(memory, maxMemoryAge)
    local available = memory and AddOnsAvailable() or not memory and Available()
    local rows, summary = {}, nil
    if memory then
        if not (available and UpdateAddOnMemoryUsage and GetAddOnMemoryUsage) then return rows end
        if not maxMemoryAge or not memoryScannedAt or GetTime() - memoryScannedAt >= maxMemoryAge then
            if not pcall(UpdateAddOnMemoryUsage) then return rows end
            MarkMemoryScan()
        end
    else
        local overall, frame
        if available then overall, frame = RecentTimes() end
        local fps = ReadNumber(GetFramerate)
        summary = { overall = overall, frame = frame, share = FrameShare(overall, frame),
            fps = fps and fps > 0 and fps or nil, fpsCost = EstimateFPSCost(overall, fps) }
    end
    if not available then return rows, summary end
    for _, name in ipairs(LoadedAddons()) do
        if memory then
            local kib = ReadNumber(GetAddOnMemoryUsage, name)
            if kib then rows[#rows + 1] = { name = name, memory = kib / 1024 } end
        else
            local recent = Read(name, "RecentAverageTime")
            rows[#rows + 1] = {
                name = name, recent = recent, average = Read(name, "SessionAverageTime"),
                peak = Read(name, "PeakTime"), share = FrameShare(recent, summary.frame),
            }
        end
    end
    if memory then return rows, memoryScannedAt, memoryUpdated end
    return rows, summary
end

local function Add(record, name, new)
    if record.rows[name] then return end
    local five, ten, fifty, peak
    if new then five, ten, fifty, peak = 0, 0, 0, 0
    else
        five, ten, fifty = Counts(name)
        peak = Read(name, "PeakTime")
    end
    if five == nil then return end
    record.rows[name] = {
        start5 = five, last5 = five, start10 = ten, last10 = ten, start50 = fifty, last50 = fifty,
        startPeak = peak, value = 0, ten = ten and 0, fifty = fifty and 0,
    }
end

local function TrackAddOnLoads()
    if not loader then
        loader = CreateFrame("Frame")
        loader:SetScript("OnEvent", function(_, _, name)
            if type(name) ~= "string" or issecretvalue and issecretvalue(name)
                or name == addonName or name:match("^Blizzard_") then return end
            local _, _, _, _, _, security = addons.GetAddOnInfo(name)
            if security == "SECURE" then return end
            if active then Add(active, name, true) end
            if background and background.ticker then Add(background, name, true) end
        end)
    end
    if active or background and background.ticker then loader:RegisterEvent("ADDON_LOADED")
    else loader:UnregisterEvent("ADDON_LOADED") end
end

local function Delta(now, before)
    if now and before and now >= before then return now - before end
end

local function ReadSpikes(record, overall)
    if overall == nil or record.lastOverall == overall then return end
    local overallIncrease = Delta(overall, record.lastOverall)
    record.lastOverall = overall
    local total, total10, total50 = 0, 0, 0
    local contributors
    for name, row in pairs(record.rows) do
        local counter = Read(name, thresholds[1])
        local increase = Delta(counter, row.last5)
        if increase and increase > 0 then
            local ten, fifty = Read(name, thresholds[2]), Read(name, thresholds[3])
            local added10, added50 = Delta(ten, row.last10) or 0, Delta(fifty, row.last50) or 0
            row.value, row.ten, row.fifty = Delta(counter, row.start5), Delta(ten, row.start10), Delta(fifty, row.start50)
            row.last5, row.last10, row.last50 = counter, ten, fifty
            total = total + increase
            total10 = total10 + math.min(added10, increase)
            total50 = total50 + math.min(added50, added10, increase)
            contributors = contributors or {}
            contributors[#contributors + 1] = { name = name, value = increase }
        end
    end
    if contributors then
        table.sort(contributors, Order)
        for index = #contributors, 9, -1 do contributors[index] = nil end
    end
    return contributors, total, total10, total50, overallIncrease
end

local function Sample(record)
    local overall = Read(nil, thresholds[1])
    if overall == nil then return end
    record.updated = date("%H:%M:%S")
    local contributors, total, total10, total50 = ReadSpikes(record, overall)
    if not contributors then return end
    local leader = contributors[1]
    local elapsed = GetTime() - record.started
    local bin = math.max(1, math.min(record.duration, math.ceil(elapsed)))
    local point = record.timeline[#record.timeline]
    if point and point.bin == bin then
        point.total, point.ten, point.fifty = point.total + total, point.ten + total10, point.fifty + total50
        local values, merged = {}, {}
        for _, entry in ipairs(point.contributors) do values[entry.name] = entry.value end
        for _, entry in ipairs(contributors) do values[entry.name] = (values[entry.name] or 0) + entry.value end
        for name, count in pairs(values) do merged[#merged + 1] = { name = name, value = count } end
        table.sort(merged, Order)
        for index = #merged, 9, -1 do merged[index] = nil end
        point.contributors, point.name, point.count = merged, merged[1].name, merged[1].value
    else
        record.timeline[#record.timeline + 1] = {
            bin = bin, elapsed = elapsed, name = leader.name, count = leader.value, total = total, ten = total10,
            fifty = total50, contributors = contributors,
        }
    end
end

local function CountText(value)
    return value and tostring(value) or "—"
end

local function Report(record)
    Print(Text(("Замер %.1f с. Кадры аддонов >5 / >10 / >50 мс."):format(record.elapsed),
        ("%.1f s capture. Addon frames >5 / >10 / >50 ms."):format(record.elapsed)))
    for index = 1, math.min(6, #record.ranked) do
        local row = record.ranked[index]
        local peak = row.peak and Text("  новый пик %.2f мс", "  new peak %.2f ms"):format(row.peak) or ""
        Print(("%s  %d / %s / %s%s"):format(row.name, row.value, CountText(row.ten), CountText(row.fifty), peak))
    end
    if #record.ranked == 0 then Print(Text("Спайков >5 мс за замер не найдено.", "No >5 ms addon spikes found.")) end
    if #record.timeline > 0 then
        Print(Text("Последние интервалы замера", "Latest sample windows"))
        for index = math.max(1, #record.timeline - 5), #record.timeline do
            local point = record.timeline[index]
            Print(Text("+%.1f с  %s ×%d  (всего отметок %d)", "+%.1f s  %s ×%d  (total samples %d)")
                :format(point.elapsed, point.name, point.count, point.total))
        end
    end
end

local function Stop(showReport)
    local record = active
    if not record then return end
    active = nil
    record.ticker:Cancel()
    TrackAddOnLoads()
    Sample(record)
    record.elapsed = GetTime() - record.started
    record.ranked = {}
    for name, row in pairs(record.rows) do
        local five, ten, fifty = Counts(name)
        local peak = Read(name, "PeakTime")
        row.value, row.ten, row.fifty = Delta(five, row.start5), Delta(ten, row.start10), Delta(fifty, row.start50)
        row.peak = peak and row.startPeak and peak > row.startPeak and peak or nil
        row.name = name
        if row.value and row.value > 0 then record.ranked[#record.ranked + 1] = row end
    end
    table.sort(record.ranked, Order)
    last = record
    if showReport or not record.silent then Report(record) end
    if ns.OnCaptureChanged then ns.OnCaptureChanged() end
end
ns.Stop = Stop

local function Watch(argument, silent)
    if active then
        Print(Text("Замер уже идет. Остановить можно командой /sperf stop.", "A capture is running. Use /sperf stop."))
        return
    end
    local seconds = argument == "" and 30 or tonumber(argument)
    if not seconds or seconds ~= math.floor(seconds) or seconds < 5 or seconds > 120 then
        Print(Text("Длительность замера от 5 до 120 секунд.", "Capture duration must be 5 to 120 seconds."))
        return
    end
    if not (C_Timer and C_Timer.NewTicker) then
        Print(Text("Запись замера недоступна.", "Timed captures unavailable."))
        return
    end
    local record = { rows = {}, timeline = {}, duration = seconds, silent = silent }
    for _, name in ipairs(LoadedAddons()) do Add(record, name) end
    record.lastOverall = Read(nil, thresholds[1])
    if record.lastOverall ~= nil then record.updated = date("%H:%M:%S") end
    record.started = GetTime()
    record.deadline = record.started + seconds
    active = record
    TrackAddOnLoads()
    record.ticker = C_Timer.NewTicker(1, function()
        if GetTime() >= record.deadline then
            Stop()
        else
            Sample(record)
            if ns.OnCaptureChanged then ns.OnCaptureChanged() end
        end
    end)
    if not silent then
        Print(Text(("Замер запущен на %d с."):format(seconds), ("Capturing for %d s."):format(seconds)))
    end
    if ns.OnCaptureChanged then ns.OnCaptureChanged() end
end
ns.Watch = Watch

local function SampleBackground(record)
    local overall = Read(nil, thresholds[1])
    record.readable = overall ~= nil
    if overall == nil then return end
    local now, previous = GetTime(), record.checked
    record.checked, record.updated = now, date("%H:%M:%S")
    if overall < record.lastOverall then
        record.lastOverall = overall
        record.rows = {}
        for _, name in ipairs(LoadedAddons()) do Add(record, name) end
        return
    end
    local contributors, total, ten, fifty, increase = ReadSpikes(record, overall)
    if not increase then return end
    local windows = record.windows
    if #windows == backgroundWindows then table.remove(windows, 1) end
    windows[#windows + 1] = {
        ended = now, elapsed = now - previous, overall = increase,
        from = previous - record.started, bin = now - record.started,
        total = total, ten = ten, fifty = fifty, contributors = contributors or {},
    }
end

local function StartBackground()
    if not (Available() and C_Timer and C_Timer.NewTicker) then return end
    local overall = Read(nil, thresholds[1])
    if overall == nil then return end
    local record = { rows = {}, windows = {}, lastOverall = overall, readable = true }
    for _, name in ipairs(LoadedAddons()) do Add(record, name) end
    record.checked = GetTime()
    record.updated = date("%H:%M:%S")
    record.started, record.interval = record.checked, backgroundInterval
    record.ticker = C_Timer.NewTicker(backgroundInterval, function()
        SampleBackground(record)
        if ns.OnBackgroundSample then ns.OnBackgroundSample() end
        if ns.OnBackgroundTimelineChanged then ns.OnBackgroundTimelineChanged(true) end
    end)
    background = record
    TrackAddOnLoads()
    return true
end

function ns.InitBackground(db)
    settings = db
    if settings.background == true and not background then StartBackground() end
end

function ns.BackgroundEnabled()
    return settings and settings.background == true
end

function ns.SetBackgroundEnabled(enabled)
    if enabled then
        if not (background and background.ticker) and not StartBackground() then return false end
    elseif background and background.ticker then
        background.ticker:Cancel()
        background.ticker = nil
        TrackAddOnLoads()
        SampleBackground(background)
        background.rows = nil
    end
    if settings then settings.background = enabled end
    if ns.OnBackgroundChanged then ns.OnBackgroundChanged() end
    if ns.OnBackgroundTimelineChanged then ns.OnBackgroundTimelineChanged() end
    return true
end

function ns.BackgroundCapture()
    return background, background and background.ticker ~= nil
end

function ns.BackgroundReport(sample)
    if not background then
        if ns.BackgroundEnabled() then
            return { Text("Фоновый сбор недоступен.", "Background monitoring unavailable.") }
        end
        return { Text("Фоновый сбор выключен.", "Background monitoring off.") }
    end
    if sample and background.ticker then SampleBackground(background) end
    local lines = { background.ticker and Text("Фоновый сбор идет.", "Background monitoring active.")
        or Text("Фоновый сбор остановлен.", "Background monitoring stopped.") }
    if background.ticker and not background.readable then
        lines[1] = Text("Счетчики фона временно недоступны.", "Background counters temporarily unavailable.")
    end
    if #background.windows == 0 then
        lines[2] = Text("Спайков >5 мс пока нет.", "No >5 ms spikes recorded yet.")
        return lines
    end
    lines[2] = Text("Кадры всех аддонов вместе >5 мс | отметки отдельных аддонов >5 / >10 / >50 мс.",
        "Combined addon frames >5 ms | per-addon counts >5 / >10 / >50 ms.")
    local now = GetTime()
    for index = #background.windows, 1, -1 do
        local point = background.windows[index]
        local names = {}
        for contributor = 1, math.min(3, #point.contributors) do
            local entry = point.contributors[contributor]
            names[contributor] = ("%s ×%d"):format(entry.name, entry.value)
        end
        local interval = Text("%.0f с назад (за %.1f с)", "%.0f s ago (over %.1f s)")
            :format(now - point.ended, point.elapsed)
        lines[#lines + 1] = ("%s  %d | %d / %d / %d  %s"):format(interval, point.overall,
            point.total, point.ten, point.fifty, table.concat(names, ", "))
    end
    return lines
end

local function BackgroundCommand(argument)
    if argument == "on" then
        if ns.SetBackgroundEnabled(true) then
            Print(Text("Фоновый сбор включен. Отчет: /sperf background.", "Background monitoring on. Report: /sperf background."))
        else
            Print(Text("Фоновый сбор недоступен.", "Background monitoring unavailable."))
        end
    elseif argument == "off" then
        ns.SetBackgroundEnabled(false)
        Print(Text("Фоновый сбор выключен.", "Background monitoring off."))
    elseif argument == "" or argument == "report" then
        if not background and not ns.BackgroundEnabled() then
            Print(Text("Запусти фоновый сбор командой /sperf background on.", "Start monitoring with /sperf background on."))
        else
            for _, line in ipairs(ns.BackgroundReport(true)) do Print(line) end
        end
    else
        Print("/sperf background [on|off|report]")
    end
end

function ns.Capture()
    return active or last, active ~= nil
end

local function ShowTime(value)
    return value and Text("%.3f мс", "%.3f ms"):format(value) or "—"
end

local function Inspect(search)
    if search == "" then Print(Text("/sperf info <папка аддона>", "/sperf info <addon folder>")); return end
    search = search:lower()
    local match, matches = nil, 0
    for _, name in ipairs(LoadedAddons()) do
        local lower = name:lower()
        if lower == search then match, matches = name, 1; break end
        if lower:sub(1, #search) == search then match, matches = name, matches + 1 end
    end
    if matches ~= 1 then
        Print(Text("Укажи точное имя папки загруженного аддона.", "Use the exact folder name of a loaded addon."))
        return
    end
    Print(("%s  %s %s  %s %s  %s %s"):format(match, Text("среднее за сеанс", "session avg"),
        ShowTime(Read(match, "SessionAverageTime")), Text("недавнее", "recent"),
        ShowTime(Read(match, "RecentAverageTime")), Text("пик", "peak"), ShowTime(Read(match, "PeakTime"))))
    local five, ten, fifty = Counts(match)
    Print(Text("Кадры за сеанс >1 / >5 / >10 / >50 мс  %s / %s / %s / %s",
        "Session frames >1 / >5 / >10 / >50 ms  %s / %s / %s / %s")
        :format(CountText(Read(match, "CountTimeOver1Ms")), CountText(five), CountText(ten), CountText(fifty)))
    local row = last and last.rows[match]
    if row then
        Print(Text("Последний замер >5 / >10 / >50 мс  %s / %s / %s", "Last capture >5 / >10 / >50 ms  %s / %s / %s")
            :format(CountText(row.value), CountText(row.ten), CountText(row.fifty)))
    end
end

SLASH_SINTEZZAPERF1 = "/sperf"
SlashCmdList.SINTEZZAPERF = function(message)
    local command, argument = message:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" and ns.Toggle then ns.Toggle(); return end
    if command == "" or command == "help" then
        Print(Text("/sperf top [recent|peak|spikes|memory], /sperf info <папка аддона>",
            "/sperf top [recent|peak|spikes|memory], /sperf info <addon folder>"))
        Print("/sperf watch [5–120], /sperf stop, /sperf report, /sperf minimap")
        Print("/sperf background [on|off|report]")
        return
    end
    if command == "minimap" and ns.ToggleMinimap then ns.ToggleMinimap(); return end
    if command == "background" then BackgroundCommand(argument:lower()); return end
    if command == "stop" then
        if active then Stop(true) else Print(Text("Замер сейчас не идет.", "No capture is running.")) end
        return
    end
    if command == "report" then
        if last then Report(last) else Print(Text("Сначала запусти /sperf watch.", "Start with /sperf watch.")) end
        return
    end
    if not Available() then
        Print(Text("Штатный профайлер WoW недоступен.", "The built-in WoW profiler is unavailable."))
        return
    end
    if command == "top" then Top(argument == "" and "recent" or argument:lower())
    elseif command == "info" then Inspect(argument)
    elseif command == "watch" then Watch(argument)
    else Print("/sperf help") end
end
