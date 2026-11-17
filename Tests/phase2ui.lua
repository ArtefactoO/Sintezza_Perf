assert(loadfile(ADDON_ROOT..'/Tests/FrameMock.lua'))()
local checks=0
local function check(v,label)assert(v,label);checks=checks+1 end
local ns={}
for _,file in ipairs({'History.lua','Analytics.lua','Perf.lua','Window.lua','Phase2Window.lua'})do assert(loadfile(ADDON_ROOT..'/'..file))('Sintezza_Perf',ns)end
Sintezza_PerfDB={};Mock.event('ADDON_LOADED','Sintezza_Perf')
ns.Toggle();Mock.layout();local ui=ns.window;local p=ui.phase2
check(p and ui.tabs.compare,'phase2 module attached')
ui.start:Click();check(p.setup:IsShown()and not select(2,ns.Capture()),'new capture opens setup first')
p.setup.scenario:SetText('');p.setup.start:Click();check(p.setup:IsShown()and p.setup.error:GetText()~='','scenario validation')
p.setup.scenario:SetText('Map');p.setup.start:Click();Mock.layout()
check(select(2,ns.Capture())and ns.Capture().profile=='light','default light capture')
check(not ui.content:IsShown()and p.root:IsShown(),'approved report surface replaces old capture')
Mock.tick(.01);for i=1,60 do Mock.tick(.01)end
p.mark:Click();check(#ns.Capture().markers==1,'manual mark action')
ui.start:Click();Mock.layout();local partial=ns.Capture()
ui.background:Click();check(ns.BackgroundEnabled()and ui.background.text:GetText()=='Фон: включен','background footer refreshes on capture');ui.background:Click()
check(not partial.complete and partial.p99==10,'partial report has scoped measurements')
p.tabs.addons:Click();check(p.empty:IsShown()and p.empty:GetText():find('не записывались',1,true),'light missing detail explained')
p.tabs.smooth:Click();check(p.graph:IsShown(),'frame graph view')
p.export:Click();check(Sintezza_PerfDialog:IsShown(),'report export opens');Sintezza_PerfDialog:Hide()
ns.Start(5,{profile='detailed',scenario='Map'});Mock.tick(.01)
for i=1,502 do if select(2,ns.Capture())then Mock.tick(.01)end end
local full=ns.Capture();check(full.complete,'complete fixture captured')
ui.tabs.history:Click();Mock.layout();check(p.history:IsShown(),'full history view')
p.historyRows[1].A:Click();check(full.group=='A','history assignment A')
p.historyRows[1]:Click();check(ui.reportID==full.id and ui.view=='capture','open selected historic record')
p.rename:Click();local d=Sintezza_PerfDialog;local edit
for _,f in ipairs(Mock.objects)do if f.kind=='EditBox'and f:IsVisible()then edit=f end end
edit:SetText('Renamed');Mock.button('Сохранить'):Click();check(full.name=='Renamed'and full.scenario=='Map','rename does not rewrite recorded scenario')
p.pin:Click();check(full.pinned,'report pin')
p.tabs.addons:Click();Mock.layout();check(ui.tableFrame:GetParent()==p.root and ui.own:IsVisible(),'detailed table reused with observer')
ui.tabs.compare:Click();check(p.compare:IsShown()and p.compatible:GetText():find('обеих',1,true),'comparison empty group explained')
p.addB:Click();check(p.options.group=='B'and p.options.scenario=='Map','repeat setup inherits baseline')
p.setup.trigger:Click();check(p.options.trigger=='combat','trigger picker')
p.setup.start:Click();check(ns.Armed()and p.empty:GetText():find('Покадровый',1,true),'waiting view')
ui.start:Click();check(not ns.Armed(),'cancel waiting action')
p.conditions:Click();check(Sintezza_PerfDialog:IsShown(),'read-only conditions dialog');Sintezza_PerfDialog:Hide()
ui.tabs.live:Click();Mock.layout();check(ui.content:IsShown()and not p.root:IsShown(),'live view preserved')
check(ui.tableFrame:GetParent()==ui.content,'table reparented to live surface')
ui.settings:Click();check(Sintezza_PerfDialog.pages.settings.perfSettings~=nil,'clear settings retained');Sintezza_PerfDialog:Hide()
local baseline=#Mock.objects
for i=1,100 do p:Setup();p.setup:Hide()end
check(#Mock.objects==baseline,'setup widgets reused')
local timer=ui.timer;ns.Toggle();check(timer.cancelled and not p.setup:IsShown(),'hidden window stops redraw and setup')
ns.Toggle();ui.tabs.capture:Click();Mock.layout()
local tooltips=0
for _,f in ipairs(Mock.objects)do if f.perfTooltip and f:IsVisible()then f.scripts.OnEnter(f);check(type(GameTooltip.detail)=='string','tooltip readable');tooltips=tooltips+1 end end
check(tooltips>15,'phase2 tooltip coverage')
print('Phase2 UI mocks: PASS ('..checks..' checks, '..tooltips..' tooltips)')
