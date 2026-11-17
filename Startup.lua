local addon, ns = ...
local clock = GetTimePreciseSec or GetTime
local started = clock()
local frame = CreateFrame("Frame")
local observing = true
local previousAt, previousAddon = started, nil
local loginAt, worldAt, screenAt, startupType
local gaps, addonEvents = {}, 0
local trace = { { kind = "start", at = 0 } }
local traceOmitted, omittedAtWorld, addonEventsAtWorld = 0, nil, nil
local function Trace(kind, at, name)
    if screenAt and at > screenAt then return end
    if #trace >= 127 then traceOmitted = traceOmitted + 1; return end
    trace[#trace+1] = { kind = kind, at = at - started, name = name }
end
local events = { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "LOADING_SCREEN_DISABLED", "PLAYER_LOGOUT" }
local maxReloadSeconds = 300

local function Stop()
    observing = false
    for _, event in ipairs(events) do frame:UnregisterEvent(event) end
    frame:SetScript("OnEvent", nil)
end

local function ObserveGap(at, name)
    local duration = ns.Number(at - previousAt)
    if duration and duration > 0 then
        local position = #gaps + 1
        for i, gap in ipairs(gaps) do
            if duration > gap.duration then position = i; break end
        end
        if position <= 5 then
            table.insert(gaps, position, { duration = duration, after = previousAddon, before = name })
            gaps[6] = nil
        end
    end
    previousAt, previousAddon = at, name
end

local function ReloadLead(marker)
    if startupType ~= "reload" or not GetTimePreciseSec or type(marker) ~= "table" then return end
    local at, wall = ns.Number(marker.at), ns.Number(marker.wall)
    if not at or not wall then return end
    local lead, age = started - at, time() - wall
    if lead >= 0 and lead <= maxReloadSeconds and age >= 0 and age <= maxReloadSeconds
        and math.abs(clock() - at - age) <= 2 then return lead end
end

local function Finish(at, endpoint)
    Stop()
    local storage = ns.db
    if not storage then return end
    local marker = storage.startupReload
    storage.startupReload = nil
    local observed = ns.Number(at - started)
    if not observed or observed <= 0 or not startupType then return end
    local lead = ReloadLead(marker)
    local beforeLogin = loginAt and loginAt <= at and ns.Number(loginAt - started)
    local recordedTrace = {}
    for _, step in ipairs(trace) do
        if step.at <= observed then recordedTrace[#recordedTrace+1] = step end
    end
    recordedTrace[#recordedTrace+1] = { kind = "finish", at = observed }
    local version, build = GetBuildInfo()
    ns.SaveRecord({
        kind = "startup", complete = true,
        name = startupType == "login" and ns.Text("Вход персонажа", "Character login") or ns.Text("Перезагрузка интерфейса", "UI reload"),
        build = tostring(version) .. "." .. tostring(build),
        duration = observed + (lead or 0),
        startup = { type = startupType, endpoint = endpoint, reloadLead = lead, beforeLogin = beforeLogin or nil,
            addonEvents = endpoint == "world" and addonEventsAtWorld or addonEvents, gaps = gaps, traceVersion = 1, trace = recordedTrace,
            traceOmitted = endpoint == "world" and omittedAtWorld or traceOmitted },
    })
    if ns.OnDataChanged then ns.OnDataChanged() end
end

frame:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGOUT" then Stop(); return end
    local at = ns.Number(clock())
    if not at or at < started then Stop(); return end
    if event == "ADDON_LOADED" then
        if screenAt and at > screenAt then return end
        if issecretvalue and issecretvalue(arg1) or type(arg1) ~= "string" then return end
        addonEvents = addonEvents + 1
        local name = ns.CleanText(arg1, 128)
        Trace("addon", at, name)
        if not loginAt then ObserveGap(at, name) end
    elseif event == "PLAYER_LOGIN" then
        loginAt = loginAt or at
        Trace("login", at)
        ObserveGap(at, nil)
        frame:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "LOADING_SCREEN_DISABLED" then
        if not loginAt and not worldAt then return end
        screenAt = screenAt or at
        if worldAt then Finish(screenAt, "screen") end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if issecretvalue and (issecretvalue(arg1) or issecretvalue(arg2)) then Stop(); return end
        startupType = arg2 == true and "reload" or arg1 == true and "login" or nil
        if not startupType then
            if ns.db then ns.db.startupReload = nil end
            Stop(); return
        end
        worldAt = at
        Trace("world", at)
        omittedAtWorld = traceOmitted
        addonEventsAtWorld = addonEvents
        frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if screenAt then Finish(screenAt, "screen")
        elseif C_Timer and C_Timer.After then
            C_Timer.After(5, function() if observing then Finish(worldAt, "world") end end)
        else Finish(worldAt, "world") end
    end
end)
for _, event in ipairs(events) do pcall(frame.RegisterEvent, frame, event) end

function ns.StartMeasuredReload()
    if not ns.db or not GetTimePreciseSec or type(ReloadUI) ~= "function" or not IsLoggedIn() or InCombatLockdown() then return false end
    local at = ns.Number(clock())
    if not at then return false end
    ns.db.startupReload = { at = at, wall = time() }
    local ok = pcall(ReloadUI)
    if not ok then ns.db.startupReload = nil end
    return ok
end
