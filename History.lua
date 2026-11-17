local addon, ns = ...
function ns.Text(ru, en)
    local theme = Sintezza_Theme
    return (theme and theme:GetLocale() or GetLocale()) == "ruRU" and ru or en
end
local L = ns.Text
ns.VERSION, ns.HISTORY_SCHEMA = "0.7.0", 2
ns.MAX_ADDONS, ns.MAX_BINS, ns.MAX_PINNED = 256, 120, 10
ns.MAX_STARTUP = 10
local db

function ns.Number(value)
    if issecretvalue and issecretvalue(value) then return end
    if type(value) == "number" and value >= 0 and value < math.huge then return value end
end
function ns.CleanText(value, limit)
    if type(value) ~= "string" or issecretvalue and issecretvalue(value) then return end
    value = value:gsub("[%z\1-\31\127]", " "):gsub("|", ""):match("^%s*(.-)%s*$")
    if value == "" then return end
    if #value > limit then
        value = value:sub(1, limit):gsub("[\194-\244][\128-\191]*$", "")
    end
    return value
end
local fields = { "id", "timestamp", "duration", "requested", "frames", "samples", "average", "peak",
    "five", "ten", "fifty", "missing", "memoryTimestamp", "memoryAge", "costAverage", "costPeak", "costSamples", "omitted",
    "frameSamples", "frameMissing", "frameMean", "framePeak", "p95", "p99", "long50", "long100", "markerOmitted", "encounterID" }
local rowFields = { "average", "peak", "five", "ten", "fifty", "samples", "missing", "memory" }
local binFields = { "from", "to", "frames", "samples", "average", "peak", "five", "ten", "fifty", "missing", "addonMissing", "individualFive", "frameSamples", "framePeak", "frameAt", "cpuAtFramePeak", "perfAtFramePeak", "long50" }
local function Numbers(source, target, keys)
    for _, key in ipairs(keys) do target[key] = ns.Number(source[key]) end
