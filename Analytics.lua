local addon, ns = ...
local L, Number = ns.Text, ns.Number
local histogram = {}
local BUCKETS = 2801
ns.MAX_MARKERS, ns.MAX_MEMORY_POINTS = 80, 30
ns.MEASUREMENT = "frame-interval-histogram-v1"

local function Public(value)
    if issecretvalue and issecretvalue(value) then return end
    return value
end
local function Call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok then return Public(value) end
end
function ns.ReadContext()
    local context = {}
    context.zone = ns.CleanText(Call(GetRealZoneText or GetZoneText), 128)
    context.map = Number(Call(C_Map and C_Map.GetBestMapForUnit, "player"))
    context.groupSize = Number(Call(GetNumGroupMembers))
    context.combat = Public(InCombatLockdown())
    if type(context.combat) ~= "boolean" then context.combat = nil end
    local fps = Call(C_CVar and C_CVar.GetCVar or GetCVar, "maxFPS")
    if type(fps) == "string" or type(fps) == "number" then context.fpsLimit = Number(tonumber(fps)) end
    if type(GetInstanceInfo) == "function" then
        local ok, _, instanceType, difficulty = pcall(GetInstanceInfo)
        if ok then context.instanceType = ns.CleanText(Public(instanceType), 32); context.difficulty = Number(difficulty) end
    end
    return context
end

function ns.BeginFrameStats(record)
    for i = 1, BUCKETS do histogram[i] = 0 end
    record.histogram = histogram
    record.measurement = ns.MEASUREMENT
    record.frameSamples, record.frameMissing, record.frameTotal, record.framePeak = 0, 0, 0, 0
    record.long50, record.long100 = 0, 0
    record.markers, record.markerOmitted = {}, 0
end

local function Bucket(ms)
    if ms <= 100 then return math.max(1, math.ceil(ms * 10)) end
    if ms <= 1000 then return 1000 + math.ceil(ms - 100) end
    if ms <= 10000 then return 1900 + math.ceil((ms - 1000) / 10) end
    return BUCKETS
end
local function Upper(index, maximum)
    if index <= 1000 then return index / 10 end
    if index <= 1900 then return 100 + index - 1000 end
    if index <= 2800 then return 1000 + (index - 1900) * 10 end
    return maximum
end

function ns.SampleFrame(record, point, elapsed, cpu, observer, at)
    local seconds = Number(elapsed)
    if not seconds or seconds <= 0 then record.frameMissing = record.frameMissing + 1; return end
    local ms = seconds * 1000
    local index = Bucket(ms)
    histogram[index] = histogram[index] + 1
    point.frameSamples = (point.frameSamples or 0) + 1
    record.frameSamples, record.frameTotal = record.frameSamples + 1, record.frameTotal + ms
    if ms > record.framePeak then record.framePeak = ms end
    if ms > 50 then record.long50 = record.long50 + 1; point.long50 = point.long50 + 1 end
    if ms > 100 then record.long100 = record.long100 + 1 end
    if not point.framePeak or ms > point.framePeak then
        point.framePeak, point.cpuAtFramePeak, point.perfAtFramePeak = ms, cpu, observer
        point.frameAt = Number(at) or point.from or 0
    end
end

function ns.FinishFrameStats(record)
    if record.frameSamples > 0 then
        record.frameMean = record.frameTotal / record.frameSamples
        local rank95, rank99 = math.ceil(record.frameSamples * .95), math.ceil(record.frameSamples * .99)
        local count = 0
        for i = 1, BUCKETS do
            count = count + histogram[i]
            if not record.p95 and count >= rank95 then record.p95 = Upper(i, record.framePeak) end
            if count >= rank99 then record.p99 = Upper(i, record.framePeak); break end
        end
    else record.framePeak, record.long50, record.long100 = nil, nil, nil end
    record.histogram = nil
end

