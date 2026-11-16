local addon, ns = ...
local L = ns.Text
local shared = Sintezza_Theme
local T = shared and shared:ForAddon() or {
    bg = { .09, .07, .06, .98 }, panel = { .15, .11, .08, 1 }, line = { .45, .33, .20, 1 },
    lineSoft = { .34, .25, .16, 1 }, text = { .95, .91, .84, 1 }, muted = { .72, .65, .56, 1 },
    brass = { .75, .58, .37, 1 }, accent = { .90, .72, .47, 1 }, accentDim = { .30, .22, .12, 1 },
}
local W = shared and shared:CreateWidgets(T)
local icon = "Interface\\AddOns\\" .. addon .. "\\Media\\Icon"
local width, height, rowHeight = 916, 591, 24
local ui, db, launcher, settingsCategory
local refreshMinimapSetting
local views = { "cpu", "memory", "spikes" }
local titles = { "CPU", L("Память", "Memory"), L("Спайки", "Spikes") }
local usageInterval = 60
local intervals = { 5, 15, 30, 60, 120 }
local shades = { { .44, .65, .62, 1 }, T.accent, { .82, .48, .37, 1 } }

local function Color(region, method, tint)
    if shared then shared:Tint(region, method, tint) else region[method](region, unpack(tint)) end
end

local function Backdrop(frame, tint, border)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    Color(frame, "SetBackdropColor", tint)
    Color(frame, "SetBackdropBorderColor", border or T.lineSoft)
end

local function Panel(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if W then T:PanelSurface(frame) else Backdrop(frame, T.panel) end
    return frame
end

local function Label(parent, value, size, color, role)
    local label
    if W then
        label = W:Label(parent, value, size, color, role)
    else
        label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local path, _, flags = label:GetFont()
        if path then label:SetFont(path, size or 11, flags) end
        label:SetText(value)
        label:SetTextColor(unpack(color or T.text))
        label:SetJustifyH("LEFT")
    end
    label:SetWordWrap(false)
    return label
end

local function Button(parent, value, click, primary)
    if W then return W:Button(parent, value, click, primary) end
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetHeight(24)
    Backdrop(button, primary and T.accentDim or T.panel)
    button.text = Label(button, value, 11)
    button.text:SetPoint("CENTER")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    button:SetScript("OnClick", click)
    return button
end

local function Highlight(button, selected)
    if W then T:PaintButton(button, selected)
    else button:SetBackdropColor(unpack(selected and T.accentDim or T.panel)) end
end

local function TintBlock(parent, color, layer)
    local block = parent:CreateTexture(nil, layer or "ARTWORK")
    Color(block, "SetColorTexture", color)
    return block
end

local function ShowTooltip(owner, title, ...)
    if not GameTooltip then return end
    if ui then ui.tooltipOwner = owner end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title)
    for index = 1, select("#", ...) do
        local line = select(index, ...)
        GameTooltip:AddLine(line, .9, .9, .9, true)
    end
    GameTooltip:Show()
end

local function HideTooltip(owner)
    if owner and GameTooltip and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

local function BindTooltip(owner, onEnter)
    owner:HookScript("OnEnter", onEnter)
    owner:HookScript("OnLeave", HideTooltip)
    owner:HookScript("OnHide", HideTooltip)
end

local function Describe(owner, title, description)
    BindTooltip(owner, function(self) ShowTooltip(self, title, description) end)
end

local function HoverRegion(parent, target)
    local region = CreateFrame("Frame", nil, parent)
    if not (region.SetMouseMotionEnabled and region.SetMouseClickEnabled) then return region end
    if target then region:SetAllPoints(target) end
    region:SetMouseMotionEnabled(true)
    region:SetMouseClickEnabled(false)
    return region
end

