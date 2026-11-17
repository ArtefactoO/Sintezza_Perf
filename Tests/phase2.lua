assert(loadfile(ADDON_ROOT..'/Tests/FrameMock.lua'))()
local count=0
local function check(value,message)assert(value,message);count=count+1 end
function GetRealZoneText()return 'Stormwind'end
function GetNumGroupMembers()return 0 end
function GetInstanceInfo()return 'Stormwind','none',0 end
C_Map={GetBestMapForUnit=function()return 84 end}
C_CVar={GetCVar=function()return '120'end}
local ns={}
for _,file in ipairs({'History.lua','Analytics.lua','Perf.lua'})do assert(loadfile(ADDON_ROOT..'/'..file))('Sintezza_Perf',ns)end
local old={schema=1,id=1,kind='capture',timestamp=time()-300,duration=30,name='Old capture',average=2,peak=9,rows={{name='Sintezza_Perf',average=.1}},timeline={}}
local db={history={old},duration=30,memoryManual=true,windowAppearance={scale=80}}
ns.InitHistory(db);ns.InitCollector(db)
check(#ns.History()==1 and ns.History()[1].average==2,'legacy report survives migration')
check(not ns.Eligible(ns.History()[1]),'legacy report not fabricated into frame statistics')
check(db.profile=='light'and db.windowAppearance.scale==80,'new defaults preserve old settings')
local function capture(profile,dt,seconds)
    check(ns.Start(seconds or 5,{profile=profile,scenario='Map',trigger='manual'}),'start '..profile)
    Mock.tick(.01)
    for i=1,math.ceil((seconds or 5)/dt)+1 do if select(2,ns.Capture())then Mock.tick(dt)end end
    return ns.Capture()
end
local before=Mock.apiCalls
local r=capture('light',.01)
check(r.profile=='light'and #r.rows==1 and r.rows[1].name=='Sintezza_Perf','light tracks observer only')
check(Mock.apiCalls-before==r.frames*2,'light uses two native metric reads per frame')
check(r.p95==10 and r.p99==10 and r.long50==0 and r.frameSamples==r.frames,'constant frame percentile')
check(r.complete and ns.Eligible(r),'complete capture comparable')
check(r.context.zone=='Stormwind'and r.context.fpsLimit==120,'capture context')
check(ns.AssignGroup(r.id,'A'),'assign A')
local second=capture('light',.02)
check(ns.AssignGroup(second.id,'B'),'assign B')
local c=ns.Comparison()
check(c.compatible and c.metrics.p99.A==10 and c.metrics.p99.B==20 and c.metrics.p99.delta==100,'comparison medians and delta')
second.p99=5;check(ns.ExportComparison('json'):find('"delta":%-50')~=nil,'negative improvement survives JSON export');second.p99=20
check(not c.repeated,'low repeat count disclosed')
second.profile='detailed';check(not ns.Comparison().compatible,'profile mismatch blocks comparison');second.profile='light'
second.duration=30;check(not ns.Comparison().compatible,'duration mismatch blocks comparison');second.duration=r.duration
second.context.zone='Elsewhere';check(not ns.Comparison().compatible,'context mismatch blocks comparison');second.context.zone='Stormwind'
second.context.fpsLimit=nil;check(not ns.Comparison().compatible,'unknown conditions block comparison');second.context.fpsLimit=120
check(ns.ExportComparison('json'):find('comparison%-1')~=nil,'comparison JSON')
check(ns.Start(5,{profile='light',scenario='Partial'}),'start partial');Mock.tick(.01);Mock.tick(.1);local partial=ns.Stop('manual')
check(not partial.complete and not ns.AssignGroup(partial.id,'A'),'partial cannot enter groups')
local plan={profile='light',trigger='combat',scenario='Combat'}
check(ns.ArmCapture(5,plan),'arm combat')
before=Mock.apiCalls;for i=1,60 do Mock.tick(.01)end
check(Mock.apiCalls==before and ns.Armed()~=nil and not select(2,ns.Capture()),'arming does not sample frames')
Mock.combat=true;Mock.event('PLAYER_REGEN_DISABLED');check(not ns.Armed()and select(2,ns.Capture()),'combat event activates once')
Mock.tick(.01);for i=1,100 do Mock.tick(.01)end
Mock.combat=false;Mock.event('PLAYER_REGEN_ENABLED')
local fight,active=ns.Capture();check(not active and fight.complete and fight.reason=='combat_end','combat end completes capture')
check(#fight.markers==2,'combat context markers')
check(ns.ArmCapture(5,{profile='detailed',trigger='boss',scenario='Boss'}),'arm boss')
Mock.event('ENCOUNTER_START',77,'Boss',1,5);Mock.tick(.01);Mock.tick(.06)
Mock.event('ENCOUNTER_END',88,'Other',1,5);check(select(2,ns.Capture()),'wrong encounter does not stop')
Mock.event('ENCOUNTER_END',77,'Boss',1,5);check(not select(2,ns.Capture()),'matching boss end stops')
check(ns.ArmCapture(5,plan),'arm expiry');local timer=Mock.tickers[#Mock.tickers];timer.callback();check(not ns.Armed()and timer.cancelled,'wait expires and cancels timer')
ns.ArmCapture(5,plan);ns.CancelArm();before=Mock.apiCalls;Mock.tick(1);check(Mock.apiCalls==before and not ns.Armed(),'cancel leaves no collector')
ns.Start(5,{profile='light',scenario='Markers'});Mock.tick(.01);Mock.tick(.01)
for i=1,100 do ns.Mark('Mark '..i)end
Mock.event('ZONE_CHANGED_NEW_AREA')
local marked=ns.Stop('manual');check(#marked.markers==80 and marked.markerOmitted==21,'marker bound')
check(marked.contextChanged,'context change recorded')
for i=1,40 do ns.NoteMemory({timestamp=time()+i*60,total=100+i})end
check(#ns.MemoryTrail()==30,'memory history bound')
ns.NoteMemory({timestamp=time()+40*60+5,total=150});check(#ns.MemoryTrail()==30,'frequent cache samples coalesced')
local windowStart=time()+100000
for i=0,40 do ns.NoteMemory({timestamp=windowStart+i*5,total=150+i})end
local windows=0;for _,point in ipairs(ns.MemoryTrail())do if point.timestamp>=windowStart then windows=windows+1 end end
check(windows>=4 and #ns.MemoryTrail()<=30,'five-second cache refreshes still accumulate fixed minute windows')
local stats={};ns.BeginFrameStats(stats)
local point={long50=0};for i=1,95 do ns.SampleFrame(stats,point,.01,1,.01)end
for i=1,4 do ns.SampleFrame(stats,point,.02,2,.02)end
ns.SampleFrame(stats,point,.08,7,.1);ns.FinishFrameStats(stats)
check(stats.p95==10 and stats.p99==20 and stats.framePeak==80 and stats.long50==1,'tail quantiles and long frames')
check(point.framePeak==80 and point.cpuAtFramePeak==7 and point.perfAtFramePeak==.1,'CPU is paired with selected worst frame')
ns.Start(120,{profile='light',scenario='Heap'});Mock.tick(.01);collectgarbage('collect');local heap=collectgarbage('count')
for i=1,1000 do Mock.tick(.01)end
check(collectgarbage('count')-heap<8,'light steady-state allocation bound');ns.Stop('manual')
print('Phase2 mocks: PASS ('..count..' checks)')
