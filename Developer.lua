local addon, ns = ...
local N, Clean = ns.Number, ns.CleanText
local clock, profile = GetTimePreciseSec or GetTime, debugprofilestop
local modules, moduleKeys, points = {}, {}, {}
local moduleList, pointCount = {}, 0
local active, last
local collector=CreateFrame("Frame")
local API={version=1}
Sintezza_PerfAPI=API
ns.DEV_LIMITS={modules=64,registeredPoints=512,points=128,operations=20000,depth=32,seconds=60}
local contextEvents={"PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","ENCOUNTER_START","ENCOUNTER_END","ZONE_CHANGED_NEW_AREA","GROUP_ROSTER_UPDATE","PLAYER_LOGOUT"}

local function ID(value,limit)
    if type(value)~="string" or issecretvalue and issecretvalue(value) or #value<1 or #value>limit then return end
    if value:find("[^%w_%.%-]") then return end
    return value
end
local function Bool(value) return not (issecretvalue and issecretvalue(value)) and type(value)=="boolean" end
local function Notify() if ns.OnDataChanged then ns.OnDataChanged() end end
local function Pending(reason)
    if active and not active.reason then active.reason=reason;active.accepting=false end
end
local function Cost(started)
    if not active then return end
    local elapsed=N(profile()-started)
    if not elapsed then active.report.missing=active.report.missing+1;Pending("clock");return end
    active.frameCost=active.frameCost+elapsed
    if elapsed>20 then Pending("overhead") end
