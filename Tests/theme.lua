assert(loadfile(ADDON_ROOT..'/Tests/FrameMock.lua'))()
Mock.installTheme()
local preferences={windows={},opacity=.73,scale=.9,layer='HIGH'}
function preferences:CanMove()return true end
function preferences:Apply()for frame in pairs(self.windows)do frame:SetAlpha(self.opacity);frame:SetScale(self.scale);frame:SetFrameStrata(self.layer)end end
function preferences:Bind(frame,options)self.windows[frame]=options or{};self:Apply()end
Sintezza_Theme.NewWindowPreferences=function()return preferences end
Sintezza_Theme.RegisterGlobalWindowPreferences=function()end
local checks=0
local function check(v,label)assert(v,label);checks=checks+1 end
local ns={}
for _,file in ipairs({'History.lua','Analytics.lua','Perf.lua','DeveloperHistory.lua','Developer.lua','Window.lua','Phase2Window.lua','DeveloperWindow.lua'})do assert(loadfile(ADDON_ROOT..'/'..file))('Sintezza_Perf',ns)end
Sintezza_PerfDB={};Mock.event('ADDON_LOADED','Sintezza_Perf');ns.Toggle();Mock.layout()
local ui=ns.window;local shared=Sintezza_Theme;local palette=shared:ForAddon()
check(ui.themeSurface=='window'and ui.historyPane.themeSurface=='sidebar','main window/sidebar use Theme surfaces')
check(ui.summary.themeSurface=='sidebar','live metrics use the subdued Theme surface')
check(ui.search.themeInput and ui.progress.themeProgress,'Theme input/progress factories')
check(ui.own.meter.themeRole=='brass','row meter uses Theme secondary data color')
ui.settings:Click();check(Sintezza_PerfDialog.themeSurface=='window','settings use Theme window surface');Sintezza_PerfDialog:Hide()
ui.start:Click();check(ui.phase2.setup.themeSurface=='window'and ui.phase2.setup.scenario.themeInput,'ordinary setup uses Theme');ui.phase2.setup:Hide()
local api=Sintezza_PerfAPI
local m=api:RegisterModule('Sintezza_UI','transport',{title='Transport timers',titleRu='Таймеры транспорта'})
local call=api:RegisterPoint(m,'next_visit',{memory=true});local counter=api:RegisterPoint(m,'world_refresh',{kind='counter'})
ui.tabs.developer:Click();local d=ui.developer
check(d.detail.themeSurface=='sidebar','module detail uses the subdued Theme surface')
ui.start:Click();check(d.setup.themeSurface=='window'and d.setup.edit.themeInput,'developer setup uses window rather than panel')
check(d.setup.modeNote:GetText():find('Миллисекунды',1,true),'default counter description explains absent milliseconds')
d.setup.start:Click();api:Call(call,function()Mock.now=Mock.now+.003 end);api:Count(counter);ui.start:Click()
local old=ns.DevCurrent();check(old.mode=='count'and old.modules[1].totalMs==nil,'counter data remains correctly untimed')
check(d.detailBody:GetText():find('Время не записывалось',1,true)and d.note:GetText():find('CPU',1,true),'counter report explains unavailable time')
check(d.detailBody:GetText():find('видимости не подключен',1,true)and d.detailBody:GetText():find('Метка кода не передана',1,true),'integration gaps explicitly distinguished')
d.recordCPU:Click();check(d.mode=='cpu'and not ns.DevRunning(),'Record CPU prepares without automatic collection')
check(d.selected['Sintezza_UI:transport']and d.setup.modeNote:GetText():find('миллисекундах',1,true),'CPU selection and visible mode description')
d.setup.start:Click();api:Call(call,function()Mock.now=Mock.now+.004 end);api:Count(counter);ui.start:Click()
local timed=ns.DevCurrent();check(timed.mode=='cpu'and timed.modules[1].totalMs>0,'registered call reports actual scoped milliseconds')
check(old.mode=='count'and old.modules[1].totalMs==nil,'previous counter recording preserved')
check(not d.recordCPU:IsShown(),'repeat CPU prompt hidden for timed recording')
d.export:Click();check(d.dialog.themeSurface=='window'and d.dialog.scroll.themeScroll and d.dialog.edit.themeInput,'developer export fully uses Theme')
check(preferences.windows[ui]and preferences.windows[Sintezza_PerfDialog]and preferences.windows[ui.phase2.setup]and preferences.windows[d.setup]and preferences.windows[d.dialog],'all standalone windows bind shared preferences')
preferences.opacity=.62;preferences.scale=.85;preferences:Apply()
check(d.dialog:GetAlpha()==.62 and d.setup:GetScale()==.85 and ui.phase2.setup:GetFrameStrata()=='HIGH','dialog opacity/scale/layer update through Theme preferences')
local height=d.dialog.edit:GetHeight();d.dialog.scroll.scripts.OnMouseWheel(d.dialog.scroll,-1);check(d.dialog.scroll:GetVerticalScroll()>=0 and height>0,'themed export scroll remains functional');d.dialog:Hide()
d.headerCost.scripts.OnEnter(d.headerCost);check(Mock.themeTooltip and Mock.themeTooltip.owner==d.headerCost,'Theme tooltip route used')
d.headerCost.scripts.OnLeave(d.headerCost);check(not Mock.themeTooltip,'Theme tooltip closes on leave')
local original=palette.brass[1];palette.brass[1]=.15;shared:RefreshAppearance();check(ui.own.meter.paintFill[1]==.15,'data marks follow palette changes');palette.brass[1]=original
local count=#Mock.objects;for i=1,40 do d:Setup();d.setup:Hide();d.cost:Click();d.dialog:Hide()end
check(#Mock.objects==count,'Theme surfaces and dialogs reused without growing widget count')
ui.tabs.capture:Click();check(ui.phase2.progress.themeProgress and ui.phase2.cpuLines[1].themeRole=='brass','phase2 charts/progress use Theme primitives')
check(ui.phase2.summary.themeSurface=='sidebar' and ui.phase2.detail.themeSurface=='sidebar','recorded metrics use the same subdued Theme surface')
local graph=ui.phase2;graph:Graph({timeline={},duration=15,memoryTrail={}},false)
check(graph.seriesLegend:IsShown()and not graph.legend:IsShown(),'two-series Theme legend visible only for frame/CPU')
palette.brass[1]=.23;shared:RefreshAppearance()
check(graph.cpuSwatch.paintFill[1]==.23 and graph.cpuLines[1].paintFill[1]==.23 and graph.frameSwatch.paintFill[1]==graph.lines[1].paintFill[1],'legend and traces follow identical live Theme tokens')
palette.brass[1]=original;shared:RefreshAppearance();graph:Graph({memoryTrail={}},true)
check(not graph.seriesLegend:IsShown()and graph.legend:IsShown(),'memory view retains separate one-series caption')

-- Execute the production Theme factories as well as the consumer contract above.
local themeRoot=ADDON_ROOT..'/../Sintezza_Theme/'
assert(loadfile(themeRoot..'Widgets.lua'))('Sintezza_Theme',shared)
local widgets=shared:CreateWidgets(palette)
local window=widgets:Surface(UIParent,nil,'window');check(window.themeSurface=='window','production Surface factory delegates correctly')
local line=widgets:DataLine(window,'brass',2);check(line.paintFill[1]==palette.brass[1],'production data-line tint')
local fill=widgets:DataTexture(window,'accent','ARTWORK');check(fill.paintFill[1]==palette.accent[1],'production data-fill tint')
local progress=widgets:ProgressBar(window);check(progress.paintFill[1]==palette.accent[1],'production progress tint')
local input=widgets:EditBox(window,'',function()end);check(input.scripts.OnTabPressed~=nil,'production EditBox keeps Theme keyboard hook')
C_Timer.After=function(_,fn)fn()end
local scroll,body,bar=widgets:ScrollFrame(window,input,45);check(body==input and bar and input:GetParent()==scroll,'production shared scrollbar factory')
local methods=getmetatable(window).__index
function methods:GetEffectiveScale()return self:GetScale()end
function methods:GetBottom()return 600 end
function methods:GetStringHeight()return 40 end
function methods:IsMouseOver()return true end
assert(loadfile(themeRoot..'Help.lua'))('Sintezza_Theme',shared)
local before=#Mock.objects;widgets:Tooltip(window,'Header','Body');local tooltip
for _,f in ipairs(Mock.objects)do if f.note and f.owner==window then tooltip=f end end
check(tooltip and tooltip.note:GetText()=='Header\n\nBody','production Theme tooltip presents title/body')
local withTip=#Mock.objects;shared:HideTooltip(window);check(not tooltip:IsShown(),'production Theme tooltip hides')
widgets:Tooltip(window,'Header','Changed');check(#Mock.objects==withTip and withTip>before,'one reusable Theme tooltip')
check(tooltip:GetWidth()<260 and tooltip:GetWidth()>=140,'short tooltip sizes to its content')
shared:HideTooltip(window);widgets:Tooltip(window,'',string.rep('Long tooltip ',80))
check(tooltip.note:GetText():sub(1,1)~='\n'and tooltip:GetWidth()<=260,'empty title adds no blank lines and long tooltip stays bounded')
print(('Theme integration: PASS (%d checks)'):format(checks))
