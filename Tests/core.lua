local checks = 0
local function check(value, message)
    assert(value, message)
    checks = checks + 1
end
local now, scans, calls, profileStep, profileTime = 0, 0, 0, .01, 0
local frames, tickers, loaded = {}, {}, { "Sintezza_Perf", "Alpha", "Beta" }
local secret = {}
function issecretvalue(value) return value == secret end
function GetLocale() return "ruRU" end
function GetTime() return now end
GetTimePreciseSec = GetTime
function time() return 1794859200 + math.floor(now) end
date = os.date
local combat = false
function InCombatLockdown() return combat end
function GetFramerate() return 120 end
function GetBuildInfo() return "1.60.1", "70938" end
function debugprofilestop() profileTime = profileTime + profileStep; return profileTime end
function UpdateAddOnMemoryUsage() scans = scans + 1 end
function GetAddOnMemoryUsage() return 1024 end
function hooksecurefunc(name, callback)
    local old = _G[name]
    _G[name] = function(...) old(...); callback(...) end
end
function CreateFrame()
    local f = { scripts = {}, events = {} }
    function f:SetScript(name, callback) self.scripts[name] = callback end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:UnregisterEvent(event) self.events[event] = nil end
    frames[#frames + 1] = f
    return f
end
C_Timer = { NewTicker = function(delay, callback)
    local ticker = { delay = delay, callback = callback }
    function ticker:Cancel() self.cancelled = true end
    tickers[#tickers + 1] = ticker
    return ticker
end }
local function event(eventName, ...)
    for _, f in ipairs(frames) do if f.events[eventName] then f.scripts.OnEvent(f, eventName, ...) end end
end
local function tick(dt)
    now = now + dt
    for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, dt) end end
end
local function backgroundTick()
    now = now + 5
    for _, ticker in ipairs(tickers) do if not ticker.cancelled then ticker.callback() end end
end
C_AddOns = {
    GetNumAddOns = function() return #loaded end,
    GetAddOnInfo = function(index) return type(index) == "number" and loaded[index] or index, nil, nil, nil, nil, "INSECURE" end,
    IsAddOnLoaded = function() return true, true end,
    GetAddOnMetadata = function() return "1.0" end,
}
Enum = { AddOnProfilerMetric = {} }
for _, name in ipairs({"LastTime", "RecentAverageTime", "SessionAverageTime", "PeakTime", "CountTimeOver5Ms", "CountTimeOver10Ms", "CountTimeOver50Ms"}) do Enum.AddOnProfilerMetric[name] = name end
local counters = { overall = {5, 1, 0}, Alpha = {2, 1, 0}, Beta = {1, 0, 0}, Sintezza_Perf = {0, 0, 0} }
local readings = { overall = 8, Alpha = 3, Beta = 3, Sintezza_Perf = 2 }
local enabled = true
local function metric(name, key)
    calls = calls + 1
    if key == "LastTime" then return readings[name] end
    if key == "PeakTime" then return 9999 end
    if key == "RecentAverageTime" then return 2 end
    local index = key == "CountTimeOver5Ms" and 1 or key == "CountTimeOver10Ms" and 2 or 3
    return counters[name] and counters[name][index]
end
C_AddOnProfiler = {
    IsEnabled = function() return enabled end,
    GetAddOnMetric = metric,
    GetOverallMetric = function(key) return metric('overall', key) end,
    GetApplicationMetric = function() return 8.333 end,
}
SlashCmdList = {}
local ns = {}
assert(loadfile(ADDON_ROOT .. '/History.lua'))('Sintezza_Perf', ns)
assert(loadfile(ADDON_ROOT .. '/Analytics.lua'))('Sintezza_Perf', ns)
assert(loadfile(ADDON_ROOT .. '/Perf.lua'))('Sintezza_Perf', ns)
local storage = { minimap = {hide=true}, duration=60, windowAppearance={scale=80}, extra='keep' }
ns.InitHistory(storage); ns.InitCollector(storage)
check(storage.minimap.hide and storage.windowAppearance.scale==80 and storage.extra=='keep', 'old profile preserved')
check(storage.duration==60 and storage.historyLimit==20 and #ns.History()==0, 'defaults migrate')
local before = calls
for i=1,100 do tick(.01) end
check(calls==before and scans==0 and #tickers==0, 'idle closed work is zero')
ns.Memory(false)
check(scans==1, 'initial visible memory refresh')
ns.Memory(false)
check(scans==1, 'fresh memory cached')
combat=true; now=now+61; ns.Memory(true)
check(scans==1, 'combat forbids memory scan')
combat=false
check(ns.Start(5), 'start capture')
ns.Memory(true)
check(scans==1, 'capture forbids memory scan')
tick(.01)
before=calls
for i=1,300 do tick(1/60) end
local record, active=ns.Capture()
if active then record=ns.Stop() end
check(record.frames==300 and record.average==8 and record.peak==8, 'interval mean and peak independent of session peak')
check(record.five==300 and record.ten==0, 'combined-only spikes retained')
check(record.timeline[1].five>0 and record.timeline[1].individualFive==0, 'combined-only timeline retained')
check(record.rows[1].name=='Sintezza_Perf' and record.rows[1].average==2, 'own profiler retained')
check(calls-before==300*4, 'one read per addon plus overall per tick')
check(record.memoryTimestamp~=nil and record.memoryAge>=60, 'snapshot time and age retained')
storage.memoryManual=true
ns.Memory(false)
check(scans==2,'deferred manual request runs at next safe visible read')
ns.Memory(false)
check(scans==2,'deferred manual request consumed once')
before=calls;tick(.1);check(calls==before, 'collector detached after capture')
local json=ns.Export(record,'json')
check(json:find('"profilerIncluded":true',1,true) and json:find('"averageMs":8',1,true), 'JSON scope and totals')
check(ns.Export(record,'text'):find('Perf включен',1,true), 'localized report includes observer caveat')
check(ns.RenameRecord(record.id,'  Проверка |cffabcdefкарты  '), 'rename works')
check(record.name=='Проверка cffabcdefкарты', 'name sanitizes markup')
check(not ns.RenameRecord(record.id,'  '), 'empty rename rejected')
ns.InitHistory(storage)
check(#ns.History()==1 and ns.History()[1].average==8, 'reload migration keeps report')
ns.InitHistory(storage)
check(#ns.History()==1, 'migration idempotent')
readings.Alpha=secret
check(ns.Start(5), 'second capture starts')
tick(.01);tick(.02)
local partial=ns.Stop('manual')
local missing
for _, row in ipairs(partial.rows) do if row.name=='Alpha' then missing=row end end
check(missing.average==nil and missing.peak==nil and missing.missing==1, 'secret readings remain unavailable')
check(partial.timeline[1].addonMissing==1,'interval retains missing individual readings for honest explanation')
readings.Alpha=3
ns.SetBackgroundEnabled(true)
before=calls
for i=1,20 do backgroundTick() end
check(calls-before==20, 'unchanged background one read per five seconds')
counters.overall={8,2,0}
backgroundTick()
local episode=ns.History()[1]
check(episode.kind=='background' and episode.five==3 and episode.average==nil and episode.peak==nil, 'background preserves aggregate only')
check(episode.timeline[1].individualFive==0, 'background aggregate has no invented culprit')
check(ns.Export(episode,'json'):find('"averageMs":null',1,true), 'missing metric exported as null')
counters.overall={0,0,0}
local count=#ns.History();backgroundTick()
check(#ns.History()==count, 'counter reset is not a spike')
ns.SetBackgroundEnabled(false)
before=calls;backgroundTick();check(calls==before, 'background off cancels ticker')
profileStep=1.1
ns.Start(5);tick(.01)
for i=1,60 do tick(.01) end
local guard,running=ns.Capture()
check(not running and guard.reason=='overhead' and guard.frames==60, 'collector budget stops costly recording')
profileStep=.01
ns.Start(120);tick(.01)
collectgarbage('collect')
local heapBefore=collectgarbage('count')
for i=1,1000 do tick(.01)end
local heapGrowth=collectgarbage('count')-heapBefore
check(heapGrowth<8,'steady collector avoids per-frame table allocation')
ns.Stop('manual')
print(('Collector steady-state heap growth over 1000 frames: %.3f KiB'):format(heapGrowth))
for i=1,30 do ns.SaveRecord(record) end
check(#ns.History()==20, 'regular history bounded')
for i=1,10 do check(ns.PinRecord(ns.History()[i].id), 'pin within cap') end
check(not ns.PinRecord(ns.History()[11].id), 'pin cap enforced')
ns.SaveRecord(record)
local pins=0;for _,r in ipairs(ns.History()) do if r.pinned then pins=pins+1 end end
check(pins==10, 'retention preserves pins')
local id=ns.History()[1].id;check(ns.DeleteRecord(id) and not ns.FindRecord(id), 'delete record')
enabled=false;check(not ns.Start(5), 'unavailable API prevents capture')
check(storage.windowAppearance.scale==80, 'preferences still preserved')
print('Core mocks: PASS ('..checks..' checks, Lua '.._VERSION..')')
