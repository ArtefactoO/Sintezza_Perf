assert(loadfile(ADDON_ROOT .. '/Tests/FrameMock.lua'))()
local checks = 0
local function check(ok, label) assert(ok, label); checks = checks + 1 end
local function load(name, ns) assert(loadfile(ADDON_ROOT .. '/' .. name .. '.lua'))('Sintezza_Perf', ns) end
local timers = {}
C_Timer.After = function(delay, callback) timers[#timers+1] = {delay, callback} end
local function boot(at, storage)
    Mock.now = at
    Sintezza_PerfDB = storage or {}
    local ns = {}
    for _, file in ipairs({'Startup','History','Analytics','Perf','DeveloperHistory','Developer','Window','Phase2Window','DeveloperWindow'}) do load(file, ns) end
    Mock.event('ADDON_LOADED','Sintezza_Perf')
    return ns
end
local ns = boot(100)
Mock.now = 101; Mock.event('LOADING_SCREEN_DISABLED') -- unrelated before login
for i, stamp in ipairs({101, 103, 103.5, 104, 105, 106, 106.1}) do
    Mock.now = stamp; Mock.event('ADDON_LOADED','Addon' .. i)
end
Mock.now = 107; Mock.event('PLAYER_LOGIN')
Mock.now = 110; Mock.event('LOADING_SCREEN_DISABLED')
Mock.now = 111; Mock.event('PLAYER_ENTERING_WORLD',true,false)
local login = ns.History()[1]
check(login and login.startup.type == 'login' and login.startup.endpoint == 'screen' and login.duration == 10,'login may receive screen dismissal before entering-world event')
check(login.startup.beforeLogin == 7 and login.startup.addonEvents == 8,'first code, login and addon event scopes')
check(login.startup.traceVersion==1 and login.startup.trace[1].kind=='start'and login.startup.trace[#login.startup.trace].kind=='finish','chronological trace has explicit boundaries')
check(login.startup.trace[#login.startup.trace].at==10 and login.startup.trace[#login.startup.trace-1].kind=='login','screen before world excludes later marker')
local chain=ns.StartupChain(login)
check(chain[3].name=='Addon1'and chain[4].name=='Addon2'and chain[3].at<chain[4].at,'event chain preserves observation order rather than gap ranking')
check(ns.StartupChainText(login):find('Addon1 --2.00 с--> Addon2',1,true),'plain chain preserves elapsed edge times for copy')
check(ns.StartupCompactTime({{at=0},{at=.03}},1)=='30 мс','short display times use milliseconds')
check(ns.StartupCompactTime({{at=0},{at=.0004}},1)=='<1 мс'and ns.StartupCompactTime({{at=0},{at=0}},1)=='0 мс','submillisecond and zero display times stay distinct')
check(ns.StartupCompactTime({{at=0},{at=1.2}},1)=='1.20 с'and ns.StartupCompactTime({{at=0},{at=.9996}},1)=='1.00 с','long intervals and rounding across one second use seconds')
check(ns.StartupCompactTime({{at=0}},1)==nil,'terminal marker has no compact interval')
local ranks=ns.StartupLongestLinks({{at=0},{at=1},{at=4},{at=6},{at=9},{at=9}})
check(ranks[2]==1 and ranks[4]==2 and ranks[3]==3 and not ranks[1]and not ranks[5],'three longest positive links use stable observation order for ties')
check(next(ns.StartupLongestLinks({{at=0},{at=0},{at=0}}))==nil,'zero-duration links are not ranked')
check(ns.StartupLongestLinks({{at=0},{at=1}})[1]==1 and next(ns.StartupLongestLinks(nil))==nil,'short and missing chains need no invented top-three intervals')
check(#login.startup.gaps == 5 and login.startup.gaps[1].duration == 2 and login.startup.gaps[1].after == 'Addon1' and login.startup.gaps[1].before == 'Addon2','bounded largest gaps keep adjacent endpoints')
check(not login.startup.reloadLead and not ns.Eligible(login),'login has partial start scope and is excluded from performance comparisons')
check(ns.Export(login,'json'):find('"scope":"startup"',1,true) and ns.Export(login,'text'):find('Addon1',1,true),'loading exports use loading metrics')
local observers = 0
for _, f in ipairs(Mock.objects) do if f.events.LOADING_SCREEN_DISABLED then observers = observers + 1 end end
check(observers == 0 and #Mock.tickers == 0,'startup watcher unregisters and runs no periodic timer')
Mock.event('LOADING_SCREEN_DISABLED'); Mock.event('PLAYER_ENTERING_WORLD',false,false)
check(#ns.History() == 1,'later transitions do not write loading startup reports')

ns.Toggle(); local ui, p = ns.window, ns.window.phase2
local tab = ui.tabs.live
local idle, edge = tab.paintFill, tab.border
tab.scripts.OnEnter(tab)
check(tab.paintFill ~= idle and tab.paintFill[1] > 0 and tab.paintFill[1] > tab.paintFill[3],'standalone hover uses a warm surface fill')
tab.scripts.OnMouseDown(tab,'LeftButton'); check(tab.paintFill[1] < .15,'pressed appearance')
tab.scripts.OnMouseUp(tab,'LeftButton'); tab.scripts.OnLeave(tab)
check(tab.paintFill[1] == idle[1] and tab.border[1] == edge[1],'selected style restored on leave')
ui.tabs.history:Click()
check(p.historyRows[1].record == login and not p.historyRows[1].A:IsShown() and not p.historyRows[1].p99:IsShown(),'loading row omits frame-specific controls')
p.historyRows[1]:Click()
check(p.startup:IsShown() and not p.tabs.smooth:IsShown() and p.export:IsShown(),'loading details routed through history')
p.export:Click(); check(Sintezza_PerfDialog:IsShown(),'loading report opens existing export dialog'); Sintezza_PerfDialog:Hide(); ns.Toggle()

local saved = Sintezza_PerfDB
local calls = 0
function ReloadUI() calls = calls + 1 end
Mock.combat = true
check(not ns.StartMeasuredReload() and calls == 0 and not saved.startupReload,'combat prevents marked reload')
Mock.combat = false
Mock.now = 120
SlashCmdList.SINTEZZAPERF('reload')
check(calls == 1 and saved.startupReload.at == 120,'measured command marks clock before reload')
ns = boot(122, saved)
Mock.now = 124; Mock.event('PLAYER_LOGIN')
Mock.now = 125; Mock.event('PLAYER_ENTERING_WORLD',false,true)
Mock.now = 127; Mock.event('LOADING_SCREEN_DISABLED')
local reload = ns.History()[1]
check(reload.startup.reloadLead == 2 and reload.duration == 7 and reload.startup.beforeLogin == 2,'command reload spans prior and new Lua state')
local reloadChain=ns.StartupChain(reload)
check(reloadChain[1].kind=='command'and reloadChain[2].kind=='start'and reloadChain[2].at==2 and reloadChain[#reloadChain].at==7,'marked reload prepends earlier command phase without shifting endpoint')
check(ns.StartupDetails({duration=37,startup={reloadLead=30,beforeLogin=2,gaps={}}}):find('Дольше от команды до запуска Perf',1,true),'dominant pre-Perf reload segment is included in diagnosis')
check(ns.History()[2].id == login.id and saved.startupReload == nil,'startup record survives migration and marker is consumed')
check(ns.History()[2].startup.traceVersion==1,'new trace survives history reload alongside old profiles')
timers[#timers][2](); check(#ns.History() == 2,'fallback cannot duplicate a screen-completed report')

ns = boot(133, saved)
Mock.now = 134; Mock.event('PLAYER_LOGIN')
Mock.now = 136; Mock.event('PLAYER_ENTERING_WORLD',false,true)
Mock.now = 141; timers[#timers][2]()
local fallback = ns.History()[1]
check(not fallback.startup.reloadLead and fallback.duration == 3 and fallback.startup.endpoint == 'world','unmarked reload fallback reports actual world timestamp without timeout delay')
local before = #ns.History()
Mock.event('LOADING_SCREEN_DISABLED'); check(#ns.History() == before,'late dismissal cannot replace already saved scope')

saved.startupReload = {at=140, wall=1794859200+140}
ns = boot(143, saved)
Mock.now = 146; Mock.event('PLAYER_LOGIN'); Mock.event('PLAYER_ENTERING_WORLD',true,false)
Mock.now = 147; Mock.event('LOADING_SCREEN_DISABLED')
check(not ns.History()[1].startup.reloadLead and saved.startupReload == nil,'character login discards any stale reload marker')
saved.startupReload = {at=2, wall=1794859202}
ns = boot(600, saved)
Mock.now = 601; Mock.event('PLAYER_LOGIN'); Mock.event('PLAYER_ENTERING_WORLD',false,true)
Mock.now = 602; Mock.event('LOADING_SCREEN_DISABLED')
check(not ns.History()[1].startup.reloadLead,'expired reload marker excluded')
ns = boot(610, saved)
Mock.now = 612; Mock.event('PLAYER_ENTERING_WORLD',false,false)
Mock.event('LOADING_SCREEN_DISABLED')
check(ns.History()[1].timestamp == 1794859200+602,'late load or zone flag produces no startup entry')
local recorded = #ns.History()
saved.startupReload = {at=611, wall=1794859200+300}
ns = boot(620, saved)
Mock.now = 622; Mock.event('PLAYER_ENTERING_WORLD',false,true)
Mock.now = 623; Mock.event('LOADING_SCREEN_DISABLED')
check(not ns.History()[1].startup.reloadLead and not ns.History()[1].startup.beforeLogin,'disagreeing clocks and absent login stay unavailable')
check(#ns.History() == recorded+1,'missing login marker still permits scoped entering-world report')
function ReloadUI() error('reload unavailable') end
check(not ns.StartMeasuredReload() and saved.startupReload == nil,'failed reload clears pending marker')
saved.history[#saved.history+1] = {schema=2,kind='startup',id=9999,timestamp=time(),duration=-3,startup={type='login',endpoint='screen'}}
ns.InitHistory(saved)
check(not ns.FindRecord(9999),'malformed persisted loading record rejected')
local secret = {}
issecretvalue = function(value) return value==secret end
local n = boot(630, saved)
Mock.now=631;Mock.event('PLAYER_ENTERING_WORLD',secret,false);Mock.event('LOADING_SCREEN_DISABLED')
check(n.History()[1].id == ns.History()[1].id,'secret world flags stop collection without inspection')
issecretvalue=function()return false end
ns=boot(650,saved)
Mock.now=651;Mock.event('PLAYER_LOGIN')
Mock.now=652;Mock.event('ADDON_LOADED','LateAddon')
Mock.now=653;Mock.event('PLAYER_ENTERING_WORLD',false,true)
Mock.now=654;Mock.event('ADDON_LOADED','WorldAddon')
Mock.now=655;Mock.event('LOADING_SCREEN_DISABLED')
local late=ns.StartupChain(ns.History()[1])
check(late[4].name=='LateAddon'and late[5].kind=='world'and late[6].name=='WorldAddon','trace includes addon events after login and world entry')
ns=boot(660,saved)
for i=1,200 do Mock.now=660+i*.01;Mock.event('ADDON_LOADED','Many'..i)end
Mock.now=663;Mock.event('PLAYER_LOGIN');Mock.now=664;Mock.event('PLAYER_ENTERING_WORLD',true,false)
Mock.now=665;Mock.event('LOADING_SCREEN_DISABLED')
local bounded=ns.History()[1]
check(#bounded.startup.trace==128 and bounded.startup.traceOmitted>0 and bounded.startup.trace[128].kind=='finish','trace cap retains final endpoint and discloses omitted markers')
check(ns.Export(bounded,'text'):find('пропущено отметок',1,true),'text export discloses aggregated omitted span')
local malformed=ns.SaveRecord({kind='startup',duration=5,startup={type='login',endpoint='screen',gaps={},traceVersion=1,trace={{kind='start',at=0},{kind='addon',name='Backwards',at=4},{kind='finish',at=2}}}})
check(malformed and not ns.StartupChain(malformed),'invalid trace rejected while legacy report stays readable')
ns=boot(700,saved)
for i=1,200 do Mock.now=700+i*.01;Mock.event('ADDON_LOADED','Bound'..i)end
Mock.now=703;Mock.event('PLAYER_LOGIN');Mock.now=704;Mock.event('PLAYER_ENTERING_WORLD',true,false)
for i=1,20 do Mock.now=704+i*.01;Mock.event('ADDON_LOADED','AfterWorld'..i)end
Mock.now=709;timers[#timers][2]()
local cutoff=ns.History()[1]
check(cutoff.startup.addonEvents==201 and cutoff.startup.traceOmitted==77 and cutoff.startup.trace[#cutoff.startup.trace].at==4,'fallback endpoint excludes later counters and omitted markers')
local retained={historyLimit=100}
ns.InitHistory(retained)
local firstStartup,lastStartup
for i=1,25 do
    local record=ns.SaveRecord({kind='startup',duration=1,startup={type='login',endpoint='screen'}})
    if i==1 then firstStartup=record.id end
    if i<=10 then assert(ns.PinRecord(record.id))end
    lastStartup=record.id
end
for _=1,110 do ns.SaveRecord({kind='background',duration=5,rows={},timeline={}})end
local function counts()
    local loading,pinned,performance=0,0,0
    for _,record in ipairs(ns.History())do
        if record.pinned then pinned=pinned+1 elseif record.kind=='startup'then loading=loading+1 else performance=performance+1 end
    end
    return loading,pinned,performance
end
local loading,pinned,performance=counts()
check(loading==10 and pinned==10 and performance==100 and #ns.History()==120,'loading retention is independently bounded beside performance and pinned limits')
check(ns.FindRecord(firstStartup)and ns.FindRecord(lastStartup),'newest loading reports and shared pins survive background churn')
ns.InitHistory(retained);loading,pinned,performance=counts()
check(loading==10 and pinned==10 and performance==100,'reload migration preserves all three bounded history groups')
ns.InitHistory(retained);check(#ns.History()==120,'retention migration is idempotent at maximum size')
print(('Startup and standalone UI: PASS (%d checks)'):format(checks))