end
local function Sanitize(source)
    if type(source) ~= "table" or source.schema ~= 1 and source.schema ~= ns.HISTORY_SCHEMA then return end
    if source.kind == "startup" then
        local id, timestamp, duration = ns.Number(source.id), ns.Number(source.timestamp), ns.Number(source.duration)
        local s = source.startup
        if not id or not timestamp or not duration or duration <= 0 or duration > 86400 or type(s) ~= "table"
            or (s.type ~= "login" and s.type ~= "reload") or (s.endpoint ~= "screen" and s.endpoint ~= "world") then return end
        local lead = s.type == "reload" and ns.Number(s.reloadLead) or nil
        if lead and (lead > duration or lead > 300) then lead = nil end
        local beforeLogin = ns.Number(s.beforeLogin)
        if beforeLogin and beforeLogin > duration - (lead or 0) then beforeLogin = nil end
        local startup = { type = s.type, endpoint = s.endpoint, reloadLead = lead, beforeLogin = beforeLogin,
            addonEvents = ns.Number(s.addonEvents), gaps = {} }
        if type(s.gaps) == "table" then
            for i = 1, math.min(#s.gaps, 5) do
                local g = s.gaps[i]
                local elapsed = type(g) == "table" and ns.Number(g.duration)
                if elapsed and elapsed > 0 and elapsed <= duration - (lead or 0) then
                    startup.gaps[#startup.gaps + 1] = { duration = elapsed, after = ns.CleanText(g.after, 128), before = ns.CleanText(g.before, 128) }
                end
            end
        end
        if s.traceVersion == 1 and type(s.trace) == "table" and #s.trace >= 2 and #s.trace <= 128 then
            local steps, previous, valid = {}, 0, true
            local observed = duration - (lead or 0)
            for i, step in ipairs(s.trace) do
                local kind = type(step) == "table" and ns.CleanText(step.kind, 16)
                local at = type(step) == "table" and ns.Number(step.at)
                local name = type(step) == "table" and ns.CleanText(step.name, 128)
                if not at or at < previous or at > observed + .001
                    or (kind ~= "start" and kind ~= "addon" and kind ~= "login" and kind ~= "world" and kind ~= "finish")
                    or kind == "addon" and not name or i == 1 and (kind ~= "start" or at ~= 0)
                    or i > 1 and kind == "start" or i < #s.trace and kind == "finish" then valid = false; break end
                steps[#steps+1] = { kind = kind, at = at, name = kind == "addon" and name or nil }
                previous = at
            end
            if valid and steps[#steps].kind == "finish" and math.abs(previous - observed) <= .001 then
                startup.traceVersion, startup.trace = 1, steps
                startup.traceOmitted = math.floor(math.min(ns.Number(s.traceOmitted) or 0, 100000))
            end
        end
        return { schema = ns.HISTORY_SCHEMA, kind = "startup", id = id, timestamp = timestamp, duration = duration,
            name = ns.CleanText(source.name, 180) or L("Загрузка", "Loading"), version = ns.CleanText(source.version, 40),
            build = ns.CleanText(source.build, 80), startup = startup, complete = true, pinned = source.pinned == true }
    end
    if source.kind ~= "capture" and source.kind ~= "background" then return end
    local record = { schema = ns.HISTORY_SCHEMA, kind = source.kind, rows = {}, timeline = {} }
    Numbers(source, record, fields)
    if not record.id or not record.timestamp or not record.duration or record.duration > 86400 then return end
    record.name = ns.CleanText(source.name, 180) or L("Замер", "Capture")
    record.version = ns.CleanText(source.version, 40)
    record.build = ns.CleanText(source.build, 80)
    record.reason = ns.CleanText(source.reason, 40)
    record.memoryState = ns.CleanText(source.memoryState, 24)
    record.profile = source.profile == "light" and "light" or "detailed"
    record.trigger = source.trigger == "combat" and "combat" or source.trigger == "boss" and "boss" or "manual"
    record.scenario = ns.CleanText(source.scenario, 160)
    record.measurement = ns.CleanText(source.measurement, 80)
    record.complete = source.complete == true
    record.contextChanged = source.contextChanged == true
    record.group = source.group == "A" and "A" or source.group == "B" and "B" or nil
    record.context, record.markers, record.memoryTrail = {}, {}, {}
    if type(source.context) == "table" then
        for _, key in ipairs({ "zone", "instanceType" }) do record.context[key] = ns.CleanText(source.context[key], 128) end
        Numbers(source.context, record.context, { "map", "groupSize", "fpsLimit", "difficulty" })
        if type(source.context.combat) == "boolean" then record.context.combat = source.context.combat end
    end
    if type(source.markers) == "table" then
        for i = 1, math.min(#source.markers, 80) do
            local m = source.markers[i]
            if type(m) == "table" then
                local text, at = ns.CleanText(m.text, 160), ns.Number(m.at)
                if text and at then record.markers[#record.markers+1] = { text=text, at=at, kind=ns.CleanText(m.kind,32) } end
            end
        end
    end
    if type(source.memoryTrail) == "table" then
        for i = 1, math.min(#source.memoryTrail, 30) do
            local m = source.memoryTrail[i]
            if type(m) == "table" and ns.Number(m.timestamp) and ns.Number(m.total) then record.memoryTrail[#record.memoryTrail+1] = {timestamp=m.timestamp,total=m.total} end
        end
    end
    record.pinned = source.pinned == true
    if type(source.rows) == "table" then
        for i = 1, math.min(#source.rows, ns.MAX_ADDONS) do
            local old = source.rows[i]
            if type(old) == "table" then
                local name = ns.CleanText(old.name, 128)
                if name then
                    local row = { name = name, version = ns.CleanText(old.version, 40) }
                    Numbers(old, row, rowFields)
                    record.rows[#record.rows + 1] = row
                end
            end
        end
    end
    if type(source.timeline) == "table" then
        for i = 1, math.min(#source.timeline, ns.MAX_BINS) do
            local old = source.timeline[i]
            if type(old) == "table" then
                local point = { contributors = {} }
                Numbers(old, point, binFields)
                if type(old.contributors) == "table" then
                    for j = 1, math.min(#old.contributors, 3) do
                        local entry = old.contributors[j]
                        if type(entry) == "table" then
                            local name, value = ns.CleanText(entry.name, 128), ns.Number(entry.value)
                            if name and value and value > 0 then point.contributors[#point.contributors + 1] = { name = name, value = value } end
                        end
                    end
                end
                record.timeline[#record.timeline + 1] = point
            end
        end
    end
    if record.kind == "background" then
        record.average, record.peak, record.frames, record.samples = nil, nil, nil, nil
        for _, row in ipairs(record.rows) do row.average, row.peak, row.memory = nil, nil, nil end
        record.complete, record.group, record.measurement = false, nil, nil
    end
    return record
end
function ns.TrimHistory()
    local kept, pins, regular, startup = {}, 0, 0, 0
    for _, record in ipairs(db.history) do
        if record.pinned and pins < ns.MAX_PINNED then pins = pins + 1; kept[#kept + 1] = record
        elseif record.kind == "startup" then
            if startup < ns.MAX_STARTUP then record.pinned = false; startup = startup + 1; kept[#kept + 1] = record end
        elseif regular < db.historyLimit then record.pinned = false; regular = regular + 1; kept[#kept + 1] = record end
    end
    db.history = kept
end
function ns.InitHistory(storage)
    db, ns.db = storage, storage
    if type(db.minimap) ~= "table" then db.minimap = {} end
    if db.duration ~= 5 and db.duration ~= 15 and db.duration ~= 30 and db.duration ~= 60 and db.duration ~= 120 then db.duration = 30 end
    if db.historyLimit ~= 20 and db.historyLimit ~= 50 and db.historyLimit ~= 100 then db.historyLimit = 20 end
    db.background, db.memoryManual = db.background == true, db.memoryManual == true
    db.profile = db.profile == "detailed" and "detailed" or "light"
    db.trigger = db.trigger == "combat" and "combat" or db.trigger == "boss" and "boss" or "manual"
    db.scenario = ns.CleanText(db.scenario, 160) or L("Мой сценарий", "My scenario")
    local old, nextID, seen = db.history, 0, {}
    db.history = {}
    if type(old) == "table" then
        for i = 1, math.min(#old, 100 + ns.MAX_PINNED + ns.MAX_STARTUP) do
            local record = Sanitize(old[i])
            if record and not seen[record.id] then
                seen[record.id] = true
                nextID = math.max(nextID, record.id)
                db.history[#db.history + 1] = record
            end
        end
    end
    table.sort(db.history, function(a, b) return a.id > b.id end)
    db.nextID, db.schema = math.max(nextID, ns.Number(db.nextID) or 0), ns.HISTORY_SCHEMA
    ns.TrimHistory()
end
function ns.History() return db and db.history or {} end
function ns.FindRecord(id)
    for _, record in ipairs(ns.History()) do if record.id == id then return record end end
end
function ns.SaveRecord(record)
    if not db then return end
    db.nextID = db.nextID + 1
    record.id, record.schema, record.version = db.nextID, ns.HISTORY_SCHEMA, ns.VERSION
    record.timestamp = record.timestamp or time()
    local saved = Sanitize(record)
    if not saved then return end
    table.insert(db.history, 1, saved)
    ns.TrimHistory()
    if ns.OnHistoryChanged then ns.OnHistoryChanged(saved) end
    return saved
end
function ns.RenameRecord(id, name)
    local record = ns.FindRecord(id)
    name = ns.CleanText(name, 180)
    if not record or not name then return false end
    record.name = name
    return true
end
function ns.PinRecord(id)
    local record = ns.FindRecord(id)
    if not record then return false end
    if not record.pinned then
        local count = 0
        for _, entry in ipairs(db.history) do if entry.pinned then count = count + 1 end end
        if count >= ns.MAX_PINNED then return false end
    end
    record.pinned = not record.pinned
    ns.TrimHistory()
    return true
end
function ns.DeleteRecord(id)
    for i, record in ipairs(ns.History()) do if record.id == id then table.remove(db.history, i); return true end end
    return false
end
local function Quote(text)
    return '"' .. tostring(text):gsub('[%z\1-\31\\"]', function(c)
        if c == '"' then return '\\"' elseif c == '\\' then return '\\\\' end
        return ('\\u%04x'):format(c:byte())
    end) .. '"'
end
local function JSON(value, array)
    if issecretvalue and issecretvalue(value) then return "null" end
    local kind = type(value)
    if kind == "string" then return Quote(value) elseif kind == "number" then return value==value and value>-math.huge and value<math.huge and tostring(value) or "null"
    elseif kind == "boolean" then return tostring(value) elseif kind ~= "table" then return "null" end
    local parts = {}
    if array or #value > 0 then
        for i = 1, #value do parts[i] = JSON(value[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do parts[#parts + 1] = Quote(key) .. ":" .. JSON(value[key], key == "rows" or key == "timeline" or key == "contributors" or key == "markers" or key == "memoryTrail" or key == "A" or key == "B" or key == "modules" or key == "points" or key == "gaps") end
    return "{" .. table.concat(parts, ",") .. "}"
end
ns.JSON = JSON
local function Value(value, format) return value ~= nil and (format or "%s"):format(value) or L("нет данных", "unavailable") end
function ns.StartupScope(record)
    local s = record.startup
    local from = s.reloadLead and L("От команды /sperf reload", "From /sperf reload") or L("От первого кода Perf", "From Perf's first code")
    local to = s.endpoint == "screen" and L("до закрытия экрана загрузки", "to loading screen dismissal")
        or L("до события входа в мир", "to the entering-world event")
    return from .. " " .. to
end

function ns.StartupChain(record)
    local s = record and record.startup
    if not s or s.traceVersion ~= 1 then return end
    local nodes = {}
    local lead = s.reloadLead or 0
    if lead > 0 then nodes[1] = { kind = "command", at = 0 } end
    for _, step in ipairs(s.trace) do
        nodes[#nodes+1] = { kind = step.kind, name = step.name, at = step.at + lead }
    end
    return nodes
end

function ns.StartupStepName(step, record)
    if step.kind == "addon" then return step.name end
    if step.kind == "command" then return "/sperf reload" end
    if step.kind == "start" then return L("Старт Perf", "Perf starts") end
    if step.kind == "login" then return "PLAYER_LOGIN" end
    if step.kind == "world" then return "PLAYER_ENTERING_WORLD" end
    return record.startup.endpoint == "screen" and L("Вошел в игру", "World visible") or L("Вход в мир (событие)", "World entry event")
end

function ns.StartupLinkTime(nodes, index)
    local following = nodes[index+1]
    if not following then return end
    local duration = math.max(0, following.at - nodes[index].at)
    return duration > 0 and duration < .01 and L("<0.01 с", "<0.01 s") or ("%.2f"):format(duration)..L(" с", " s")
end

function ns.StartupCompactTime(nodes, index)
    local following = nodes[index+1]
    if not following then return end
    local duration = math.max(0, following.at - nodes[index].at)
    if duration >= 1 then return ("%.2f"):format(duration)..L(" с", " s") end
    if duration > 0 and duration < .001 then return L("<1 мс", "<1 ms") end
    local milliseconds = math.floor(duration * 1000 + .5)
    if milliseconds >= 1000 then return L("1.00 с", "1.00 s") end
    return milliseconds..L(" мс", " ms")
end

function ns.StartupLongestLinks(nodes)
    local longest, ranks = {}, {}
    for index = 1, #(nodes or {}) - 1 do
        local duration = nodes[index+1].at - nodes[index].at
        if duration > 0 then
            for place = 1, 3 do
                if not longest[place] or duration > longest[place].duration then
                    table.insert(longest, place, { index = index, duration = duration })
                    longest[4] = nil
                    break
                end
            end
        end
    end
    for place, link in ipairs(longest) do ranks[link.index] = place end
    return ranks
end

function ns.StartupChainText(record)
    local nodes = ns.StartupChain(record)
    if not nodes then return end
    local lines = { L("Цепочка наблюдавшейся загрузки", "Observed loading chain"),
        L("Время на переходах измерено между отметками.", "Link times are elapsed intervals between markers.") }
    for index = 1, #nodes-1 do
        local duration = ns.StartupLinkTime(nodes, index)
        if index == #nodes-1 and record.startup.traceOmitted > 0 then
            duration = duration .. L("; пропущено отметок: ", "; markers omitted: ") .. record.startup.traceOmitted
        end
        lines[#lines+1] = ns.StartupStepName(nodes[index], record) .. " --" .. duration .. "--> " .. ns.StartupStepName(nodes[index+1], record)
    end
    return table.concat(lines, "\n")
end

function ns.StartupDetails(record, gapsOnly)
    local s = record.startup
    local lines = {}
    if s.reloadLead then lines[#lines+1] = L("От команды до старта Perf: ", "Command to Perf startup: ") .. ("%.2f s"):format(s.reloadLead) end
    if not gapsOnly and s.beforeLogin then
        lines[#lines+1] = L("От старта Perf до PLAYER_LOGIN: ", "Perf startup to PLAYER_LOGIN: ") .. ("%.2f s"):format(s.beforeLogin)
        lines[#lines+1] = L("От PLAYER_LOGIN до конца замера: ", "PLAYER_LOGIN to end: ") .. ("%.2f s"):format(math.max(0, record.duration - (s.reloadLead or 0) - s.beforeLogin))
    elseif not s.beforeLogin then lines[#lines+1] = L("Метка PLAYER_LOGIN недоступна. Разбивка по этапам отсутствует.", "The PLAYER_LOGIN timestamp is unavailable. Phase timings are unavailable.") end
    if #lines > 0 then lines[#lines+1] = "" end
    if s.beforeLogin then
        local afterLogin = math.max(0, record.duration - (s.reloadLead or 0) - s.beforeLogin)
        local hint
        if s.reloadLead and s.reloadLead > math.max(s.beforeLogin, afterLogin) then
            hint = L("Дольше от команды до запуска Perf. Этот этап включает перезагрузку клиента и код, загрузившийся раньше Perf.",
                "The command-to-Perf phase took longest. It includes UI restart work and code loaded before Perf.")
        elseif s.beforeLogin >= afterLogin then
            hint = L("Дольше этап до PLAYER_LOGIN. Проверьте инициализацию аддонов контрольными повторами.",
                "The phase before PLAYER_LOGIN took longer. Test addon initialization with controlled repeats.")
        else
            hint = L("Дольше этап после PLAYER_LOGIN. Здесь продолжаются вход в мир и обработчики аддонов.",
                "The phase after PLAYER_LOGIN took longer. World entry and addon handlers continue during this phase.")
        end
        lines[#lines+1] = hint
        lines[#lines+1] = ""
    end
    if not s.reloadLead then
        lines[#lines+1] = L("Первая отметка появляется при запуске Perf. Начальный отрезок загрузки остается за ее пределами.",
            "The first timestamp is taken as Perf starts. Earlier loading time is outside this interval.")
        lines[#lines+1] = ""
    end
    local chain = ns.StartupChainText(record)
    if chain then
        lines[#lines+1] = chain
    else
        lines[#lines+1] = L("В этой записи сохранены только длинные интервалы. Новый вход или /reload запишет цепочку.",
            "This report keeps only long intervals. A new login or /reload records a chain.")
        lines[#lines+1] = L("Самые длинные интервалы между событиями загрузки", "Longest intervals between loading events")
        lines[#lines+1] = L("Сначала длинные интервалы. Время измерено между отметками начала и конца.",
            "Longest intervals first. Duration is measured between the start and end markers.")
        for _, gap in ipairs(s.gaps) do
            lines[#lines+1] = ""
            lines[#lines+1] = ("%.2f"):format(gap.duration)..L(" с"," s")
            lines[#lines+1] = L("Начало: ","Start: ")..(gap.after or L("Старт Perf", "Perf startup"))
            lines[#lines+1] = L("Конец: ","End: ")..(gap.before or "PLAYER_LOGIN")
        end
        if #s.gaps == 0 then lines[#lines+1] = L("Нет наблюдавшихся интервалов.", "No intervals observed.") end
    end
    lines[#lines+1] = ""
    lines[#lines+1] = L("Названия аддонов отмечают границы интервала. В него может входить работа клиента и других аддонов.", "Addon names mark interval boundaries. The interval can include client work and other addons.")
    lines[#lines+1] = L("Для проверки причины повторите замер в тех же условиях, изменив один аддон или настройку.", "To test a cause, repeat under the same conditions and change one addon or setting.")
    return table.concat(lines, "\n")
end
function ns.Export(record, format)
    if not record then return "" end
    if record.kind == "startup" then
        if format == "json" then return ns.JSON({ format = "Sintezza_Perf/2", scope = "startup", report = record }) end
        return table.concat({record.name, date("%Y-%m-%d %H:%M:%S", record.timestamp) .. " | " .. (record.build or "WoW Forever"),
            ns.StartupScope(record), ("%.2f s"):format(record.duration), "", ns.StartupDetails(record)}, "\n")
    end
    if format == "json" then
        return '{"format":"Sintezza_Perf/2","profilerIncluded":true,"scope":' .. Quote(record.kind)
            .. ',"averageMs":' .. JSON(record.average) .. ',"peakMs":' .. JSON(record.peak)
            .. ',"frameP99Ms":' .. JSON(record.p99)
            .. ',"memorySnapshotUnix":' .. JSON(record.memoryTimestamp) .. ',"report":' .. JSON(record) .. '}'
    end
    local lines = { "Sintezza Perf " .. (record.version or ns.VERSION), record.name,
        date("%Y-%m-%d %H:%M:%S", record.timestamp) .. " | " .. (record.build or "WoW Forever"),
        L("Режим: ", "Mode: ") .. (record.kind == "background" and L("легкий фоновый сбор", "light background") or L("подробный замер", "detailed capture")),
        L("Длительность, с: ", "Duration, s: ") .. Value(record.duration, "%.2f"),
        L("Сценарий: ", "Scenario: ") .. (record.scenario or L("не записан", "not recorded")),
        L("Профиль: ", "Profile: ") .. (record.profile == "light" and L("легкий", "light") or L("подробный", "detailed")),
        L("Полная запись: ", "Complete recording: ") .. (record.complete and L("да", "yes") or L("нет", "no")),
        L("Наблюдавшиеся кадры: ", "Observed frames: ") .. Value(record.frames),
        L("Кадры: p95 / p99 / максимум, мс: ", "Frames: p95 / p99 / maximum, ms: ") .. Value(record.p95,"%.2f") .. " / " .. Value(record.p99,"%.2f") .. " / " .. Value(record.framePeak,"%.2f"),
        L("Кадры клиента >50 / >100 мс: ", "Client frames >50 / >100 ms: ") .. Value(record.long50) .. " / " .. Value(record.long100),
        L("Среднее CPU, мс/кадр: ", "Average CPU, ms/frame: ") .. Value(record.average, "%.3f"),
        L("Пик CPU, мс: ", "Peak CPU, ms: ") .. Value(record.peak, "%.3f"),
        L("Все аддоны >5 / >10 / >50 мс: ", "Combined addons >5 / >10 / >50 ms: ") .. Value(record.five) .. " / " .. Value(record.ten) .. " / " .. Value(record.fifty),
        L("Пропущенные показания: ", "Missing readings: ") .. Value(record.missing or 0),
        L("Память: ", "Memory: ") .. (record.memoryTimestamp and date("%H:%M:%S", record.memoryTimestamp) or L("не записывалась", "not recorded")),
        L("Сборщик CPU, среднее / пик, мс: ", "CPU collector, mean / peak, ms: ") .. Value(record.costAverage, "%.3f") .. " / " .. Value(record.costPeak, "%.3f"),
        "", L("Аддон | среднее мс | пик мс | >5 / >10 / >50 | память МиБ | версия", "Addon | mean ms | peak ms | >5 / >10 / >50 | memory MiB | version") }
    for _, row in ipairs(record.rows) do
        lines[#lines + 1] = row.name .. " | " .. Value(row.average, "%.3f") .. " | " .. Value(row.peak, "%.3f")
            .. " | " .. Value(row.five) .. " / " .. Value(row.ten) .. " / " .. Value(row.fifty)
            .. " | " .. Value(row.memory, "%.2f") .. " | " .. (row.version or "?")
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = L("Perf включен в общие показатели. Пики и счетчики отдельных аддонов не складываются.", "Perf is included in overall results. Per-addon peaks and threshold counts must not be added together.")
    if record.measurement then
        lines[#lines+1] = L("p95/p99: верхняя граница корзины гистограммы (0,1 мс до 100 мс; 1 мс до 1 с; 10 мс до 10 с). Не 1% low FPS и не измерение GPU.", "p95/p99: histogram bucket upper bound (0.1 ms up to 100 ms; 1 ms up to 1 s; 10 ms up to 10 s). Not 1% low FPS or a GPU measurement.")
        lines[#lines+1] = L("Условия: ", "Conditions: ") .. JSON(record.context or {})
        for _, marker in ipairs(record.markers or {}) do lines[#lines+1] = ("%.2f s | %s"):format(marker.at,marker.text) end
        lines[#lines+1] = L("Пропущено меток: ", "Omitted markers: ") .. tostring(record.markerOmitted or 0)
        lines[#lines+1] = L("Снимки памяти (отдельный период сеанса): ", "Memory snapshots (separate session period): ") .. JSON(record.memoryTrail or {},true)
    end
    if record.reason then lines[#lines + 1] = L("Причина завершения: ", "Stop reason: ") .. record.reason end
    if (record.omitted or 0) > 0 then lines[#lines + 1] = L("Аддонов вне подробной таблицы: ", "Addons outside the detailed table: ") .. record.omitted end
    return table.concat(lines, "\n")
end
