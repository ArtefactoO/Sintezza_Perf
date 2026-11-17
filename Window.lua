local addon, ns = ...
local L, shared = ns.Text, Sintezza_Theme
local T = shared and shared:ForAddon() or {
    bg = { .098, .071, .055, 1 }, panel = { .17, .118, .09, 1 }, input = { .106, .075, .059, 1 },
    line = { .55, .37, .26, 1 }, lineSoft = { .35, .23, .18, 1 }, text = { .98, .91, .85, 1 },
    muted = { .82, .71, .64, 1 }, accent = { .91, .65, .48, 1 }, accentDim = { .30, .18, .12, 1 },
}
local W = shared and shared:CreateWidgets(T)
local width, height, rowHeight = 1000, 760, 27
local ui, db, launcher, category, dialog, prefs, startupWindow, choicePopup
local Paint, Schedule, OpenDialog, Switch
local icon = "Interface\\AddOns\\" .. addon .. "\\Media\\Icon"
local teal = W and T.brass or { .52, .74, .70, 1 }
if shared and shared.NewWindowPreferences and shared.RegisterGlobalWindowPreferences then
    prefs = shared:NewWindowPreferences(function() return db end)
    shared:RegisterGlobalWindowPreferences("Sintezza Perf", prefs)
end
local function Color(region, method, color, alpha)
    if shared then shared:Tint(region, method, color, alpha)
    else region[method](region, color[1], color[2], color[3], alpha or color[4] or 1) end
end
local function Surface(frame, color, border)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    Color(frame, "SetBackdropColor", color or T.panel)
    Color(frame, "SetBackdropBorderColor", border or T.lineSoft)
end
local function StyledSurface(parent, name, role)
    if W and W.Surface then return W:Surface(parent, name, role) end
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    if W then
        if role=="window" then T:WindowSurface(f)
        elseif role=="sidebar" then T:SidebarSurface(f) else T:PanelSurface(f) end
    else Surface(f,role=="window"and T.bg or nil,role=="window"and T.line or nil) end
    return f
end
local function Panel(parent,name)return StyledSurface(parent,name,"panel")end
local function Window(parent,name)return StyledSurface(parent,name,"window")end
local function Sidebar(parent,name)return StyledSurface(parent,name,"sidebar")end
local function BindDialog(frame)
    if prefs then prefs:Bind(frame,{defaultLayer="FULLSCREEN_DIALOG"})
    elseif ui then frame:SetScale(ui:GetScale()) end
end
local function DataTexture(parent,role,layer)
    if W and W.DataTexture then return W:DataTexture(parent,role,layer) end
    local texture=parent:CreateTexture(nil,layer or "ARTWORK")
    Color(texture,"SetColorTexture",role=="brass"and teal or T[role]);return texture
end
local function DataLine(parent,role,thickness)
    if W and W.DataLine then return W:DataLine(parent,role,thickness or 2) end
    if not parent.CreateLine then return end
    local line=parent:CreateLine(nil,"ARTWORK");line:SetThickness(thickness or 2)
    Color(line,"SetColorTexture",role=="brass"and teal or T[role]);return line
end
local function Progress(parent)
    if W and W.ProgressBar then return W:ProgressBar(parent) end
    local bar=CreateFrame("StatusBar",nil,parent);bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8");bar:SetStatusBarColor(unpack(teal));return bar
end
local function Scroll(parent,body,nativeTemplate)
    if W and W.ScrollFrame then
        local scroll,_,bar=W:ScrollFrame(parent,body,45)
        bar:SetPoint("TOPLEFT",scroll,"TOPRIGHT",4,0);bar:SetPoint("BOTTOMLEFT",scroll,"BOTTOMRIGHT",4,0)
        return scroll
    end
    local scroll=CreateFrame("ScrollFrame",nil,parent,nativeTemplate and "UIPanelScrollFrameTemplate"or nil)
    body:SetParent(scroll);scroll:SetScrollChild(body);return scroll
end
local function Label(parent, text, size, color, role)
    if W then return W:Label(parent, text, size or 12, color or T.text, role) end
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local path = f:GetFont()
    f:SetFont(path or "Fonts\\FRIZQT__.TTF", size or 12, "")
    f:SetTextColor(unpack(color or T.text)); f:SetText(text); f:SetJustifyH("LEFT")
    return f
end
local function Tip(owner, title, text)
    if choicePopup and choicePopup:IsShown() then return end
    if W and W.Tooltip then return W:Tooltip(owner,title,text) end
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(title)
    GameTooltip:AddLine(text, .94, .90, .83, true)
    GameTooltip:Show()
end
local function HideTip(owner)
    if shared and shared.HideTooltip then shared:HideTooltip(owner)
    elseif GameTooltip and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end
local function Describe(owner, title, text)
    owner.perfTooltip = { title, text }
    owner:HookScript("OnEnter", function(self)
        local value = self.perfTooltip
        Tip(self, type(value[1]) == "function" and value[1]() or value[1], type(value[2]) == "function" and value[2]() or value[2])
    end)
    owner:HookScript("OnLeave", HideTip)
    owner:HookScript("OnHide", HideTip)