end
function API:RegisterModule(addonFolder,moduleID,options)
    if not ID(addonFolder,128) or not ID(moduleID,64) then return nil,"invalid_id" end
    options=type(options)=="table" and options or {}
    local key=addonFolder..":"..moduleID
    if moduleKeys[key] then return moduleKeys[key].handle,"existing" end
    if active then return nil,"busy" end
    if #moduleList>=ns.DEV_LIMITS.modules then return nil,"registry_limit" end
    local handle={}
    local m={key=key,addon=addonFolder,module=moduleID,title=Clean(options.title,120) or moduleID,
        titleRu=Clean(options.titleRu,120),build=Clean(options.build,80),buildSource=Clean(options.buildSource,32),
        visibility=options.visibility==true,changeSignal=options.changes==true,points={},handle=handle}
    modules[handle],moduleKeys[key]=m,m;moduleList[#moduleList+1]=m
    return handle
end
function API:RegisterPoint(module,pointID,options)
    local m=modules[module]
    if not m or not ID(pointID,64) then return nil,"invalid_id" end
    for _,p in ipairs(m.points) do if p.point==pointID then return p.handle,"existing" end end
    if active then return nil,"busy" end
    if pointCount>=ns.DEV_LIMITS.registeredPoints then return nil,"registry_limit" end
    options=type(options)=="table" and options or {}
    local handle={}
    local p={key=m.key..":"..pointID,addon=m.addon,module=m.module,point=pointID,owner=m,handle=handle,
        title=Clean(options.title,120) or pointID,titleRu=Clean(options.titleRu,120),
        kind=options.kind=="counter" and "counter" or "call",memory=options.memory==true,
        visibility=m.visibility,changeSignal=m.changeSignal}
    p.timing=p.kind=="call";if not p.timing then p.memory=false end
    points[handle]=p;m.points[#m.points+1]=p;pointCount=pointCount+1
    return handle
end
function API:SetBuildLabel(module,label,source)
    local m=modules[module]
    if not m then return false,"unknown_module" end
    if active then return false,"busy" end
    local cleanLabel,cleanSource=Clean(label,80),Clean(source,32)
    if not cleanLabel or not cleanSource then return false,"invalid_label" end
    m.build,m.buildSource=cleanLabel,cleanSource;return true
end
function API:IsActive(point)
    return active~=nil and active.accepting and active.points[points[point]]~=nil
end
local function Signal(run)
    run.report.signals=run.report.signals+1
    if run.report.calls+run.report.signals>=ns.DEV_LIMITS.operations then Pending("limit") end
end
local function VisibilityTime(state,now)
    local delta=math.max(0,now-state.visibleAt)
    if state.visible~=nil then
        state.visibilitySeconds=state.visibilitySeconds+delta
        if not state.visible then state.hiddenSeconds=state.hiddenSeconds+delta end
    end
    state.visibleAt=now
end
function API:SetVisible(module,value)
    local m=modules[module]
    if not m or not m.visibility then return false end
    if issecretvalue and issecretvalue(value) then return false end
    if value~=nil and not Bool(value) then return false end
    if m.visible==value then return true end
    m.visible=value
    local run=active;local state=run and run.modules[m]
    if state and run.accepting then
        local started=profile();VisibilityTime(state,clock());state.visible=value;Signal(run);Cost(started)
    end
    return true
end
function API:MarkChanged(point)
    local run=active
    if not run or not run.accepting then return false end
    local p=points[point];local row=p and run.points[p]
    if not row or not p.changeSignal then return false end
    local started=profile();row.changes=row.changes+1;run.modules[p.owner].changes=run.modules[p.owner].changes+1
    Signal(run);Cost(started);return true
end
local function Observe(run,p,row)
    local state=run.modules[p.owner]
    row.calls=row.calls+1;state.calls=state.calls+1;run.report.calls=run.report.calls+1
    if state.visible~=nil then
        row.visibilityCalls=row.visibilityCalls+1;state.visibilityCalls=state.visibilityCalls+1
        if not state.visible then row.hiddenCalls=row.hiddenCalls+1;state.hiddenCalls=state.hiddenCalls+1 end
    end
    if run.report.calls+run.report.signals>=ns.DEV_LIMITS.operations then Pending("limit") end
    return state
end
function API:Count(point)
    local run=active
    if not run or not run.accepting then return false end
    local p=points[point];local row=p and run.points[p]
    if not row or p.kind~="counter" then return false end
    local started=profile()
    if clock()>=run.deadline then Pending("complete");Cost(started);return false end
    Observe(run,p,row);Cost(started);return true
end
local function Result(value)
    if issecretvalue and issecretvalue(value) or type(value)~="table" then return end
    local elapsed,allocated,freed=N(value.elapsedMilliseconds),N(value.allocatedBytes),N(value.deallocatedBytes)
    if not elapsed or not allocated or not freed or allocated>9007199254740991 or freed>9007199254740991 then return end
    return elapsed,allocated,freed
end
local function Probe() return 17,nil,29 end
function API:GetCapabilities()
    local native=C_AddOnProfiler
    local enabled=true
    if native and type(native.IsEnabled)=="function" then
        local ok,value=pcall(native.IsEnabled)
        enabled=ok and not (issecretvalue and issecretvalue(value)) and value==true
    end
    return {count=type(profile)=="function" and type(clock)=="function",cpu=type(profile)=="function" and type(clock)=="function",
        memory=enabled and type(profile)=="function" and type(native)=="table" and type(native.MeasureCall)=="function",
        memoryNeedsProbe=true,apiVersion=1}
end
local function NativeProbe()
    local api=C_AddOnProfiler
    if not API:GetCapabilities().memory then return false end
    local ok,result,a,b,c=pcall(api.MeasureCall,Probe)
    if not ok or issecretvalue and (issecretvalue(a) or issecretvalue(b) or issecretvalue(c)) or a~=17 or b~=nil or c~=29 then return false end
    local readable,elapsed=pcall(Result,result)
    return readable and elapsed~=nil
end
local function Finish(slot,ok,elapsed,allocated,freed,ended)
    local run=slot.run;local row,state=slot.row,slot.module
    if not ok then
        row.errors=row.errors+1;state.errors=state.errors+1;run.report.errors=run.report.errors+1;Pending("error")
    end
    if run.report.mode~="count" then
        if ok and elapsed then
            row.samples=row.samples+1;row.totalMs=row.totalMs+elapsed;row.peakMs=math.max(row.peakMs,elapsed)
            if slot.selfValid and elapsed>=slot.children then row.selfMs=row.selfMs+elapsed-slot.children else row.selfValid=false end
            if slot.root then state.samples=state.samples+1;state.totalMs=state.totalMs+elapsed;state.peakMs=math.max(state.peakMs,elapsed) end
            if allocated and freed then
                row.allocatedBytes=row.allocatedBytes+allocated;row.freedBytes=row.freedBytes+freed;row.memorySamples=row.memorySamples+1
                if slot.root then state.allocatedBytes=state.allocatedBytes+allocated;state.freedBytes=state.freedBytes+freed;state.memorySamples=state.memorySamples+1 end
            end
        else
            row.missing=row.missing+1;row.selfValid=false;state.missing=state.missing+1;run.report.missing=run.report.missing+1
            if ok then Pending("metric") end
        end
    end
    state.depth=state.depth-1;run.depth=run.depth-1
    local parent=run.stack[run.depth]
    if parent then
        if elapsed and ok then parent.children=parent.children+elapsed else parent.selfValid=false end
    end
    -- Target execution is excluded; nested service work is charged by its own slot.
    local service=slot.started-slot.before+math.max(0,profile()-ended)
    if run.report.mode=="alloc" and elapsed then service=service+math.max(0,ended-slot.started-elapsed) end
    run.frameCost=run.frameCost+math.max(0,service)
    if service>20 then Pending("overhead") end
    slot.run,slot.row,slot.module=nil,nil,nil
end
local function FinishCPU(slot,ok,...)
    local ended=profile();local elapsed=N(ended-slot.started)
    if ok and not elapsed then Pending("clock") end
    Finish(slot,ok,elapsed,nil,nil,ended)
    if not ok then error((...),0) end
    return ...
end
local function FinishNative(slot,ok,result,...)
    local ended=profile();local readable,elapsed,allocated,freed=pcall(Result,result)
    if not readable then elapsed,allocated,freed=nil,nil,nil end
    Finish(slot,ok,elapsed,allocated,freed,ended)
    if not ok then error(result,0) end
    return ...
end
function API:Call(point,fn,...)
    local run=active
    if not run or not run.accepting then return fn(...) end
    local p=points[point];local row=p and run.points[p]
    if not row or p.kind~="call" then return fn(...) end
    local before=profile()
    if clock()>=run.deadline then Pending("complete");Cost(before);return fn(...) end
    if run.depth>=ns.DEV_LIMITS.depth then
        row.selfValid=false;run.report.missing=run.report.missing+1;Pending("depth");Cost(before);return fn(...)
    end
    local state=Observe(run,p,row)
    run.depth=run.depth+1;local slot=run.stack[run.depth]
    slot.run,slot.row,slot.module,slot.before=run,row,state,before
    slot.root=state.depth==0;state.depth=state.depth+1
    slot.children,slot.selfValid=0,true;slot.started=profile()
    if run.report.mode=="alloc" then return FinishNative(slot,pcall(run.measure,fn,...)) end
    return FinishCPU(slot,pcall(fn,...))
end
function ns.DevModules() return moduleList end
function ns.DevRunning() return active~=nil end
function ns.DevCurrent()
    if last and not ns.DevFind(last.id) then last=nil end
    return active and active.report or last or ns.DevHistory()[1]
end
function ns.DevElapsed() return active and math.max(0,clock()-active.started) or 0 end
function ns.DevTitle(row) return ns.Text(row.titleRu or row.title,row.title) or row.key end
local function NewRow(source)
    return {key=source.key,addon=source.addon,module=source.module,point=source.point,title=source.title,titleRu=source.titleRu,
        kind=source.kind,timing=source.timing,memory=source.memory,visibility=source.visibility,changeSignal=source.changeSignal,
        build=source.build,buildSource=source.buildSource,calls=0,hiddenCalls=0,visibilityCalls=0,changes=0,samples=0,missing=0,errors=0,
        totalMs=0,selfMs=0,peakMs=0,allocatedBytes=0,freedBytes=0,memorySamples=0,selfValid=true,
        hiddenSeconds=0,visibilitySeconds=0,depth=0}
end
local function EndCapture()
    local run=active
    if not run or run.depth>0 then return end
    local r=run.report;local now=clock()
    r.duration=math.max(0,(run.stoppedAt or now)-run.started);r.reason=run.reason or "manual";r.complete=r.reason=="complete"
    for _,row in pairs(run.modules) do VisibilityTime(row,run.stoppedAt or now) end
    r.serviceTotal=run.serviceTotal+run.frameCost
    r.servicePeak=math.max(run.servicePeak,run.frameCost)
    r.serviceMean=r.frames>0 and r.serviceTotal/r.frames or nil
    r.nativeMean=r.nativeSamples>0 and r.nativeSamples==r.frames-1 and run.nativeTotal/r.nativeSamples or nil
    for _,row in ipairs(r.points) do
        if r.mode=="count" or not row.timing or row.samples~=row.calls then row.totalMs,row.selfMs,row.peakMs=nil,nil,nil end
        if not row.selfValid then row.selfMs=nil end
        if r.mode~="alloc" or row.memorySamples~=row.calls then row.allocatedBytes,row.freedBytes=nil,nil end
        if not row.visibility or row.visibilityCalls~=row.calls then row.hiddenCalls=nil end
        if not row.changeSignal then row.changes=nil end
    end
    for _,row in ipairs(r.modules) do
        if r.mode=="count" or not row.timing or row.missing>0 then row.totalMs,row.peakMs=nil,nil end
        if r.mode~="alloc" then row.allocatedBytes,row.freedBytes=nil,nil end
        if not row.visibility or row.visibilityCalls~=row.calls then row.hiddenCalls=nil end
        if not row.changeSignal then row.changes=nil end
        if not row.visibility or row.visibilitySeconds+0.001<r.duration then row.hiddenSeconds=nil end
    end
    active=nil;collector:SetScript("OnUpdate",nil)
    for _,event in ipairs(contextEvents) do collector:UnregisterEvent(event) end
    last=ns.DevSave(r)
    if ns.ResetBackgroundBaseline then ns.ResetBackgroundBaseline() end
    Notify()
end
function ns.DevStop(reason)
    if not active then return false end
    Pending(reason or "manual");active.stoppedAt=active.stoppedAt or clock()
    if active.depth==0 then EndCapture() end
    return true
end
local function Tick()
    local run=active;if not run then return end
    local started=profile();local r=run.report
    if run.reason then run.stoppedAt=run.stoppedAt or clock();EndCapture();return end
    r.frames=r.frames+1
    -- LastTime describes the preceding frame; discard the first callback.
    if r.frames>1 and run.nativeAvailable and ns.Metric then
        local native=ns.Metric(addon,"LastTime")
        if native then run.nativeTotal=run.nativeTotal+native;r.nativeSamples=r.nativeSamples+1 end
    end
    local cost=run.frameCost+math.max(0,profile()-started)
    run.frameCost=0;run.serviceTotal=run.serviceTotal+cost;run.servicePeak=math.max(run.servicePeak,cost)
    run.costIndex=run.costIndex%60+1;run.costSum=run.costSum-run.costs[run.costIndex]+cost;run.costs[run.costIndex]=cost
    if cost>20 or r.frames>=60 and run.costSum/60>1 then Pending("overhead") end
    if clock()>=run.deadline then Pending("complete") end
    if run.reason then run.stoppedAt=clock();EndCapture() end
end
collector:SetScript("OnEvent",function(_,event)
    if not active then return end
    if event=="PLAYER_LOGOUT" then ns.DevStop("logout") else active.report.contextChanged=true end
end)
function ns.DevStart(options)
    if active or select(2,ns.Capture()) or ns.Armed() then return false,"busy" end
    if not ns.db or not ns.db.developer then return false,"not_ready" end
    options=type(options)=="table" and options or {}
    local mode=options.mode or "count"
    if mode~="count" and mode~="cpu" and mode~="alloc" then return false,"mode" end
    if type(profile)~="function" or type(clock)~="function" then return false,"clock" end
    if mode=="alloc" and not NativeProbe() then return false,"memory_api" end
    local scenario=Clean(options.scenario,160)
    if not scenario then return false,"scenario" end
    local duration=N(options.duration) or 15
    if duration<1 or duration>60 then return false,"duration" end
    local selected=type(options.modules)=="table" and options.modules or {}
    local pointFilter,filterCount,matched
    if options.points~=nil then
        if type(options.points)~="table" or #options.points>ns.DEV_LIMITS.points then return false,"points_limit" end
        pointFilter,filterCount,matched={},0,0
        for _,key in ipairs(options.points)do
            if type(key)~="string" or issecretvalue and issecretvalue(key) then return false,"unknown_point" end
            if not pointFilter[key]then pointFilter[key]=true;filterCount=filterCount+1 end
        end
    end
    local run={points={},modules={},stack={},costs={},costIndex=0,costSum=0,frameCost=0,serviceTotal=0,servicePeak=0,nativeTotal=0,depth=0,accepting=true,
        measure=C_AddOnProfiler and C_AddOnProfiler.MeasureCall,nativeAvailable=ns.Available()}
    local r={schema=ns.DEV_SCHEMA,mode=mode,requested=duration,scenario=scenario,method=mode=="alloc" and "native-measurecall-1" or mode=="cpu" and "lua-clock-1" or "counters-1",
        timestamp=time(),modules={},points={},context=ns.ReadContext(),calls=0,signals=0,errors=0,missing=0,frames=0,nativeSamples=0}
    local version,build=GetBuildInfo();r.client=tostring(version).."."..tostring(build)
    run.report=r
    for _,key in ipairs(selected) do
        local m=moduleKeys[key]
        if not m then return false,"unknown_module" end
        if not run.modules[m] then
            local row=NewRow(m);run.modules[m]=row;r.modules[#r.modules+1]=row
            local before=#r.points
            for _,p in ipairs(m.points) do
                if not pointFilter or pointFilter[p.key]then
                    if pointFilter then matched=matched+1 end
                    row.timing=row.timing or p.timing
                    if mode=="alloc" and (not p.memory or not p.timing) then return false,"point_memory" end
                    local pr=NewRow(p);run.points[p]=pr;r.points[#r.points+1]=pr
                    if #r.points>ns.DEV_LIMITS.points then return false,"points_limit" end
                end
            end
            if #r.points==before then table.remove(r.modules);run.modules[m]=nil end
        end
    end
    if pointFilter and matched~=filterCount then return false,"unknown_point" end
    if #r.points==0 then return false,"no_points" end
    table.sort(r.modules,function(a,b)return a.key<b.key end);table.sort(r.points,function(a,b)return a.key<b.key end)
    for i=1,ns.DEV_LIMITS.depth do run.stack[i]={} end
    for i=1,60 do run.costs[i]=0 end
    run.started=clock();run.deadline=run.started+duration
    for m,row in pairs(run.modules) do row.visible=m.visible;row.visibleAt=run.started end
    for _,event in ipairs(contextEvents) do if not pcall(collector.RegisterEvent,collector,event) then r.contextChanged=true end end
    active=run;collector:SetScript("OnUpdate",Tick);Notify();return true
end
