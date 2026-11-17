local addonName, ns = ...
local L, Number = ns.Text, ns.Number
local api, metrics, addons = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric, C_AddOns
local active, last, background, memory, settings, armed
local collector, events = CreateFrame("Frame"), CreateFrame("Frame")
local clock, profileClock = GetTimePreciseSec or GetTime, debugprofilestop
local thresholds = { "CountTimeOver5Ms", "CountTimeOver10Ms", "CountTimeOver50Ms" }
local memoryGeneration, scannedAt, scannedUnix, memoryRequested = 0, nil, nil, false
ns.COST_BUDGET_MS, ns.COST_WINDOW = 1, 60
local function Read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok then return Number(value) end
end
local function Metric(name, key)
    local id = metrics and metrics[key]
    if id == nil or not api then return end
    if name then return Read(api.GetAddOnMetric, name, id) end
    return Read(api.GetOverallMetric, id)
end
ns.Metric = Metric
function ns.Available()
    if not (api and api.GetAddOnMetric and api.GetOverallMetric and metrics and metrics.LastTime ~= nil
        and addons and addons.GetNumAddOns and addons.GetAddOnInfo and addons.IsAddOnLoaded) then return false end
    if api.IsEnabled then
        local ok, enabled = pcall(api.IsEnabled)
        if not ok or issecretvalue and issecretvalue(enabled) or enabled ~= true then return false end
    end
    return true
end
local function Loaded()
    local names = {}
    if not addons or not addons.GetNumAddOns then return names end
    for index = 1, addons.GetNumAddOns() do
        local name, _, _, _, _, security = addons.GetAddOnInfo(index)
        local first, loaded = addons.IsAddOnLoaded(index)
        if type(name) == "string" and not (issecretvalue and issecretvalue(name)) and security ~= "SECURE"
            and not name:match("^Blizzard_") and (loaded or loaded == nil and first) then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) if a == b then return false elseif a == addonName then return true elseif b == addonName then return false end return a < b end)
    return names
end
local function Version(name)
    if not addons.GetAddOnMetadata then return end
    local ok, value = pcall(addons.GetAddOnMetadata, name, "Version")
    return ok and ns.CleanText(value, 40) or nil
end
local function MarkMemory()
    memoryGeneration = memoryGeneration + 1
    scannedAt, scannedUnix = clock(), time()
end
if type(hooksecurefunc) == "function" and type(UpdateAddOnMemoryUsage) == "function" then hooksecurefunc("UpdateAddOnMemoryUsage", MarkMemory) end
function ns.Memory(force)
    if ns.DevRunning and ns.DevRunning() then
        if force then memoryRequested=true end
        return memory,"deferred"
    end
    local now = clock()
    local blocked = active ~= nil or InCombatLockdown()
    if force and blocked then memoryRequested = true end
    local stale = not scannedAt or now - scannedAt >= 60
    if not blocked and type(UpdateAddOnMemoryUsage) == "function" and (force or memoryRequested or stale and settings and not settings.memoryManual) then
        local generation = memoryGeneration
        local ok = pcall(UpdateAddOnMemoryUsage)
        if ok then
            memoryRequested = false
            if generation == memoryGeneration then MarkMemory() end
        end
    end
    if scannedAt and (not memory or memory.generation ~= memoryGeneration) then
        local result = { values = {}, total = 0, at = scannedAt, timestamp = scannedUnix, generation = memoryGeneration }
        local valid = false
        for _, name in ipairs(Loaded()) do
            local kb = Read(GetAddOnMemoryUsage, name)
            if kb then result.values[name] = kb / 1024; result.total = result.total + kb / 1024; valid = true end
        end
        if valid then memory = result; ns.NoteMemory(result) end
    end
    return memory, blocked and "deferred" or memory and (now - memory.at >= 60 and "stale" or "fresh") or "unavailable"