end
local function Hover(parent, target, title, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(target); f:EnableMouse(true)
    if f.SetMouseClickEnabled then f:SetMouseClickEnabled(false) end
    Describe(f, title, text)
    return f
end
local buttonNormal = { .15, .105, .079, 1 }
local buttonHover = { .23, .155, .104, 1 }
local buttonPressed = { .105, .074, .056, 1 }
local buttonDisabled = { .12, .087, .069, 1 }
local buttonQuiet = { .125, .091, .071, 1 }
local function PaintStandaloneButton(button)
    local enabled = button:IsEnabled()
    local selected = button.perfSelected or button.perfPrimary
    local hovered = enabled and button.perfHovered
    local fill = not enabled and buttonDisabled or button.perfPressed and buttonPressed
        or hovered and buttonHover or selected and T.accentDim or button.perfQuiet and buttonQuiet or buttonNormal
    local border = enabled and (selected and T.accent or hovered and T.line or T.lineSoft) or T.lineSoft
    button:SetBackdropColor(unpack(fill))
    local r, g, b = unpack(border)
    button:SetBackdropBorderColor(r, g, b, not enabled and .42 or button.perfQuiet and not hovered and .52 or 1)
    button.text:SetTextColor(unpack(enabled and T.text or T.muted))
    button.text:SetAlpha(enabled and 1 or .55)
end
local function Button(parent, text, click, primary, help)
    local b
    if W then b = W:Button(parent, text, click, primary)
    else
        b = CreateFrame("Button", nil, parent, "BackdropTemplate")
        Surface(b)
        b.text = Label(b, text, 12)
        b.text:SetPoint("LEFT", 5, 0); b.text:SetPoint("RIGHT", -5, 0)
        b.text:SetJustifyH("CENTER"); b.text:SetWordWrap(false)
        b.perfPrimary = primary
        b:HookScript("OnEnter", function(self) self.perfHovered = true; PaintStandaloneButton(self) end)
        b:HookScript("OnLeave", function(self) self.perfHovered, self.perfPressed = nil, nil; PaintStandaloneButton(self) end)
        b:HookScript("OnMouseDown", function(self, key) if key == "LeftButton" then self.perfPressed = true; PaintStandaloneButton(self) end end)
        b:HookScript("OnMouseUp", function(self) self.perfPressed = nil; PaintStandaloneButton(self) end)
        b:HookScript("OnHide", function(self) self.perfHovered, self.perfPressed = nil, nil; PaintStandaloneButton(self) end)
        b:HookScript("OnDisable", function(self) self.perfPressed = nil; PaintStandaloneButton(self) end)
        b:HookScript("OnEnable", PaintStandaloneButton)
        PaintStandaloneButton(b)
        b:SetScript("OnClick", click)
    end
    b:SetSize(100, 28)
    if help then Describe(b, text, help) end
    return b
end
local function Selected(button, selected)
    if W then T:PaintButton(button, selected)
    else button.perfSelected = selected; PaintStandaloneButton(button) end
end
local function QuietRow(button)
    if not W then button.perfQuiet = true; PaintStandaloneButton(button) end
end
local function Text(button, value) button.text:SetText(value) end
local function Enable(button, enabled) if enabled then button:Enable() else button:Disable() end end
local function Value(value, format) return ns.Number(value) ~= nil and (format or "%.2f"):format(value) or L("н/д", "n/a") end
local function Average(row)
    if row.average ~= nil then return row.average end
    if row.total and row.samples and row.samples > 0 then return row.total / row.samples end
end
local function Peak(row) if row.samples ~= 0 then return row.peak end end
local function Clock(value)
    value = math.max(0, value or 0)
    local rounded = math.floor(value * 100 + .5) / 100
    if rounded % 1 ~= 0 then return ("%02d:%05.2f"):format(math.floor(rounded / 60), rounded % 60) end
    return ("%02d:%02d"):format(math.floor(rounded / 60), math.floor(rounded % 60))
end
local function Record()
    if ui.reportID and ui.view == "capture" then return ns.FindRecord(ui.reportID) end
    if ui.view == "history" then return ns.FindRecord(ui.selectedID) end
    return ns.Capture()
end
local function Picker(owner, choices, value, commit)
    HideTip(owner)
    if W and T.OpenPicker then choicePopup=T:OpenPicker(owner, choices, value, commit)
    else
        local index = 0
        for i, choice in ipairs(choices) do if choice.value == value then index = i end end
        commit(choices[index % #choices + 1].value)
    end
end
local function Input(parent)
    if W and W.EditBox then
        local box=W:EditBox(parent,"",function()end)
        box:SetScript("OnEnterPressed",nil)
        return box
    end
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetAutoFocus(false); box:SetTextInsets(8, 8, 2, 2); box:SetHeight(28)
    if W and T.SkinInput then T:SkinInput(box, 12) else Surface(box, T.input); box:SetFontObject(GameFontHighlightSmall) end
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end
local function Header(frame, title, close)
    if W then return W:WindowHeader(frame, { title = title, titleSize = 24, height = 50, icon = icon, onClose = close }) end
    local h = Panel(frame); h:SetPoint("TOPLEFT", 1, -1); h:SetPoint("TOPRIGHT", -1, -1); h:SetHeight(50)
    h.title = Label(h, title, 24); h.title:SetPoint("LEFT", 16, 0)
    h.close = Button(h, "", close)
    h.close:SetSize(25, 25); h.close:SetPoint("RIGHT", -10, 0)
    for _, rotation in ipairs({ .785398, -.785398 }) do
        local line = h.close:CreateTexture(nil, "ARTWORK"); line:SetColorTexture(unpack(T.text)); line:SetSize(12, 1); line:SetPoint("CENTER"); line:SetRotation(rotation)
    end
    return h
end
local function Stat(parent, index)
    local f = CreateFrame("Frame", nil, parent)
    f.label = Label(f, "", 11, T.muted); f.label:SetPoint("TOPLEFT", 12, -7)
    f.value = Label(f, "", 21); f.value:SetPoint("TOPLEFT", 12, -24)
    f:EnableMouse(true)
    Describe(f, function() return f.label:GetText() end, function() return f.help or "" end)
    return f
end
local function SetStat(index, title, value, help)
    local stat = ui.stats[index]
    stat.label:SetText(title); stat.value:SetText(value); stat.help = help
end
local fields = { "name", "average", "peak", "five", "memory" }
local labels = { L("Аддон", "Addon"), L("Среднее, мс", "Mean, ms"), L("Пик, мс", "Peak, ms"), L("Кадры >5 мс", "Frames >5 ms"), L("Память, МиБ", "Memory, MiB") }
local function MetricHelp(key)
    local live = ui.view == "live"
    if key == "name" then return L("Имя папки аддона. Наведите на строку, чтобы увидеть дополнительные счетчики и версию. Строка Perf всегда видна отдельно и включена в общий итог.", "Addon folder name. Hover a row for more counters and version. Perf has a separate row and remains included in totals.") end
    if key == "average" then return live and L("Среднее время аддона за последние 60 кадров клиента. Это не процент загрузки процессора компьютера.", "Average addon time over the client's last 60 ticks. This is not the computer's CPU utilization.")
        or L("Сумма доступных значений LastTime, разделенная на число наблюдавшихся кадров с данными. Только выбранный замер; н/д означает, что измерение не проводилось.", "Sum of available LastTime readings divided by observed frames with data, for this capture only. n/a means not measured.") end
    if key == "peak" then return live and L("Максимум с начала сеанса клиента. Он не является пиком текущего ручного замера.", "Maximum since the client session started. This is not the peak of the current timed capture.")
        or L("Наибольшее время аддона среди наблюдавшихся кадров этого замера. Пики разных аддонов могут приходиться на разные кадры и не складываются.", "Highest addon time among this capture's observed frames. Different addon peaks may occur in different frames and must not be added.") end
    if key == "five" then return live and L("Накопленный счетчик кадров этого аддона >5 мс за сеанс клиента.", "Cumulative session count of this addon's frames over 5 ms.")
        or L("Число кадров аддона >5 мс в выбранном отчете. Один кадр может учитываться у нескольких аддонов. В тултипе строки есть пороги 10 и 50 мс.", "Frames over 5 ms in this report. Several addons may count the same frame. The row tooltip also shows 10 and 50 ms thresholds.") end
    return L("Память Lua, отнесенная клиентом к аддону, а не вся ОЗУ WoW. В замере используется снимок до записи. Его время и возраст указаны в отчете; н/д означает отсутствие снимка. Объем сам по себе не доказывает утечку.", "Lua memory attributed to the addon, not all WoW process RAM. Captures use a pre-recording snapshot; its time and age are shown. n/a means no snapshot. Size alone does not prove a leak.")
end
local function RowHelp(row)
    local data = row.data
    if not data then return end
    local report = Record()
    local text = L("Кадры >5 / >10 / >50 мс: ", "Frames >5 / >10 / >50 ms: ") .. Value(data.five, "%d") .. " / " .. Value(data.ten, "%d") .. " / " .. Value(data.fifty, "%d")
        .. "\n" .. L("Пропущенные показания: ", "Missing readings: ") .. Value(data.missing or 0, "%d")
    if data.version then text = text .. "\n" .. L("Версия: ", "Version: ") .. data.version end
    if data.name == addon and report and report.kind == "capture" then
        text = text .. "\n" .. L("Стоимость сборщика, среднее / пик: ", "Collector cost, mean / peak: ") .. Value(report.costAverage, "%.3f") .. " / " .. Value(report.costPeak, "%.3f") .. L(" мс. Это только цикл сбора. Строка Perf включает работу окна в наблюдавшихся кадрах; подготовка и сохранение за границами замера в нее не входят.", " ms. This measures collection only. The Perf row includes window work in observed frames; preparation and saving outside the capture are not included.")
    end
    Tip(row, data.name, text)
end
local function MakeRow(parent, own)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(rowHeight); row:EnableMouse(true)
    row.cells = {}
    row.wash = DataTexture(row,"panel","BACKGROUND"); row.wash:SetAllPoints()
    row.wash:SetAlpha(own and .95 or .45)
    for i = 1, 5 do row.cells[i] = Label(row, "", 11, own and i == 1 and T.accent or T.text); row.cells[i]:SetWordWrap(false) end
    row.meter = DataTexture(row,"brass"); row.meter:SetHeight(2)
    row:SetScript("OnEnter", RowHelp); row:SetScript("OnLeave",HideTip);row:SetScript("OnHide",HideTip)
    return row
end
local function LayoutRow(row, tableWidth)
    local positions = { 0, .35, .53, .69, .84, 1 }
    for i = 1, 5 do
        local f = row.cells[i]; f:ClearAllPoints(); f:SetPoint("LEFT", row, "LEFT", positions[i] * tableWidth + 7, 0)
        f:SetWidth((positions[i+1] - positions[i]) * tableWidth - 14); f:SetJustifyH(i == 1 and "LEFT" or "RIGHT")
    end
    row.meter:ClearAllPoints(); row.meter:SetPoint("BOTTOMRIGHT", row, "BOTTOMLEFT", .53 * tableWidth - 7, 2)
end
local function PaintRow(row, data, maximum, tableWidth)
    row.data = data
    row:SetShown(data ~= nil)
    if not data then return end
    row.cells[1]:SetText(data.name)
    local average = Average(data)
    row.cells[2]:SetText(Value(average, "%.3f")); row.cells[3]:SetText(Value(Peak(data), "%.2f"))
    row.cells[4]:SetText(Value(data.five, "%d")); row.cells[5]:SetText(Value(data.memory, "%.2f"))
    row.meter:SetShown(average ~= nil and maximum > 0)
    if average and maximum > 0 then row.meter:SetWidth(math.max(1, (.18 * tableWidth - 14) * average / maximum)) end
end
local function PaintTable(rows, top, parent)
    local content, tableFrame = parent or ui.content, ui.tableFrame
    tableFrame:SetParent(content)
    ui.tableCount:SetParent(content);ui.tableUp:SetParent(content);ui.tableDown:SetParent(content)
    ui.tableCount:ClearAllPoints();ui.tableCount:SetPoint("BOTTOMRIGHT",content,"BOTTOMRIGHT",-60,8)
    ui.tableUp:ClearAllPoints();ui.tableUp:SetPoint("BOTTOMRIGHT",content,"BOTTOMRIGHT",-29,3)
    ui.tableDown:ClearAllPoints();ui.tableDown:SetPoint("BOTTOMRIGHT",content,"BOTTOMRIGHT",0,3)
    tableFrame:Show();ui.tableCount:Show();ui.tableUp:Show();ui.tableDown:Show()
    tableFrame:ClearAllPoints(); tableFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top); tableFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 30)
    local tw = content:GetWidth()
    local positions = { 0, .35, .53, .69, .84, 1 }
    for i, button in ipairs(ui.headings) do
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", positions[i] * tw, 0); button:SetSize((positions[i+1]-positions[i])*tw-3, 24)
        Text(button, labels[i]); Selected(button, ui.sort == fields[i])
    end
    local values, own, max = {}, nil, 0
    local query = ui.search:GetText():lower()
    for _, data in ipairs(rows) do
        local average = Average(data)
        max = math.max(max, average or 0)
        if data.name == addon then own = data
        elseif query == "" or data.name:lower():find(query, 1, true) then values[#values + 1] = data end
    end
    table.sort(values, function(a, b)
        local key = ui.sort
        local av = key == "average" and Average(a) or a[key]
        local bv = key == "average" and Average(b) or b[key]
        if av == bv then return a.name < b.name end
        if av == nil or av == false then return false elseif bv == nil or bv == false then return true end
        if ui.descending then return av > bv end
        return av < bv
    end)
    local visible = math.max(1, math.min(#ui.rows, math.floor((tableFrame:GetHeight() - 60) / rowHeight)))
    ui.rowOffset = math.max(0, math.min(ui.rowOffset, math.max(0, #values - visible)))
    for i, row in ipairs(ui.rows) do
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, -27-(i-1)*rowHeight); row:SetWidth(tw)
        LayoutRow(row, tw)
        PaintRow(row, i <= visible and values[ui.rowOffset+i] or nil, max, tw)
    end
    ui.own:ClearAllPoints(); ui.own:SetPoint("BOTTOMLEFT", tableFrame, "BOTTOMLEFT", 0, 0); ui.own:SetWidth(tw)
    LayoutRow(ui.own, tw); PaintRow(ui.own, own, max, tw)
    ui.tableCount:SetText(("%d–%d / %d"):format(#values == 0 and 0 or ui.rowOffset+1, math.min(#values, ui.rowOffset+visible), #values))
    Enable(ui.tableUp, ui.rowOffset > 0); Enable(ui.tableDown, ui.rowOffset + visible < #values)
    ui.visibleRows, ui.filteredCount = visible, #values
end
local function PaintChart(record)
    local chart = ui.chart
    local current, running = ns.Capture()
    local span = math.max(.001, running and current == record and record.requested or record.duration or 0)
    local timeline, count = record.timeline or {}, math.min(30, #(record.timeline or {}))
    local stride = math.max(1, math.ceil(#timeline / 30))
    local bins, maximum = {}, 1
    for i = 1, #timeline, stride do
        local bin = { from = timeline[i].from or 0, to = 0, five = 0, peak = nil, individualFive = 0, addonMissing = 0, contributors = {} }
        local valid = false
        for j = i, math.min(#timeline, i+stride-1) do
            local point = timeline[j]
            bin.to = point.to or bin.to
            if point.five ~= nil and (not point.samples or point.samples > 0) then bin.five = bin.five + point.five; valid = true end
            if point.peak and (not point.samples or point.samples > 0) then bin.peak = math.max(bin.peak or 0, point.peak) end
            bin.individualFive = bin.individualFive + (point.individualFive or 0)
            bin.addonMissing = bin.addonMissing + (point.addonMissing or 0)
            for _, item in ipairs(point.contributors or {}) do if item.value > 0 then bin.contributors[item.name] = (bin.contributors[item.name] or 0) + item.value end end
        end
        if not valid then bin.five = nil end
        bins[#bins+1] = bin
        maximum = math.max(maximum, (ui.graph == "peak" and bin.peak or bin.five) or 0)
    end
    ui.bins = bins; count = #bins
    ui.interval = math.min(math.max(1, ui.interval), math.max(1, count))
    local plotWidth, plotHeight = chart:GetWidth()-30, 108
    for i, bar in ipairs(ui.bars) do
        local bin = bins[i]
        bar:SetShown(bin ~= nil)
        if bin then
            bar.data = bin; bar:ClearAllPoints(); bar:SetPoint("BOTTOMLEFT", chart, "BOTTOMLEFT", 26+bin.from/span*plotWidth, 25)
            bar:SetSize(math.max(1,(bin.to-bin.from)/span*plotWidth-3),plotHeight)
            bar.wash:SetShown(i==ui.interval)
            local value = ui.graph == "peak" and bin.peak or bin.five
            bar.fill:SetShown(value ~= nil and value > 0)
            if value and value > 0 then bar.fill:SetHeight(math.max(1,value/maximum*plotHeight)) end
            Color(bar.fill,"SetColorTexture",i==ui.interval and T.accent or teal)
        end
    end
    ui.axisMax:SetText(Value(maximum,"%.0f")); ui.axisMid:SetText(Value(maximum/2,"%.0f"))
    ui.axisEnd:SetText(Clock(span)); ui.axisMiddle:SetText(Clock(span/2))
    local point = bins[ui.interval]
    if point then
        ui.detailTime:SetText(Clock(point.from).."–"..Clock(point.to))
        ui.detailCounts:SetText(L("Вместе >5 мс: ","Combined >5 ms: ")..Value(point.five,"%d"))
        ui.detailPeak:SetText(L("Пик всех аддонов: ","Combined peak: ")..Value(point.peak,"%.2f")..L(" мс"," ms"))
        local explanation
        if not point.five then explanation=L("Нет доступных показаний в этом интервале.","No available readings in this interval.")
        elseif point.five==0 then explanation=L("Суммарных превышений 5 мс нет.","No combined frames over 5 ms.")
        elseif point.individualFive==0 and (point.addonMissing>0 or (record.omitted or 0)>0) then explanation=L("Общий порог превышен. Индивидуальные данные неполны; по ним нельзя определить вклад всех аддонов.","The combined threshold was crossed. Individual data is incomplete, so not every addon's contribution can be determined.")
        elseif point.individualFive==0 then explanation=L("Ни один отслеживаемый аддон отдельно не превысил 5 мс. Порог превышен суммарной работой.","No tracked addon individually exceeded 5 ms. Their combined work crossed the threshold.")
        else
            local entries={};for name,value in pairs(point.contributors) do entries[#entries+1]={name=name,value=value} end
            table.sort(entries,function(a,b)return a.value>b.value end)
            local text={};for i=1,math.min(3,#entries) do text[#text+1]=entries[i].name.." ×"..entries[i].value end
            explanation=table.concat(text,"\n")
        end
        ui.detailText:SetText(explanation)
    end
    Enable(ui.previous,ui.interval>1);Enable(ui.next,ui.interval<count)
    Selected(ui.spikeMode,ui.graph=="five");Selected(ui.peakMode,ui.graph=="peak")
    Enable(ui.peakMode,record.kind=="capture")
end
local function PaintHistory()
    local records={};for _,record in ipairs(ns.History()) do records[#records+1]=record end
    table.sort(records,function(a,b)if a.pinned~=b.pinned then return a.pinned end return a.id>b.id end)
    if not ns.FindRecord(ui.selectedID) then ui.selectedID=records[1] and records[1].id end
    ui.historyOffset=math.min(ui.historyOffset,math.max(0,#records-#ui.historyRows))
    for i,button in ipairs(ui.historyRows) do
        local record=records[ui.historyOffset+i];button.record=record;button:SetShown(record~=nil)
        if record then
            button.name:SetText((record.pinned and "* " or "")..record.name)
            button.detail:SetText(date("%d.%m %H:%M",record.timestamp).." · "..Value(record.duration,"%.1f")..L(" с"," s").."\n"..(record.kind=="background" and L("Фон","Background") or L("Замер","Capture")).." · >5 "..Value(record.five,"%d"))
            Selected(button,record.id==ui.selectedID)
        end
    end
    Enable(ui.historyUp,ui.historyOffset>0);Enable(ui.historyDown,ui.historyOffset+#ui.historyRows<#records)
end
Paint=function(refresh)
    if not ui or not ui:IsShown() then return end
    Text(ui.background,ns.BackgroundEnabled() and L("Фон: включен","Background: on") or L("Фон: выключен","Background: off"))
    if ui.developer and ui.developer:Paint() then return end
    if ui.phase2 and ui.phase2:Paint(refresh) then return end
    ui.content:Show()
    local history=ui.view=="history"
    ui.historyPane:SetShown(history)
    ui.content:ClearAllPoints();ui.content:SetPoint("TOPLEFT",ui,"TOPLEFT",history and 232 or 18,-112);ui.content:SetPoint("BOTTOMRIGHT",ui,"BOTTOMRIGHT",-18,42)
    if history then PaintHistory() end
    local record, running=Record(),select(2,ns.Capture())
    local live=ui.view=="live"
    for key,button in pairs(ui.tabs) do Selected(button,key==ui.view) end
    Text(ui.tabs.history,L("История ","History ")..#ns.History())
    Text(ui.start,running and L("Остановить","Stop") or ns.Armed() and L("Отменить ожидание","Cancel waiting") or ui.phase2 and L("Новый замер","New capture") or L("Начать замер","Start capture"))
    Enable(ui.start,running or ns.Armed() or ns.Available());Enable(ui.duration,not running)
    Text(ui.duration,db.duration..L(" с"," s"))
    ui.search:SetShown(live);ui.searchLabel:SetShown(live);ui.refresh:SetShown(live)
    ui.export:SetShown(not live and record~=nil and not (ui.view=="capture" and running))
    ui.rename:SetShown(not live and record~=nil and not (ui.view=="capture" and running))
    ui.pin:SetShown(not live and record~=nil and not (ui.view=="capture" and running))
    ui.delete:SetShown(history and record~=nil)
    ui.title:SetText(live and L("Нагрузка сейчас","Current load") or record and record.name or L("Запишите проблемный момент","Record the slow moment"))
    ui.empty:SetShown(not live and not record)
    ui.empty:SetText(L("Выберите длительность и начните замер.\nОтчет появится в истории и сохранится после /reload.","Choose a duration and start a capture.\nThe report will be kept in history across /reload."))
    ui.chartArea:SetShown(not live and record~=nil)
    ui.summary:SetShown(live or record~=nil);ui.tableFrame:SetShown(live or record~=nil);ui.tableTitle:SetShown(live or record~=nil)
    ui.tableCount:SetShown(live or record~=nil);ui.tableUp:SetShown(live or record~=nil);ui.tableDown:SetShown(live or record~=nil);ui.footnote:SetShown(live or record~=nil)
    ui.progress:SetShown(running and ui.view=="capture")
    if running then ui.progress:SetMinMaxValues(0,db.duration);ui.progress:SetValue(ns.Elapsed()) end
    local available=ns.Available()
    if live then
        if refresh or not ui.liveRows or GetTime()>=ui.nextLive then
            ui.memory,ui.memoryState=ns.Memory(false)
            ui.liveRows,ui.liveSummary=ns.Snapshot();ui.nextLive=GetTime()+2
        end
        local s=ui.liveSummary or {}
        ui.meta:SetText((available and L("CPU обновлен ","CPU read ")..date("%H:%M:%S",s.updated) or L("Счетчики CPU недоступны","CPU counters unavailable")).." · "..(ui.memory and L("память ","memory ")..date("%H:%M:%S",ui.memory.timestamp) or L("память н/д","memory n/a"))..(ui.memoryState=="deferred" and L(" (снимок отложен)"," (scan deferred)") or ""))
        SetStat(1,L("FPS сейчас","Current FPS"),Value(s.fps,"%.0f"),L("Текущий FPS всего клиента. По нему нельзя вычислить реальный выигрыш от отключения аддонов.","Current FPS of the whole client. It cannot predict the actual gain from disabling addons."))
        SetStat(2,L("CPU всех аддонов","All addon CPU"),Value(s.overall,"%.3f")..L(" мс"," ms"),L("Нативное среднее за последние 60 кадров, включая Sintezza Perf. Не загрузка всего процессора.","Native mean over the last 60 ticks, including Sintezza Perf. Not total processor utilization."))
        SetStat(3,L("Доля кадра / память Lua","Frame share / Lua memory"),Value(s.share,"%.1f").."% · "..Value(ui.memory and ui.memory.total,"%.1f")..L(" МиБ"," MiB"),L("Доля: среднее время всех аддонов / среднее время кадра клиента за 60 кадров. Память: сумма последнего снимка аддонов, не вся память WoW. Снимки в бою и во время записи отложены.","Share: average addon time / client frame time over 60 ticks. Memory: last addon snapshot, not all WoW memory. Scans are deferred in combat and during capture."))
        ui.tableTitle:SetText(L("Нагрузка аддонов","Addon usage"));ui.tableTitle:ClearAllPoints();ui.tableTitle:SetPoint("TOPLEFT",ui.content,"TOPLEFT",0,-142)
        ui.footnote:SetText(L("CPU: последние 60 кадров. Пик и счетчики: весь сеанс. Колесо мыши прокручивает таблицу.","CPU: last 60 ticks. Peak and counts: entire session. Mouse wheel scrolls the table."))
        PaintTable(ui.liveRows or {},164)
    elseif record then
        local current=running and ui.view=="capture"
        local elapsed=current and ns.Elapsed() or record.duration
        ui.meta:SetText(date("%d.%m %H:%M:%S",record.timestamp).." · "..Value(elapsed,"%.1f")..L(" с"," s").." · "..(current and L("идет запись","recording") or record.kind=="background" and L("легкий сбор","light collection") or Value(record.frames,"%d")..L(" кадров · сохранен"," frames · saved"))..(record.reason=="overhead" and L(" · остановлен: нагрузка сборщика"," · stopped: collector budget") or ""))
        local average=Average(record)
        SetStat(1,L("CPU в среднем","Mean CPU"),Value(average,"%.3f")..L(" мс/кадр"," ms/frame"),MetricHelp("average"))
        SetStat(2,L("Пик за замер","Capture peak"),Value(Peak(record),"%.2f")..L(" мс"," ms"),L("Максимальное суммарное время всех аддонов среди наблюдавшихся кадров этого замера. Не сумма пиков строк. В легком фоне не измеряется.","Maximum combined addon time among this capture's observed ticks. Not a sum of row peaks. Not measured in light background mode."))
        SetStat(3,L("Все аддоны >5 мс","Combined addons >5 ms"),Value(record.five,"%d")..L(" кадров"," frames"),L("Суммарный счетчик: один кадр учитывается один раз, даже если порог превысили несколько аддонов. Сумма индивидуальных счетчиков может отличаться.","Combined count: each frame counts once even when several addons cross the threshold. The sum of individual counts can differ.").."\n>10 / >50: "..Value(record.ten,"%d").." / "..Value(record.fifty,"%d"))
        if record.kind=="background" then ui.graph="five" end
        PaintChart(record)
        ui.tableTitle:SetText(record.kind=="background" and L("Превышения за интервал","Thresholds in the interval") or L("Аддоны за весь замер","Addons over the whole capture"))
        ui.tableTitle:ClearAllPoints();ui.tableTitle:SetPoint("TOPLEFT",ui.content,"TOPLEFT",0,-308)
        ui.footnote:SetText(record.kind=="background" and L("Фон: среднее CPU, точный пик и память не записывались.","Background: mean CPU, exact peak and memory were not recorded.") or record.memoryTimestamp and L("Память до записи: ","Pre-capture memory: ")..date("%H:%M:%S",record.memoryTimestamp)..L(" · возраст "," · age ")..Value(record.memoryAge,"%.0f")..L(" с. Пики не складываются."," s. Peaks are not additive.") or L("Память до записи: нет снимка. Пики разных аддонов не складываются.","Pre-capture memory: no snapshot. Per-addon peaks are not additive."))
        Selected(ui.pin,record.pinned)
        Text(ui.pin,record.pinned and L("Открепить","Unpin") or L("Закрепить","Pin"))
        PaintTable(record.rows,330)
    else ui.meta:SetText(available and L("Готов к замеру","Ready to capture") or L("Профайлер CPU недоступен. Сохраненные отчеты доступны в истории.","CPU profiler unavailable. Saved reports remain available in History.")) end
    ui.dirty=false
end
Schedule=function()
    if ui.timer then ui.timer:Cancel();ui.timer=nil end
    if not ui:IsShown() then return end
    if ui.view=="live" or select(2,ns.Capture()) or ns.DevRunning and ns.DevRunning() then
        ui.timer=C_Timer.NewTicker(1,function() if ui:IsShown() then Paint(false) end end)
    end
end
Switch=function(view)
    ui.view,ui.rowOffset,ui.interval,ui.reportID=view,0,1,nil
    ui.search:SetText("")
    Paint(true);Schedule()
end

local function BuildWindow()
    ui=Window(UIParent,"Sintezza_PerfWindow")
    ui:SetSize(width,height);ui:SetPoint("CENTER");ui:SetFrameStrata("DIALOG");ui:SetClampedToScreen(true);ui:SetMovable(true);ui:EnableMouse(true);ui:Hide()
    ui.view,ui.sort,ui.descending,ui.graph="live","average",true,"five"
    ui.rowOffset,ui.historyOffset,ui.interval,ui.nextLive=0,0,1,0
    UISpecialFrames[#UISpecialFrames+1]=ui:GetName()
    local header=Header(ui,"Sintezza Perf",function()ui:Hide()end)
    Describe(header.close,L("Закрыть","Close"),L("Скрывает окно. Запись и включенный фоновый сбор продолжатся; отрисовка окна остановится.","Hide the window. Recording and enabled background collection continue; window rendering stops."))
    header:EnableMouse(true);header:SetScript("OnMouseDown",function(_,button)if button=="LeftButton" and not InCombatLockdown() and (not prefs or prefs:CanMove()) then ui:StartMoving() end end)
    header:SetScript("OnMouseUp",function()ui:StopMovingOrSizing()end)
    ui.settings=Button(header,L("Настройки","Settings"),function()OpenDialog("settings")end,false,L("Фоновый сбор, снимки памяти, история и значок у миникарты.","Background collection, memory scans, history and minimap icon."))
    ui.settings:SetPoint("RIGHT",header.close,"LEFT",-8,0);header.title:SetPoint("RIGHT",ui.settings,"LEFT",-12,0)
    ui.startupButton=Button(header,L("Время входа","Login timing"),function()ns.ToggleStartup()end,false,
        L("Открыть или закрыть окно времени входа и перезагрузки. В нем доступны этапы и интервалы загрузки.","Open or close login and reload timing, with phases and loading intervals."))
    ui.startupButton:SetWidth(110);ui.startupButton:SetPoint("RIGHT",ui.settings,"LEFT",-8,0)
    header.title:SetPoint("RIGHT",ui.startupButton,"LEFT",-12,0)
    ui.tabs={}
    for i,entry in ipairs({{"live",L("Нагрузка","Load"),L("Текущие CPU и память. Период и время снимка указаны над таблицей.","Current CPU and memory, with measurement scope and snapshot time above the table.")},{"capture",L("Замер","Capture"),L("Текущая запись или последний подробный замер. Метрики относятся только к его интервалу.","Current recording or latest detailed capture. Metrics belong only to its interval.")},{"history",L("История","History"),L("Сохраненные подробные замеры и фоновые эпизоды. Доступны после /reload.","Saved detailed captures and background episodes, available across /reload.")}}) do
        local key=entry[1];local b=Button(ui,entry[2],function()Switch(key)end,false,entry[3]);b:SetPoint("TOPLEFT",18+(i-1)*106,-64);ui.tabs[key]=b
    end
    ui.start=Button(ui,L("Начать замер","Start capture"),function()
        if ns.DevRunning and ns.DevRunning() then ns.DevStop("manual")
        elseif ui.view=="developer" and ui.developer then ui.developer:Setup();return
        elseif select(2,ns.Capture()) then ns.Stop("manual")
        elseif ns.Armed() then ns.CancelArm()
        elseif ui.phase2 then ui.phase2:Setup();return
        else ui.view="capture";ns.Start(db.duration) end
        Paint(true);Schedule()
    end,true,L("Подробно читает время каждого аддона раз в кадр, только на выбранный срок. Без снимков памяти. При средней стоимости сборщика >1 мс за 60 кадров или разовом >20 мс запись завершится досрочно и сохранит результат.","Reads each addon's time once per frame, only for the selected duration. No memory scans. Collection stops and saves early if its mean cost exceeds 1 ms over 60 frames or a single pass exceeds 20 ms."))
    ui.start:SetSize(150,28);ui.start:SetPoint("TOPRIGHT",-18,-64)
    local startHelp=ui.start.perfTooltip[2]
    ui.start.perfTooltip[1]=function()return ui.start.text:GetText()end
    ui.start.perfTooltip[2]=function()
        if ns.DevRunning and ns.DevRunning()then return L("Остановить разработческий сбор и сохранить частичный отчет. Код измеряемого аддона продолжит работать.","Stop developer collection and save a partial report. The measured addon's code keeps running.")end
        if ui.view=="developer"then return L("Выберите модули и режим: счетчики, CPU или память. По умолчанию 15 секунд; максимум 60. Подробный сбор выключен вне записи.","Select modules and a mode: counters, CPU or memory. Default 15 seconds, maximum 60. Detailed collection is off outside recordings.")end
        return select(2,ns.Capture()) and L("Завершает запись сейчас и сохраняет собранный интервал в истории. Неполный замер не участвует в A/B.","Stop recording now and save the collected interval in history. Partial captures are excluded from A/B.") or ns.Armed() and L("Отменяет ожидание события и освобождает подготовленные буферы.","Cancel event waiting and release prepared buffers.") or L("Выберите ручной запуск, следующий бой или босса, легкий или подробный режим. Покадровый сбор идет только во время ограниченного замера.","Choose manual, next combat or boss, and light or detailed mode. Per-frame collection runs only during a bounded capture.")
    end
    ui.duration=Button(ui,"",function(self)
        local choices={};for _,v in ipairs({5,15,30,60,120})do choices[#choices+1]={value=v,label=v..L(" с"," s")}end
        Picker(self,choices,db.duration,function(v)db.duration=v;Paint(false)end)
    end,false,L("Длительность подробной записи от 5 до 120 секунд. Остановить раньше можно той же кнопкой. Закрытие окна не отменяет запись.","Detailed recording duration from 5 to 120 seconds. Stop early with the same button. Closing the window does not cancel recording."))
    ui.duration:SetSize(65,28);ui.duration:SetPoint("RIGHT",ui.start,"LEFT",-8,0)
    local durationLabel=Label(ui,L("Длительность","Duration"),11,T.muted);durationLabel:SetPoint("RIGHT",ui.duration,"LEFT",-8,0);ui.durationLabel=durationLabel
    ui.content=CreateFrame("Frame",nil,ui)
    ui.title=Label(ui.content,"",18,T.accent);ui.title:SetPoint("TOPLEFT",0,0);ui.title:SetPoint("TOPRIGHT",-310,0);ui.title:SetWordWrap(false)
    ui.meta=Label(ui.content,"",11,T.muted);ui.meta:SetPoint("TOPLEFT",0,-27);ui.meta:SetPoint("TOPRIGHT",0,-27);ui.meta:SetWordWrap(false)
    Hover(ui.content,ui.meta,L("Область измерения","Measurement scope"),function()
        local r=Record()
        return L("Время и длительность относятся к выбранному отчету. Подробный замер наблюдает предыдущий кадр через LastTime; недоступные значения пропускаются, а не заменяются нулем.","Time and duration refer to the selected report. Detailed capture observes the previous tick via LastTime; unavailable values are skipped, never replaced with zero.")..(r and "\n"..L("Пропущено: ","Missing: ")..Value(r.missing or 0,"%d").." · "..L("Аддонов вне таблицы: ","Addons outside table: ")..Value(r.omitted or 0,"%d") or "")
    end)
    ui.delete=Button(ui.content,L("Удалить","Delete"),function()OpenDialog("delete")end,false,L("Удаляет только выбранный отчет после подтверждения.","Delete only the selected report after confirmation."));ui.delete:SetSize(75,26);ui.delete:SetPoint("TOPRIGHT",0,2)
    ui.export=Button(ui.content,L("Экспорт","Export"),function()OpenDialog("export")end,false,L("Открывает выбранный отчет для копирования как текст или JSON. Содержит версию, период, счетчики, ограничения и нагрузку Perf. Имена персонажей и чат не собираются.","Open the selected report for copying as text or JSON. Includes version, scope, counters, limitations and Perf overhead. Character names and chat are not collected."));ui.export:SetSize(85,26);ui.export:SetPoint("RIGHT",ui.delete,"LEFT",-6,0)
    ui.pin=Button(ui.content,L("Закрепить","Pin"),function()local r=Record();if r and not ns.PinRecord(r.id) then print(L("Можно закрепить не более 10 отчетов.","At most 10 reports can be pinned."))end;Paint(false)end,false,L("Защищает отчет от удаления по лимиту истории. Можно закрепить до 10 отчетов сверх обычного лимита. Повторное нажатие снимает закрепление.","Protects a report from retention pruning. Up to 10 reports can be pinned in addition to the regular limit. Press again to unpin."));ui.pin:SetSize(88,26);ui.pin:SetPoint("RIGHT",ui.export,"LEFT",-6,0)
    ui.rename=Button(ui.content,L("Имя","Name"),function()OpenDialog("rename")end,false,L("Задает название выбранному замеру, например название проверяемого действия.","Name the selected capture after the action you were checking."));ui.rename:SetSize(50,26);ui.rename:SetPoint("RIGHT",ui.pin,"LEFT",-6,0)
    ui.summary=Sidebar(ui.content);ui.summary:SetPoint("TOPLEFT",0,-52);ui.summary:SetPoint("TOPRIGHT",0,-52);ui.summary:SetHeight(57)
    ui.stats={};for i=1,3 do local s=Stat(ui.summary,i);s:SetPoint("TOPLEFT",ui.summary,"TOPLEFT",0,0);ui.stats[i]=s end
    ui.summary:SetScript("OnSizeChanged",function(self,w)for i,s in ipairs(ui.stats)do s:ClearAllPoints();s:SetPoint("TOPLEFT",(i-1)*w/3,0);s:SetSize(w/3,57)end end)
    ui.progress=Progress(ui.content);ui.progress:SetPoint("TOPLEFT",ui.summary,"BOTTOMLEFT",0,-2);ui.progress:SetPoint("TOPRIGHT",ui.summary,"BOTTOMRIGHT",0,-2);ui.progress:SetHeight(3)
    ui.chartArea=CreateFrame("Frame",nil,ui.content);ui.chartArea:SetPoint("TOPLEFT",0,-123);ui.chartArea:SetPoint("TOPRIGHT",0,-123);ui.chartArea:SetHeight(174)
    ui.chart=CreateFrame("Frame",nil,ui.chartArea);ui.chart:SetPoint("TOPLEFT",0,0);ui.chart:SetPoint("BOTTOMRIGHT",-237,0)
    local chartTitle=Label(ui.chart,L("Нагрузка по времени","Load over time"),13);chartTitle:SetPoint("TOPLEFT",0,0)
    ui.spikeMode=Button(ui.chart,L("Кадры >5 мс","Frames >5 ms"),function()ui.graph="five";Paint(false)end,false,L("Каждый столбец: число наблюдавшихся кадров, где все аддоны вместе превысили 5 мс. Нажмите столбец для деталей. Длинные замеры объединяются максимум в 30 столбцов.","Each bar counts observed frames where all addons together exceeded 5 ms. Select a bar for details. Long captures are grouped into at most 30 bars."));ui.spikeMode:SetSize(105,22);ui.spikeMode:SetPoint("TOPRIGHT",-74,3)
    ui.peakMode=Button(ui.chart,L("Пик CPU","CPU peak"),function()ui.graph="peak";Paint(false)end,false,L("Максимальное суммарное время аддонов внутри каждого интервала, мс. Это не FPS и не среднее. Доступно только для подробной записи.","Maximum combined addon time inside each interval, in ms. Not FPS or an average. Available only for detailed captures."));ui.peakMode:SetSize(70,22);ui.peakMode:SetPoint("TOPRIGHT",0,3)
    ui.axisMax=Label(ui.chart,"",10,T.muted);ui.axisMax:SetPoint("TOPLEFT",0,-27)
    ui.axisMid=Label(ui.chart,"",10,T.muted);ui.axisMid:SetPoint("TOPLEFT",0,-81)
    local zero=Label(ui.chart,"0",10,T.muted);zero:SetPoint("BOTTOMLEFT",0,20)
    ui.axisStart=Label(ui.chart,"0:00",10,T.muted);ui.axisStart:SetPoint("BOTTOMLEFT",26,4)
    ui.axisMiddle=Label(ui.chart,"",10,T.muted);ui.axisMiddle:SetPoint("BOTTOM",0,4)
    ui.axisEnd=Label(ui.chart,"",10,T.muted);ui.axisEnd:SetPoint("BOTTOMRIGHT",0,4)
    ui.bars={}
    for i=1,30 do
        local index=i;local bar=CreateFrame("Button",nil,ui.chart);bar.wash=DataTexture(bar,"accentDim","BACKGROUND");bar.wash:SetAllPoints()
        bar.fill=DataTexture(bar,"brass");bar.fill:SetPoint("BOTTOMLEFT");bar.fill:SetPoint("BOTTOMRIGHT");bar.fill:SetHeight(1)
        bar:SetScript("OnClick",function()ui.interval=index;Paint(false)end)
        Describe(bar,L("Интервал графика","Chart interval"),function()local p=bar.data;if not p then return "" end;return Clock(p.from).."–"..Clock(p.to).."\n>5: "..Value(p.five,"%d").."\n"..L("Пик, мс: ","Peak, ms: ")..Value(p.peak,"%.3f").."\n"..L("Общие кадры не равны сумме счетчиков аддонов.","Combined frames are not the sum of per-addon counts.")end)
        ui.bars[i]=bar
    end
    local detail=Sidebar(ui.chartArea);detail:SetPoint("TOPRIGHT",0,0);detail:SetPoint("BOTTOMRIGHT",0,0);detail:SetWidth(222)
    local detailLabel=Label(detail,L("Выбранный интервал","Selected interval"),11,T.muted);detailLabel:SetPoint("TOPLEFT",10,-8)
    ui.detailTime=Label(detail,"",18,T.accent);ui.detailTime:SetPoint("TOPLEFT",10,-27)
    ui.detailCounts=Label(detail,"",11);ui.detailCounts:SetPoint("TOPLEFT",10,-56)
    ui.detailPeak=Label(detail,"",11);ui.detailPeak:SetPoint("TOPLEFT",10,-74)
    ui.detailText=Label(detail,"",11,T.muted);ui.detailText:SetPoint("TOPLEFT",10,-96);ui.detailText:SetPoint("TOPRIGHT",-10,-96);ui.detailText:SetWordWrap(true)
    ui.previous=Button(detail,"<",function()ui.interval=math.max(1,ui.interval-1);Paint(false)end,false,L("Предыдущий интервал графика.","Previous chart interval."));ui.previous:SetSize(23,22);ui.previous:SetPoint("TOPRIGHT",-36,-26)
    ui.next=Button(detail,">",function()ui.interval=ui.interval+1;Paint(false)end,false,L("Следующий интервал графика.","Next chart interval."));ui.next:SetSize(23,22);ui.next:SetPoint("LEFT",ui.previous,"RIGHT",4,0)
    ui.tableTitle=Label(ui.content,"",13)
    ui.tableFrame=CreateFrame("Frame",nil,ui.content);ui.tableFrame:EnableMouseWheel(true)
    ui.tableFrame:SetScript("OnMouseWheel",function(_,delta)ui.rowOffset=math.max(0,ui.rowOffset-delta*3);Paint(false)end)
    ui.headings={};for i,key in ipairs(fields)do local sortKey=key;local b=Button(ui.tableFrame,labels[i],function()if ui.sort==sortKey then ui.descending=not ui.descending else ui.sort,ui.descending=sortKey,sortKey~="name" end;Paint(false)end,false,function()return MetricHelp(sortKey)end);ui.headings[i]=b end
    ui.rows={};for i=1,20 do ui.rows[i]=MakeRow(ui.tableFrame,false) end
    ui.own=MakeRow(ui.tableFrame,true)
    ui.tableCount=Label(ui.content,"",10,T.muted);ui.tableCount:SetPoint("BOTTOMRIGHT",-60,8)
    ui.tableUp=Button(ui.content,"<",function()ui.rowOffset=math.max(0,ui.rowOffset-ui.visibleRows);Paint(false)end,false,L("Предыдущая страница аддонов.","Previous page of addons."));ui.tableUp:SetSize(24,22);ui.tableUp:SetPoint("BOTTOMRIGHT",-29,3)
    ui.tableDown=Button(ui.content,">",function()ui.rowOffset=ui.rowOffset+ui.visibleRows;Paint(false)end,false,L("Следующая страница аддонов.","Next page of addons."));ui.tableDown:SetSize(24,22);ui.tableDown:SetPoint("BOTTOMRIGHT",0,3)
    ui.footnote=Label(ui.content,"",10,T.muted);ui.footnote:SetPoint("BOTTOMLEFT",0,8);ui.footnote:SetPoint("BOTTOMRIGHT",-190,8);ui.footnote:SetWordWrap(false)
    Hover(ui.content,ui.footnote,L("Память и границы отчета","Memory and report scope"),function()return ui.footnote:GetText().."\n"..MetricHelp("memory")end)
    ui.searchLabel=Label(ui.content,L("Найти аддон","Find addon"),11,T.muted);ui.searchLabel:SetPoint("TOPLEFT",0,-119)
    ui.search=Input(ui.content);ui.search:SetPoint("TOPLEFT",95,-115);ui.search:SetSize(220,24)
    ui.search:SetScript("OnTextChanged",function()if ui:IsShown() and ui.view=="live" then ui.rowOffset=0;Paint(false)end end)
    Describe(ui.search,L("Найти аддон","Find addon"),L("Фильтр по имени папки. Нагрузка Perf остается видна независимо от фильтра.","Filter by folder name. Perf overhead stays visible regardless of the filter."))
    ui.refresh=Button(ui.content,L("Обновить память","Refresh memory"),function()ui.memory,ui.memoryState=ns.Memory(true);ui.nextLive=0;Paint(true)end,false,L("Обновляет снимок Lua-памяти. Полный обход может вызвать паузу, поэтому в бою и во время записи откладывается. CPU обновляется независимо раз в две секунды при открытой вкладке.","Refresh the Lua-memory snapshot. The full scan may cause a pause, so it is deferred during combat and capture. CPU refreshes independently every two seconds while this tab is visible."));ui.refresh:SetSize(145,27);ui.refresh:SetPoint("TOPRIGHT",0,2)
    ui.empty=Label(ui.content,"",14,T.muted);ui.empty:SetPoint("TOPLEFT",35,-180);ui.empty:SetPoint("TOPRIGHT",-35,-180);ui.empty:SetJustifyH("CENTER");ui.empty:SetWordWrap(true)
    ui.historyPane=Sidebar(ui);ui.historyPane:SetPoint("TOPLEFT",18,-112);ui.historyPane:SetPoint("BOTTOMLEFT",18,42);ui.historyPane:SetWidth(196)
    local histTitle=Label(ui.historyPane,L("Сохраненные отчеты","Saved reports"),12,T.muted);histTitle:SetPoint("TOPLEFT",10,-10)
    ui.historyRows={};for i=1,7 do
        local b=Button(ui.historyPane,"",function(self)ui.selectedID=self.record.id;ui.rowOffset,ui.interval=0,1;Paint(false)end,false,L("Открывает сохраненный отчет. Звездочкой отмечен закрепленный отчет.","Open the saved report. An asterisk marks a pinned report."));b:SetPoint("TOPLEFT",6,-35-(i-1)*73);b:SetSize(184,68)
        b.name=Label(b,"",11);b.name:SetPoint("TOPLEFT",8,-7);b.name:SetPoint("TOPRIGHT",-8,-7);b.name:SetWordWrap(false)
        b.detail=Label(b,"",10,T.muted);b.detail:SetPoint("TOPLEFT",8,-28);b.detail:SetPoint("TOPRIGHT",-8,-28)
        b.perfTooltip[1]=function()return b.record and b.record.name or L("Отчет","Report")end
        ui.historyRows[i]=b
    end
    ui.historyUp=Button(ui.historyPane,"<",function()ui.historyOffset=math.max(0,ui.historyOffset-7);Paint(false)end,false,L("Предыдущие отчеты.","Previous reports."));ui.historyUp:SetSize(30,24);ui.historyUp:SetPoint("BOTTOMLEFT",8,10)
    ui.historyDown=Button(ui.historyPane,">",function()ui.historyOffset=ui.historyOffset+7;Paint(false)end,false,L("Следующие отчеты.","Next reports."));ui.historyDown:SetSize(30,24);ui.historyDown:SetPoint("BOTTOMRIGHT",-8,10)
    ui.background=Button(ui,"",function()if not ns.SetBackgroundEnabled(not ns.BackgroundEnabled()) then print(L("Фоновый сбор сейчас недоступен.","Background collection is currently unavailable."))end;Paint(false)end,false,L("По умолчанию выключен. Раз в 5 секунд читает один общий счетчик. При его росте читает аддоны и сохраняет эпизод; без покадровой записи и снимков памяти. Во время подробного замера фоновая проверка пропускается.","Off by default. Reads one combined counter every 5 seconds; when it grows, reads addons and saves an episode. No per-frame recording or memory scans. Background checks are skipped during a detailed capture."));ui.background:SetSize(165,25);ui.background:SetPoint("BOTTOMLEFT",18,9)
    local ownHint=Label(ui,L("Perf включен в общие показатели","Perf is included in overall results"),11,T.muted);ownHint:SetPoint("BOTTOMRIGHT",-18,15)
    ui:HookScript("OnShow",function()
        if not prefs then ui:SetScale(math.min(1,math.max(.35,math.min((UIParent:GetWidth()-12)/width,(UIParent:GetHeight()-12)/height))))end
        Paint(true);Schedule()
    end)
    ui:SetScript("OnHide",function()
        if ui.timer then ui.timer:Cancel();ui.timer=nil end
        if dialog then dialog:Hide()end
        if ui.phase2 then ui.phase2:HideDialogs()end
        if ui.developer then ui.developer:HideDialogs()end
        ui:StopMovingOrSizing();ui.search:ClearFocus()
        if W and T.ClosePicker then T:ClosePicker()end
    end)
    if prefs then prefs:Bind(ui)end
    ns.window=ui
    if ns.BuildPhase2UI then
        ui.phase2=ns.BuildPhase2UI(ui,{Label=Label,Button=Button,Sidebar=Sidebar,Describe=Describe,Hover=Hover,Selected=Selected,QuietRow=QuietRow,
            Text=Text,Enable=Enable,Value=Value,Clock=Clock,Record=Record,PaintTable=PaintTable,Input=Input,Header=Header,
            Picker=Picker,Paint=Paint,Schedule=Schedule,Switch=Switch,OpenDialog=function(kind)OpenDialog(kind)end,
            Theme=T,Widgets=W,Color=Color,Tip=Tip,Window=Window,Scroll=Scroll,Progress=Progress,DataTexture=DataTexture,DataLine=DataLine,Secondary=teal,BindDialog=BindDialog})
    end
    if ns.BuildDeveloperUI then
        ui.developer=ns.BuildDeveloperUI(ui,{Label=Label,Button=Button,Panel=Panel,Sidebar=Sidebar,Describe=Describe,Hover=Hover,Selected=Selected,
            Text=Text,Enable=Enable,Value=Value,Input=Input,Header=Header,Picker=Picker,Paint=Paint,Schedule=Schedule,Switch=Switch,Theme=T,Widgets=W,Tip=Tip,Window=Window,Scroll=Scroll,BindDialog=BindDialog})
    end
end

function ns.Toggle()
    if not db then return end
    if not ui then BuildWindow()end
    ui:SetShown(not ui:IsShown())
end
function ns.OpenDeveloper()
    if not db then return end
    if not ui then BuildWindow()end
    ui:Show();Switch("developer")
end
local function BuildStartupWindow()
    local startupWidth,startupHeight=920,640
    local panelWidth,contentWidth=startupWidth-40,startupWidth-88
    local window=Window(UIParent,"Sintezza_PerfStartupWindow")
    window:SetSize(startupWidth,startupHeight);window:SetPoint("CENTER");window:SetFrameStrata("FULLSCREEN_DIALOG")
    window:SetClampedToScreen(true);window:SetMovable(true);window:EnableMouse(true);window:Hide()
    UISpecialFrames[#UISpecialFrames+1]=window:GetName()
    local header=Header(window,L("Вход и перезагрузка","Login and reload timing"),function()window:Hide()end)
    Describe(header.close,L("Закрыть","Close"),L("Закрыть отчет загрузки. ПКМ на значке миникарты также закрывает это окно.","Close the loading report. Right-clicking the minimap icon also closes this window."))
    header:EnableMouse(true)
    header:SetScript("OnMouseDown",function(_,button)
        if button=="LeftButton" and not InCombatLockdown() and (not prefs or prefs:CanMove()) then window:StartMoving() end
    end)
    header:SetScript("OnMouseUp",function()window:StopMovingOrSizing()end)
    Describe(header,L("Перемещение окна","Move window"),L("Перетащите заголовок вне боя.","Drag the header outside combat."))
    window.reportPicker=Button(window,"",function(owner)
        local choices={}
        for _,record in ipairs(ns.History()) do
            if record.kind=="startup" then
                choices[#choices+1]={value=record.id,label=date("%d.%m %H:%M",record.timestamp).." · "..record.name}
            end
        end
        if #choices>0 then Picker(owner,choices,window.recordID,function(id)window.recordID=id;window:Refresh()end) end
    end,false,L("Сохраненные входы и перезагрузки.","Saved logins and UI reloads."))
    window.reportPicker.perfTooltip[1]=L("Выбор замера","Choose a recording")
    window.reportPicker:SetPoint("TOPLEFT",20,-65);window.reportPicker:SetWidth(330)
    if W and T.DropdownArrow then T:DropdownArrow(window.reportPicker,window.reportPicker.text) end
    window.scope=Label(window,"",12,T.muted);window.scope:SetPoint("TOPLEFT",20,-106);window.scope:SetWidth(panelWidth);window.scope:SetWordWrap(true)
    local summary=Sidebar(window);summary:SetPoint("TOPLEFT",20,-146);summary:SetSize(panelWidth,62)
    window.values={}
    local labels={L("Измеренный интервал","Measured interval"),L("До PLAYER_LOGIN","Before PLAYER_LOGIN"),L("После PLAYER_LOGIN","After PLAYER_LOGIN")}
    for index,title in ipairs(labels) do
        local field=CreateFrame("Frame",nil,summary);field:SetPoint("TOPLEFT",(index-1)*panelWidth/3,0);field:SetSize(panelWidth/3,62)
        local label=Label(field,title,11,T.muted);label:SetPoint("TOPLEFT",10,-8);label:SetWidth(panelWidth/3-20)
        local value=Label(field,"",21);value:SetPoint("TOPLEFT",10,-28);value:SetWidth(panelWidth/3-20);window.values[index]=value
        field:EnableMouse(true);Describe(field,title,function()return window.scope:GetText()end)
    end
    window.output=Input(window);window.output:SetMultiLine(true);window.output:SetWidth(startupWidth-60)
    window.scroll=Scroll(window,window.output,true);window.scroll:SetPoint("TOPLEFT",20,-224);window.scroll:SetPoint("BOTTOMRIGHT",-38,62)
    window.output:SetScript("OnTextChanged",function(self,user)
        if user then self:SetText(window.reportText or "")end
    end)
    window.output:SetScript("OnEscapePressed",function()window:Hide()end)
    window.chainPanel=Sidebar(window);window.chainPanel:SetPoint("TOPLEFT",20,-224);window.chainPanel:SetPoint("BOTTOMRIGHT",-20,62)
    local chainTitle=Label(window.chainPanel,L("Цепочка загрузки","Loading chain"),14,T.accent)
    chainTitle:SetPoint("TOPLEFT",12,-10)
    window.chainNote=Label(window.chainPanel,"",11,T.muted)
    window.chainNote:SetPoint("TOPLEFT",12,-31);window.chainNote:SetWidth(panelWidth-24)
    window.chainBody=CreateFrame("Frame",nil,window.chainPanel);window.chainBody:SetSize(contentWidth,1)
    window.chainScroll=Scroll(window.chainPanel,window.chainBody,true)
    window.chainScroll:SetPoint("TOPLEFT",12,-52);window.chainScroll:SetPoint("BOTTOMRIGHT",-28,12)
    window.chainUnits={}
    local measure=Label(window.chainBody,"",12);measure:SetWordWrap(false);measure:Hide()
    window.chainHelp=Hover(window.chainPanel,chainTitle,L("Как читать цепочку","Reading the chain"),L("В звене указаны название и время до следующей отметки: мс до одной секунды, затем с. Время включает всю работу между событиями, а не загрузку одного аддона. #1–3 выделяют самые долгие переходы на их местах. Копирование сохраняет весь отчет.","Each link shows its name and time to the next marker: ms below one second, then s. Time includes all work between events, not one addon's loading time. #1–3 highlight the longest links in their original positions. Copy text keeps the complete report."))
    local function ChainUnit(index)
        local unit=window.chainUnits[index]
        if unit then return unit end
        unit=CreateFrame("Frame",nil,window.chainBody)
        unit.card=Sidebar(unit)
        unit.card:SetPoint("TOPLEFT")
        unit.highlight=DataTexture(unit.card,"accentDim","BACKGROUND")
        unit.highlight:SetPoint("TOPLEFT",1,-1);unit.highlight:SetPoint("BOTTOMRIGHT",-1,1)
        unit.name=Label(unit.card,"",12);unit.name:SetPoint("LEFT",6,0)
        unit.time=Label(unit.card,"",12,T.muted);unit.time:SetPoint("RIGHT",-6,0);unit.time:SetWordWrap(false)
        unit.arrow=CreateFrame("Frame",nil,unit);unit.arrow:SetPoint("LEFT",unit.card,"RIGHT",4,0);unit.arrow:SetSize(14,12)
        unit.arrow:SetAlpha(.55)
        unit.lines={}
        if W and T.Glyph then
            unit.glyph=T:Glyph(unit.arrow,"chevron",18,T.muted);unit.glyph:SetPoint("CENTER")
            if shared.SnapTexture then shared:SnapTexture(unit.glyph)end
        else
            for part,p in ipairs({{4,-2,8,-6},{8,-6,4,-10}})do
                local line=DataLine(unit.arrow,"muted",1)
                if line then line:SetStartPoint("TOPLEFT",unit.arrow,p[1],p[2]);line:SetEndPoint("TOPLEFT",unit.arrow,p[3],p[4]);unit.lines[part]=line end
            end
        end
        unit.card:EnableMouse(true)
        Describe(unit.card,L("Отметка загрузки","Loading marker"),function()
            if not unit.step then return ""end
            local text=ns.StartupStepName(unit.step,window.chainRecord).."\n"..L("От начала замера: ","From measurement start: ")..Value(unit.step.at,"%.3f")..L(" с."," s.")
            local nextStep=window.chainNodes[unit.index+1]
            if nextStep then text=text..L("\nДо ","\nTo ")..ns.StartupStepName(nextStep,window.chainRecord)..": "..ns.StartupCompactTime(window.chainNodes,unit.index)..L(". Это вся работа между событиями.",". Includes all work between events.")end
            if unit.rank then text=text..L("\nМесто по длительности: #","\nDuration rank: #")..unit.rank end
            if unit.index==#window.chainNodes-1 and window.chainRecord.startup.traceOmitted>0 then text=text..L("\nПропущено отметок внутри перехода: ","\nMarkers omitted within this link: ")..window.chainRecord.startup.traceOmitted end
            return text
        end)
        window.chainUnits[index]=unit
        return unit
    end
    function window:PaintChain()
        local nodes=self.chainNodes or{}
        local available=self.chainBody:GetWidth()
        local x,y,rowHeight=0,2,0
        for index,step in ipairs(nodes)do
            local unit=ChainUnit(index)
            if unit.step~=step then HideTip(unit.card)end
            unit.step,unit.index,unit.rank=step,index,self.chainRanks[index]
            local name=ns.StartupStepName(step,self.chainRecord)
            local elapsed=ns.StartupCompactTime(nodes,index)
            if elapsed and index==#nodes-1 and (self.chainRecord.startup.traceOmitted or 0)>0 then elapsed=elapsed.." *"end
            local time=elapsed and (unit.rank and "#"..unit.rank.." · "or "")..elapsed or ""
            measure:SetText(time);local timeWidth=elapsed and math.ceil(measure:GetStringWidth())+2 or 0
            measure:SetText(name);local naturalName=math.ceil(measure:GetStringWidth())+2
            local tail=elapsed and 18 or 0
            local fixed=elapsed and timeWidth+20 or 12
            local nameWidth=math.min(naturalName,math.max(1,available-fixed-tail))
            unit.name:SetText(name);unit.name:SetWidth(nameWidth);unit.name:SetWordWrap(nameWidth<naturalName)
            unit.name:SetHeight(0);local nameHeight=unit.name:GetStringHeight()+2;unit.name:SetHeight(nameHeight)
            unit.time:SetText(time);unit.time:SetWidth(timeWidth);unit.time:SetShown(elapsed~=nil)
            local h=math.max(24,nameHeight+6)
            local cardWidth=nameWidth+fixed
            local unitWidth=cardWidth+tail
            if x>0 and x+unitWidth>available then x=0;y=y+rowHeight+6;rowHeight=0 end
            unit:ClearAllPoints();unit:SetPoint("TOPLEFT",x,-y);unit:SetSize(unitWidth,h)
            unit.card:SetSize(cardWidth,h);unit.arrow:SetShown(elapsed~=nil)
            unit.highlight:SetShown(unit.rank~=nil)
            Color(unit.card,"SetBackdropColor",T.input,.22)
            Color(unit.card,"SetBackdropBorderColor",unit.rank and T.accent or T.lineSoft,unit.rank and .6 or .22)
            Color(unit.name,"SetTextColor",unit.rank and T.accent or T.text)
            Color(unit.time,"SetTextColor",unit.rank and T.accent or T.muted)
            unit:Show();x=x+unitWidth+6;rowHeight=math.max(rowHeight,h)
        end
        for index=#nodes+1,#self.chainUnits do
            local unit=self.chainUnits[index];HideTip(unit.card);unit.step=nil;unit:Hide()
        end
        self.chainBody:SetHeight(math.max(1,y+rowHeight+4))
    end
    if shared and shared.TrackAppearance then shared:TrackAppearance(window.chainBody,"state",function()if window:IsShown()then window:PaintChain()end end)end
    local function View(view)
        window.view=view=="chain"and window.chainNodes and "chain"or "details"
        window.output:ClearFocus()
        Selected(window.chainTab,window.view=="chain");Selected(window.detailsTab,window.view=="details")
        window.chainPanel:SetShown(window.view=="chain");window.scroll:SetShown(window.view~="chain")
    end
    window.chainTab=Button(window,L("Цепочка","Chain"),function()View("chain")end,false,L("Отметки загрузки в порядке наблюдения.","Loading markers in their observed order."))
    window.chainTab:SetPoint("TOPRIGHT",-148,-65);window.chainTab:SetWidth(120)
    window.detailsTab=Button(window,L("Подробности","Details"),function()View("details")end,false,L("Пояснения и текстовый отчет. Копирование включает всю цепочку.","Explanation and plain-text report. Copying includes the entire chain."))
    window.detailsTab:SetPoint("TOPRIGHT",-20,-65);window.detailsTab:SetWidth(120)
    window.copy=Button(window,L("Копировать текст","Copy text"),function()
        local record=ns.FindRecord(window.recordID)
        if record then HideTip(window.copy);OpenDialog("copy",record)else window:Refresh()end
    end,true,L("Открывает полный отчет с выделенным текстом. Нажмите Ctrl+C в открывшемся окне, затем вставьте отчет.","Open the complete report with its text selected. Press Ctrl+C in that window, then paste the report."))
    window.copy:SetWidth(170);window.copy:SetPoint("BOTTOMLEFT",20,18)
    Enable(window.copy,false)
    local close=Button(window,L("Закрыть","Close"),function()window:Hide()end,false,L("Закрыть окно отчета загрузки.","Close the loading report window."))
    close:SetPoint("BOTTOMRIGHT",-20,18)
    function window:Refresh()
        local record=self.recordID and ns.FindRecord(self.recordID)
        if not record or record.kind~="startup" then
            record=nil
            for _,entry in ipairs(ns.History()) do if entry.kind=="startup" then record=entry;break end end
        end
        self.recordID=record and record.id
        if self.chainRecord~=record then
            self.chainNodes=ns.StartupChain(record);self.chainRanks=ns.StartupLongestLinks(self.chainNodes);self.chainRecord=record
        end
        if self.renderedRecordID~=self.recordID then self.view=self.chainNodes and "chain"or "details"end
        self.renderedRecordID=self.recordID
        if not self.chainNodes then self.view="details"end
        Enable(self.chainTab,self.chainNodes~=nil)
        local omitted=record and record.startup.traceOmitted or 0
        local note=L("Время до следующей отметки · #1–3: самые долгие переходы","Time to next marker · #1–3: longest links")
        if omitted>0 then note=note..L(" · * пропущено: "," · * omitted: ")..omitted end
        self.chainNote:SetText(note)
        self.chainScroll:SetVerticalScroll(0);self:PaintChain()
        Text(self.reportPicker,record and date("%d.%m %H:%M",record.timestamp).." · "..record.name or L("Отчетов загрузки пока нет","No loading reports yet"))
        Enable(self.reportPicker,record~=nil);Enable(self.copy,record~=nil)
        self.scope:SetText(record and ns.StartupScope(record)or L("Отчет появится после следующего входа или перезагрузки интерфейса.","A report will appear after the next login or UI reload."))
        local before=record and record.startup.beforeLogin
        local after=before and math.max(0,record.duration-(record.startup.reloadLead or 0)-before)
        for index,value in ipairs({record and record.duration or false,before or false,after or false}) do
            self.values[index]:SetText(Value(value,"%.2f")..(value and L(" с"," s")or ""))
        end
        self.reportText=record and ns.StartupDetails(record,true)or L("Замер начинается с первого кода Perf. Команда /sperf reload ставит отметку перед перезагрузкой.\n\nСохраненные отчеты доступны и в «Истории» основного окна.","Measurement starts with Perf's first code. /sperf reload marks time before reloading.\n\nSaved reports are also available in the main window's History.")
        self.output:SetText(self.reportText)
        self.output:HighlightText(0,0)
        self.output:SetHeight(math.max(310,(select(2,self.reportText:gsub("\n",""))+math.ceil(#self.reportText/70))*16+30))
        self.scroll:SetVerticalScroll(0)
        View(self.view)
    end
    window:HookScript("OnShow",function(self)self:Refresh()end)
    window:SetScript("OnHide",function(self)
        self:StopMovingOrSizing();self.output:ClearFocus()
        if dialog and dialog.body==dialog.pages.copy then dialog:Hide()end
        if W and T.ClosePicker then T:ClosePicker()end
    end)
    if prefs then prefs:Bind(window,{defaultLayer="FULLSCREEN_DIALOG"})
    else window:SetScale(math.min(1,(UIParent:GetWidth()-24)/startupWidth,(UIParent:GetHeight()-24)/startupHeight)) end
    return window
end
function ns.ToggleStartup()
    if not db then return end
    startupWindow=startupWindow or BuildStartupWindow()
    startupWindow:SetShown(not startupWindow:IsShown())
end
ns.OnDataChanged=function()if ui and ui:IsShown()then Paint(false);Schedule()end end
ns.OnHistoryChanged=function(record)
    if ui then if ui.view=="capture" then ui.selectedID=record.id end;ui.dirty=true end
    if startupWindow and startupWindow:IsShown() and record.kind=="startup" then startupWindow.recordID=record.id;startupWindow:Refresh()end
end

local function MinimapShown()return not db.minimap.hide end
local function SetMinimap(shown)db.minimap.hide=not shown;if launcher then launcher:SetShown(shown)end end
function ns.ToggleMinimap()SetMinimap(not MinimapShown())end
local function CreateLauncher()
    if not Minimap then return end
    local function click(_,button)if button=="LeftButton"then ns.Toggle()end end
    local function tooltip(tip)
        tip:AddLine("Sintezza Perf")
        if shared and shared.AddMinimapToggleHint then shared:AddMinimapToggleHint(tip)else tip:AddLine(L("ЛКМ: открыть или закрыть окно.","Left-click to open or close the window."))end
        tip:AddLine(L("ПКМ: открыть или закрыть отчет загрузки.","Right-click to open or close the loading report."))
    end
    if shared and shared.CreateMinimapButton then launcher=shared:CreateMinimapButton(addon,icon,db.minimap,click,tooltip)
    else
        launcher=CreateFrame("Button",addon.."MinimapButton",Minimap);launcher:SetSize(28,28);launcher:SetPoint("BOTTOMLEFT",2,1);launcher:SetNormalTexture(icon)
        launcher:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");launcher:SetScript("OnClick",click)
        launcher:SetScript("OnEnter",function(self)if GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_LEFT");tooltip(GameTooltip);GameTooltip:Show()end end)
        launcher:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end);launcher:SetShown(MinimapShown())
    end
    if launcher then
        launcher:RegisterForClicks("LeftButtonUp","RightButtonUp")
        launcher:HookScript("OnClick",function(_,button)if button=="RightButton"then ns.ToggleStartup()end end)
    end
end
local function SettingsContent(parent)
    parent.perfSettings={}
    local function Row(y,title,description,help)
        local row=CreateFrame("Frame",nil,parent);row:SetPoint("TOPLEFT",18,-y);row:SetPoint("TOPRIGHT",-18,-y);row:SetHeight(70)
        local label=Label(row,title,13);label:SetPoint("TOPLEFT",0,0);label:SetPoint("TOPRIGHT",-180,0);label:SetWordWrap(false)
        local detail=Label(row,description,11,T.muted);detail:SetPoint("TOPLEFT",0,-23);detail:SetPoint("TOPRIGHT",-180,-23);detail:SetWordWrap(true)
        Hover(row,label,title,help);Hover(row,detail,title,help)
        return row
    end
    local function Toggle(row,title,get,set,help,key)
        local b,Refresh
        local function Commit(value)set(value);Refresh()end
        if W and W.Toggle then
            b=W:Toggle(row,"",get,Commit,nil,true,"inline")
            Refresh=function()b.label:SetText(get()and L("Включен","On")or L("Выключен","Off"));b:Refresh(false)end
        else
            b=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate");b:SetSize(28,28)
            b.text=Label(row,"",12);b.text:SetPoint("RIGHT",b,"LEFT",-8,0)
            Refresh=function()b:SetChecked(get());b.text:SetText(get()and L("Включен","On")or L("Выключен","Off"))end
            b:SetScript("OnClick",function(self)Commit(self:GetChecked()==true)end)
        end
        if W and W.Toggle then b:SetSize(160,30)end
        b:SetPoint("TOPRIGHT",0,2);b:HookScript("OnShow",Refresh);Describe(b,title,help)
        parent.perfSettings[key]=b;Refresh()
    end
    local backgroundHelp=L("По умолчанию выключен. Даже при закрытом окне проверяет общий счетчик раз в 5 секунд. При его росте читает аддоны и сохраняет легкий эпизод. Это не подробная покадровая запись; память не сканируется.","Off by default. Even with the window closed, checks one combined counter every 5 seconds. When it grows, reads addons and saves a light episode. This is not detailed per-frame recording; memory is not scanned.")
    local backgroundRow=Row(66,L("Ловить спайки в фоне","Watch spikes in background"),L("Раз в 5 с, в том числе при закрытом окне.","Every 5 s, including while the window is closed."),backgroundHelp)
    Toggle(backgroundRow,L("Фоновый сбор","Background collection"),ns.BackgroundEnabled,function(v)
        if not ns.SetBackgroundEnabled(v)then print(L("Фоновый сбор сейчас недоступен.","Background collection is currently unavailable."))end
    end,backgroundHelp,"background")
    local memoryHelp=L("Автоматически: не чаще раза в минуту, только на открытой вкладке «Нагрузка». Только по кнопке: новый снимок делает «Обновить память». В обоих режимах снимки откладываются в бою и во время замера. Чужое обновление общего кеша может появиться независимо.","Automatic: at most once per minute, only while Load is visible. Button only: Refresh memory requests a new snapshot. Both modes defer scans during combat and captures. Other addons can independently refresh the shared cache.")
    local memoryRow=Row(146,L("Снимки памяти","Memory snapshots"),L("В бою и во время записи новые снимки отложены.","New snapshots wait during combat and recording."),memoryHelp)
    local memoryButton
    local function RefreshMemoryMode()Text(memoryButton,db.memoryManual and L("Только по кнопке","Button only")or L("Автоматически","Automatic"))end
    memoryButton=Button(memoryRow,"",function(self)
        Picker(self,{{value=false,label=L("Автоматически","Automatic")},{value=true,label=L("Только по кнопке","Button only")}},db.memoryManual,function(v)db.memoryManual=v;RefreshMemoryMode()end)
    end,false,memoryHelp)
    memoryButton:SetSize(160,30);memoryButton:SetPoint("TOPRIGHT",0,2);memoryButton:HookScript("OnShow",RefreshMemoryMode);parent.perfSettings.memory=memoryButton;RefreshMemoryMode()
    local historyHelp=L("Хранится 20, 50 или 100 отчетов нагрузки, отдельно 10 загрузок и до 10 закрепленных. Самые старые незакрепленные записи удаляются первыми. Каждый отчет нагрузки ограничен 256 строками и 120 интервалами.","Keep 20, 50 or 100 performance reports, separately 10 loading reports and up to 10 pinned reports. Oldest unpinned records are removed first. Each performance report is limited to 256 rows and 120 intervals.")
    local historyRow=Row(226,L("Хранить отчетов","Reports to keep"),L("Закрепленные: до 10 дополнительно.","Pinned reports: up to 10 extra."),historyHelp)
    local limit=Button(historyRow,"",function(self)
        Picker(self,{{value=20,label="20"},{value=50,label="50"},{value=100,label="100"}},db.historyLimit,function(v)db.historyLimit=v;ns.TrimHistory();Text(self,tostring(v));if ui and ui:IsShown()then Paint(false)end end)
    end,false,historyHelp)
    limit:SetSize(160,30);limit:SetPoint("TOPRIGHT",0,2);Text(limit,tostring(db.historyLimit));parent.perfSettings.history=limit
    limit:HookScript("OnShow",function(self)Text(self,tostring(db.historyLimit))end)
    local minimapHelp=L("Показывает кнопку Perf у миникарты. ЛКМ открывает или закрывает основное окно, ПКМ открывает или закрывает отчет загрузки.","Show the Perf minimap button. Left-click toggles the main window. Right-click toggles the loading report.")
    local minimapRow=Row(306,L("Значок у миникарты","Minimap icon"),L("Кнопка открытия Perf. Не влияет на сбор.","Perf launcher. Does not change collection."),minimapHelp)
    Toggle(minimapRow,L("Значок у миникарты","Minimap icon"),MinimapShown,SetMinimap,minimapHelp,"minimap")
    local note=Label(parent,L("Запись настраивается кнопкой «Новый замер».\nСкрытое окно не обновляет таблицы. Работающий замер продолжится.","Configure recording with New capture.\nA hidden window stops redrawing tables; an active capture continues."),11,T.muted)
    note:SetPoint("TOPLEFT",18,-390);note:SetPoint("TOPRIGHT",-18,-390);note:SetWordWrap(true)
    Hover(parent,note,L("Нагрузка самого Perf","Perf overhead"),L("В фоне нет покадрового обхода аддонов. Подробный замер ограничен по времени и остановится при средней стоимости сборщика >1 мс за 60 кадров или разовой >20 мс. Этот лимит не включает отрисовку окна.","Background mode does not poll addons every frame. Detailed recording is time-limited and stops if collector cost averages >1 ms over 60 frames or one pass exceeds 20 ms. This budget does not include window rendering."))
end
OpenDialog=function(kind,selectedRecord)
    if dialog then dialog:Hide()end
    local record=selectedRecord or ui and Record()
    if kind=="comparison" then record={comparison=true} end
    if kind=="conditions" then record={conditions=true} end
    if kind~="settings" and not record then return end
    if not dialog then
        dialog=Window(UIParent,"Sintezza_PerfDialog");dialog:Hide();dialog:SetFrameStrata("FULLSCREEN_DIALOG");dialog:SetClampedToScreen(true);dialog:EnableMouse(true);dialog:SetMovable(true);dialog.pages={}
        dialog:HookScript("OnHide",function(self)self:StopMovingOrSizing()end)
        UISpecialFrames[#UISpecialFrames+1]=dialog:GetName()
    end
    if dialog.body then dialog.body:Hide()end
    dialog.record=record
    local wide=kind=="export" or kind=="comparison" or kind=="conditions" or kind=="copy"
    dialog:SetSize(wide and 650 or kind=="settings" and 600 or 480,wide and 470 or kind=="settings" and 455 or 195)
    if not dialog.perfMoved then dialog:ClearAllPoints();dialog:SetPoint("CENTER",kind=="copy"and startupWindow or ui or UIParent,"CENTER")end
    BindDialog(dialog)
    if kind=="copy"and not prefs and startupWindow then dialog:SetScale(startupWindow:GetScale())end
    if dialog.pages[kind] then
        dialog.body=dialog.pages[kind];dialog.body:Show();dialog:Show();if dialog.body.Refresh then dialog.body:Refresh()end
        if dialog.body.FocusText then dialog.body.FocusText()end
        return
    end
    local body=CreateFrame("Frame",nil,dialog);body:SetAllPoints();dialog.body=body;dialog.pages[kind]=body
    local titles={settings=L("Сбор и хранение","Collection and retention"),export=L("Экспорт замера","Export report"),copy=L("Копирование отчета","Copy report"),comparison=L("Экспорт сравнения","Export comparison"),conditions=L("Записанные условия","Recorded conditions"),rename=L("Название замера","Capture name"),delete=L("Удалить отчет?","Delete report?")}
    local header=Header(body,titles[kind],function()dialog:Hide()end)
    body.header=header;header:EnableMouse(true)
    header:SetScript("OnMouseDown",function(_,button)
        if button=="LeftButton"and not InCombatLockdown()then dialog:StartMoving();dialog.perfMoved=true end
    end)
    header:SetScript("OnMouseUp",function()dialog:StopMovingOrSizing()end)
    Describe(header,L("Перемещение окна","Move window"),L("Перетащите заголовок левой кнопкой мыши. Перемещение доступно вне боя; положение сохраняется до /reload.","Drag the header with the left mouse button outside combat. The position is kept until /reload."))
    Describe(header.close,L("Закрыть","Close"),L("Закрывает диалог. Не удаляет отчет и не останавливает текущую запись.","Close this dialog without deleting a report or stopping recording."))
    if kind=="settings"then SettingsContent(body)
    elseif kind=="delete"then
        local name=Label(body,record.name,13);name:SetPoint("TOPLEFT",18,-65);name:SetPoint("TOPRIGHT",-18,-65);name:SetWordWrap(true)
        body.Refresh=function()name:SetText(dialog.record.name)end
        local cancel=Button(body,L("Отмена","Cancel"),function()dialog:Hide()end,false,L("Оставляет отчет в истории.","Keep the report in history."));cancel:SetPoint("BOTTOMLEFT",18,20)
        local remove=Button(body,L("Удалить отчет","Delete report"),function()ns.DeleteRecord(dialog.record.id);dialog:Hide();Paint(false)end,false,L("Безвозвратно удаляет только этот отчет. Остальная история и настройки не меняются.","Permanently remove only this report. Other history and settings stay unchanged."));remove:SetWidth(145);remove:SetPoint("BOTTOMRIGHT",-18,20)
    elseif kind=="rename"then
        local edit=Input(body);edit:SetPoint("TOPLEFT",18,-65);edit:SetPoint("TOPRIGHT",-18,-65);edit:SetMaxLetters(60);edit:SetText(record.name)
        local errorLabel=Label(body,"",11,T.accent);errorLabel:SetPoint("TOPLEFT",18,-104)
        local function Save()if ns.RenameRecord(dialog.record.id,edit:GetText())then dialog:Hide();Paint(false)else errorLabel:SetText(L("Введите название.","Enter a name."))end end
        body.Refresh=function()edit:SetText(dialog.record.name);errorLabel:SetText("");edit:SetFocus();edit:HighlightText()end
        edit:SetScript("OnEnterPressed",Save);edit:SetScript("OnEscapePressed",function()dialog:Hide()end)
        local save=Button(body,L("Сохранить","Save"),Save,true,L("Сохраняет название отчета, до 60 символов.","Save the report name, up to 60 characters."));save:SetPoint("BOTTOMRIGHT",-18,18)
        Describe(edit,L("Название","Name"),L("Например, проверяемое действие или настройка. Enter сохраняет, Escape отменяет.","For example, the action or setting being checked. Enter saves; Escape cancels."))
        dialog:Show();edit:SetFocus();edit:HighlightText();return
    else
        local format="text"
        local edit=Input(body);edit:SetMultiLine(true);edit:SetWidth(dialog:GetWidth()-(W and 62 or 48));edit:SetHeight(500)
        body.output=edit
        local scroll=Scroll(body,edit);scroll:SetPoint("TOPLEFT",18,-97);scroll:SetPoint("BOTTOMRIGHT",W and -32 or -18,61);scroll:EnableMouseWheel(true)
        local output=""
        local function Refresh()
            output=dialog.record.comparison and ns.ExportComparison(format) or dialog.record.conditions and ns.ExportConditions() or ns.Export(dialog.record,format);edit:SetText(output);edit:SetHeight(math.max(300,(select(2,output:gsub("\n",""))+math.ceil(#output/70))*15+20));scroll:SetVerticalScroll(0)
        end
        edit:SetScript("OnTextChanged",function(self,user)if user then self:SetText(output)end end)
        edit:SetScript("OnEscapePressed",function()dialog:Hide()end)
        if not W then scroll:SetScript("OnMouseWheel",function(self,delta)self:SetVerticalScroll(math.max(0,math.min(edit:GetHeight()-self:GetHeight(),self:GetVerticalScroll()-delta*45)))end)end
        local formatButton=Button(body,L("Текст для автора","Text for author"),function(self)format=format=="text"and"json"or"text";Text(self,format=="json"and"JSON"or L("Текст для автора","Text for author"));Refresh()end,false,L("Переключает человекочитаемый текст и JSON. Данные относятся только к выбранному отчету; отсутствующие измерения в JSON обозначаются null.","Switch human-readable text and JSON. Data belongs only to the selected report; missing measurements are null in JSON."));formatButton:SetSize(180,27);formatButton:SetPoint("TOPLEFT",18,-59)
        local actionLabel=kind=="copy"and L("Закрыть","Close")or L("Выделить текст","Select text")
        local actionHelp=kind=="copy"and L("Закрыть окно копирования. Escape также закрывает его.","Close the copy window. Escape also closes it.")or L("Выделяет отчет. Нажмите Ctrl+C, затем вставьте текст вне игры. Аддон не отправляет отчет автоматически.","Select the report, then press Ctrl+C and paste outside the game. No report is sent automatically.")
        local selectButton=Button(body,actionLabel,function()
            if kind=="copy"then dialog:Hide()else edit:SetFocus();edit:HighlightText()end
        end,kind~="copy",actionHelp);selectButton:SetWidth(150);selectButton:SetPoint("BOTTOMRIGHT",-18,17)
        if kind=="conditions"or kind=="copy"then formatButton:Hide()end
        local hint=Label(body,kind=="copy"and L("Escape закрывает окно.","Escape closes this window.")or L("Выделите текст и нажмите Ctrl+C","Select the text and press Ctrl+C"),11,T.muted);hint:SetPoint("BOTTOMLEFT",18,24)
        if kind=="copy"then
            local instruction=Label(body,L("Текст выделен. Нажмите Ctrl+C, чтобы скопировать отчет.","Text selected. Press Ctrl+C to copy the report."),12,T.accent)
            instruction:SetPoint("TOPLEFT",18,-65);instruction:SetPoint("TOPRIGHT",-18,-65);instruction:SetWordWrap(true)
            body.FocusText=function()edit:SetFocus();edit:HighlightText()end
            Describe(edit,L("Копирование через Ctrl+C","Copy with Ctrl+C"),L("Текст уже выделен. Ctrl+C копирует его средствами клиента. Escape закрывает окно.","The text is already selected. Ctrl+C copies it through the client. Escape closes this window."))
            dialog:HookScript("OnHide",function()edit:ClearFocus()end)
        end
        body.Refresh=Refresh
        Refresh()
    end
    dialog:Show()
    if body.FocusText then body.FocusText()end
end
local function RegisterSettings()
    if not(Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory)then return end
    local panel=CreateFrame("Frame");panel:Hide()
    panel:SetScript("OnShow",function(self)
        if self.built then return end;self.built=true
        local title=Label(self,"Sintezza Perf",22,T.text,"display");title:SetPoint("TOPLEFT",18,-16)
        SettingsContent(self)
    end)
    category=Settings.RegisterCanvasLayoutCategory(panel,"Sintezza Perf");Settings.RegisterAddOnCategory(category)
end
local startup=CreateFrame("Frame")
startup:RegisterEvent("ADDON_LOADED")
startup:SetScript("OnEvent",function(self,event,name)
    if event=="PLAYER_LOGIN"then self:UnregisterEvent(event);if db.background then ns.SetBackgroundEnabled(true)end;return end
    if name~=addon then return end
    self:UnregisterEvent(event)
    if type(Sintezza_PerfDB)~="table"then Sintezza_PerfDB={}end
    db=Sintezza_PerfDB;ns.InitHistory(db);ns.InitCollector(db);if ns.InitDeveloperHistory then ns.InitDeveloperHistory(db)end;CreateLauncher();RegisterSettings()
    if db.background and not ns.BackgroundAvailable()then self:RegisterEvent("PLAYER_LOGIN")end
end)