local function Clock(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return ("%02d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function MarkCount(count)
    return tostring(count or 0)
end

local function Measure(value, format)
    return value and format:format(value) or "—"
end

local function SetStat(index, label, value, description)
    local field = ui.status.fields[index]
    field.description = description
    field:SetShown(label ~= nil)
    if not label then return end
    field.label:SetText(label)
    field.value:SetText(value)
end

local function PaintProgress(record, recording, monitoring)
    local action = recording and L("Остановить", "Stop") or L("Начать замер", "Start capture")
    if ui.start.text:GetText() ~= action then HideTooltip(ui.start) end
    ui.start.text:SetText(action)
    ui.start:SetEnabled(recording or not not ns.Available())
    ui.duration:SetEnabled(not recording)
    ui.track:SetShown(recording and not ui.displayBackground)
    SetStat(4, L("Обновлено", "Updated"), record and record.updated or "—",
        L("Время последнего чтения счетчиков спайков.", "Time of the last spike counter reading."))
    if ui.displayBackground then
        local elapsed = record.checked - record.started
        local total = 0
        for _, point in ipairs(record.windows) do total = total + point.overall end
        local text = L("Фоновый сбор остановлен", "Background monitoring stopped")
        if monitoring then
            text = record.readable and L("Фоновый сбор идет", "Background monitoring active")
                or L("Счетчики недоступны", "Counters unavailable")
        end
        SetStat(1, L("Статус", "Status"), text,
            L("Идет ли фоновый сбор и доступны ли счетчики WoW.", "Whether background monitoring is active and the WoW counters are available."))
        SetStat(2, L("Время сбора", "Monitoring time"), Clock(elapsed),
            L("Время от начала фонового сбора до последнего чтения счетчиков.", "Time from the start of background monitoring to the last counter reading."))
        SetStat(3, L("Кадры >5 мс на графике", "Charted frames >5 ms"), tostring(total),
            L("Число кадров в показанных интервалах, где все аддоны вместе заняли больше 5 мс.",
                "Frames in the displayed intervals where all addons together took more than 5 ms."))
        return 0
    end
    local text = ns.Available() and L("Готов к замеру", "Ready to capture") or L("Профайлер WoW недоступен", "WoW profiler unavailable")
    if recording then text = L("Идет замер", "Capturing")
    elseif record then text = L("Последний замер", "Last capture")
    elseif ns.BackgroundEnabled() then text = L("Фоновый сбор недоступен", "Background monitoring unavailable") end
    local elapsed = record and (recording and GetTime() - record.started or record.elapsed) or 0
    local ticks = 0
    for _, point in ipairs(record and record.timeline or {}) do ticks = ticks + point.total end
    SetStat(1, L("Статус", "Status"), text,
        L("Готовность профайлера и состояние ручного замера.", "Profiler availability and timed capture status."))
    SetStat(2, L("Время замера", "Capture time"), record and Clock(elapsed) or "—",
        L("Сколько времени прошло с начала замера. Полоска показывает, какая часть выбранной длительности прошла.",
            "Time since the capture started. The bar shows how much of the chosen duration has elapsed."))
    SetStat(3, L("Отметки >5 мс за замер", "Capture marks >5 ms"), record and tostring(ticks) or "—",
        L("Число превышений 5 мс по отдельным аддонам. Один кадр может дать несколько отметок.",
            "Number of times individual addons exceeded 5 ms. One frame can contribute several marks."))
    return record and math.min(1, elapsed / record.duration) * 112 or 0
end

local function SetDimension(region, axis, value)
    if axis == "width" then region:SetWidth(math.max(.1, value))
    else region:SetHeight(math.max(.1, value)) end
    region:SetShown(value > 0)
    region.perfSize = value
end

local function Animate(region, axis, value)
    local pending = ui.motion[region]
    if pending and pending.target == value then return end
    local current = region.perfSize or 0
    if current == value then ui.motion[region] = nil; return end
    if shared and shared.animateControls == false or not ui:IsShown() then
        ui.motion[region] = nil
        SetDimension(region, axis, value)
        return
    end
    ui.motion[region] = { start = current, target = value, axis = axis, time = 0 }
    if ui:GetScript("OnUpdate") then return end
    ui:SetScript("OnUpdate", function(self, elapsed)
        for node, job in pairs(self.motion) do
            job.time = job.time + elapsed
            local progress = math.min(1, job.time / .20)
            local eased = 1 - (1 - progress) * (1 - progress)
            SetDimension(node, job.axis, job.start + (job.target - job.start) * eased)
            if progress == 1 then self.motion[node] = nil end
        end
        if not next(self.motion) then self:SetScript("OnUpdate", nil) end
    end)
end

local function BucketData(timeline, origin, seconds, stride, background)
    local slots, maximum = {}, 0
    for index = 1, math.ceil(seconds / stride) do slots[index] = { total = 0, ten = 0, fifty = 0, overall = 0 } end
    for _, item in ipairs(timeline) do
        local slot = slots[math.ceil((item.bin - origin) / stride)]
        if slot then
            slot.total, slot.ten, slot.fifty = slot.total + item.total, slot.ten + item.ten, slot.fifty + item.fifty
            if background then slot.overall = slot.overall + item.overall end
            slot.contributors = slot.contributors or {}
            for _, entry in ipairs(item.contributors) do
                slot.contributors[entry.name] = (slot.contributors[entry.name] or 0) + entry.value
            end
            maximum = math.max(maximum, background and slot.overall or slot.total)
        end
    end
    return slots, math.max(4, math.ceil(maximum / 4) * 4)
end

local function PaintDetails()
    local slot = ui.slots and ui.slots[ui.selected]
    local start = ui.origin + (ui.selected - 1) * ui.stride
    ui.detailTime:SetText(ui.record and (Clock(start) .. "–" .. Clock(math.min(ui.origin + ui.seconds, start + ui.stride))) or "")
    local names = {}
    for name, count in pairs(slot and slot.contributors or {}) do
        names[#names + 1] = { name = name, value = count }
    end
    table.sort(names, function(a, b)
        return a.value > b.value or a.value == b.value and a.name < b.name
    end)
    if ui.displayBackground and slot and slot.overall > 0 then
        table.insert(names, 1, { name = L("Все аддоны вместе", "All addons combined"), value = slot.overall })
    end
    ui.detailEmpty:SetShown(#names == 0)
    for index, line in ipairs(ui.detailRows) do
        local entry = names[index]
        line.name:SetText(entry and entry.name or "")
        line.count:SetText(entry and MarkCount(entry.value) or "")
        line.hover:SetShown(entry ~= nil)
    end
    local previous, nextSlot = ui.bars[ui.highlighted], ui.bars[ui.selected]
    if previous then previous.select:Hide() end
    if nextSlot and slot and ui.record then nextSlot.select:Show() end
    ui.highlighted = ui.selected
end

local function SelectSlot(index)
    ui.selected, ui.follow = index, false
    ui.selectedTime = ui.origin + math.min(ui.seconds, index * ui.stride)
    PaintDetails()
end

local function MakeBar(plot, index)
    local bar = CreateFrame("Button", nil, plot)
    bar:SetHeight(124)
    bar:SetScript("OnClick", function() SelectSlot(index) end)
    BindTooltip(bar, function(self)
        if not ui.record then return end
        ShowTooltip(self, L("Интервал на графике", "Chart interval"),
            ui.displayBackground and L("Высота показывает число кадров, где все аддоны вместе заняли больше 5 мс.",
                "Bar height counts frames where all addons together took more than 5 ms.")
                or L("Высота показывает число отметок отдельных аддонов. Цвета обозначают диапазоны времени работы.",
                    "Bar height counts marks from individual addons. Colors indicate ranges of addon time."),
            L("Нажми, чтобы увидеть вклад аддонов.", "Click to see addon contributions."))
    end)
    bar.select = TintBlock(bar, { 1, .81, .53, .13 }, "BACKGROUND")
    bar.select:SetAllPoints()
    bar.select:Hide()
    bar.parts = {}
    for tier, shade in ipairs(shades) do
        local segment = TintBlock(bar, shade)
        local anchor = bar.parts[tier - 1] or bar
        local edge = tier > 1 and "TOP" or "BOTTOM"
        local inset = tier == 1 and 2 or 0
        segment:SetPoint("BOTTOMLEFT", anchor, edge .. "LEFT", inset, 0)
        segment:SetPoint("BOTTOMRIGHT", anchor, edge .. "RIGHT", -inset, 0)
        SetDimension(segment, "height", 0)
        bar.parts[tier] = segment
    end
    return bar
end

local function PaintTimeline(record, recording)
    local background = ui.displayBackground
    local origin, seconds, minimumStride = 0, 30, 1
    local timeline = {}
    if background then
        local totalTime = math.ceil(record.checked - record.started)
        origin = math.max(0, totalTime - 30)
        if record.windows[1] then origin = math.min(origin, math.floor(record.windows[1].from)) end
        seconds, minimumStride, timeline = math.max(30, totalTime - origin), record.interval, record.windows
    elseif record then
        seconds = recording and record.duration or math.min(record.duration, math.ceil(record.elapsed))
        timeline = record.timeline
    end
    seconds = math.max(1, seconds)
    local stride = math.max(minimumStride, math.ceil(seconds / 40))
    local slots, limit = BucketData(timeline, origin, seconds, stride, background)
    ui.origin, ui.seconds, ui.stride, ui.slots = origin, seconds, stride, slots
    if ui.follow and timeline[#timeline] then
        ui.selected = math.ceil((timeline[#timeline].bin - origin) / stride)
    elseif background and ui.selectedTime then
        ui.selected = math.ceil((ui.selectedTime - origin) / stride)
    end
    ui.selected = math.max(1, math.min(#slots, ui.selected))
    for index, label in ipairs(ui.grid) do label:SetText(tostring(limit * (3 - index) / 2)) end
    for index, label in ipairs(ui.times) do label:SetText(Clock(origin + math.floor(seconds * (index - 1) / 3))) end
    local stick = 586 / #slots
    for index, bar in ipairs(ui.bars) do
        local slot = slots[index]
        bar:SetShown(slot ~= nil)
        if slot then
            if ui.stick ~= stick then
                bar:SetPoint("BOTTOMLEFT", ui.plot, "BOTTOMLEFT", (index - 1) * stick, 20)
                bar:SetWidth(stick)
            end
            Animate(bar.parts[1], "height", (background and slot.overall or slot.total - slot.ten) / limit * 124)
            Animate(bar.parts[2], "height", (background and 0 or slot.ten - slot.fifty) / limit * 124)
            Animate(bar.parts[3], "height", (background and 0 or slot.fifty) / limit * 124)
        end
    end
    ui.stick = stick
    ui.chartMeasure:SetText(background and L("Кадры >5 мс за интервал", "Frames >5 ms per interval")
        or L("Отметки аддонов за интервал", "Addon marks per interval"))
    ui.legend[1].label:SetText(background and L("Все аддоны вместе >5 мс", "All addons combined >5 ms") or ui.legend[1].text)
    for index = 2, #ui.legend do
        ui.legend[index].marker:SetShown(not background)
        ui.legend[index].label:SetShown(not background)
        ui.legend[index].hover:SetShown(not background)
    end
    local empty = L("Запусти замер, чтобы увидеть спайки.", "Start a capture to see frame spikes.")
    if background then empty = L("Фоновых спайков свыше 5 мс пока нет.", "No background spikes above 5 ms yet.")
    elseif record then empty = L("За замер пока нет кадров свыше 5 мс.", "No frames above 5 ms in this capture yet.")
    elseif ns.BackgroundEnabled() then empty = L("Фоновый сбор недоступен.", "Background monitoring unavailable.") end
    ui.plotEmpty:SetText(empty)
    ui.plotEmpty:SetShown(#timeline == 0)
    PaintDetails()
end

local function Columns(mode)
    if mode == "spikes" then
        if ui.displayBackground then
            return {
                { "when", L("Интервал", "Interval"), 0, 150 }, { "name", L("Аддон", "Addon"), 158, 252 },
                { "overall", L("Вместе >5 мс", "Combined >5 ms"), 418, 126 },
                { "five", ">5 " .. L("мс", "ms"), 550, 94 }, { "ten", ">10 " .. L("мс", "ms"), 652, 94 },
                { "fifty", ">50 " .. L("мс", "ms"), 756, 94 },
            }
        end
        return {
            { "when", L("Интервал", "Interval"), 0, 158 }, { "name", L("Больше всего отметок", "Most marks"), 166, 366 },
            { "five", ">5 " .. L("мс", "ms"), 540, 94 }, { "ten", ">10 " .. L("мс", "ms"), 648, 94 },
            { "fifty", ">50 " .. L("мс", "ms"), 756, 94 },
        }
    end
    return {
        { "name", L("Аддон", "Addon"), 0, 251 },
        { "recent", L("CPU, мс/кадр", "CPU, ms/frame"), 259, 112 },
        { "memory", L("Память, МиБ", "Memory, MiB"), 379, 108 },
        { "average", L("Ср. за сеанс, мс", "Session avg, ms"), 495, 126 },
        { "peak", L("Худший кадр, мс", "Worst frame, ms"), 629, 120 },
        { "share", L("Доля кадра", "Frame share"), 757, 93 },
    }
end

local columnDescriptions = {
    recent = L("Среднее время работы аддона за последние 60 кадров. Полная полоска соответствует максимуму в колонке.",
        "The addon's average time over the last 60 frames. A full bar represents the column maximum."),
    memory = L("Память Lua, отнесенная к аддону в последнем снимке. Полная полоска соответствует максимуму в колонке.",
        "Lua memory attributed to the addon in the latest snapshot. A full bar represents the column maximum."),
    average = L("Среднее время работы аддона за кадр с начала сеанса.", "The addon's average time per frame since the session started."),
    peak = L("Самое долгое время работы аддона в одном кадре с начала сеанса.",
        "The longest time the addon spent in a single frame since the session started."),
    share = L("Среднее время работы аддона за последние 60 кадров в процентах от средней длительности кадра WoW за те же кадры.",
        "The addon's average time over the last 60 frames as a percentage of WoW's average frame duration over those frames."),
    when = L("Начало и конец интервала относительно начала сбора или замера.",
        "Interval start and end relative to the start of monitoring or capture."),
    leader = L("Аддон с наибольшим числом отметок свыше 5 мс в этом интервале.",
        "The addon with the most marks above 5 ms in this interval."),
    overall = L("Кадры за интервал, где все аддоны вместе заняли больше 5 мс.",
        "Frames in this interval where all addons together took more than 5 ms."),
    five = L("Отметки отдельных аддонов свыше 5 мс за интервал, включая отметки свыше 10 и 50 мс.",
        "Per-addon marks over 5 ms in this interval, including marks over 10 and 50 ms."),
    ten = L("Отметки отдельных аддонов свыше 10 мс за интервал, включая отметки свыше 50 мс.",
        "Per-addon marks over 10 ms in this interval, including marks over 50 ms."),
    fifty = L("Отметки отдельных аддонов свыше 50 мс за интервал.", "Per-addon marks over 50 ms in this interval."),
}

local function ColumnDescription(key)
    return columnDescriptions[ui.mode == "spikes" and key == "name" and "leader" or key]
end

local function Format(key, value, row)
    if key == "recent" or key == "average" or key == "peak" then return Measure(value, "%.3f") end
    if key == "share" then return Measure(value, "%.2f%%") end
    if key == "memory" then return Measure(value, "%.2f") end
    if key == "when" then return Clock(row.from or math.max(0, value - 1)) .. "–" .. Clock(value) end
    return value and tostring(value) or "—"
end

local function PaintRows()
    if not ui.data or not ui.columns then return end
    local offset = math.floor(ui.scroll:GetValue() + .5)
    local memoryMax, cpuMax = ui.memoryMax or 0, ui.cpuMax or 0
    local usage = ui.mode ~= "spikes"
    for index, row in ipairs(ui.rows) do
        local item = index <= ui.visibleRows and ui.data[offset + index] or nil
        row.item = item
        row:SetShown(item ~= nil)
        if item then
            for column, spec in ipairs(ui.columns) do
                row.cells[column]:SetText(Format(spec[1], item[spec[1]], item))
            end
            if usage then
                local cpuFraction = cpuMax > 0 and (item.recent or 0) / cpuMax or 0
                local memoryFraction = memoryMax > 0 and (item.memory or 0) / memoryMax or 0
                Animate(row.cpuMeter, "width", (ui.columns[2][4] - 8) * cpuFraction)
                Animate(row.memoryMeter, "width", (ui.columns[3][4] - 8) * memoryFraction)
            end
        end
    end
end

local function Sort()
    local key, descending = ui.sort, ui.descending
    table.sort(ui.data, function(a, b)
        local left, right = a[key], b[key]
        if left == right then return a.name < b.name end
        if left == nil then return false elseif right == nil then return true end
        if descending then return left > right end
        return left < right
    end)
    for index, col in ipairs(ui.columns) do
        local heading = ui.heading[index]
        heading.text:SetText(col[2])
        heading.arrow:SetShown(col[1] == key)
        if T.Glyph then
            heading.arrow:SetRotation(descending and -math.pi / 2 or math.pi / 2)
        else
            heading.arrow:SetTexCoord(0, .5625, descending and 1 or 0, descending and 0 or 1)
        end
    end
    PaintRows()
end

local function PaintTable(record)
    local spikes = ui.mode == "spikes"
    if not spikes then
        local rows, summary = ns.Snapshot(false)
        ui.nextCPU = GetTime() + 2
        local seen, largest = {}, 0
        local hasCPU = summary.overall ~= nil
        for _, row in ipairs(rows) do
            seen[row.name] = true
            row.memory = ui.memoryByName[row.name]
            largest = math.max(largest, row.recent or 0)
            hasCPU = hasCPU or row.recent ~= nil or row.average ~= nil or row.peak ~= nil
        end
        for _, row in ipairs(ui.memory) do
            if not seen[row.name] then rows[#rows + 1] = row end
        end
        ui.data, ui.cpuMax = rows, largest
        ui.usageUpdated:SetText(L("CPU %s  ·  Память %s", "CPU %s  ·  Memory %s")
            :format(hasCPU and date("%H:%M:%S") or "—", ui.memoryUpdated or "—"))
        SetStat(1, L("FPS сейчас", "Current FPS"), Measure(summary.fps, "%.0f"))
        SetStat(2, L("Среднее за 60 кадров", "Addons · 60-frame avg"),
            Measure(summary.overall, L("%.3f мс", "%.3f ms")),
            L("Среднее суммарное время работы всех аддонов за последние 60 кадров.",
                "Average combined time spent by all addons over the last 60 frames."))
        SetStat(3, L("Доля кадра аддонов", "Addon share of frame"), Measure(summary.share, "%.2f%%"),
            L("Суммарное время аддонов в процентах от полной длительности кадра. Оба значения усреднены за последние 60 кадров.",
                "Combined addon time as a percentage of total frame duration. Both are averaged over the last 60 frames."))
        SetStat(4, L("Потеря FPS (оценка)", "Estimated FPS cost"), Measure(summary.fpsCost, "%.1f"),
            L("На сколько мог бы вырасти FPS, если вычесть среднее время работы аддонов из длительности кадра при текущем FPS.",
                "How much FPS might increase if average addon time were subtracted from the frame duration at current FPS."))
        SetStat(5, L("Память аддонов", "Addon memory"), Measure(ui.memoryTotal, L("%.2f МиБ", "%.2f MiB")),
            L("Сумма значений памяти Lua всех аддонов в таблице.", "Total Lua memory of all addons shown in the table."))
        ui.tableTitle:SetText(L("Нагрузка аддонов", "Addon usage"))
        ui.empty:SetText(L("Данные CPU и памяти недоступны.", "CPU and memory data unavailable."))
    else
        ui.data = {}
        local timeline = record and (ui.displayBackground and record.windows or record.timeline)
        for _, point in ipairs(timeline or {}) do
            local leader = point.contributors[1]
            ui.data[#ui.data + 1] = {
                when = point.bin, from = point.from, overall = point.overall,
                name = leader and leader.name or "—", five = point.total, ten = point.ten, fifty = point.fifty,
            }
        end
        ui.tableTitle:SetText(ui.displayBackground and L("Фоновые интервалы", "Background intervals")
            or L("Интервалы со спайками", "Spike intervals"))
        ui.empty:SetText(ui.displayBackground and L("Фоновых спайков пока нет.", "No background spikes yet.")
            or L("За замер нет кадров свыше 5 мс.", "The capture has no frames above 5 ms."))
    end
    ui.empty:SetShown(#ui.data == 0)
    local offset = math.max(0, #ui.data - ui.visibleRows)
    ui.scroll:SetMinMaxValues(0, offset)
    ui.scroll:SetValue(math.min(ui.scroll:GetValue(), offset))
    ui.scroll:SetShown(offset > 0)
    local count = ""
    if #ui.data > 0 then
        local format = spikes and L("Интервалов: %d", "Intervals: %d") or L("Аддонов: %d", "Addons: %d")
        count = format:format(#ui.data)
    end
    ui.summary:SetText(count)
    ui.summaryHover:SetShown(count ~= "")
    Sort()
end

local function ReadMemory(force)
    local maxAge
    if not force then maxAge = usageInterval end
    local rows, sampledAt, updated = ns.Snapshot(true, maxAge)
    local byName, total, largest = {}, 0, 0
    for _, row in ipairs(rows) do
        byName[row.name] = row.memory
        total = total + row.memory
        largest = math.max(largest, row.memory)
    end
    ui.memory, ui.memoryByName, ui.memoryMax = rows, byName, largest
    ui.memoryAt = sampledAt or GetTime()
    ui.memoryTotal = #rows > 0 and total or nil
    ui.memoryUpdated = ui.memoryTotal and updated or nil
end

local function StopUsageTimer()
    if not ui.usageTimer then return end
    ui.usageTimer:Cancel()
    ui.usageTimer = nil
end

local function ScheduleUsage()
    if not ui:IsVisible() or ui.mode == "spikes" then
        StopUsageTimer()
        return
    end
    if not ui.memoryAt or GetTime() - ui.memoryAt >= usageInterval then
        ReadMemory()
        StopUsageTimer()
    end
    if ui.usageTimer or not (C_Timer and C_Timer.NewTimer) then return end
    local delay = math.max(.1, ui.memoryAt + usageInterval - GetTime())
    local timer
    timer = C_Timer.NewTimer(delay, function()
        if ui.usageTimer ~= timer then return end
        ui.usageTimer = nil
        if not ui:IsVisible() or ui.mode == "spikes" then return end
        ScheduleUsage()
        PaintTable()
    end)
    ui.usageTimer = timer
end

local LayoutTable
local function Paint(refresh)
    if not ui or not ui:IsShown() then return end
    local capture, recording = ns.Capture()
    local ended = ui.recording and not recording
    if recording and ui.capture ~= capture then ui.source = "manual" end
    ui.capture, ui.recording = capture, recording

    if ui.mode ~= "spikes" then
        if refresh or ended or recording and GetTime() >= ui.nextCPU then PaintTable() end
        return
    end

    local background, monitoring = ns.BackgroundCapture()
    local showBackground = background ~= nil and ui.source ~= "manual"
    if ui.displayBackground ~= showBackground then
        HideTooltip(ui.tooltipOwner)
        ui.displayBackground = showBackground
        if ui.sort == "overall" then ui.sort = "when" end
        LayoutTable()
    end
    local chooseSource = background ~= nil and capture ~= nil
    ui.sourceLabel:SetShown(chooseSource)
    ui.sourceHover:SetShown(chooseSource)
    ui.backgroundView:SetShown(chooseSource)
    ui.captureView:SetShown(chooseSource)
    if chooseSource then
        Highlight(ui.backgroundView, showBackground)
        Highlight(ui.captureView, not showBackground)
    end
    local record = showBackground and background or capture
    if ui.record ~= record then
        ui.record, ui.selected, ui.follow, ui.selectedTime = record, 1, true, nil
    end
    Animate(ui.progress, "width", PaintProgress(record, recording, monitoring))
    PaintTable(record)
    PaintTimeline(record, recording)
end

ns.OnCaptureChanged = function()
    if ui and ui.mode == "spikes" and ui.displayBackground then
        local capture, recording = ns.Capture()
        if ui.capture == capture and ui.recording == recording then return end
    end
    Paint(false)
end

ns.OnBackgroundTimelineChanged = function(sampleOnly)
    if ui and ui.mode == "spikes" and (not sampleOnly or ui.displayBackground) then Paint(false) end
end

LayoutTable = function()
    local spikes = ui.mode == "spikes"
    local base = spikes and -380 or -153
    ui.table:ClearAllPoints()
    ui.table:SetPoint("TOPLEFT", 16, base)
    ui.visibleRows = spikes and 6 or 15
    ui.table:SetHeight(52 + ui.visibleRows * rowHeight)
    ui.columns = Columns(ui.mode)
    for index, heading in ipairs(ui.heading) do
        local spec = ui.columns[index]
        heading:SetShown(spec ~= nil)
        if spec then
            heading:ClearAllPoints()
            heading:SetPoint("TOPLEFT", ui.table, "TOPLEFT", spec[3] + 6, -28)
            heading:SetWidth(spec[4])
            heading.text:SetJustifyH(index == 1 and "LEFT" or "RIGHT")
        end
        for rowIndex, row in ipairs(ui.rows) do
            local label, hover = row.cells[index], row.hover[index]
            label:SetShown(spec ~= nil and rowIndex <= ui.visibleRows)
            hover:SetShown(spec ~= nil and spec[1] ~= "name" and rowIndex <= ui.visibleRows)
            if spec then
                label:ClearAllPoints()
                label:SetPoint("LEFT", row, "LEFT", spec[3] + 6, 0)
                label:SetWidth(spec[4] - 8)
                label:SetJustifyH(index == 1 and "LEFT" or "RIGHT")
                hover:ClearAllPoints()
                hover:SetPoint("LEFT", row, "LEFT", spec[3] + 6, 0)
                hover:SetSize(spec[4] - 8, rowHeight)
            end
        end
    end
    for _, row in ipairs(ui.rows) do
        row:EnableMouse(spikes)
        if not spikes then
            row.cpuMeter:SetPoint("BOTTOMLEFT", ui.columns[2][3] + 6, 3)
            row.memoryMeter:SetPoint("BOTTOMLEFT", ui.columns[3][3] + 6, 3)
        else
            ui.motion[row.cpuMeter], ui.motion[row.memoryMeter] = nil, nil
            SetDimension(row.cpuMeter, "width", 0)
            SetDimension(row.memoryMeter, "width", 0)
        end
    end
end

local function Switch(mode)
    HideTooltip(ui.tooltipOwner)
    ui.mode = mode
    local spikes = mode == "spikes"
    ui.sort = spikes and "when" or mode == "memory" and "memory" or "recent"
    ui.descending = true
    for index, tab in ipairs(ui.tabs) do Highlight(tab, views[index] == mode) end
    ui.chart:SetShown(spikes)
    ui.details:SetShown(spikes)
    ui.start:SetShown(spikes)
    ui.duration:SetShown(spikes)
    ui.durationLabel:SetShown(spikes)
    ui.durationHover:SetShown(spikes)
    if not spikes then
        ui.sourceLabel:Hide()
        ui.sourceHover:Hide()
        ui.backgroundView:Hide()
        ui.captureView:Hide()
        ui.track:Hide()
        if W then T:ClosePicker(ui.duration) end
    end
    ui.refresh:SetShown(not spikes)
    ui.usageUpdated:SetShown(not spikes)
    ui.usageUpdatedHover:SetShown(not spikes)
    ui.status.fields[5]:SetShown(not spikes)
    local spacing = spikes and 218 or 174
    for index, field in ipairs(ui.status.fields) do
        field:ClearAllPoints()
        field:SetPoint("TOPLEFT", 12 + (index - 1) * spacing, 0)
        field:SetWidth(spacing - 12)
    end
    ui.data = nil
    ui.scroll:SetValue(0)
    LayoutTable()
    ScheduleUsage()
    Paint(true)
end

local function BuildTable()
    local tableFrame = CreateFrame("Frame", nil, ui)
    tableFrame:SetWidth(884)
    tableFrame:EnableMouseWheel(true)
    ui.table = tableFrame
    ui.tableTitle = Label(tableFrame, "", 15, T.brass, "display")
    ui.tableTitle:SetPoint("TOPLEFT", 0, -3)
    ui.summary = Label(tableFrame, "", 11, T.muted)
    ui.summary:SetPoint("TOPRIGHT", -14, -7)
    ui.summaryHover = HoverRegion(tableFrame, ui.summary)
    BindTooltip(ui.summaryHover, function(self)
        if ui.mode ~= "spikes" then
            ShowTooltip(self, L("Аддоны в таблице", "Addons in table"),
                L("Число загруженных аддонов в списке, включая строки за пределами видимой области.",
                    "Number of loaded addons in the list, including rows outside the visible area."))
        else
            ShowTooltip(self, L("Интервалы в таблице", "Intervals in table"),
                L("Число интервалов со спайками в выбранном отчете.", "Number of intervals with spikes in the selected report."))
        end
    end)
    ui.empty = Label(tableFrame, "", 12, T.muted)
    ui.empty:SetPoint("TOPLEFT", 6, -70)
    ui.heading, ui.rows = {}, {}
    for index = 1, 6 do
        local button = Button(tableFrame, "", function()
            local key = ui.columns[index][1]
            if ui.sort == key then ui.descending = not ui.descending else ui.sort, ui.descending = key, key ~= "name" end
            ui.scroll:SetValue(0)
            Sort()
        end)
        if T.Glyph then button.arrow = T:Glyph(button, "chevron", 9, T.brass)
        else
            button.arrow = button:CreateTexture(nil, "OVERLAY")
            button.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
            button.arrow:SetSize(9, 8)
        end
        button.arrow:SetPoint("RIGHT", -6, 0)
        button.text:ClearAllPoints()
        button.text:SetPoint("LEFT", 6, 0)
        button.text:SetPoint("RIGHT", -18, 0)
        BindTooltip(button, function(self)
            local column = ui.columns[index]
            if not column then return end
            local detail = ColumnDescription(column[1])
            local sort = L("Нажми для сортировки по этому столбцу.", "Click to sort by this column.")
            if detail then ShowTooltip(self, column[2], detail, sort)
            else ShowTooltip(self, column[2], sort) end
        end)
        ui.heading[index] = button
    end
    for index = 1, 15 do
        local row = CreateFrame("Button", nil, tableFrame)
        row:SetSize(868, rowHeight)
        row:SetPoint("TOPLEFT", 1, -52 - (index - 1) * rowHeight)
        local tint = TintBlock(row, { .65, .52, .32, index % 2 == 0 and .15 or .07 }, "BACKGROUND")
        tint:SetAllPoints()
        row:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        row:SetScript("OnClick", function(self)
            if ui.mode == "spikes" and self.item then
                SelectSlot(math.ceil((self.item.when - ui.origin) / ui.stride))
            end
        end)
        row.cells, row.hover = {}, {}
        for index = 1, 6 do
            row.cells[index] = Label(row, "", 11)
            local hover = HoverRegion(row)
            row.hover[index] = hover
            BindTooltip(hover, function(self)
                local column = ui.columns[index]
                if not (row.item and column and column[1] ~= "name") then return end
                local detail = ColumnDescription(column[1])
                if detail then ShowTooltip(self, column[2], detail) end
            end)
        end
        row.cpuMeter = TintBlock(row, shades[1])
        row.cpuMeter:SetHeight(3)
        SetDimension(row.cpuMeter, "width", 0)
        row.memoryMeter = TintBlock(row, T.accent)
        row.memoryMeter:SetHeight(3)
        SetDimension(row.memoryMeter, "width", 0)
        ui.rows[index] = row
    end
    local scroll = CreateFrame("Slider", nil, tableFrame)
    scroll:SetOrientation("VERTICAL")
    scroll:SetWidth(9)
    scroll:SetPoint("TOPRIGHT", -2, -53)
    scroll:SetPoint("BOTTOMRIGHT", -2, -18)
    scroll:SetMinMaxValues(0, 0)
    scroll:SetValueStep(1)
    scroll:SetObeyStepOnDrag(true)
    if W then T:SkinScrollBar(scroll, 7, 23)
    else
        local art = TintBlock(scroll, T.accent)
        art:SetSize(7, 23)
        scroll:SetThumbTexture(art)
    end
    scroll:SetScript("OnValueChanged", PaintRows)
    Describe(scroll, L("Прокрутка", "Scroll"),
        L("Перетащи ползунок или прокрути колесо мыши над таблицей, чтобы увидеть остальные строки.",
            "Drag the thumb or use the mouse wheel over the table to see more rows."))
    tableFrame:SetScript("OnMouseWheel", function(_, delta)
        local _, maximum = scroll:GetMinMaxValues()
        scroll:SetValue(math.max(0, math.min(maximum, scroll:GetValue() - delta * 3)))
    end)
    ui.scroll = scroll
end

local function ShowSpikeHelp(owner)
    ShowTooltip(owner, L("Как читать спайки", "How to read spikes"),
        L("Кадр со спайком попадает в отчет, когда работа аддонов за этот кадр заняла больше 5 мс.",
            "A frame is counted as a spike when addon work takes more than 5 ms in that frame."),
        L("По горизонтали — время с начала сбора. Высота столбца — число кадров или отметок за интервал.",
            "The horizontal axis is time since collection started. Bar height is the count within that interval."),
        L("Фон считает кадры, где аддоны вместе заняли больше 5 мс. В деталях видны общий счетчик и аддоны, которые сами превысили порог.",
            "Background counts frames where addons together took more than 5 ms. Details show the combined count and addons that crossed the threshold on their own."),
        L("Ручной замер считает отметки отдельных аддонов. За один кадр отметки могут получить несколько аддонов. Цвет показывает диапазон 5–10, 10–50 или свыше 50 мс.",
            "Timed captures count marks per addon. Several addons can contribute in one frame. Colors show 5–10, 10–50, or over 50 ms."),
        L("Нажми столбец или строку, чтобы увидеть вклад аддонов. В таблице отметки >50 мс также входят в >10 и >5 мс.",
            "Click a bar or row to see addon contributions. In the table, marks over 50 ms also count toward over 10 and over 5 ms."))
end

local function BuildChart()
    local chart, details = Panel(ui), Panel(ui)
    ui.chart, ui.details = chart, details
    chart:SetPoint("TOPLEFT", 16, -146)
    chart:SetSize(639, 222)
    details:SetPoint("TOPLEFT", chart, "TOPRIGHT", 12, 0)
    details:SetPoint("BOTTOMRIGHT", ui, "TOPRIGHT", -16, -368)
    local chartTitle = Label(chart, L("Спайки по времени", "Spikes over time"), 16, T.brass, "display")
    chartTitle:SetPoint("TOPLEFT", 12, -12)
    BindTooltip(HoverRegion(chart, chartTitle), ShowSpikeHelp)
    local help = Button(chart, L("Как читать", "How to read"), ShowSpikeHelp)
    help:SetSize(84, 22)
    help:SetPoint("TOPRIGHT", -12, -8)
    BindTooltip(help, ShowSpikeHelp)
    ui.chartMeasure = Label(chart, "", 11, T.muted)
    ui.chartMeasure:SetPoint("RIGHT", help, "LEFT", -9, 0)
    BindTooltip(HoverRegion(chart, ui.chartMeasure), ShowSpikeHelp)
    local detailLabel = Label(details, L("Выбранный интервал", "Selected interval"), 11, T.muted)
    detailLabel:SetPoint("TOPLEFT", 12, -14)
    ui.detailTime = Label(details, "", 17, T.accent, "display")
    ui.detailTime:SetPoint("TOPLEFT", 12, -37)
    ui.detailTime:SetPoint("TOPRIGHT", -12, -37)
    local function ExplainInterval(owner)
        ShowTooltip(owner, L("Выбранный интервал", "Selected interval"), columnDescriptions.when,
            L("Выбери другой интервал на графике или в таблице.", "Select another interval on the chart or in the table."))
    end
    BindTooltip(HoverRegion(details, detailLabel), ExplainInterval)
    BindTooltip(HoverRegion(details, ui.detailTime), ExplainInterval)
    ui.detailEmpty = Label(details, L("Отметок нет", "No marks"), 11, T.muted)
    ui.detailEmpty:SetPoint("TOPLEFT", 12, -74)
    ui.detailRows = {}
    for index = 1, 6 do
        local name, count = Label(details, "", 11), Label(details, "", 11, T.accent)
        name:SetPoint("TOPLEFT", 12, -74 - (index - 1) * 20)
        name:SetWidth(162)
        count:SetPoint("TOPRIGHT", -12, -74 - (index - 1) * 20)
        local hover = HoverRegion(details, count)
        BindTooltip(hover, function(self)
            local combined = ui.displayBackground and index == 1
            ShowTooltip(self, L("За выбранный интервал", "In the selected interval"),
                combined and columnDescriptions.overall or L("Сколько раз этот аддон превысил 5 мс за выбранный интервал.",
                    "Number of times this addon exceeded 5 ms in the selected interval."))
        end)
        ui.detailRows[index] = { name = name, count = count, hover = hover }
    end
    local plot = CreateFrame("Frame", nil, chart)
    plot:SetPoint("TOPLEFT", 40, -44)
    plot:SetSize(586, 144)
    ui.plot, ui.bars, ui.grid, ui.times = plot, {}, {}, {}
    for index = 1, 3 do
        local line = TintBlock(plot, { .75, .68, .57, .19 }, "BACKGROUND")
        line:SetPoint("TOPLEFT", 0, -(index - 1) * 62)
        line:SetSize(586, 1)
        local tick = Label(plot, "", 10, T.muted)
        tick:SetPoint("RIGHT", line, "LEFT", -7, 0)
        BindTooltip(HoverRegion(plot, tick), ShowSpikeHelp)
        ui.grid[index] = tick
    end
    for index = 1, 4 do
        local tick = Label(plot, "", 10, T.muted)
        tick:SetPoint(index == 4 and "BOTTOMRIGHT" or "BOTTOMLEFT", (index == 4 and 0 or (index - 1) * (586 / 3)), 2)
        Describe(HoverRegion(plot, tick), L("Ось времени", "Time axis"),
            L("Время с начала сбора или замера в минутах и секундах.",
                "Minutes and seconds since monitoring or capture started."))
        ui.times[index] = tick
    end
    for index = 1, 40 do
        ui.bars[index] = MakeBar(plot, index)
    end
    ui.plotEmpty = Label(plot, L("Запусти замер, чтобы увидеть спайки.", "Start a capture to see frame spikes."), 12, T.muted)
    ui.plotEmpty:SetPoint("CENTER", 0, 14)
    local legend = { "5–10 " .. L("мс", "ms"), "10–50 " .. L("мс", "ms"), L("Свыше 50 мс", "Over 50 ms") }
    ui.legend = {}
    local x = 41
    for index, value in ipairs(legend) do
        local marker = TintBlock(chart, shades[index])
        marker:SetPoint("BOTTOMLEFT", x, 13)
        marker:SetSize(7, 7)
        local label = Label(chart, value, 10, T.muted)
        label:SetPoint("LEFT", marker, "RIGHT", 5, 0)
        local hover = HoverRegion(chart)
        hover:SetPoint("TOPLEFT", marker, "TOPLEFT", 0, 2)
        hover:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 0, -2)
        BindTooltip(hover, function(self)
            ShowTooltip(self, label:GetText(), ui.displayBackground and columnDescriptions.overall
                or L("В этот цвет окрашены отметки, где отдельный аддон потратил указанное время за кадр.",
                    "This color marks frames where an individual addon spent this amount of time."))
        end)
        ui.legend[index] = { marker = marker, label = label, text = value, hover = hover }
        x = x + 86
    end
end

local function RefreshUsage()
    ReadMemory(true)
    StopUsageTimer()
    ScheduleUsage()
    Paint(true)
end

local function BuildWindow()
    local frame = CreateFrame("Frame", "Sintezza_PerfWindow", UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    ui = frame
    frame.motion, frame.memory, frame.memoryByName = {}, {}, {}
    frame.nextCPU, frame.stick = 0, 0
    frame.slots, frame.selected, frame.stride, frame.seconds = {}, 1, 1, 30
    UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()

    local header
    if W then
        T:WindowSurface(frame)
        header = W:WindowHeader(frame, { title = "Sintezza Perf", titleSize = 25, icon = icon, height = 53 })
    else
        Backdrop(frame, T.bg, T.line)
        header = Panel(frame)
        header:SetPoint("TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", -1, -1)
        header:SetHeight(53)
        local image = header:CreateTexture(nil, "ARTWORK")
        image:SetPoint("LEFT", 10, 0)
        image:SetSize(27, 27)
        image:SetTexture(icon)
        header.title = Label(header, "Sintezza Perf", 24)
        header.title:SetPoint("LEFT", image, "RIGHT", 9, 0)
        header.close = Button(header, "×", function() frame:Hide() end)
        header.close:SetWidth(26)
        header.close:SetPoint("RIGHT", -9, 0)
    end
    if settingsCategory and Settings.OpenToCategory then
        local settings = Button(header, L("Настройки", "Settings"), function()
            if InCombatLockdown() then
                print(L("Настройки Sintezza Perf можно открыть после боя.", "You can open Sintezza Perf settings after combat."))
                return
            end
            frame:Hide()
            Settings.OpenToCategory(settingsCategory:GetID())
        end)
        settings:SetWidth(100)
        settings:SetPoint("RIGHT", header.close, "LEFT", -4, 0)
        header.title:SetPoint("RIGHT", settings, "LEFT", -8, 0)
        Describe(settings, L("Настройки", "Settings"),
            L("Открывает настройки фонового сбора и значка у миникарты.",
                "Open settings for background monitoring and the minimap icon."))
    end
    Describe(header.close, L("Закрыть", "Close"),
        L("Скрывает окно. Если идет ручной замер или фоновый сбор, он продолжится.",
            "Hide the window. Any active capture or background monitoring continues."))
    header:EnableMouse(true)
    header:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then frame:StartMoving() end end)
    header:SetScript("OnMouseUp", function() frame:StopMovingOrSizing() end)

    frame.tabs = {}
    local tabDescriptions = {
        L("Нагрузка аддонов. По умолчанию таблица отсортирована по CPU за последние кадры.",
            "Addon usage, sorted by recent CPU time by default."),
        L("Нагрузка аддонов. По умолчанию таблица отсортирована по расходу памяти Lua.",
            "Addon usage, sorted by Lua memory usage by default."),
        L("График и таблица кадров, в которых аддоны превысили пороги времени работы.",
            "Chart and table of frames in which addon work exceeded time thresholds."),
    }
    for index, view in ipairs(views) do
        local tab = Button(frame, titles[index], function() Switch(view) end)
        tab:SetSize(80, 28)
        tab:SetPoint("TOPLEFT", 16 + (index - 1) * 85, -65)
        Describe(tab, titles[index], tabDescriptions[index])
        frame.tabs[index] = tab
    end
    frame.start = Button(frame, L("Начать замер", "Start capture"), function()
        local _, recording = ns.Capture()
        if recording then ns.Stop() elseif ns.Available() then ns.Watch(tostring(db.duration), true) end
    end, true)
    frame.start:SetSize(131, 28)
    frame.start:SetPoint("TOPRIGHT", -16, -65)
    BindTooltip(frame.start, function(self)
        ShowTooltip(self, self.text:GetText(), ui.recording
            and L("Завершает текущий замер и оставляет собранные данные в отчете.",
                "End the current capture and keep the results in the report.")
            or L("Начинает запись спайков на выбранное время.", "Record spikes for the selected duration."))
    end)
    frame.duration = Button(frame, "", function(self)
        if W then
            local entries = {}
            for _, value in ipairs(intervals) do entries[#entries + 1] = { value = value, label = value .. " " .. L("с", "s") } end
            T:OpenPicker(self, entries, db.duration, function(value)
                db.duration = value
                self.text:SetText(db.duration .. " " .. L("с", "s"))
            end)
        else
            local index = 1
            for i, value in ipairs(intervals) do if value == db.duration then index = i; break end end
            db.duration = intervals[index % #intervals + 1]
            self.text:SetText(db.duration .. " " .. L("с", "s"))
        end
    end)
    frame.duration:SetSize(62, 28)
    frame.duration:SetPoint("TOPRIGHT", frame.start, "TOPLEFT", -7, 0)
    frame.duration.text:SetText(db.duration .. " " .. L("с", "s"))
    frame.durationLabel = Label(frame, L("Ручной замер", "Timed capture"), 11, T.muted)
    frame.durationLabel:SetPoint("RIGHT", frame.duration, "LEFT", -8, 0)
    local durationTitle = L("Длительность замера", "Capture duration")
    local durationHelp = L("Время, через которое ручной замер завершится автоматически.",
        "How long a timed capture runs before stopping automatically.")
    Describe(frame.duration, durationTitle, durationHelp)
    local durationHover = HoverRegion(frame, frame.durationLabel)
    Describe(durationHover, durationTitle, durationHelp)
    frame.durationHover = durationHover
    frame.refresh = Button(frame, L("Обновить", "Refresh"), RefreshUsage)
    frame.refresh:SetSize(131, 28)
    frame.refresh:SetPoint("TOPRIGHT", -16, -65)
    Describe(frame.refresh, L("Обновить", "Refresh"),
        L("Сразу обновляет CPU и делает новый снимок памяти Lua.", "Read CPU counters and take a fresh Lua memory snapshot now."))
    frame.usageUpdated = Label(frame, "", 11, T.muted)
    frame.usageUpdated:SetPoint("RIGHT", frame.refresh, "LEFT", -12, 0)
    frame.usageUpdatedHover = HoverRegion(frame, frame.usageUpdated)
    Describe(frame.usageUpdatedHover, L("Последнее обновление", "Last updated"),
        L("Время последнего чтения CPU и снимка памяти. Обе метрики обновляются раз в минуту, пока видна таблица. Во время ручного замера CPU обновляется примерно раз в две секунды.",
            "Time of the last CPU reading and memory snapshot. Both metrics refresh once a minute while the table is visible. CPU refreshes about every two seconds during a timed capture."))
    frame.sourceLabel = Label(frame, L("График", "Chart"), 11, T.muted)
    frame.sourceLabel:SetPoint("LEFT", frame.tabs[3], "RIGHT", 16, 0)
    frame.sourceHover = HoverRegion(frame, frame.sourceLabel)
    Describe(frame.sourceHover, L("Источник данных", "Data source"),
        L("Выбор между фоновым сбором и ручным замером меняет график и таблицу интервалов.",
            "Switch between background monitoring and a timed capture for the chart and interval table."))
    frame.backgroundView = Button(frame, L("Фон", "Background"), function()
        frame.source = "background"
        Paint(false)
    end)
    frame.backgroundView:SetSize(86, 28)
    frame.backgroundView:SetPoint("LEFT", frame.sourceLabel, "RIGHT", 8, 0)
    Describe(frame.backgroundView, L("Фоновый сбор", "Background monitoring"),
        L("Показывает последние сохраненные интервалы фонового сбора.", "Show the latest recorded background intervals."))
    frame.captureView = Button(frame, L("Замер", "Capture"), function()
        frame.source = "manual"
        Paint(false)
    end)
    frame.captureView:SetSize(66, 28)
    frame.captureView:SetPoint("LEFT", frame.backgroundView, "RIGHT", 5, 0)
    Describe(frame.captureView, L("Ручной замер", "Timed capture"),
        L("Показывает текущий или последний завершенный ручной замер.", "Show the active or most recently completed timed capture."))

    local status = Panel(frame)
    frame.status = status
    status:SetPoint("TOPLEFT", 16, -105)
    status:SetPoint("TOPRIGHT", -16, -105)
    status:SetHeight(36)
    status.fields = {}
    for index = 1, 5 do
        local field = CreateFrame("Frame", nil, status)
        field:SetHeight(36)
        field.label = Label(field, "", 10, T.muted)
        field.label:SetPoint("TOPLEFT", 0, -4)
        field.label:SetPoint("TOPRIGHT", 0, -4)
        field.value = Label(field, "", 13)
        field.value:SetPoint("BOTTOMLEFT", 0, 4)
        BindTooltip(HoverRegion(field, field), function(self)
            if field.description then ShowTooltip(self, field.label:GetText(), field.description) end
        end)
        status.fields[index] = field
    end
    frame.track = CreateFrame("Frame", nil, status.fields[2])
    frame.track:SetPoint("BOTTOMLEFT", 57, 9)
    frame.track:SetSize(112, 3)
    TintBlock(frame.track, { .60, .49, .35, .23 }, "BACKGROUND"):SetAllPoints()
    frame.progress = TintBlock(frame.track, T.accent)
    frame.progress:SetPoint("LEFT")
    frame.progress:SetHeight(3)
    SetDimension(frame.progress, "width", 0)
    BuildChart()
    BuildTable()

    frame:SetScript("OnShow", function(self)
        self:SetScale(math.min(1, math.max(.35, math.min((UIParent:GetWidth() - 12) / width,
            (UIParent:GetHeight() - 12) / height))))
        ScheduleUsage()
        Paint(true)
    end)
    frame:SetScript("OnHide", function(self)
        HideTooltip(self.tooltipOwner)
        StopUsageTimer()
        self:StopMovingOrSizing()
        self:SetScript("OnUpdate", nil)
        for region, job in pairs(self.motion) do SetDimension(region, job.axis, job.target) end
        self.motion = {}
        if W then T:ClosePicker(self.duration) end
    end)
    Switch("cpu")
end

function ns.Toggle()
    if not ui then BuildWindow() end
    if ui:IsShown() then ui:Hide() else ui:Show() end
end

local function CreateLauncher()
    if not Minimap then return end
    if shared then
        launcher = shared:CreateMinimapButton(addon, icon, db.minimap, function(_, button)
            if button == "RightButton" then ns.ToggleMinimap() else ns.Toggle() end
        end, function(tip)
            tip:AddLine("Sintezza Perf")
            tip:AddLine(L("ЛКМ открывает окно. ПКМ скрывает кнопку.", "Left-click to open. Right-click to hide."))
        end)
        return
    end
    launcher = CreateFrame("Button", addon .. "MinimapButton", Minimap)
    launcher:SetSize(28, 28)
    launcher:SetPoint("BOTTOMLEFT", 2, 1)
    launcher:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    launcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    launcher:SetNormalTexture(icon)
    launcher:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    launcher:SetScript("OnClick", function(_, button)
        if button == "RightButton" then ns.ToggleMinimap() else ns.Toggle() end
    end)
    launcher:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Sintezza Perf")
        GameTooltip:AddLine(L("ЛКМ открывает окно. ПКМ скрывает кнопку.", "Left-click to open. Right-click to hide."))
        GameTooltip:Show()
    end)
    launcher:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    launcher:SetShown(not db.minimap.hide)
end

local function MinimapShown()
    return not db.minimap.hide
end

local function SetMinimapShown(shown)
    db.minimap.hide = not shown
    if not launcher then CreateLauncher()
    elseif shown then launcher:Show()
    else launcher:Hide() end
    if refreshMinimapSetting then refreshMinimapSetting() end
end

function ns.ToggleMinimap()
    SetMinimapShown(not MinimapShown())
end

local function SettingsToggle(panel, label, getValue, setValue)
    if W then
        local toggle = W:Toggle(panel, label, getValue, setValue, nil, true, "inline")
        toggle:SetSize(262, 26)
        return toggle, function() toggle:Refresh(false) end
    end

    local toggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    toggle:SetSize(26, 26)
    local text = Label(panel, label, 12)
    text:SetPoint("LEFT", toggle, "RIGHT", 4, 0)
    toggle:SetScript("OnClick", function(self) setValue(self:GetChecked() == true) end)
    return toggle, function() toggle:SetChecked(getValue()) end
end

local function BuildSettings(panel)
    local heading = Label(panel, "Sintezza Perf", 18, T.text, "display")
    heading:SetPoint("TOPLEFT", 22, -22)
    heading:SetPoint("TOPRIGHT", -22, -22)

    local minimapToggle, syncMinimap = SettingsToggle(panel, L("Значок у миникарты", "Minimap icon"),
        MinimapShown, SetMinimapShown)
    minimapToggle:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -14)
    Describe(minimapToggle, L("Значок у миникарты", "Minimap icon"),
        L("Показывает кнопку открытия окна рядом с миникартой.", "Show the button that opens the window next to the minimap."))

    local reportTitle = Label(panel, L("Последние спайки", "Recent spikes"), 14, T.text, "display")
    reportTitle:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -128)
    reportTitle:SetPoint("TOPRIGHT", heading, "BOTTOMRIGHT", 0, -128)

    local report = Label(panel, "", 12)
    report:SetPoint("TOPLEFT", reportTitle, "BOTTOMLEFT", 0, -20)
    report:SetPoint("TOPRIGHT", reportTitle, "BOTTOMRIGHT", 0, -20)
    report:SetJustifyV("TOP")
    report:SetWordWrap(true)
    report:SetSpacing(5)
    Describe(HoverRegion(panel, report), L("Последние спайки", "Recent spikes"),
        L("Последние шесть фоновых интервалов со спайками. В каждой строке видны общий счетчик и вклад отдельных аддонов.",
            "The latest six background intervals with spikes. Each row shows the combined count and individual addon contributions."))

    local function RefreshReport(sample)
        report:SetText(table.concat(ns.BackgroundReport(sample), "\n"))
    end

    local syncBackground
    local function Refresh(sample)
        syncBackground()
        RefreshReport(sample)
    end

    local function SetEnabled(enabled)
        if ns.SetBackgroundEnabled(enabled) then return end
        Refresh(false)
        report:SetText(L("Фоновый сбор недоступен.", "Background monitoring unavailable."))
    end

    local backgroundToggle
    backgroundToggle, syncBackground = SettingsToggle(panel, L("Собирать спайки в фоне", "Monitor spikes in the background"),
        ns.BackgroundEnabled, SetEnabled)
    backgroundToggle:SetPoint("TOPLEFT", minimapToggle, "BOTTOMLEFT", 0, -6)
    Describe(backgroundToggle, L("Фоновый сбор", "Background monitoring"),
        L("Проверяет счетчик спайков раз в пять секунд, даже при закрытом окне.",
            "Check the spike counter every five seconds, even with the window closed."))

    local detail = Label(panel, L("Сбор работает при закрытом окне. История хранится до выхода или /reload.",
        "Monitoring continues with the window closed. History lasts until logout or /reload."), 11, T.muted)
    detail:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -81)
    detail:SetPoint("TOPRIGHT", heading, "BOTTOMRIGHT", 0, -81)
    detail:SetWordWrap(true)

    local refresh = Button(panel, L("Обновить", "Refresh"), function() RefreshReport(true) end)
    refresh:SetSize(106, 24)
    refresh:SetPoint("TOPRIGHT", reportTitle, "TOPRIGHT", 0, 3)
    Describe(refresh, L("Обновить отчет", "Refresh report"),
        L("Обновляет список интервалов. Пока сбор идет, сразу читает счетчики WoW.",
            "Refresh the interval list and read the WoW counters immediately if monitoring is active."))

    local function Activate()
        refreshMinimapSetting = syncMinimap
        ns.OnBackgroundChanged = Refresh
        ns.OnBackgroundSample = RefreshReport
        syncMinimap()
        Refresh(true)
    end
    panel:SetScript("OnShow", Activate)
    panel:SetScript("OnHide", function()
        refreshMinimapSetting = nil
        ns.OnBackgroundChanged = nil
        ns.OnBackgroundSample = nil
    end)
    Activate()
end

local function RegisterSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    panel:Hide()
    panel:SetScript("OnShow", BuildSettings)
    panel.OnDefault = function()
        if not MinimapShown() then SetMinimapShown(true) end
        if ns.BackgroundEnabled() then ns.SetBackgroundEnabled(false) end
    end
    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Sintezza Perf")
    Settings.RegisterAddOnCategory(settingsCategory)
end

local startup = CreateFrame("Frame")
startup:RegisterEvent("ADDON_LOADED")
startup:SetScript("OnEvent", function(self, event, name)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent(event)
        ns.InitBackground(db)
        if ns.OnBackgroundTimelineChanged then ns.OnBackgroundTimelineChanged() end
        return
    end
    if name ~= addon then return end
    self:UnregisterEvent("ADDON_LOADED")
    if type(Sintezza_PerfDB) ~= "table" then Sintezza_PerfDB = {} end
    db = Sintezza_PerfDB
    if type(db.minimap) ~= "table" then db.minimap = {} end
    local validDuration
    for _, duration in ipairs(intervals) do if db.duration == duration then validDuration = true end end
    if not validDuration then db.duration = 30 end
    CreateLauncher()
    ns.InitBackground(db)
    if ns.BackgroundEnabled() and not ns.BackgroundCapture() and not IsLoggedIn() then
        self:RegisterEvent("PLAYER_LOGIN")
    end
    RegisterSettings()
end)