end
function ns.Snapshot()
    local rows, summary = {}, { fps = Read(GetFramerate), updated = time() }
    if not ns.Available() then
        if memory then for name, value in pairs(memory.values) do rows[#rows + 1] = { name = name, memory = value } end end
        return rows, summary
    end
    summary.overall = Metric(nil, "RecentAverageTime")
    summary.frame = Read(api.GetApplicationMetric, metrics.RecentAverageTime)
    if summary.overall and summary.frame and summary.frame > 0 then summary.share = summary.overall / summary.frame * 100 end
    for _, name in ipairs(Loaded()) do
        rows[#rows + 1] = { name = name, average = Metric(name, "RecentAverageTime"), peak = Metric(name, "PeakTime"),
            five = Metric(name, thresholds[1]), ten = Metric(name, thresholds[2]), fifty = Metric(name, thresholds[3]), memory = memory and memory.values[name] }
    end
    return rows, summary
end
local function Counts(name) return Metric(name, thresholds[1]), Metric(name, thresholds[2]), Metric(name, thresholds[3]) end
local function Delta(now, before) if now and before and now >= before then return now - before end end
local function Notify() if ns.OnDataChanged then ns.OnDataChanged() end end
local contextEvents = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ENCOUNTER_START", "ENCOUNTER_END", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE" }
local function TrackLoads()
    if active or background or armed then events:RegisterEvent("ADDON_LOADED") else events:UnregisterEvent("ADDON_LOADED") end
    for _, name in ipairs(contextEvents) do
        if active or armed then
            local ok = pcall(events.RegisterEvent, events, name)
            if not ok then if active then active.contextChanged = true end;if armed then armed.contextChanged = true end end
        else events:UnregisterEvent(name) end
    end
end
local function Build()
    if not GetBuildInfo then return "WoW Forever" end
    local version, build = GetBuildInfo()
    return tostring(version) .. "." .. tostring(build)
end
local function NewPoint(from, to)
    return { from = from, to = to, frames = 0, samples = 0, total = 0, peak = 0, five = 0, ten = 0, fifty = 0,
        individualFive = 0, missing = 0, addonMissing = 0, long50 = 0, frameSamples = 0,
        framePeak = 0, frameAt = 0, cpuAtFramePeak = false, perfAtFramePeak = false,
        contributors = { { name = "", value = 0 }, { name = "", value = 0 }, { name = "", value = 0 } } }
end
local function Top(point, name, value)
    local entries, found = point.contributors
    for i = 1, 3 do if entries[i].name == name then found = i; break end end
    if not found then if value <= entries[3].value then return end; found = 3; entries[3].name = name end
    entries[found].value = value
    while found > 1 and entries[found].value > entries[found - 1].value do
        entries[found], entries[found - 1] = entries[found - 1], entries[found]
        found = found - 1
    end
