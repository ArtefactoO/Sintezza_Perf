assert(loadfile(ADDON_ROOT..'/Tests/FrameMock.lua'))()
local checks=0
local function check(value,label)assert(value,label);checks=checks+1 end
local profileCalls,profileStep=0,0
function debugprofilestop()profileCalls=profileCalls+1;return Mock.now*1000+profileCalls*profileStep end
local ns={}
for _,file in ipairs({'History.lua','Analytics.lua','Perf.lua','DeveloperHistory.lua','Developer.lua'})do assert(loadfile(ADDON_ROOT..'/'..file))('Sintezza_Perf',ns)end
local db={history={{schema=1,kind='capture',id=7,timestamp=10,duration=30,rows={},timeline={}}},minimap={hide=true}}
ns.InitHistory(db);ns.InitCollector(db);ns.InitDeveloperHistory(db)
local api=Sintezza_PerfAPI
local m=api:RegisterModule('Fixture','map',{title='Map',titleRu='Карта',visibility=true,changes=true,build='local-a',buildSource='manual'})
local p=api:RegisterPoint(m,'refresh',{memory=true})
local child=api:RegisterPoint(m,'child',{memory=true})
local counters=api:RegisterModule('Fixture','counts',{title='Counts',visibility=true,changes=true,build='a',buildSource='manual'})
local cp=api:RegisterPoint(counters,'count',{kind='counter'})
check(m and p and api.version==1,'versioned registration')
check(api:RegisterModule('Fixture','map')==m and api:RegisterPoint(m,'refresh')==p,'idempotent registration')
check(not api:RegisterModule('../bad','map'),'stable IDs validated')
local function target(...)return ... end
local before=profileCalls
local a,b,c=api:Call(p,target,1,nil,3)
check(a==1 and b==nil and c==3 and profileCalls==before,'disabled direct returns and no clocks')
check(select('#',api:Call(p,target,1,nil,nil))==3,'trailing nil returns preserved while disabled')
check(not api:IsActive(p)and not api:Count(cp)and not api:MarkChanged(p),'disabled signals no work')
local function start(mode,modules,duration)
    local ok,reason=ns.DevStart({mode=mode or'cpu',scenario='map',duration=duration or 15,modules=modules or {'Fixture:map'}})
    assert(ok,reason)
end
local function stop()ns.DevStop('manual');return ns.DevCurrent()end
api:SetVisible(m,false);start()
check(api:IsActive(p)and not api:IsActive(cp),'selected points only')
check(not ns.Start(5)and not ns.ArmCapture(5,{trigger='combat'}),'ordinary capture excluded')
check(not api:RegisterPoint(m,'late')and not api:SetBuildLabel(m,'b','manual'),'registry/code locked while active')
local scans=Mock.scans;ns.Memory(true);check(scans==Mock.scans,'no memory scan during developer capture')
local function nested()
    Mock.now=Mock.now+.002
    api:Call(child,function()Mock.now=Mock.now+.003 end)
    Mock.now=Mock.now+.005
    return 4,nil,6,nil
