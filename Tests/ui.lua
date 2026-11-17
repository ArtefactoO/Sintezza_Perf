assert(loadfile(ADDON_ROOT..'/Tests/FrameMock.lua'))()
local checks=0
local function check(value,message)assert(value,message);checks=checks+1 end
local ns={}
for _,file in ipairs({'History.lua','Analytics.lua','Perf.lua','Window.lua'})do assert(loadfile(ADDON_ROOT..'/'..file))('Sintezza_Perf',ns)end
Sintezza_PerfDB={windowAppearance={scale=80}}
Mock.event('ADDON_LOADED','Sintezza_Perf')
check(Mock.settingsPanel~=nil,'built-in settings registered')
ns.Toggle();Mock.layout()
local ui=ns.window
check(ui and ui:IsShown()and ui.view=='live','window opens live')
check(ui.stats[2].value:GetText():find('1.240',1,true),'live CPU rendered')
check(ui.own.data.name=='Sintezza_Perf','own row always separate')
ui.tabs.capture:Click();Mock.layout()
check(ui.empty:IsShown(),'empty capture')
ui.start:Click();Mock.layout()
check(select(2,ns.Capture()),'capture starts from UI')
check(not ui.duration:IsEnabled(),'duration locked while recording')
ui.start.scripts.OnEnter(ui.start);check(GameTooltip.title=='Остановить'and GameTooltip.detail:find('сохраняет',1,true),'recording button tooltip changes with state')
check(ui.stats[1].value:GetText():find('н/д',1,true),'zero-sample average unavailable')
Mock.tick(.01);for i=1,60 do Mock.tick(1/60)end
ui.start:Click();Mock.layout()
local record=ns.Capture()
check(record.frames==60 and #ns.History()==1,'stop saves record')
check(not ui.axisEnd:GetText():find('00:30',1,true),'early stop axis uses observed duration')
ns.Start(5);Mock.tick(.01);Mock.tick(.02);ns.Stop('manual');Mock.layout()
check(ui.axisEnd:GetText()=='00:00.02','subsecond stop axis retains fractional boundary')
ns.DeleteRecord(ns.Capture().id);ns.OnDataChanged()
check(ui.export:IsShown(),'saved capture export visible')
local objects=#Mock.objects
ui.export:Click()
local d=Sintezza_PerfDialog
check(d:IsShown()and d.pages.export~=nil,'export dialog opens')
local closeTip=false
for _,f in ipairs(Mock.objects)do if f:IsVisible()and f.perfTooltip and f.perfTooltip[1]=='Закрыть'then closeTip=true end end
check(closeTip,'dialog close tooltip')
local exportObjects=#Mock.objects
d:Hide();ui.export:Click()
check(#Mock.objects==exportObjects,'export dialog widgets reused')
local selectButton=Mock.button('Выделить текст');selectButton:Click()
local selected=false;for _,f in ipairs(Mock.objects)do if f.kind=='EditBox'and f.selectedText and f:IsVisible()then selected=true end end
check(selected,'export text selectable')
d:Hide();ui.rename:Click()
local edit
for _,f in ipairs(Mock.objects)do if f.kind=='EditBox'and f:IsVisible()then edit=f end end
edit:SetText('');Mock.button('Сохранить'):Click();check(d:IsShown(),'rename validates empty')
edit:SetText('Проверка карты');Mock.button('Сохранить'):Click();check(record.name=='Проверка карты'and not d:IsShown(),'rename saves selected record')
ui.pin:Click();check(record.pinned,'pin action')
ui.tabs.history:Click();Mock.layout();check(ui.historyPane:IsShown(),'history pane')
ui.delete:Click();Mock.button('Отмена'):Click();check(ns.FindRecord(record.id)~=nil,'delete cancel')
ui.delete:Click();Mock.button('Удалить отчет'):Click();check(#ns.History()==0,'delete confirmation')
ui.tabs.capture:Click();check(ui.empty:IsShown(),'deleted last capture cannot reappear')
ui.tabs.live:Click();ui.search:SetText('nothing');check(ui.filteredCount==0 and ui.own:IsShown(),'no-match filter retains observer')
ui.search:SetText('')
ui.settings:Click();check(d.pages.settings~=nil,'settings dialog')
local controls=d.pages.settings.perfSettings
check(controls.memory.text:GetText()=='Автоматически','positive memory mode label')
controls.memory:Click();check(Sintezza_PerfDB.memoryManual and controls.memory.text:GetText()=='Только по кнопке','memory selector preserves storage semantics')
controls.memory:Click();check(not Sintezza_PerfDB.memoryManual,'memory selector returns to automatic')
check(controls.history.text:GetText()=='20','history limit separated from label')
local oldBackground=ns.BackgroundEnabled();controls.background:Click();check(ns.BackgroundEnabled()~=oldBackground,'background setting toggle');controls.background:Click()
local header=d.pages.settings.header
header.scripts.OnMouseDown(header,'LeftButton');check(d.moving and d.perfMoved,'settings header starts dragging')
d:ClearAllPoints();d:SetPoint('TOPLEFT',UIParent,'TOPLEFT',80,-90)
header.scripts.OnMouseUp(header);check(not d.moving,'header release stops dragging')
d:Hide();ui.settings:Click();check(d.points[1][1]=='TOPLEFT'and d.points[1][4]==80,'dialog position retained on reopening')
Mock.combat=true;header.scripts.OnMouseDown(header,'LeftButton');check(not d.moving,'dialog cannot start drag in combat');Mock.combat=false
local settingsObjects=#Mock.objects;d:Hide();ui.settings:Click();check(#Mock.objects==settingsObjects,'settings widgets reused')
for i=1,100 do d:Hide();ui.settings:Click()end
check(#Mock.objects==settingsObjects,'100 dialog opens allocate no additional widgets')
d:Hide()
Mock.combat=true;local scans=Mock.scans;ui.refresh:Click();check(Mock.scans==scans,'UI memory scan deferred in combat')
Mock.combat=false
Mock.unavailable=true;ui.tabs.capture:Click();check(not ui.start:IsEnabled(),'unavailable API disables start')
Mock.unavailable=false
ui.tabs.live:Click();local lastTicker=ui.timer;ns.Toggle();check(lastTicker.cancelled and ui.timer==nil,'hidden window cancels redraw ticker')
check(Sintezza_PerfDB.windowAppearance.scale==80,'existing shared preferences preserved')
local tooltipCount=0
for _,f in ipairs(Mock.objects)do
    if f.perfTooltip and f:IsVisible()then
        f.scripts.OnEnter(f);check(type(GameTooltip.detail)=='string'and #GameTooltip.detail>0,'tooltip text present');tooltipCount=tooltipCount+1
    end
end
ns.Toggle();Mock.layout()
for _,f in ipairs(Mock.objects)do if f.perfTooltip and f:IsVisible()then f.scripts.OnEnter(f);tooltipCount=tooltipCount+1 end end
check(tooltipCount>=15,'visible parameter tooltips available')
print('UI mocks: PASS ('..checks..' checks, '..tooltipCount..' tooltips)')
TEST_NS=ns
