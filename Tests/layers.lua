assert(loadfile(ADDON_ROOT..'/Tests/FrameMock.lua'))()
Mock.installTheme()
local checks=0
local function check(value,label)assert(value,label);checks=checks+1 end
local methods=getmetatable(UIParent).__index
local function Dispatch(frame,event,...)
    local primary=frame.primaryScripts and frame.primaryScripts[event]
    if primary then primary(frame,...)end
    for _,callback in ipairs(frame.postScripts and frame.postScripts[event]or{})do callback(frame,...)end
end
function methods:SetScript(event,callback)
    self.primaryScripts=self.primaryScripts or{}
    self.primaryScripts[event]=callback
    if self.postScripts and self.postScripts[event] then
        self.scripts[event]=function(frame,...)Dispatch(frame,event,...)end
    else self.scripts[event]=callback end
end
function methods:HookScript(event,callback)
    self.primaryScripts=self.primaryScripts or{}
    self.postScripts=self.postScripts or{}
    if not self.postScripts[event]then self.primaryScripts[event]=self.scripts[event];self.postScripts[event]={}end
    self.postScripts[event][#self.postScripts[event]+1]=callback
    self.scripts[event]=function(frame,...)Dispatch(frame,event,...)end
end
local probe=CreateFrame('Frame',nil,UIParent)
local calls={}
probe:HookScript('OnShow',function()calls[#calls+1]='hook'end)
probe:SetScript('OnShow',function()calls[#calls+1]='primary'end)
probe:Hide();probe:Show()
check(table.concat(calls,',')=='primary,hook','post-hook model survives replacement of the primary handler')
function methods:GetFrameLevel()
    if self.level then return self.level end
    return self.parent and self.parent:GetFrameLevel()+1 or 0
end
function methods:GetFrameStrata()
    return self.strata or self.parent and self.parent:GetFrameStrata() or 'MEDIUM'
end
function methods:GetChildren()
    local children={}
    for _,frame in ipairs(Mock.objects)do
        if frame.parent==self and frame.kind~='Texture'and frame.kind~='FontString'and frame.kind~='Line' then children[#children+1]=frame end
    end
    return unpack(children)
end
local shared=Sintezza_Theme
assert(loadfile(ADDON_ROOT..'/../Sintezza_Theme/WindowStack.lua'))('Sintezza_Theme',shared)
local theme=shared:ForAddon()
local paint=theme.WindowSurface
function theme:WindowSurface(frame)paint(self,frame);shared:TrackWindow(frame)end
local preferences={windows={}}
function preferences:CanMove()return true end
function preferences:Bind(frame,options)
    self.windows[frame]=options or{}
    -- A shared layer override deliberately puts both windows in the same stratum.
    frame:SetFrameStrata('HIGH')
    frame:HookScript('OnShow',function(self)self:SetFrameStrata('HIGH')end)
end
shared.NewWindowPreferences=function()return preferences end
shared.RegisterGlobalWindowPreferences=function()end
local ns={}
for _,file in ipairs({'History','Analytics','Perf','DeveloperHistory','Developer','Window','Phase2Window','DeveloperWindow'})do
    assert(loadfile(ADDON_ROOT..'/'..file..'.lua'))('Sintezza_Perf',ns)
end
Sintezza_PerfDB={};Mock.event('ADDON_LOADED','Sintezza_Perf')
local function Highest(frame)
    local highest=frame:GetFrameLevel()
    for _,child in ipairs({frame:GetChildren()})do highest=math.max(highest,Highest(child))end
    return highest
end
ns.ToggleStartup();local window=Sintezza_PerfStartupWindow
ns.Toggle();local ui=ns.window
check(window:GetFrameStrata()=='HIGH'and ui:GetFrameStrata()=='HIGH','same-stratum regression setup')
check(ui:GetFrameLevel()>Highest(window),'main OnShow retains Theme group raising')
ns.ToggleStartup()
GetMouseFoci=function()return{ui.startupButton}end
Mock.event('GLOBAL_MOUSE_DOWN')
ui.startupButton:Click()
check(window:GetFrameLevel()>Highest(ui),'login report OnShow raises all children above main content')
check(ui.startupButton.text:GetText()=='Время входа','header button identifies timing')
local oldCount=#Mock.objects
for _=1,20 do ns.ToggleStartup();ns.ToggleStartup()end
check(window:GetFrameLevel()>Highest(ui)and #Mock.objects==oldCount,'reopening preserves group order and widget reuse')

local menu=CreateFrame('Frame',nil,UIParent);menu:Hide()
function theme:OpenPicker(owner,choices,selected,commit)
    menu.owner=owner;menu.choices=choices;menu.commit=commit;menu:Show();return menu
end
function theme:ClosePicker()menu:Hide()end
ns.SaveRecord({kind='startup',duration=5,name='Login',startup={type='login',endpoint='screen',beforeLogin=2,gaps={}}})
window.reportPicker.scripts.OnEnter(window.reportPicker)
check(Mock.themeTooltip and Mock.themeTooltip.owner==window.reportPicker,'picker help initially visible')
window.reportPicker:Click()
check(menu:IsShown()and not Mock.themeTooltip,'opening list dismisses owner tooltip')
window.reportPicker.scripts.OnEnter(window.reportPicker)
check(not Mock.themeTooltip,'owner reentry cannot cover the open list with help')
ui.startupButton.scripts.OnEnter(ui.startupButton)
check(not Mock.themeTooltip,'other Perf hints suppressed while choices are open')
menu:Hide();window.reportPicker.scripts.OnEnter(window.reportPicker)
check(Mock.themeTooltip~=nil,'help resumes after closing list')
window.reportPicker.scripts.OnLeave(window.reportPicker)
check(not Mock.themeTooltip,'resumed help dismisses normally')
window.copy:Click()
local copy=Sintezza_PerfDialog
check(copy.record.kind=='startup'and copy.body.output.selectedText,'copy dialog uses explicit loading report override')
check(copy:GetFrameLevel()>Highest(window),'first copy dialog show raises it over the entire loading window')
print(('Window layers and menus: PASS (%d checks)'):format(checks))
