Mock = { objects={}, tickers={}, now=0, scans=0, combat=false, apiCalls=0 }
local M, objects = Mock, Mock.objects
local methods = {}
local function widget(kind,name,parent)
    local f=setmetatable({kind=kind,name=name,parent=parent,scripts={},events={},points={},shown=true,enabled=true,id=#objects+1}, {__index=methods})
    objects[#objects+1]=f
    if name then _G[name]=f end
    return f
end
local positions={TOPLEFT={0,0},TOP={.5,0},TOPRIGHT={1,0},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,1},BOTTOM={.5,1},BOTTOMRIGHT={1,1}}
local rect
rect=function(f,depth)
    if not f or (depth or 0)>25 then return 0,0,0,0 end
    if f==UIParent then return 0,0,1920,1080 end
    if f.kind=='Line'and f.lineStart and f.lineEnd then
        local a,b=f.lineStart,f.lineEnd;local ax,ay,aw,ah=rect(a[2],(depth or 0)+1);local bx,by,bw,bh=rect(b[2],(depth or 0)+1)
        local ap,bp=positions[a[1]],positions[b[1]]
        local x1,y1=ax+aw*ap[1]+a[3],ay+ah*ap[2]-a[4]
        local x2,y2=bx+bw*bp[1]+b[3],by+bh*bp[2]-b[4]
        return math.min(x1,x2),math.min(y1,y2),math.max(1,math.abs(x2-x1)),math.max(1,math.abs(y2-y1))
    end
    local width=f.width or (f.kind=='FontString' and #(f.textValue or '')*(f.fontSize or 12)*.30) or 0
    local height=f.height or (f.kind=='FontString' and (f.fontSize or 12)*1.3) or 0
    local anchors={}
    for _,p in ipairs(f.points)do
        local rx,ry,rw,rh=rect(p[2]or f.parent,(depth or 0)+1)
        local rp=positions[p[3]]or positions[p[1]]
        anchors[#anchors+1]={point=positions[p[1]],x=rx+rw*rp[1]+p[4],y=ry+rh*rp[2]-p[5]}
    end
    local first=anchors[1]
    local scrollOffset=f.parent and f.parent.kind=='ScrollFrame'and f.parent.scrollChild==f and (f.parent.scroll or 0)or 0
    if not first then local x,y=rect(f.parent,(depth or 0)+1);return x,y-scrollOffset,width,height end
    for _,a in ipairs(anchors)do
        if a.point[1]~=first.point[1] then width=(a.x-first.x)/(a.point[1]-first.point[1])end
        if a.point[2]~=first.point[2] then height=(a.y-first.y)/(a.point[2]-first.point[2])end
    end
    return first.x-width*first.point[1],first.y-height*first.point[2]-scrollOffset,width,height
end
function methods:SetPoint(point,a,b,c,d)
    local relative,relativePoint,x,y
    if type(a)=='number'then relative,relativePoint,x,y=self.parent,point,a,b or 0
    elseif type(a)=='table'then relative=a;if type(b)=='string'then relativePoint,x,y=b,c or 0,d or 0 else relativePoint,x,y=point,b or 0,c or 0 end
    else relative,relativePoint,x,y=self.parent,point,0,0 end
    for i=#self.points,1,-1 do if self.points[i][1]==point then table.remove(self.points,i)end end
    self.points[#self.points+1]={point,relative,relativePoint,x,y}
end
function methods:ClearAllPoints()self.points={}end
function methods:SetAllPoints(target)target=target or self.parent;self:ClearAllPoints();self:SetPoint('TOPLEFT',target,'TOPLEFT',0,0);self:SetPoint('BOTTOMRIGHT',target,'BOTTOMRIGHT',0,0)end
function methods:SetSize(w,h)self.width,self.height=w,h end
function methods:SetWidth(w)self.width=w end
function methods:SetHeight(h)self.height=h end
function methods:GetWidth()local _,_,w=rect(self);return w end
function methods:GetHeight()local _,_,_,h=rect(self);return h end
function methods:SetScript(name,fn)self.scripts[name]=fn end
function methods:GetScript(name)return self.scripts[name]end
function methods:HookScript(name,fn)local old=self.scripts[name];self.scripts[name]=function(...)if old then old(...)end;fn(...)end end
function methods:RegisterEvent(name)self.events[name]=true end
function methods:UnregisterEvent(name)self.events[name]=nil end
function methods:SetShown(value)
    value=not not value;if value==self.shown then return end
    self.shown=value;local script=self.scripts[value and 'OnShow'or'OnHide'];if script then script(self)end
end
function methods:Show()self:SetShown(true)end
function methods:Hide()self:SetShown(false)end
function methods:IsShown()return self.shown end
function methods:IsVisible()return self.shown and (not self.parent or self.parent:IsVisible())end
function methods:SetParent(p)self.parent=p end
function methods:GetParent()return self.parent end
function methods:GetName()return self.name end
function methods:SetText(value)
    assert(value==nil or type(value)=='string'or type(value)=='number','invalid text')
    value=tostring(value or'');local changed=value~=self.textValue;self.textValue=value
    if changed and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false)end
end
function methods:GetText()return self.textValue or''end
local function visibleText(text)return text:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r','')end
local function textWidth(frame,text)
    if M.measureWidth then return M.measureWidth(text,frame.font,frame.fontSize or 12)end
    return #text:gsub('[\128-\191]','')*(frame.fontSize or 12)*(M.fontWidthFactor or .52)
end
function methods:GetStringWidth()
    local width=0
    for line in self:GetText():gmatch('[^\n]+')do
        local text=visibleText(line)
        width=math.max(width,textWidth(self,text))
    end
    return width
end
function methods:GetStringHeight()
    local lines=0
    for line in (self:GetText()..'\n'):gmatch('(.-)\n')do
        local text=visibleText(line)
        local width=textWidth(self,text)
        lines=lines+math.max(1,self.wrap and math.ceil(width/math.max(1,self.width or width))or 1)
    end
    return lines*(self.fontSize or 12)*1.3+math.max(0,lines-1)*(self.spacing or 0)
end
function methods:SetFont(path,size,flags)self.fontSize=size;self.font=path;return true end
function methods:GetFont()return 'Fonts/FRIZQT__.TTF',self.fontSize or 12,''end
function methods:SetFontObject()self.fontSize=12;self.color={.98,.91,.85,1}end
function methods:SetTextColor(...)self.color={...}end
function methods:SetBackdropColor(...)self.paintFill={...}end
function methods:SetBackdropBorderColor(...)self.border={...}end
function methods:SetColorTexture(...)self.paintFill={...}end
function methods:SetVertexColor(...)self.color={...}end
function methods:SetAlpha(v)self.alpha=v end
function methods:GetAlpha()return self.alpha or 1 end
function methods:SetScale(v)self.scale=v end
function methods:GetScale()return self.scale or 1 end
function methods:SetFrameStrata(v)self.strata=v end
function methods:GetFrameStrata()return self.strata or'DIALOG'end
function methods:SetFrameLevel(v)self.level=v end
function methods:GetFrameLevel()return self.level or 1 end
function methods:CreateTexture()return widget('Texture',nil,self)end
function methods:CreateLine()return widget('Line',nil,self)end
function methods:SetThickness(value)self.thickness=value end
function methods:SetStartPoint(point,relative,x,y)self.lineStart={point,relative,x,y}end
function methods:SetEndPoint(point,relative,x,y)self.lineEnd={point,relative,x,y}end
function methods:CreateFontString()return widget('FontString',nil,self)end
function methods:SetTexture(v)self.texture=v end
function methods:SetTexCoord(...)self.texCoord={...}end
function methods:SetJustifyH(v)self.align=v end
function methods:SetWordWrap(v)self.wrap=v end
function methods:Enable()if not self.enabled then self.enabled=true;if self.scripts.OnEnable then self.scripts.OnEnable(self)end end end
function methods:Disable()if self.enabled then self.enabled=false;if self.scripts.OnDisable then self.scripts.OnDisable(self)end end end
function methods:IsEnabled()return self.enabled end
function methods:Click()if self.enabled and self.scripts.OnClick then if self.kind=='CheckButton'then self.checked=not self.checked end;self.scripts.OnClick(self,'LeftButton')end end
function methods:SetChecked(value)self.checked=not not value end
function methods:GetChecked()return self.checked end
function methods:SetFocus()self.focus=true end
function methods:ClearFocus()self.focus=false end
function methods:HasFocus()return self.focus end
function methods:HighlightText(first,last)self.selectedText=not(first~=nil and first==last)end
function methods:SetScrollChild(child)self.scrollChild=child end
function methods:SetVerticalScroll(v)local changed=self.scroll~=v;self.scroll=v;if changed and self.scripts.OnVerticalScroll then self.scripts.OnVerticalScroll(self,v)end end
function methods:GetVerticalScroll()return self.scroll or 0 end
function methods:SetMinMaxValues(a,b)self.min,self.max=a,b end
function methods:SetValue(value)self.value=value end
function methods:SetStatusBarColor(...)self.paintFill={...}end
local noop=function()end
for _,name in ipairs({'SetBackdrop','SetClampedToScreen','SetMovable','EnableMouse','SetMouseClickEnabled','SetHighlightTexture','SetNormalTexture','RegisterForDrag','EnableMouseWheel','SetAutoFocus','SetTextInsets','SetMultiLine','SetMaxLetters','SetRotation','SetStatusBarTexture','StartMoving','StopMovingOrSizing','SetJustifyV','SetSpacing'})do methods[name]=noop end
function methods:SetSpacing(value)self.spacing=value end
function methods:RegisterForClicks(...)self.clicks={...}end
function methods:SetMovable(value)self.movable=value end
function methods:SetMultiLine(value)self.wrap=value end
function methods:StartMoving()assert(self.movable,'window not movable');assert(not M.combat,'drag started in combat');self.moving=true;self.moveStarts=(self.moveStarts or 0)+1 end
function methods:StopMovingOrSizing()self.moving=false end
function CreateFrame(kind,name,parent)return widget(kind,name,parent or UIParent)end
UIParent=widget('Frame','UIParent');Minimap=widget('Frame','Minimap',UIParent);Minimap:SetSize(150,150)
GameFontHighlightSmall={};UISpecialFrames={};SlashCmdList={}
GameTooltip={SetOwner=function(self,owner)self.owner=owner end,SetText=function(self,t)self.title=t end,AddLine=function(self,t)self.detail=t end,Show=noop,Hide=noop,IsOwned=function(self,o)return self.owner==o end}
function GetLocale()return TEST_LOCALE or'ruRU'end
function GetTime()return M.now end
GetTimePreciseSec=GetTime
function time()return 1794859200+math.floor(M.now)end
date=os.date
function InCombatLockdown()return M.combat end
function IsLoggedIn()return true end
function issecretvalue()return false end
function GetBuildInfo()return'1.60.1','70938'end
function GetRealZoneText()return 'Stormwind'end
function GetNumGroupMembers()return 0 end
function GetInstanceInfo()return 'Stormwind','none',0 end
C_Map={GetBestMapForUnit=function()return 84 end}
C_CVar={GetCVar=function()return '120'end}
function GetFramerate()return 120 end
function debugprofilestop()return M.now*1000 end
function UpdateAddOnMemoryUsage()M.scans=M.scans+1 end
function GetAddOnMemoryUsage()return 1024 end
function hooksecurefunc(name,callback)local old=_G[name];_G[name]=function(...)old(...);callback(...)end end
C_Timer={NewTicker=function(delay,callback)local t={delay=delay,callback=callback};function t:Cancel()self.cancelled=true end;M.tickers[#M.tickers+1]=t;return t end}
Enum={AddOnProfilerMetric={}}
for _,key in ipairs({'LastTime','RecentAverageTime','PeakTime','CountTimeOver5Ms','CountTimeOver10Ms','CountTimeOver50Ms'})do Enum.AddOnProfilerMetric[key]=key end
M.names={'Sintezza_Perf','Sintezza_UI','Sintezza_Rivals','Sintezza_Loot','Sintezza_Vendor','Sintezza_Disenchant','OtherAddon'}
C_AddOns={GetNumAddOns=function()return #M.names end,GetAddOnInfo=function(i)return type(i)=='number'and M.names[i]or i,nil,nil,nil,nil,'INSECURE'end,IsAddOnLoaded=function()return true,true end,GetAddOnMetadata=function()return'1.0'end}
C_AddOnProfiler={IsEnabled=function()return not M.unavailable end,GetAddOnMetric=function(name,key)M.apiCalls=M.apiCalls+1;return key=='LastTime'and(name=='Sintezza_Perf'and .04 or .2)or key=='RecentAverageTime'and .2 or 0 end,GetOverallMetric=function(key)M.apiCalls=M.apiCalls+1;return key=='LastTime'and 1.24 or key=='RecentAverageTime'and 1.24 or 0 end,GetApplicationMetric=function()return 8.333 end}
Settings={RegisterCanvasLayoutCategory=function(panel,title)M.settingsPanel=panel;return{GetID=function()return 1 end}end,RegisterAddOnCategory=noop}
function M.event(name,...)
    for _,f in ipairs(objects)do if f.events[name]and f.scripts.OnEvent then f.scripts.OnEvent(f,name,...)end end
end
function M.tick(dt)
    M.now=M.now+dt
    for _,f in ipairs(objects)do if f.scripts.OnUpdate then f.scripts.OnUpdate(f,dt)end end
end
function M.layout()
    for pass=1,3 do for _,f in ipairs(objects)do local w,h=f:GetWidth(),f:GetHeight();if (w~=f.lastWidth or h~=f.lastHeight)and f.scripts.OnSizeChanged then f.lastWidth,f.lastHeight=w,h;f.scripts.OnSizeChanged(f,w,h)end end end
end
function M.button(text)
    for i=#objects,1,-1 do local f=objects[i];if f.kind=='Button'and f:IsVisible()and f.text and f.text:GetText()==text then return f end end
end
function M.snapshot(root)
    M.layout();local rx,ry=rect(root);local result={}
    local function inside(f)local node=f;while node do if node==root then return true end;node=node.parent end;return false end
    for _,f in ipairs(objects)do
        if inside(f)and f:IsVisible()then
            local x,y,w,h=rect(f)
            if w>0 and h>0 then
                local ax,ay,dualX,dualY
                for _,p in ipairs(f.points)do local a=positions[p[1]];if ax and ax~=a[1]then dualX=true end;if ay and ay~=a[2]then dualY=true end;ax,ay=a[1],a[2]end
                local clip,ancestor=nil,f.parent
                while ancestor do if ancestor.kind=='ScrollFrame'then local cx,cy,cw,ch=rect(ancestor);clip={cx-rx,cy-ry,cw,ch};break end;ancestor=ancestor.parent end
                local line
                if f.kind=='Line'and f.lineStart and f.lineEnd then local a,b=f.lineStart,f.lineEnd;line={up=b[4]>a[4],right=b[3]>=a[3],thickness=f.thickness or 1}end
                local opacity,node=f.alpha or 1,f.parent
                while node do opacity=opacity*(node.alpha or 1);node=node.parent end
                result[#result+1]={id=f.id,parent=f.parent and f.parent.id,kind=f.kind,x=x-rx,y=y-ry,width=w,height=h,text=f.textValue,fontSize=f.fontSize,spacing=f.spacing,color=f.color,fill=f.paintFill,border=f.border,align=f.align,wrap=f.wrap,alpha=opacity,autoWidth=f.kind=='FontString'and not f.width and not dualX,autoHeight=f.kind=='FontString'and not f.height and not dualY,anchorX=ax or 0,clip=clip,line=line,texture=f.texture,texCoord=f.texCoord}
            end
        end
    end
    return result
end
function M.installTheme()
    local T={bg={.098,.071,.055,1},panel={.17,.118,.09,1},input={.106,.075,.059,1},line={.55,.37,.26,1},lineSoft={.35,.23,.18,1},text={.98,.91,.85,1},muted={.82,.71,.64,1},accent={.91,.65,.48,1},accentDim={.30,.18,.12,1}}
    T.brass={.79,.54,.37,1};T.accentLine=T.accent
    function T:WindowSurface(f)f.themeSurface='window';f:SetBackdropColor(unpack(self.bg));f:SetBackdropBorderColor(unpack(self.line))end
    function T:PanelSurface(f)f.themeSurface='panel';f:SetBackdropColor(unpack(self.panel));f:SetBackdropBorderColor(unpack(self.lineSoft))end
    function T:SidebarSurface(f)f.themeSurface='sidebar';f:SetBackdropColor(unpack(self.input));f:SetBackdropBorderColor(unpack(self.lineSoft))end
    function T:Backdrop(f,color,border)f:SetBackdropColor(unpack(color or self.panel));f:SetBackdropBorderColor(unpack(border or self.line))end
    function T:Font(f,size,flags,color)f:SetFont('Fira',size,flags);f:SetTextColor(unpack(color or self.text))end
    function T:PaintButton(b,active)b:SetBackdropColor(unpack(active and self.accentDim or self.panel))end
    function T:SkinInput(f,size)f:SetBackdropColor(unpack(self.input));f:SetFont('Fira',size,'');f:SetTextColor(unpack(self.text))end
    function T:ClosePicker()end
    function T:Glyph(parent,key,size,color)
        local index=assert(({overview=0,panels=1,combat=2,party=3,system=4,check=5,pin=6,chevron=7})[key])
        local texture=parent:CreateTexture(nil,'OVERLAY')
        texture:SetTexture('Interface\\AddOns\\Sintezza_Theme\\Media\\settings-glyphs.tga')
        texture:SetTexCoord(index/8,(index+1)/8,0,1);texture:SetSize(size,size)
        texture:SetVertexColor(unpack(color or self.brass));return texture
    end
    local W={}
    function W:Surface(parent,name,role)local f=CreateFrame('Frame',name,parent,'BackdropTemplate');if role=='window'then T:WindowSurface(f)elseif role=='sidebar'then T:SidebarSurface(f)else T:PanelSurface(f)end;return f end
    function W:DataTexture(parent,role,layer)local f=parent:CreateTexture(nil,layer or'ARTWORK');f.themeRole=role;Sintezza_Theme:Tint(f,'SetColorTexture',T[role]);return f end
    function W:DataLine(parent,role,thickness)local f=parent:CreateLine(nil,'ARTWORK');f.themeRole=role;f:SetThickness(thickness or 2);Sintezza_Theme:Tint(f,'SetColorTexture',T[role]);return f end
    function W:ProgressBar(parent)local f=CreateFrame('StatusBar',nil,parent);f.themeProgress=true;f:SetStatusBarTexture('Interface\\Buttons\\WHITE8X8');Sintezza_Theme:Tint(f,'SetStatusBarColor',T.accent);return f end
    function W:Tooltip(owner,title,body)Sintezza_Theme:ShowTooltip(owner,title,body)end
    function W:EditBox(parent)local f=CreateFrame('EditBox',nil,parent,'BackdropTemplate');f.themeInput=true;f:SetHeight(28);f:SetAutoFocus(false);T:SkinInput(f,12);return f end
    function T:AttachScrollBar(scroll,parent,step)
        local bar=CreateFrame('Slider',nil,parent);bar:SetWidth(9);scroll.bar=bar
        function scroll:RefreshRange()local body=self.scrollChild;local range=math.max(0,(body and body:GetHeight()or 0)-self:GetHeight());bar:SetMinMaxValues(0,range);bar:SetShown(range>0)end
        scroll:SetScript('OnMouseWheel',function(self,delta)self:RefreshRange();self:SetVerticalScroll(math.max(0,math.min(bar.max,self:GetVerticalScroll()-delta*(step or 45))))end)
        return bar
    end
    function W:ScrollFrame(parent,body,step)local f=CreateFrame('ScrollFrame',nil,parent,'BackdropTemplate');f.themeScroll=true;body:SetParent(f);f:SetScrollChild(body);local bar=T:AttachScrollBar(f,parent,step);body:HookScript('OnSizeChanged',function()f:RefreshRange()end);return f,body,bar end
    function W:Label(parent,text,size,color,role)local f=parent:CreateFontString();f:SetText(text);f:SetFont(role=='display'and'Spectral'or'Fira',size,'');f:SetTextColor(unpack(color));return f end
    function W:Button(parent,text,click,primary)local f=CreateFrame('Button',nil,parent);T:PaintButton(f,primary);f:SetBackdropBorderColor(unpack(T.line));f.text=self:Label(f,text,12,T.text);f.text:SetPoint('CENTER');f:SetScript('OnClick',click);return f end
    function W:Toggle(parent,text,get,set)
        local f=CreateFrame('Button',nil,parent);T:PaintButton(f,false);f.label=self:Label(f,text,11,T.text);f.label:SetPoint('LEFT',42,0)
        f.track=CreateFrame('Frame',nil,f);f.track:SetSize(28,16);f.track:SetPoint('LEFT',8,0)
        function f:Refresh()self.track:SetBackdropColor(unpack(get()and T.accent or T.lineSoft))end
        f:SetScript('OnClick',function()set(not get());f:Refresh()end);f:Refresh();return f
    end
    function W:WindowHeader(parent,options)
        local f=CreateFrame('Frame',nil,parent);f:SetPoint('TOPLEFT',1,-1);f:SetPoint('TOPRIGHT',-1,-1);f:SetHeight(options.height);T:PanelSurface(f)
        f.title=self:Label(f,options.title,options.titleSize,T.text,'display');f.title:SetPoint('LEFT',55,0)
        f.close=self:Button(f,'',options.onClose);f.close:SetSize(25,25);f.close:SetPoint('RIGHT',-8,0)
        return f
    end
    M.themeTints={};M.themeAlphas={}
    Sintezza_Theme={Settings=T,GetLocale=GetLocale,ForAddon=function()return T end,CreateWidgets=function()return W end,
        Tint=function(_,region,method,color,alpha)
            M.themeTints[region]=M.themeTints[region]or{};M.themeTints[region][method]=color
            M.themeAlphas[region]=M.themeAlphas[region]or{};M.themeAlphas[region][method]=alpha
            region[method](region,color[1],color[2],color[3],alpha or color[4]or 1)
        end,
        ShowTooltip=function(_,owner,title,body)M.themeTooltip={owner=owner,title=title,body=body};GameTooltip:SetOwner(owner);GameTooltip:SetText(title);GameTooltip:AddLine(body)end,
        HideTooltip=function(_,owner)if M.themeTooltip and M.themeTooltip.owner==owner then M.themeTooltip=nil end end,
        TrackAppearance=function(_,region,key,callback)region.themeRefresh=callback end,
        RefreshAppearance=function()for region,methodsByName in pairs(M.themeTints)do for method,color in pairs(methodsByName)do region[method](region,color[1],color[2],color[3],M.themeAlphas[region][method]or color[4]or 1)end end end}
end