end
local function AddRow(record, name)
    if record.byName[name] then return end
    if #record.rows >= ns.MAX_ADDONS then record.omitted = record.omitted + 1; return end
    local row = { name = name, version = Version(name), total = 0, samples = 0, peak = 0, five = 0, ten = 0, fifty = 0,
        missing = 0, bin = 0, binCount = 0, memory = record.memoryValues and record.memoryValues[name] }
    record.rows[#record.rows + 1], record.byName[name] = row, row
end
local function Accumulate(row, value)
    row.samples, row.total = row.samples + 1, row.total + value
    if value > row.peak then row.peak = value end
    if value > 5 then
        row.five = row.five + 1
        if value > 10 then row.ten = row.ten + 1; if value > 50 then row.fifty = row.fifty + 1 end end
    end
end
local ResetBackground
function ns.Stop(reason)
    local record = active
    if not record then return end
    active = nil
    collector:SetScript("OnUpdate", nil)
    record.duration = math.max(0, clock() - (record.started or clock()))
    record.reason = reason
    record.complete = reason == nil or reason == "combat_end" or reason == "encounter_end"
    if not record.complete then record.group = nil end
    ns.FinishFrameStats(record)
    record.memoryTrail = ns.CopyMemoryTrail()
    record.average = record.samples > 0 and record.total / record.samples or nil
    if record.samples == 0 then record.peak, record.five, record.ten, record.fifty = nil, nil, nil, nil end
    record.costAverage = record.costSamples > 0 and record.costTotal / record.costSamples or nil
    if record.costSamples == 0 then record.costPeak = nil end
    for _, row in ipairs(record.rows) do
        row.average = row.samples > 0 and row.total / row.samples or nil
        if row.samples == 0 then row.peak, row.five, row.ten, row.fifty = nil, nil, nil, nil end
    end
    local used = math.min(#record.timeline, math.max(1, math.ceil(record.duration)))
    for i = #record.timeline, used + 1, -1 do record.timeline[i] = nil end
    for index, point in ipairs(record.timeline) do
        point.to = index == used and record.duration or math.min(point.to, record.duration)
        point.average = point.samples > 0 and point.total / point.samples or nil
        if point.samples == 0 then point.peak, point.five, point.ten, point.fifty = nil, nil, nil, nil end
    end
    last = ns.SaveRecord(record)
    if background then ResetBackground() end
    TrackLoads()
    Notify()
    return last
end
local function Sample(_, frameElapsed)
    local record = active
    if not record then return end
    local now = clock()
    -- LastTime belongs to the previous tick; discard the first callback after arming.
    if not record.started then record.started = now; return end
    local startedCost = profileClock and profileClock()
    local elapsed = now - record.started
    local binIndex = math.min(#record.timeline, math.max(1, math.floor(elapsed) + 1))
    local point = record.timeline[binIndex]
    local overall = Read(api.GetOverallMetric, metrics.LastTime)
    local observer
    record.frames, point.frames = record.frames + 1, point.frames + 1
    if overall then Accumulate(record, overall); Accumulate(point, overall)
    else record.missing, point.missing = record.missing + 1, point.missing + 1 end
    for i = 1, #record.rows do
        local row = record.rows[i]
        local value = Read(api.GetAddOnMetric, row.name, metrics.LastTime)
        if row.name == addonName then observer = value end
        if value then
            Accumulate(row, value)
            if value > 5 then
                if row.bin ~= binIndex then row.bin, row.binCount = binIndex, 0 end
                row.binCount = row.binCount + 1
                point.individualFive = point.individualFive + 1
                Top(point, row.name, row.binCount)
            end
        else row.missing = row.missing + 1; point.addonMissing = point.addonMissing + 1 end
    end
    ns.SampleFrame(record, point, frameElapsed, overall, observer, elapsed)
    if startedCost then
        local cost = Number(profileClock() - startedCost)
        if cost then
            record.costSamples, record.costTotal = record.costSamples + 1, record.costTotal + cost
            record.costPeak = math.max(record.costPeak, cost)
            record.windowCost, record.windowSamples = record.windowCost + cost, record.windowSamples + 1
            if cost > 20 or record.windowSamples >= ns.COST_WINDOW and record.windowCost / record.windowSamples > ns.COST_BUDGET_MS then ns.Stop("overhead"); return end
            if record.windowSamples >= ns.COST_WINDOW then record.windowCost, record.windowSamples = 0, 0 end
        end
    end
    if record.missing >= 60 and record.samples == 0 then ns.Stop("unavailable") elseif elapsed >= record.requested then ns.Stop() end
end
local function Prepare(seconds, options)
    if active or not ns.Available() then return end
    seconds = tonumber(seconds) or 30
    if not Number(seconds) or seconds < 5 or seconds > 120 or seconds ~= math.floor(seconds) then return end
    options = options or {}
    -- Reuse an existing snapshot: starting capture must not trigger a memory walk.
    local record = { kind = "capture", name = L("Замер ", "Capture ") .. date("%H:%M:%S"), timestamp = time(),
        requested = seconds, duration = 0, frames = 0, samples = 0, total = 0, peak = 0, five = 0, ten = 0, fifty = 0,
        missing = 0, rows = {}, byName = {}, timeline = {}, omitted = 0, costTotal = 0, costSamples = 0, costPeak = 0,
        windowCost = 0, windowSamples = 0, build = Build(), memoryValues = memory and memory.values,
        memoryTimestamp = memory and memory.timestamp, memoryAge = memory and clock() - memory.at, memoryState = memory and "before_capture" or "unavailable" }
    record.profile = options.profile == "light" and "light" or "detailed"
    record.trigger = options.trigger == "combat" and "combat" or options.trigger == "boss" and "boss" or "manual"
    record.scenario = ns.CleanText(options.scenario,160) or settings and settings.scenario or L("Мой сценарий","My scenario")
    record.group = options.group == "A" and "A" or options.group == "B" and "B" or nil
    ns.BeginFrameStats(record)
    record.memoryTrail = ns.CopyMemoryTrail()
    for i = 1, seconds do record.timeline[i] = NewPoint(i - 1, i) end
    if record.profile == "light" then AddRow(record, addonName)
    else for _, name in ipairs(Loaded()) do AddRow(record, name) end end
    return record
end
local function Activate(record)
    record.timestamp, record.context = time(), ns.ReadContext()
    record.name = record.scenario .. " · " .. date("%H:%M:%S")
    record.memoryValues = memory and memory.values
    record.memoryTimestamp, record.memoryAge = memory and memory.timestamp, memory and clock() - memory.at
    for _, row in ipairs(record.rows) do row.memory = memory and memory.values[row.name] end
    active = record
    collector:SetScript("OnUpdate", Sample)
    TrackLoads()
    Notify()
    return true
end
function ns.CancelArm()
    if not armed then return end
    if armed.expiry then armed.expiry:Cancel() end
    armed = nil
    TrackLoads(); Notify()
end
function ns.Start(seconds, options)
    if active or ns.DevRunning and ns.DevRunning() then return false end
    ns.CancelArm()
    local record = Prepare(seconds, options)
    return record and Activate(record) or false
end
function ns.ArmCapture(seconds, options)
    if active or ns.DevRunning and ns.DevRunning() then return false end
    options = options or {}
    if options.trigger == nil or options.trigger == "manual" then return ns.Start(seconds, options) end
    ns.CancelArm()
    if not (C_Timer and C_Timer.NewTicker) then return false end
    local record = Prepare(seconds, options)
    if not record then return false end
    local required = record.trigger == "boss" and "ENCOUNTER_START" or "PLAYER_REGEN_DISABLED"
    if not pcall(events.RegisterEvent, events, required) then return false end
    armed = record; record.waitStarted = clock()
    record.expiry = C_Timer.NewTicker(300, function()
        if armed == record then ns.CancelArm(); print(L("Sintezza Perf: ожидание события истекло (5 минут).", "Sintezza Perf: event wait expired (5 minutes).")) end
    end)
    TrackLoads(); Notify()
    return true
end
function ns.Armed() return armed end
function ns.Mark(text)
    if not active then return false end
    local ok = ns.AddContextMarker(active, "manual", text or L("Ручная метка", "Manual marker"), ns.Elapsed())
    Notify(); return ok
end
function ns.Capture()
    if not active and last and not ns.FindRecord(last.id) then
        last = nil
        for _, record in ipairs(ns.History()) do if record.kind == "capture" then last = record; break end end
    end
    return active or last, active ~= nil
end
function ns.Elapsed() return active and active.started and clock() - active.started or 0 end
ResetBackground = function()
    if not background then return end
    background.overall5, background.overall10, background.overall50 = Counts(nil)
    background.at, background.rows = clock(), {}
    local names = Loaded()
    background.omitted = math.max(0, #names - ns.MAX_ADDONS)
    for i = 1, math.min(#names, ns.MAX_ADDONS) do
        local name = names[i]
        local five, ten, fifty = Counts(name)
        background.rows[name] = { five = five, ten = ten, fifty = fifty, version = Version(name) }
    end
end
function ns.ResetBackgroundBaseline() if background then ResetBackground() end end
local function SampleBackground()
    if not background or active or ns.DevRunning and ns.DevRunning() then return end
    local overall = Metric(nil, thresholds[1])
    if overall == nil then background.unavailable = true; return end
    if background.unavailable or not background.overall5 or overall < background.overall5 then background.unavailable = nil; ResetBackground(); return end
    if overall == background.overall5 then background.at = clock(); return end
    local now, ten, fifty = clock(), Metric(nil, thresholds[2]), Metric(nil, thresholds[3])
    local record = { kind = "background", name = L("Фоновый эпизод ", "Background episode ") .. date("%H:%M:%S"), timestamp = time(),
        duration = now - background.at, five = Delta(overall, background.overall5), ten = Delta(ten, background.overall10), fifty = Delta(fifty, background.overall50),
        rows = {}, timeline = {}, build = Build(), omitted = background.omitted, memoryState = "unavailable" }
    local point = NewPoint(0, record.duration)
    point.frames, point.samples, point.peak, point.total = nil, nil, nil, nil
    point.five, point.ten, point.fifty = record.five, record.ten, record.fifty
    for name, previous in pairs(background.rows) do
        local fiveNow, tenNow, fiftyNow = Counts(name)
        local count = Delta(fiveNow, previous.five)
        if count == nil then point.addonMissing = point.addonMissing + 1 end
        if count and (count > 0 or name == addonName) then
            record.rows[#record.rows + 1] = { name = name, five = count, ten = Delta(tenNow, previous.ten), fifty = Delta(fiftyNow, previous.fifty), version = previous.version }
            point.individualFive = point.individualFive + count
            Top(point, name, count)
        end
        previous.five, previous.ten, previous.fifty = fiveNow, tenNow, fiftyNow
    end
    record.timeline[1] = point
    ns.SaveRecord(record)
    background.overall5, background.overall10, background.overall50, background.at = overall, ten, fifty, now
    Notify()
end
function ns.BackgroundEnabled() return settings and settings.background == true end
function ns.BackgroundAvailable() return background and not background.unavailable end
function ns.SetBackgroundEnabled(enabled)
    if background and background.ticker then background.ticker:Cancel() end
    background = nil
    if enabled then
        if not ns.Available() or not C_Timer or not C_Timer.NewTicker then return false end
        background = {}; ResetBackground()
        background.ticker = C_Timer.NewTicker(5, SampleBackground)
    end
    if settings then settings.background = enabled == true end
    TrackLoads(); Notify()
    return true
end
events:SetScript("OnEvent", function(_, event, name, encounterName, difficulty, groupSize)
    if event == "PLAYER_LOGOUT" then ns.CancelArm(); if active then ns.Stop("logout") end; return end
    if armed and (armed.trigger == "combat" and event == "PLAYER_REGEN_DISABLED" or armed.trigger == "boss" and event == "ENCOUNTER_START") then
        local record = armed
        if record.expiry then record.expiry:Cancel() end
        armed = nil
        if event == "ENCOUNTER_START" then record.encounterID = Number(name) end
        Activate(record)
        ns.AddContextMarker(record,"start",event == "ENCOUNTER_START" and L("Начало боя с боссом","Boss encounter started") or L("Начало боя","Combat started"),0)
        return
    end
    if active and event ~= "ADDON_LOADED" then
        local elapsed = ns.Elapsed()
        if event == "PLAYER_REGEN_DISABLED" then ns.AddContextMarker(active,"combat_start",L("Начало боя","Combat started"),elapsed)
        elseif event == "PLAYER_REGEN_ENABLED" then
            ns.AddContextMarker(active,"combat_end",L("Конец боя","Combat ended"),elapsed)
            if active.trigger == "combat" then ns.Stop("combat_end") end
        elseif event == "ENCOUNTER_START" then ns.AddContextMarker(active,"boss_start",L("Начало боя с боссом","Boss encounter started"),elapsed)
        elseif event == "ENCOUNTER_END" then
            ns.AddContextMarker(active,"boss_end",L("Конец боя с боссом","Boss encounter ended"),elapsed)
            if active.trigger == "boss" and active.encounterID and Number(name) == active.encounterID then ns.Stop("encounter_end") end
        elseif event == "ZONE_CHANGED_NEW_AREA" or event == "GROUP_ROSTER_UPDATE" then
            active.contextChanged = true
            ns.AddContextMarker(active,event,L("Изменились зона или состав группы","Zone or group composition changed"),elapsed)
        end
        return
    end
    if type(name) ~= "string" or issecretvalue and issecretvalue(name) or name:match("^Blizzard_") then return end
    if active and active.profile == "detailed" then AddRow(active, name) end
    if armed and armed.profile == "detailed" then AddRow(armed, name) end
    if background and not background.rows[name] then
        if #Loaded() <= ns.MAX_ADDONS then background.rows[name] = { five = 0, ten = 0, fifty = 0, version = Version(name) }
        else background.omitted = background.omitted + 1 end
    end
end)
events:RegisterEvent("PLAYER_LOGOUT")
function ns.InitCollector(storage)
    settings = storage
    for _, record in ipairs(ns.History()) do if record.kind == "capture" then last = record; break end end
    if settings.background then ns.SetBackgroundEnabled(true) end
end
SLASH_SINTEZZAPERF1 = "/sperf"
SlashCmdList.SINTEZZAPERF = function(message)
    local command, argument = (message or ""):match("^(%S*)%s*(.-)$")
    command = command:lower()
    if command == "" then if ns.Toggle then ns.Toggle() end
    elseif command == "minimap" then if ns.ToggleMinimap then ns.ToggleMinimap() end
    elseif command == "watch" then if not ns.Start(argument ~= "" and argument or 30) then print(L("Замер недоступен или уже идет.", "Capture unavailable or already running.")) end
    elseif command == "dev" then if ns.OpenDeveloper then ns.OpenDeveloper() end
    elseif command == "stop" then if ns.DevRunning and ns.DevRunning() then ns.DevStop("manual") elseif ns.Armed() then ns.CancelArm() else ns.Stop("manual") end
    elseif command == "cancel" then ns.CancelArm()
    elseif command == "mark" then ns.Mark(argument ~= "" and argument or nil)
    elseif command == "report" then local record = ns.Capture(); print(ns.Export(record, "text"))
    elseif command == "startup" then
        if ns.ToggleStartup then ns.ToggleStartup()end
    elseif command == "reload" then
        if not ns.StartMeasuredReload or not ns.StartMeasuredReload() then
            print(L("Замер перезагрузки доступен после входа в игру, вне боя.", "Measured reload is available after logging in and outside combat."))
        end
    elseif command == "background" then
        if argument == "on" or argument == "off" then ns.SetBackgroundEnabled(argument == "on")
        else for _, record in ipairs(ns.History()) do if record.kind == "background" then print(ns.Export(record, "text")); break end end end
    elseif command == "top" or command == "info" then
        local rows = ns.Snapshot()
        if argument == "memory" then ns.Memory(true); rows = ns.Snapshot() end
        local key = argument == "memory" and "memory" or argument == "peak" and "peak" or argument == "spikes" and "five" or "average"
        table.sort(rows, function(a, b) return (a[key] or -1) > (b[key] or -1) end)
        for i, row in ipairs(rows) do
            if command == "top" and i <= 8 or command == "info" and row.name:lower():find(argument:lower(), 1, true) then
                print(row.name .. "  " .. tostring(row[key] or "?") .. (key == "memory" and " MiB" or key == "five" and "" or " ms"))
            end
        end
    else print("/sperf, /sperf watch 30, /sperf stop, /sperf report, /sperf startup, /sperf reload, /sperf background [on|off], /sperf top [recent|peak|spikes|memory], /sperf info AddonFolder") end
end