function ns.AddContextMarker(record, kind, text, elapsed)
    if not record or not record.markers then return false end
    if #record.markers >= ns.MAX_MARKERS then record.markerOmitted = record.markerOmitted + 1; return false end
    local value = ns.CleanText(text, 160)
    if not value then return false end
    record.markers[#record.markers + 1] = { kind = kind, text = value, at = math.max(0, elapsed or 0) }
    return true
end

local memoryTrail = {}
function ns.NoteMemory(snapshot)
    local last = memoryTrail[#memoryTrail]
    if last and last.timestamp == snapshot.timestamp then return end
    local point = { timestamp = snapshot.timestamp, total = snapshot.total }
    if last and math.floor(snapshot.timestamp / 60) == math.floor(last.timestamp / 60) then memoryTrail[#memoryTrail] = point
    else
        if #memoryTrail >= ns.MAX_MEMORY_POINTS then table.remove(memoryTrail, 1) end
        memoryTrail[#memoryTrail + 1] = point
    end
end
function ns.MemoryTrail() return memoryTrail end
function ns.CopyMemoryTrail()
    local result = {}
    for i, point in ipairs(memoryTrail) do result[i] = { timestamp = point.timestamp, total = point.total } end
    return result
end

local reasons = {
    legacy = { "В этой записи нет показателей плавности.", "This record has no frame-time measurements." },
    partial = { "Запись завершена досрочно и не участвует в сравнении.", "This partial recording is excluded from comparison." },
    missing = { "Недостаточно полных показаний кадров и CPU.", "Insufficient complete frame and CPU readings." },
    context = { "Часть условий не записана или изменилась во время замера.", "Some conditions were not recorded or changed during capture." },
    profile = { "Разные режимы сбора.", "Different collection modes." },
    scenario = { "Разные сценарии или типы запуска.", "Different scenarios or triggers." },
    duration = { "Разная длительность записей.", "Different recording durations." },
    conditions = { "Записанные условия различаются.", "Recorded conditions differ." },
    empty = { "Выберите записи для обеих групп.", "Choose recordings for both groups." },
}
function ns.ComparisonReason(reason)
    local pair = reasons[reason]
    return pair and L(pair[1], pair[2]) or ""
end
function ns.Eligible(record)
    if not record or record.kind ~= "capture" or record.measurement ~= ns.MEASUREMENT then return false, "legacy" end
    if record.complete ~= true then return false, "partial" end
    if record.trigger == "boss" and (not record.encounterID or record.encounterID <= 0) then return false, "context" end
    if not record.p99 or (record.frameSamples or 0) < 60 or (record.frameMissing or 0) > 0 or (record.missing or 0) > 0 then return false, "missing" end
    local c = record.context
    if record.contextChanged or not c or not c.zone or c.groupSize == nil or c.combat == nil or c.fpsLimit == nil
        or not c.instanceType or c.difficulty == nil or not record.build then return false, "context" end
    return true
end
function ns.Compatible(a, b)
    local ok, reason = ns.Eligible(a); if not ok then return false, reason end
    ok, reason = ns.Eligible(b); if not ok then return false, reason end
    if a.profile ~= b.profile then return false, "profile" end
    if a.scenario ~= b.scenario or a.trigger ~= b.trigger or a.encounterID ~= b.encounterID then return false, "scenario" end
    if math.abs(a.duration - b.duration) > math.max(.5, math.min(a.duration, b.duration) * .02) then return false, "duration" end
    if a.measurement ~= b.measurement or a.build ~= b.build then return false, "conditions" end
    for _, key in ipairs({ "zone", "map", "groupSize", "combat", "fpsLimit", "instanceType", "difficulty" }) do
        if a.context[key] ~= b.context[key] then return false, "conditions" end
    end
    return true
end
function ns.AssignGroup(id, group)
    local record = ns.FindRecord(id)
    if not record then return false end
    if record.group == group then record.group = nil; return true end
    local ok, reason = ns.Eligible(record); if not ok then return false, reason end
    if group ~= "A" and group ~= "B" then return false end
    record.group = group
    return true
end
local function Median(values)
    if #values == 0 then return end
    table.sort(values)
    local middle = math.floor(#values / 2)
    if #values % 2 == 1 then return values[middle + 1] end
    return (values[middle] + values[middle + 1]) / 2
end
ns.Median = Median
local function Observer(record)
    for _, row in ipairs(record.rows) do if row.name == addon then return row.average end end
end
function ns.Comparison()
    local result = { A = {}, B = {}, metrics = {}, compatible = true }
    local baseline
    for _, record in ipairs(ns.History()) do
        if record.group == "A" or record.group == "B" then
            result[record.group][#result[record.group] + 1] = record
            local ok, reason = ns.Eligible(record)
            if ok and baseline then ok, reason = ns.Compatible(baseline, record) end
            if not ok then result.compatible, result.reason = false, result.reason or reason end
            baseline = baseline or record
        end
    end
    result.baseline = baseline
    if #result.A == 0 or #result.B == 0 then result.compatible, result.reason = false, "empty" end
    for _, key in ipairs({ "p95", "p99", "long50", "average", "observer" }) do
        local metric = {}
        for _, group in ipairs({ "A", "B" }) do
            local values = {}
            for _, record in ipairs(result[group]) do
                local value = key == "observer" and Observer(record) or record[key]
                if Number(value) then values[#values + 1] = value end
            end
            metric[group] = #values == #result[group] and Median(values) or nil
        end
        if result.compatible and metric.A and metric.A > 0 and metric.B then metric.delta = (metric.B - metric.A) / metric.A * 100 end
        result.metrics[key] = metric
    end
    result.repeated = #result.A >= 3 and #result.B >= 3
    return result
end
function ns.ClearGroups()
    for _, record in ipairs(ns.History()) do record.group = nil end
end
function ns.ExportConditions()
    local result=ns.Comparison()
    local lines={L("Условия только для чтения. Номера версий не удостоверяют идентичность локального кода.","Conditions are read-only. Version numbers do not certify identical local code.")}
    for _,group in ipairs({"A","B"})do
        for _,r in ipairs(result[group])do
            local c=r.context or {}
            lines[#lines+1]="\n"..group.." | "..r.name.." | "..date("%d.%m %H:%M",r.timestamp)
            lines[#lines+1]=(r.scenario or "?").." | "..(r.profile or "?").." | "..(r.trigger or "?").." | "..("%.2f s"):format(r.duration)
            lines[#lines+1]=(r.build or "?").." | "..(c.zone or "?").." | "..(c.instanceType or "?").." | "..tostring(c.difficulty or "?")
            lines[#lines+1]=L("Группа: ","Group: ")..tostring(c.groupSize or "?")..L(" | Бой: "," | Combat: ")..tostring(c.combat)..L(" | Лимит FPS: "," | FPS cap: ")..tostring(c.fpsLimit or "?")
        end
    end
    return table.concat(lines,"\n")
end

function ns.ExportComparison(format)
    local result = ns.Comparison()
    local payload = { format = "Sintezza_Perf/comparison-1", profilerIncluded = true, compatible = result.compatible,
        reason = result.reason, repeats = { A = #result.A, B = #result.B }, metrics = result.metrics, groups = { A = result.A, B = result.B } }
    if format == "json" then return ns.JSON(payload) end
    local lines = { "Sintezza Perf: A/B", L("Наблюдатель включен в общий итог.", "Observer is included in totals."),
        ("A: %d | B: %d"):format(#result.A, #result.B), result.compatible and L("Записанные условия совпадают.", "Recorded conditions match.") or ns.ComparisonReason(result.reason) }
    for _, key in ipairs({ "p95", "p99", "long50", "average", "observer" }) do
        local m = result.metrics[key]
        lines[#lines + 1] = key .. ": " .. (m.A and ("%.3f"):format(m.A) or "n/a") .. " / " .. (m.B and ("%.3f"):format(m.B) or "n/a")
            .. " | " .. (m.delta and ("%+.1f%%"):format(m.delta) or L("не сравниваем", "not compared"))
    end
    lines[#lines + 1] = L("Одинаковые номера версий не доказывают одинаковый локальный код. Совпадение условий не исключает другую нагрузку мира или фоновых программ.", "Equal version numbers do not prove identical local code. Matching recorded conditions cannot exclude different world or background-process load.")
    for _, group in ipairs({ "A", "B" }) do
        for _, record in ipairs(result[group]) do lines[#lines + 1] = "\n" .. group .. " | " .. ns.Export(record, "text") end
    end
    return table.concat(lines, "\n")
end