end
check(select('#',api:Call(p,nested))==4,'active arbitrary trailing nil returns')
api:MarkChanged(p);Mock.tick(.01)
local r=stop();local parent=r.points[2]
check(parent.point=='refresh'and math.abs(parent.totalMs-10)<.001 and math.abs(parent.selfMs-7)<.001,'nested inclusive/known self correct')
check(math.abs(r.modules[1].totalMs-10)<.001,'module outermost time avoids double counting')
check(parent.hiddenCalls==1 and parent.changes==1,'explicit visibility and changes')
check(r.reason=='manual'and not r.complete and r.serviceMean~=nil,'partial report and observer service')
check(#db.history==1 and db.minimap.hide,'existing history and preferences preserved')
check(not r.points[1].allocatedBytes,'CPU mode does not invent allocations')
start('count',{'Fixture:counts'})
api:Count(cp);api:MarkChanged(cp);api:SetVisible(counters,false);api:Count(cp)
r=stop();check(r.points[1].calls==2 and r.points[1].hiddenCalls==nil and r.points[1].totalMs==nil,'counter mode and unknown visibility remain unavailable')
check(r.points[1].changes==1,'change signals distinct from calls')
start('cpu',{'Fixture:counts'});api:Count(cp);r=stop();check(r.modules[1].totalMs==nil and r.points[1].totalMs==nil,'counter-only module has no fabricated CPU')
local sentinel={message='original error'}
start();local count=0
local ok,err=pcall(function()api:Call(p,function()count=count+1;error(sentinel,0)end)end)
Mock.tick(.01);r=ns.DevCurrent()
check(not ok and err==sentinel and count==1,'original error object and exactly one invocation')
check(not ns.DevRunning()and r.reason=='error'and r.errors==1 and not r.complete,'error finalizes partial report')
local function recurse(depth)if depth>0 then return api:Call(p,recurse,depth-1)end;return 9 end
start();check(api:Call(p,recurse,40)==9,'depth overflow never stops target execution');Mock.tick(.01)
check(ns.DevCurrent().reason=='depth'and not ns.DevRunning(),'bounded stack depth')
start('count',{'Fixture:counts'})
for i=1,21000 do api:Count(cp)end
Mock.tick(.01);r=ns.DevCurrent();check(r.calls==20000 and r.reason=='limit','hard operation limit')
start('cpu',nil,1);Mock.tick(.4);Mock.tick(.7);r=ns.DevCurrent()
check(r.complete and r.reason=='complete'and not ns.DevRunning(),'automatic duration completion')
local frames=0;for _,f in ipairs(Mock.objects)do if f.scripts.OnUpdate then frames=frames+1 end end
check(frames==0,'no idle per-frame collector')
check(not ns.DevStart({scenario='x',mode='alloc',modules={'Fixture:map'}}),'allocation API missing fails closed')
local nativeCalls=0
C_AddOnProfiler.MeasureCall=function(fn,...)
    nativeCalls=nativeCalls+1;local result={elapsedMilliseconds=2,allocatedBytes=4096,deallocatedBytes=2048}
    return result,fn(...)
end
start('alloc');a,b,c=api:Call(p,target,1,nil,3);r=stop()
check(a==1 and b==nil and c==3 and r.points[2].allocatedBytes==4096,'native memory contract and returns')
check(nativeCalls==2,'one inert native probe then one target call')
check(not ns.DevStart({scenario='x',mode='alloc',modules={'Fixture:counts'}}),'unsupported point cannot use allocations')
local oldMeasure=C_AddOnProfiler.MeasureCall
C_AddOnProfiler.MeasureCall=function(fn,...)if fn==target then error(sentinel,0)end;return oldMeasure(fn,...)end
start('alloc');ok,err=pcall(function()return api:Call(p,target,2)end);Mock.tick(.01)
check(not ok and err==sentinel,'native errors propagate without retry')
C_AddOnProfiler.MeasureCall=oldMeasure
Mock.unavailable=true
check(not api:GetCapabilities().memory and not ns.DevStart({scenario='disabled',mode='alloc',modules={'Fixture:map'}}),'disabled native profiler rejected')
start('cpu');api:Call(p,target);Mock.tick(.1);Mock.tick(.1);r=stop();check(r.nativeMean==nil,'unavailable native observer stays n/a')
Mock.unavailable=false
local secret={};issecretvalue=function(value)return value==secret end
C_AddOnProfiler.MeasureCall=function(fn,...)if fn==target then return {elapsedMilliseconds=secret,allocatedBytes=0,deallocatedBytes=0},fn(...)end;return oldMeasure(fn,...)end
start('alloc');check(api:Call(p,target,12)==12,'secret metrics do not corrupt function returns');Mock.tick(.01)
check(ns.DevCurrent().reason=='metric'and ns.DevCurrent().points[2].totalMs==nil,'secret metrics excluded')
check(not api:SetVisible(m,secret),'secret visibility rejected before inspection')
issecretvalue=function()return false end;C_AddOnProfiler.MeasureCall=oldMeasure
start();Mock.combat=true;Mock.event('PLAYER_REGEN_DISABLED');api:Call(p,target,3);r=stop()
check(r.contextChanged and r.points[2].calls==1,'ordinary unprotected calls work in combat; context change recorded');Mock.combat=false
start();profileStep=25;api:Call(p,target);Mock.tick(.01);profileStep=0
check(ns.DevCurrent().reason=='overhead','single-service-pass budget')
start();profileStep=.5
for i=1,65 do if ns.DevRunning()then api:Call(p,target);Mock.tick(.01)end end
profileStep=0
check(ns.DevCurrent().reason=='overhead','rolling service budget')
start();profileStep=-.1;api:Call(p,target);Mock.tick(.01);profileStep=0
check(ns.DevCurrent().reason=='clock','reset timing clock invalidates capture')
start('cpu');api:Call(p,target);collectgarbage('collect');collectgarbage('stop')
local heap=collectgarbage('count')
for i=1,1000 do api:Call(p,target,i,nil)end
local growth=collectgarbage('count')-heap;collectgarbage('restart');r=stop()
check(growth<1,'CPU steady state does not allocate tables: '..growth)
local encoded=ns.DevExport(r,'json');check(encoded:find('developer%-1')and encoded:find('"points":%['),'bounded serializable export')
assert(ns.DevStart({scenario='point',mode='cpu',duration=1,modules={'Fixture:map'},points={'Fixture:map:refresh'}}))
api:Call(child,target);api:Call(p,target);r=stop()
check(#r.points==1 and r.points[1].point=='refresh'and r.calls==1,'focused capture excludes other points in module')
check(not ns.DevStart({scenario='bad',modules={'Fixture:map'},points={'Fixture:counts:count'}}),'point outside selected module rejected')
ns.InitDeveloperHistory(db);check(#ns.DevHistory()>0 and ns.DevHistory()[1].points[1].calls==r.points[1].calls,'developer history reload migration')
local function full(label,group)
    api:SetBuildLabel(m,label,'manual');start('cpu',nil,1);api:Call(p,function()Mock.now=Mock.now+.002 end);Mock.tick(.5);Mock.tick(.6)
    local saved=ns.DevCurrent();ns.DevAssign(saved.id,group);return saved
end
ns.DevClearGroups();for i=1,3 do full('code-a','A');full('code-b','B')end
local comparison=ns.DevComparison('Fixture:map:refresh')
check(comparison.compatible and comparison.repeated and comparison.metrics.totalMs.A~=nil,'three repeat A/B comparison with code labels')
local record=full('code-c','A');comparison=ns.DevComparison('Fixture:map:refresh')
check(not comparison.compatible and comparison.reason=='code'and comparison.metrics.totalMs.delta==nil,'mixed code within one group blocks percentages')
ns.DevAssign(record.id,nil);record.scenario='different';ns.DevAssign(record.id,'B')
check(not ns.DevComparison('Fixture:map:refresh').compatible,'different scenarios excluded')
ns.DevClearGroups();ns.DevAssign(r.id,'A');check(not ns.DevComparison('Fixture:map:refresh').compatible,'partial/empty groups excluded')
for i=1,25 do full('same',nil)end
check(#ns.DevHistory()==20,'developer history bounded separately')
local id=ns.DevCurrent().id;ns.DevDelete(id);check(ns.DevCurrent().id~=id,'deleted latest report not retained by UI cache')
local many=api:RegisterModule('Fixture','many',{title='Many'})
for i=1,129 do assert(api:RegisterPoint(many,'p'..i))end
local success,why=ns.DevStart({scenario='many',modules={'Fixture:many'}})
check(not success and why=='points_limit','selected point cap enforced before allocation')
local guide=assert(io.open(ADDON_ROOT..'/Docs/DeveloperAPI.md','rb'));local doc=guide:read('*a');guide:close()
local bridgeChunk,blocks,codes
codes={}
blocks=0
for code in doc:gmatch('```lua\n(.-)\n```')do local chunk=assert(loadstring(code));blocks=blocks+1;codes[blocks]=code;bridgeChunk=bridgeChunk or chunk end
check(blocks>=5,'all documented Lua examples parse')
local actualAPI=Sintezza_PerfAPI;Sintezza_PerfAPI=nil;local absent={};bridgeChunk('GuideAbsent',absent)
check(absent.PerfBridge.Wrap('refresh',target)==target,'documented bridge returns original function without Perf')
Sintezza_PerfAPI={version=999};local unsupported={};bridgeChunk('GuideUnsupported',unsupported)
check(unsupported.PerfBridge.Wrap('refresh',target)==target,'documented bridge rejects incompatible API')
local counterChunk=assert(loadstring(codes[1]..'\n'..codes[5]))
Sintezza_PerfAPI=nil;check(pcall(counterChunk,'GuideCounterAbsent',{}),'documented counter safe without Perf')
Sintezza_PerfAPI={version=999};check(pcall(counterChunk,'GuideCounterUnsupported',{}),'documented counter safe with incompatible API')
Sintezza_PerfAPI=actualAPI;local connected={};bridgeChunk('GuideConnected',connected)
check(pcall(counterChunk,'GuideCounterConnected',{}),'documented counter registers with current API')
local wrapped=connected.PerfBridge.Wrap('refresh',target)
assert(ns.DevStart({scenario='guide',mode='cpu',modules={'GuideConnected:map'}}))
check(select('#',wrapped(3,nil,nil))==3,'documented bridge preserves returns when connected');stop()
local callsBefore=profileCalls;for i=1,10000 do wrapped(i);api:Count(cp);api:MarkChanged(p)end
check(profileCalls==callsBefore,'ten thousand inactive calls/signals do not read clocks')
print(('Developer core: PASS (%d checks; CPU steady-state %.3f KiB)'):format(checks,growth))
