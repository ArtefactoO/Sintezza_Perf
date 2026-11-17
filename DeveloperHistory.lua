local _, ns = ...
local N, Clean = ns.Number, ns.CleanText
local storage
ns.DEV_SCHEMA, ns.DEV_REPORT_LIMIT = 1, 20
local reportNumbers = {"id","timestamp","duration","requested","calls","signals","errors","missing","frames","nativeSamples","nativeMean","serviceMean","servicePeak","serviceTotal"}
local rowNumbers = {"calls","hiddenCalls","visibilityCalls","changes","samples","missing","errors","totalMs","selfMs","peakMs","allocatedBytes","freedBytes","memorySamples","hiddenSeconds","visibilitySeconds"}
local function CopyNumbers(source, target, keys)
    for _, key in ipairs(keys) do target[key] = N(source[key]) end
end
local function CopyRows(source, limit)
    local rows = {}
    if type(source) ~= "table" then return rows end
    for i = 1, math.min(#source, limit) do
        local old = source[i]
        if type(old) == "table" and Clean(old.key, 260) then
            local row = { key=Clean(old.key,260), addon=Clean(old.addon,128), module=Clean(old.module,64), point=Clean(old.point,64),
                title=Clean(old.title,120), titleRu=Clean(old.titleRu,120), build=Clean(old.build,80), buildSource=Clean(old.buildSource,32),
                kind=old.kind=="counter" and "counter" or "call", timing=old.timing==true, memory=old.memory==true,
                visibility=old.visibility==true, changeSignal=old.changeSignal==true, selfValid=old.selfValid==true }
            CopyNumbers(old,row,rowNumbers)
            rows[#rows+1] = row
        end
    end
    return rows
end
local function Sanitize(old)
    if type(old) ~= "table" or old.schema ~= ns.DEV_SCHEMA or not N(old.id) or not N(old.timestamp)
        or not N(old.duration) or old.duration > 86400 or not N(old.requested) or old.requested > 60 then return end
    if old.mode ~= "count" and old.mode ~= "cpu" and old.mode ~= "alloc" then return end
    local r = {schema=ns.DEV_SCHEMA, mode=old.mode, complete=old.complete==true, contextChanged=old.contextChanged==true,
        scenario=Clean(old.scenario,160), reason=Clean(old.reason,40), method=Clean(old.method,80), client=Clean(old.client,80),
        modules=CopyRows(old.modules,64), points=CopyRows(old.points,128), context={}, group=old.group=="A" and "A" or old.group=="B" and "B" or nil}
    CopyNumbers(old,r,reportNumbers)
    if type(old.context)=="table" then
        for _,k in ipairs({"zone","instanceType"}) do r.context[k]=Clean(old.context[k],128) end
        CopyNumbers(old.context,r.context,{"map","groupSize","fpsLimit","difficulty"})
        if type(old.context.combat)=="boolean" then r.context.combat=old.context.combat end
    end
    return r
end
function ns.InitDeveloperHistory(db)
    local previous = type(db.developer)=="table" and db.developer or {}
    storage = {schema=ns.DEV_SCHEMA, reports={}, nextID=0}
    if previous.schema==ns.DEV_SCHEMA and type(previous.reports)=="table" then
        local seen={}
        for i=1,math.min(#previous.reports,ns.DEV_REPORT_LIMIT) do
            local r=Sanitize(previous.reports[i])
            if r and not seen[r.id] then
                storage.reports[#storage.reports+1]=r;seen[r.id]=true;storage.nextID=math.max(storage.nextID,r.id)
            end
        end
        storage.nextID=math.max(storage.nextID,math.min(N(previous.nextID) or 0,1e12))
    end
    db.developer=storage
end
function ns.DevHistory() return storage and storage.reports or {} end
function ns.DevFind(id)
    for _,r in ipairs(ns.DevHistory()) do if r.id==id then return r end end
end
function ns.DevSave(r)
    if not storage then return end
    storage.nextID=storage.nextID+1;r.id=storage.nextID;r.schema=ns.DEV_SCHEMA
    local saved=Sanitize(r)
    if not saved then return end
    table.insert(storage.reports,1,saved)
    while #storage.reports>ns.DEV_REPORT_LIMIT do table.remove(storage.reports) end
    return saved
end
function ns.DevDelete(id)
    for i,r in ipairs(ns.DevHistory()) do if r.id==id then table.remove(storage.reports,i);return true end end
end
function ns.DevAssign(id,group)
    local r=ns.DevFind(id)
    if not r then return false end
    r.group=group=="A" and "A" or group=="B" and "B" or nil
    return true
end
function ns.DevClearGroups()
    for _,r in ipairs(ns.DevHistory()) do r.group=nil end
end
local function Eligible(r)
    if not r.complete or r.reason~="complete" then return false,"partial" end
    if not r.scenario or not r.client or not r.method or #r.points==0 then return false,"unknown" end
    if (r.errors or 0)>0 or (r.missing or 0)>0 then return false,"missing" end
    if r.contextChanged then return false,"context" end
    local c=r.context
    for _,key in ipairs({"zone","instanceType","map","difficulty","groupSize","fpsLimit","combat"}) do
        if c[key]==nil then return false,"unknown" end
    end
    for _,m in ipairs(r.modules) do if not m.build or not m.buildSource then return false,"code" end end
    return true
end
local function Compatible(a,b)
    for _,key in ipairs({"mode","requested","scenario","method","client"}) do if a[key]~=b[key] then return false,"conditions" end end
    if math.abs(a.duration-b.duration)>math.max(.5,math.min(a.duration,b.duration)*.02) then return false,"conditions" end
    for key,value in pairs(a.context) do if b.context[key]~=value then return false,"conditions" end end
    if #a.points~=#b.points or #a.modules~=#b.modules then return false,"points" end
    for i,p in ipairs(a.points) do
        local q=b.points[i]
        for _,k in ipairs({"key","kind","timing","memory","visibility","changeSignal"}) do if p[k]~=q[k] then return false,"points" end end
    end
    return true
end
local function SameCode(a,b)
    for i,m in ipairs(a.modules) do local n=b.modules[i];if not n or m.key~=n.key or m.build~=n.build or m.buildSource~=n.buildSource then return false end end
    return true
end
function ns.DevComparison(pointKey)
    local c={A={},B={},metrics={},compatible=true,pointKey=pointKey}
    local base
    for _,r in ipairs(ns.DevHistory()) do
        if r.group then
            local list=c[r.group];list[#list+1]=r
            local ok,reason=Eligible(r)
            if ok and base then ok,reason=Compatible(base,r) end
            if ok and #list>1 and not SameCode(list[1],r) then ok,reason=false,"code" end
            if not ok then c.compatible,c.reason=false,c.reason or reason end
            base=base or r
        end
    end
    if #c.A==0 or #c.B==0 then c.compatible,c.reason=false,"empty" end
    c.baseline,c.repeated=base,#c.A>=3 and #c.B>=3
    for _,key in ipairs({"calls","totalMs","hiddenCalls","nativeMean","serviceMean"}) do
        local result={}
        for _,g in ipairs({"A","B"}) do
            local values={}
            for _,r in ipairs(c[g]) do
                local row
                for _,p in ipairs(r.points) do if p.key==pointKey then row=p;break end end
                local value
                if key=="nativeMean" or key=="serviceMean" then value=r[key]
                elseif row then
                    value=row[key]
                    if key=="totalMs" and (r.mode=="count" or not row.timing or row.samples~=row.calls) then value=nil end
                    if key=="hiddenCalls" and (not row.visibility or row.visibilityCalls~=row.calls) then value=nil end
                end
                if N(value) then values[#values+1]=value end
            end
            if #values==#c[g] then result[g]=ns.Median(values) end
        end
        if c.compatible and result.A and result.A>0 and result.B then result.delta=(result.B-result.A)/result.A*100 end
        c.metrics[key]=result
    end
    return c
end
function ns.DevExport(r,format,comparison)
    local payload={format="Sintezza_Perf/developer-1", apiVersion=1, observerIncluded=true,
        limits={seconds=60,operations=20000,points=128,depth=32}, report=r, comparison=comparison,
        scope="Registered synchronous sections only. Inclusive rows overlap. Observer estimates must not be added or subtracted. Missing values are unavailable, not zero."}
    if format=="json" then return ns.JSON(payload) end
    local lines={"Sintezza Perf / Developer API 1",payload.scope}
    if r then
        lines[#lines+1]=("%s | %s | %.2f / %.0f s | %s"):format(r.scenario or "?",r.mode,r.duration,r.requested,r.reason or "?")
        lines[#lines+1]="Conditions: "..ns.JSON(r.context)
        for _,m in ipairs(r.modules) do lines[#lines+1]=m.key.." | code="..(m.build or "n/a").." | source="..(m.buildSource or "n/a") end
        for _,p in ipairs(r.points) do
            local measured=r.mode~="count" and p.timing and p.samples==p.calls
            lines[#lines+1]=("%s | calls=%d | inclusiveMs=%s | knownSelfMs=%s | allocatedBytes=%s | errors=%d"):format(p.key,p.calls or 0,
                measured and tostring(p.totalMs) or "n/a",measured and p.selfValid and tostring(p.selfMs) or "n/a",
                r.mode=="alloc" and p.memorySamples==p.calls and tostring(p.allocatedBytes) or "n/a",p.errors or 0)
        end
        lines[#lines+1]="Native Perf ms/frame="..tostring(r.nativeMean or "n/a").."; accounted service ms/frame="..tostring(r.serviceMean or "n/a")
    end
    if comparison then lines[#lines+1]=ns.JSON(comparison) end
    return table.concat(lines,"\n")
end
