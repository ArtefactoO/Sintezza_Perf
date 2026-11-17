local addon, ns = ...
local L = ns.Text

function ns.BuildPhase2UI(ui, K)
    local P = { sub = "smooth", selected = 1, historyOffset = 0 }
    local T, teal = K.Theme, K.Secondary
    local function Mean(r) return r.average or r.total and r.samples and r.samples > 0 and r.total/r.samples or nil end
    local function Profile(r) return r.profile == "light" and L("легкий", "light") or L("подробный", "detailed") end
    local function Refresh() K.Paint(false); K.Schedule() end
    local function Reopen(id)
        ui.reportID, ui.view, ui.rowOffset = id, "capture", 0
        P.selected, P.sub, P.markerOffset = 1, "smooth", 0
        Refresh()
    end
    local function ShowError(reason) print("Sintezza Perf: " .. ns.ComparisonReason(reason)) end
    local function Observer(r)
        for _, row in ipairs(r and r.rows or {}) do if row.name == addon then return Mean(row) end end
    end
    local function Put(label, text) label:SetText(text or "") end
    local function HideTable()
        ui.tableFrame:Hide(); ui.tableCount:Hide(); ui.tableUp:Hide(); ui.tableDown:Hide()
    end
    local function Label(parent, text, x, y, size, color, right)
        local f=K.Label(parent,text,size or 12,color or T.text)
        f:SetPoint("TOPLEFT",x,-y)
        if right then f:SetPoint("TOPRIGHT",-right,-y) end
        return f
    end
    local function Button(parent,text,x,y,w,click,help,primary)
        local b=K.Button(parent,text,click,primary,help);b:SetPoint("TOPLEFT",x,-y);b:SetWidth(w)
        return b
    end
    local function Stat(parent,x,w)
        local f=CreateFrame("Frame",nil,parent);f:SetPoint("TOPLEFT",x,0);f:SetSize(w,61);f:EnableMouse(true)
        f.name=Label(f,"",12,8,11,T.muted);f.value=Label(f,"",12,27,21)
        K.Describe(f,function()return f.name:GetText()end,function()return f.help or ""end)
        return f
    end
    local function SetStat(index,title,value,help)
        local f=P.stats[index];Put(f.name,title);Put(f.value,value);f.help=help
    end
    local function NewLine(parent,role)return K.DataLine(parent,role)end
    local function Line(line,x1,y1,x2,y2)
        if not line then return end
        line:SetStartPoint("BOTTOMLEFT",P.plot,x1,y1);line:SetEndPoint("BOTTOMLEFT",P.plot,x2,y2);line:Show()
    end

    function P:Ensure()
        if self.root then return end
        local root=CreateFrame("Frame",nil,ui);root:SetPoint("TOPLEFT",18,-112);root:SetPoint("BOTTOMRIGHT",-18,42);self.root=root
        self.title=Label(root,"",0,0,19,T.accent,320)
        self.meta=Label(root,"",0,29,11,T.muted,0);self.meta:SetWordWrap(false)
        K.Hover(root,self.meta,L("Область записи","Recording scope"),function()
            local r=K.Record()
            return L("Отчет относится к выбранной записи. Частичные, старые или несовместимые записи не дают процент сравнения. Номер версии может совпадать при разном локальном коде.","Report data belongs to the selected recording. Partial, legacy or incompatible recordings do not produce comparison percentages. Equal version numbers can contain different local code.")
                ..(r and "\n"..L("Пропуски CPU / кадров: ","Missing CPU / frame readings: ")..tostring(r.missing or 0).." / "..tostring(r.frameMissing or 0) or "")
        end)
        self.export=Button(root,L("Экспорт","Export"),854,0,110,function()K.OpenDialog(ui.view=="compare"and"comparison"or"export")end,L("Копирует выбранный отчет или обе группы сравнения с условиями и нагрузкой Perf. Текст и JSON; отправки в сеть нет.","Copy the selected report or both comparison groups with conditions and Perf overhead. Text and JSON; nothing is sent over the network."))
        self.rename=Button(root,L("Имя","Name"),670,0,62,function()K.OpenDialog("rename")end,L("Изменяет название отчета. Исходное имя сценария в условиях записи сохраняется.","Rename the report. The original scenario name in recorded conditions is preserved."))
        self.pin=Button(root,L("Закрепить","Pin"),738,0,110,function()local r=K.Record();if r and not ns.PinRecord(r.id)then print(L("Лимит: 10 закрепленных отчетов.","Limit: 10 pinned reports."))end;Refresh()end,L("Сохраняет отчет сверх обычного лимита истории. Повторное нажатие снимает закрепление; максимум 10.","Retain this report in addition to regular history. Press again to unpin; maximum 10."))
        self.summary=K.Sidebar(root);self.summary:SetPoint("TOPLEFT",0,-55);self.summary:SetPoint("TOPRIGHT",0,-55);self.summary:SetHeight(61)
        self.stats={};for i=1,3 do self.stats[i]=Stat(self.summary,(i-1)*321,321)end
        self.tabs={}
        for i,entry in ipairs({{"smooth",L("Плавность и события","Smoothness and events")},{"addons",L("Аддоны","Addons")},{"memory",L("Память","Memory")}})do
            local key=entry[1]
            local b=Button(root,entry[2],(i-1)*170,130,164,function()P.sub=key;P.selected=1;ui.rowOffset=0;Refresh()end,
                key=="smooth"and L("Время наблюдавшихся кадров и CPU аддонов в том же кадре. События рядом со спайком не доказывают его причину.","Observed frame intervals and addon CPU in the same frame. Nearby events do not prove the cause of a spike.")
                or key=="addons"and L("Отдельные аддоны записываются только в подробном режиме. Perf остается включен в общий итог.","Individual addons are recorded only in detailed mode. Perf remains included in totals.")
                or L("Редкие снимки памяти сеанса на момент завершения записи. Другой временной диапазон; пропуски не интерполируются.","Rare session memory snapshots as of recording completion. A separate time range; missing samples are not interpolated."))
            self.tabs[key]=b
        end
        self.graph=CreateFrame("Frame",nil,root);self.graph:SetPoint("TOPLEFT",0,-174);self.graph:SetPoint("TOPRIGHT",0,-174);self.graph:SetHeight(260)
        self.graphTitle=Label(self.graph,"",0,0,13)
        self.legend=Label(self.graph,"",380,0,11,T.muted)
        if K.Widgets then
            self.seriesLegend=CreateFrame("Frame",nil,self.graph);self.seriesLegend:SetPoint("TOPLEFT",380,0);self.seriesLegend:SetSize(270,18)
            self.frameSwatch=K.DataTexture(self.seriesLegend,"accent");self.frameSwatch:SetPoint("TOPLEFT",0,-6);self.frameSwatch:SetSize(16,2)
            Label(self.seriesLegend,L("Кадр","Frame"),22,0,11,T.muted)
            self.cpuSwatch=K.DataTexture(self.seriesLegend,"brass");self.cpuSwatch:SetPoint("TOPLEFT",100,-6);self.cpuSwatch:SetSize(16,2)
            Label(self.seriesLegend,L("CPU аддонов","Addon CPU"),122,0,11,T.muted)
            self.seriesLegend:Hide()
        end
        self.plot=CreateFrame("Frame",nil,self.graph);self.plot:SetPoint("TOPLEFT",32,-28);self.plot:SetSize(650,192)
        self.axisMax=Label(self.graph,"",0,26,10,T.muted);self.axisMid=Label(self.graph,"",0,117,10,T.muted)
        self.axisZero=Label(self.graph,"0",13,206,10,T.muted)
        self.axisStart=Label(self.graph,"",32,224,10,T.muted);self.axisEnd=Label(self.graph,"",624,224,10,T.muted)
        self.lines,self.cpuLines,self.hits={},{},{}
        for i=1,60 do
            self.lines[i]=NewLine(self.plot,"accent");self.cpuLines[i]=NewLine(self.plot,"brass")
            local index=i;local b=CreateFrame("Button",nil,self.plot)
            b.wash=K.DataTexture(b,"accentDim","BACKGROUND");b.wash:SetAllPoints();b.wash:SetAlpha(.45)
            b:SetScript("OnClick",function()P.selected=index;Refresh()end)
            K.Describe(b,L("Интервал / снимок","Interval / snapshot"),function()local p=P.points and P.points[index];if not p then return ""end;if p.timestamp then return date("%H:%M:%S",p.timestamp).."\n"..K.Value(p.value,"%.2f")..L(" МиБ Lua. Не вся память игры."," MiB Lua. Not all game memory.")end;return K.Clock(p.at or p.from).."\n"..L("Кадр / CPU в том же кадре, мс: ","Frame / CPU in the same frame, ms: ")..K.Value(p.frame,"%.2f").." / "..K.Value(p.cpu,"%.3f")end)
            b.dot=K.DataTexture(b,"accent");b.dot:SetSize(5,5)
            self.hits[i]=b
        end
        self.detail=K.Sidebar(self.graph);self.detail:SetPoint("TOPRIGHT",0,-25);self.detail:SetSize(260,220)
        self.detailTime=Label(self.detail,"",12,10,20,T.accent)
        self.detailValue=Label(self.detail,"",12,43,12,nil,12);self.detailValue:SetWordWrap(true)
        self.detailText=Label(self.detail,"",12,100,11,T.muted,12);self.detailText:SetWordWrap(true)
        self.prev=Button(self.detail,"<",188,10,24,function()P.selected=math.max(1,P.selected-1);Refresh()end,L("Предыдущий интервал или снимок.","Previous interval or snapshot."))
        self.next=Button(self.detail,">",217,10,24,function()P.selected=P.selected+1;Refresh()end,L("Следующий интервал или снимок.","Next interval or snapshot."))
        self.context=Label(root,"",0,458,12,T.muted,0);self.context:SetWordWrap(true)
        self.events=Label(root,"",0,506,11,T.muted,0);self.events:SetWordWrap(true)
        K.Hover(root,self.events,L("Контекст и метки","Context and markers"),function()
            local r=K.Record();local result={L("События записываются только во время замера; метка не означает причину паузы.","Events are recorded only during a capture; a marker does not imply causation.")}
            for _,m in ipairs(r and r.markers or{})do result[#result+1]=K.Clock(m.at).." · "..m.text end
            if r then result[#result+1]=L("Не сохранено меток: ","Markers not retained: ")..tostring(r.markerOmitted or 0)end
            return table.concat(result,"\n")
        end)
        self.note=Label(root,"",0,572,11,T.muted,0);self.note:SetWordWrap(true)
        self.empty=Label(root,"",90,250,15,T.muted,90);self.empty:SetWordWrap(true);self.empty:SetJustifyH("CENTER")
        self.mark=Button(root,L("Отметить момент","Mark moment"),0,529,170,function()ns.Mark()end,L("Добавляет ручную отметку времени. Не запускает обход памяти или дополнительный поиск виновника.","Add a manual timestamp. Does not scan memory or run extra culprit detection."))
        self.markerButtons={}
        for i=1,4 do
            local b=Button(root,"",(i-1)*218,532,210,function(button)
                local distance,best=math.huge,1
                for j,p in ipairs(P.points or{})do local d=math.abs((p.at or 0)-button.marker.at);if d<distance then distance,best=d,j end end
                P.selected=best;Refresh()
            end,L("Выбрать ближайший наблюдавшийся кадр к метке. Совпадение по времени не доказывает причину паузы.","Select the nearest observed frame to this marker. Temporal correlation does not prove the cause of a pause."))
            b.perfTooltip[1]=function()return b.marker and K.Clock(b.marker.at).." · "..b.marker.text or L("Метка","Marker")end
            self.markerButtons[i]=b
        end
        self.markerPrev=Button(root,"<",880,532,32,function()P.markerOffset=math.max(0,(P.markerOffset or 0)-4);Refresh()end,L("Предыдущие метки.","Previous markers."))
        self.markerNext=Button(root,">",924,532,32,function()P.markerOffset=(P.markerOffset or 0)+4;Refresh()end,L("Следующие метки.","Next markers."))
        self.progress=K.Progress(root);self.progress:SetPoint("TOPLEFT",0,-118);self.progress:SetPoint("TOPRIGHT",0,-118);self.progress:SetHeight(3)
        self.history=CreateFrame("Frame",nil,root);self.history:SetAllPoints()
        self.historyHead=Label(self.history,L("Время / сценарий","Time / scenario"),8,58,11,T.muted)
        Label(self.history,L("Режим","Mode"),470,58,11,T.muted);Label(self.history,L("p99, мс","p99, ms"),625,58,11,T.muted);Label(self.history,L(">50 мс",">50 ms"),745,58,11,T.muted);Label(self.history,L("Группа","Group"),820,58,11,T.muted)
        self.historyRows={}
        for i=1,10 do
            local row=K.Button(self.history,"",function(b)if b.record then Reopen(b.record.id)end end,false,L("Открыть сохраненный отчет. Условия и время записи сохраняются независимо от названия.","Open the saved report. Recorded conditions and time stay independent of its name."));row:SetPoint("TOPLEFT",0,-85-(i-1)*45);row:SetPoint("TOPRIGHT",0,-85-(i-1)*45);row:SetHeight(41)
            K.QuietRow(row)
            row.name=Label(row,"",8,4,12,nil,510);row.name:SetWordWrap(false)
            row.meta=Label(row,"",8,22,10,T.muted,510);row.meta:SetWordWrap(false)
            row.mode=Label(row,"",470,13,11,T.muted)
            row.p99=Label(row,"",625,13,12);row.long=Label(row,"",745,13,12)
            for j,group in ipairs({"A","B"})do local g=group;row[group]=Button(row,group,820+(j-1)*39,9,32,function()local ok,why=ns.AssignGroup(row.record.id,g);if not ok then ShowError(why)end;Refresh()end,L("Добавить или убрать запись из группы. Частичные и старые записи недоступны; несовпадение условий скрывает проценты в сравнении.","Add or remove a record from a group. Partial and legacy records are unavailable; mismatched conditions suppress comparison percentages."))end
            row.remove=Button(row,L("Удалить","Delete"),890,9,64,function()ui.selectedID=row.record.id;K.OpenDialog("delete")end,L("Удалить только этот отчет с подтверждением.","Delete only this report after confirmation."))
            for _, button in ipairs({row.A, row.B, row.remove}) do button:SetHeight(23) end
            row.perfTooltip[1]=function()return row.record and row.record.name or ""end
            row.perfTooltip[2]=function()local r=row.record;if r and r.startup then return ns.StartupScope(r)end;local ok,why=ns.Eligible(r);return (ok and L("Можно добавить в сравнение.","Can be added to comparison.")or ns.ComparisonReason(why)).."\n"..(r and r.scenario or "")end
            self.historyRows[i]=row
        end
        self.historyPrev=Button(self.history,"<",0,551,35,function()P.historyOffset=math.max(0,P.historyOffset-10);Refresh()end,L("Предыдущие отчеты.","Previous reports."))
        self.historyNext=Button(self.history,">",42,551,35,function()P.historyOffset=P.historyOffset+10;Refresh()end,L("Следующие отчеты.","Next reports."))
        self.compare=CreateFrame("Frame",nil,root);self.compare:SetAllPoints()
        self.groupA=Label(self.compare,"",0,62,17,T.accent);self.groupB=Label(self.compare,"",500,62,17,T.accent)
        self.addA=Button(self.compare,L("Еще один замер A","Another capture A"),0,96,460,function()P:Setup("A")end,L("Повторить сценарий группы A с тем же режимом и лимитом времени. Новые условия записываются заново.","Repeat group A's scenario with its mode and duration limit. Current conditions are captured again."))
        self.addB=Button(self.compare,L("Еще один замер B","Another capture B"),500,96,464,function()P:Setup("B")end,L("Повторить сценарий группы B после одного изменения. Совместимость проверяется по фактически записанным условиям.","Repeat group B's scenario after one change. Compatibility uses actually recorded conditions."))
        self.compatible=Label(self.compare,"",0,151,12,T.muted,200)
        self.conditions=Button(self.compare,L("Условия замеров","Recording conditions"),770,143,194,function()K.OpenDialog("conditions")end,L("Условия каждой записи доступны только для чтения: сценарий, режим, длительность, клиент, зона, группа и лимит FPS. Один номер версии не гарантирует одинаковый код.","Read-only conditions for each record: scenario, profile, duration, client, zone, group and FPS cap. One version number does not guarantee identical code."))
        self.compareRows={}
        local metricNames={p95=L("p95 кадра, мс","Frame p95, ms"),p99=L("p99 кадра, мс","Frame p99, ms"),long50=L("Кадры >50 мс","Frames >50 ms"),average=L("CPU аддонов, мс/кадр","Addon CPU, ms/frame"),observer="Sintezza_Perf"..L(", мс/кадр",", ms/frame")}
        Label(self.compare,L("Показатель","Metric"),8,195,11,T.muted)
        for _,h in ipairs({{L("A, медиана","A median"),480,120},{L("B, медиана","B median"),645,120},{L("Изменение","Change"),805,145}})do local f=Label(self.compare,h[1],h[2],195,11,T.muted);f:SetWidth(h[3]);f:SetJustifyH("RIGHT")end
        for i,key in ipairs({"p95","p99","long50","average","observer"})do
            local row=K.Sidebar(self.compare);row:SetPoint("TOPLEFT",0,-221-(i-1)*43);row:SetPoint("TOPRIGHT",0,-221-(i-1)*43);row:SetHeight(40)
            row.name=Label(row,metricNames[key],10,11,12,key=="observer"and T.accent or T.text)
            row.a=Label(row,"",480,11,12);row.a:SetWidth(120);row.a:SetJustifyH("RIGHT");row.b=Label(row,"",645,11,12);row.b:SetWidth(120);row.b:SetJustifyH("RIGHT");row.delta=Label(row,"",805,11,12);row.delta:SetWidth(145);row.delta:SetJustifyH("RIGHT")
            row:EnableMouse(true);K.Describe(row,metricNames[key],L("Медиана по выбранным полным записям группы. Процент появляется только при совместимых условиях и ненулевой базе A. Меньше трех повторений недостаточно для уверенного вывода.","Median of selected complete recordings. Percentages require compatible conditions and a nonzero A baseline. Fewer than three repeats is insufficient for a confident conclusion."))
            self.compareRows[key]=row
        end
        self.compareNote=Label(self.compare,"",0,459,12,T.muted,0);self.compareNote:SetWordWrap(true)
        self.choose=Button(self.compare,L("Выбрать записи в истории","Choose history recordings"),0,526,250,function()K.Switch("history")end,L("Назначить группы A/B существующим отчетам.","Assign A/B groups to existing recordings."))
        self.clear=Button(self.compare,L("Очистить группы","Clear groups"),720,526,244,function()ns.ClearGroups();Refresh()end,L("Снимает метки A/B, не удаляя сами отчеты.","Remove A/B assignments without deleting reports."))
        self.startup = Label(root, "", 12, 140, 13, T.text, 12)
        self.startup:SetWordWrap(true)
        K.Hover(root, self.startup, L("Этапы загрузки", "Loading phases"), L("Время между событиями включает всю работу в интервале. Соседние аддоны отмечают границы, а причина проверяется повторным замером.", "Time between events includes all work in the interval. Adjacent addons mark its boundaries. Repeat the measurement to check a cause."))
    end

    function P:Graph(record,memory)
        self.legend:SetShown(memory or not K.Widgets)
        if self.seriesLegend then self.seriesLegend:SetShown(not memory)end
        local points={}
        for i=1,60 do if self.lines[i]then self.lines[i]:Hide()end;if self.cpuLines[i]then self.cpuLines[i]:Hide()end;self.hits[i]:Hide()end
        local maximum,minimum,span=1,0,1
        if memory then
            local list=record.memoryTrail or{}
            if #list>0 then
                minimum,maximum=list[1].total,list[1].total
                for _,p in ipairs(list)do minimum=math.min(minimum,p.total);maximum=math.max(maximum,p.total)end
                minimum=math.max(0,math.floor(minimum)-1);maximum=math.ceil(maximum)+1
                span=math.max(1,list[#list].timestamp-list[1].timestamp)
                for _,p in ipairs(list)do points[#points+1]={at=p.timestamp-list[1].timestamp,value=p.total,timestamp=p.timestamp}end
            end
            Put(self.graphTitle,L("Память Lua, МиБ · снимки сеанса","Lua memory, MiB · session snapshots"));Put(self.legend,L("Пропуски не соединяются","Gaps are not connected"))
        else
            local list=record.timeline or{}
            local stride=math.max(1,math.ceil(#list/60))
            span=math.max(.001,select(2,ns.Capture())and ns.Capture()==record and record.requested or record.duration or 1)
            for i=1,#list,stride do
                local best
                for j=i,math.min(#list,i+stride-1)do local p=list[j];if (p.frameSamples or 0)>0 and (not best or p.framePeak>best.framePeak)then best=p end end
                points[#points+1]={at=best and best.frameAt or list[i].from or 0,from=list[i].from,to=list[math.min(#list,i+stride-1)].to,frame=best and best.framePeak,cpu=best and best.cpuAtFramePeak,perf=best and best.perfAtFramePeak}
                maximum=math.max(maximum,best and best.framePeak or 0,best and ns.Number(best.cpuAtFramePeak)or 0)
            end
            Put(self.graphTitle,L("Кадр и CPU в том же кадре, мс","Frame and CPU in that frame, ms"));Put(self.legend,K.Widgets and ""or L("Медь: кадр · зеленый: аддоны","Copper: frame · teal: addons"))
        end
        self.points=points;self.selected=math.max(1,math.min(self.selected,math.max(1,#points)))
        local function Y(value)return (value-minimum)/math.max(.001,maximum-minimum)*174 end
        for i,p in ipairs(points)do
            local x=p.at/span*644
            local left=math.min(642,math.max(0,x-4));local hitWidth=math.min(650-left,memory and 12 or math.max(8,644/math.max(1,#points)))
            local b=self.hits[i];b.data=p;b:ClearAllPoints();b:SetPoint("BOTTOMLEFT",self.plot,"BOTTOMLEFT",left,0);b:SetSize(hitWidth,184);b:Show();b.wash:SetShown(i==self.selected)
            local v=memory and p.value or p.frame;b.dot:SetShown(v~=nil);if v then b.dot:ClearAllPoints();b.dot:SetPoint("CENTER",self.plot,"BOTTOMLEFT",x,Y(v))end
            if i>1 then
                local prev=points[i-1];local px=prev.at/span*644
                if memory then if p.timestamp-prev.timestamp<=90 then Line(self.cpuLines[i],px,Y(prev.value),x,Y(p.value))end
                else
                    if prev.frame and p.frame then Line(self.lines[i],px,Y(prev.frame),x,Y(p.frame))end
                    if ns.Number(prev.cpu) and ns.Number(p.cpu)then Line(self.cpuLines[i],px,Y(prev.cpu),x,Y(p.cpu))end
                end
            end
        end
        Put(self.axisMax,K.Value(maximum,"%.1f"));Put(self.axisMid,K.Value((maximum+minimum)/2,"%.1f"));Put(self.axisZero,K.Value(minimum,"%.0f"))
        Put(self.axisStart,memory and points[1]and date("%H:%M",points[1].timestamp)or"0:00")
        Put(self.axisEnd,memory and points[#points]and date("%H:%M",points[#points].timestamp)or K.Clock(span))
        local p=points[self.selected]
        K.Enable(self.prev,self.selected>1);K.Enable(self.next,self.selected<#points)
        if not p then Put(self.detailTime,L("Нет снимков","No samples"));Put(self.detailValue,"");Put(self.detailText,L("Данные не записывались. Не заменяем пропуски нулями.","Data was not recorded. Missing readings are not replaced by zero."));return end
        Put(self.detailTime,memory and date("%H:%M:%S",p.timestamp)or K.Clock(p.at))
        if memory then
            Put(self.detailValue,K.Value(p.value,"%.2f")..L(" МиБ"," MiB"))
            Put(self.detailText,L("Это занятая память Lua. Изменение объема не равно всем выделениям и само по себе не доказывает утечку.","This is occupied Lua memory. Its change is not total allocations and does not prove a leak."))
        else
            Put(self.detailValue,L("Кадр: ","Frame: ")..K.Value(p.frame,"%.2f")..L(" мс\nАддоны: "," ms\nAddons: ")..K.Value(p.cpu,"%.3f")..L(" мс\nPerf: "," ms\nPerf: ")..K.Value(p.perf,"%.3f")..L(" мс"," ms"))
            Put(self.detailText,not p.frame and L("В этом интервале нет показаний кадров.","No frame readings in this interval.") or not ns.Number(p.cpu) and L("CPU аддонов недоступен; объяснить паузу этими данными нельзя.","Addon CPU is unavailable; these readings cannot explain the pause.") or p.cpu<p.frame*.25 and L("Пауза не объясняется доступным CPU аддонов. Это не определяет причину в движке, GPU или сети.","Available addon CPU does not explain the pause. This does not identify an engine, GPU or network cause.") or L("В этом кадре заметна работа аддонов. Совпадение по времени не доказывает причину; сравните повторные замеры.","Addon work is visible in this frame. Correlation does not prove causation; compare repeated captures."))
        end
    end

    function P:PaintHistory()
        local list=ns.History();self.historyOffset=math.min(self.historyOffset,math.max(0,#list-10))
        Put(self.title,L("История замеров","Recording history"));Put(self.meta,L("Выберите отчет или назначьте группы A и B. Закрепление и экспорт находятся в отчете.","Open a report or assign A/B groups. Pinning and export are inside the report."))
        for i,row in ipairs(self.historyRows)do
            local r=list[self.historyOffset+i];row.record=r;row:SetShown(r~=nil)
            if r then
                Put(row.name,(r.pinned and "* "or"")..r.name)
                Put(row.meta,date("%d.%m %H:%M",r.timestamp).." · "..K.Value(r.duration,"%.1f")..L(" с"," s")..(r.complete and""or L(" · неполная / старая"," · partial / legacy")))
                local startup = r.kind == "startup"
                Put(row.mode,startup and L("Загрузка","Loading") or r.kind=="background"and L("Фон","Background")or Profile(r))
                row.p99:SetShown(not startup); row.long:SetShown(not startup)
                Put(row.p99,K.Value(r.p99,"%.1f"));Put(row.long,K.Value(r.long50,"%d"))
                local ok=ns.Eligible(r)
                for _,g in ipairs({"A","B"})do row[g]:SetShown(not startup);K.Selected(row[g],r.group==g);K.Enable(row[g],ok or r.group==g)end
            end
        end
        K.Enable(self.historyPrev,self.historyOffset>0);K.Enable(self.historyNext,self.historyOffset+10<#list)
        if #list==0 then self.empty:Show();Put(self.empty,L("Сохраненных записей пока нет. Начните новый замер.","No saved recordings yet. Start a new capture."))end
    end
    function P:PaintComparison()
        local c=ns.Comparison();Put(self.title,L("Сравнение повторных замеров","Compare repeated recordings"));Put(self.meta,c.baseline and c.baseline.scenario or L("Назначьте группы в истории.","Assign groups in History."))
        Put(self.groupA,"A · "..L("Исходные настройки","Baseline").." ("..#c.A..")");Put(self.groupB,"B · "..L("После изменения","After a change").." ("..#c.B..")")
        Put(self.compatible,c.compatible and L("Записанные условия совпадают","Recorded conditions match")or ns.ComparisonReason(c.reason))
        for key,row in pairs(self.compareRows)do local m=c.metrics[key];Put(row.a,K.Value(m.A,key=="long50"and"%.0f"or"%.3f"));Put(row.b,K.Value(m.B,key=="long50"and"%.0f"or"%.3f"));Put(row.delta,m.delta and("%+.1f%%"):format(m.delta)or L("не сравниваем","not compared"))end
        Put(self.compareNote,(not c.repeated and L("Меньше трех повторений в одной из групп: вывод предварительный.\n","Fewer than three repeats in a group: the result is preliminary.\n")or"")..L("Медианы по записям. Perf включен в общий итог. Совпадение условий и версии не гарантирует одинаковую нагрузку мира, программ или локального кода.","Medians across recordings. Perf stays included. Matching conditions and versions cannot guarantee identical world, process or local-code load."))
    end
    function P:Paint(refresh)
        local active,running=ns.Capture();local waiting=ns.Armed()
        ui.duration:Hide();ui.durationLabel:Hide()
        K.Text(ui.start,(running or ns.DevRunning and ns.DevRunning()) and L("Остановить","Stop")or waiting and L("Отменить ожидание","Cancel waiting")or L("Новый замер","New capture"))
        K.Enable(ui.start,running or waiting or ns.DevRunning and ns.DevRunning() or ns.Available())
        for key,b in pairs(ui.tabs)do K.Selected(b,key==ui.view)end
        K.Text(ui.tabs.history,L("История ","History ")..#ns.History())
        local selected=ui.view=="capture"and K.Record()or nil
        K.Text(self.cost,L("Perf в отчете: ","Perf in report: ")..K.Value(Observer(selected or active),"%.3f")..L(" мс"," ms"))
        if ui.view=="live"then if self.root then self.root:Hide()end;return false end
        self:Ensure();self.root:Show();ui.content:Hide();ui.historyPane:Hide();HideTable()
        for _,f in ipairs({self.summary,self.graph,self.context,self.events,self.note,self.empty,self.mark,self.progress,self.history,self.compare,self.rename,self.pin,self.export,self.startup})do f:Hide()end
        for _,b in ipairs(self.markerButtons)do b:Hide()end;self.markerPrev:Hide();self.markerNext:Hide()
        for _,b in pairs(self.tabs)do b:Hide()end
        if ui.view=="history"then self.history:Show();self:PaintHistory();return true end
        if ui.view=="compare"then self.compare:Show();self.export:Show();self:PaintComparison();return true end
        local r=K.Record();local current=running and r==active
        if r and r.startup then
            Put(self.title,r.name)
            Put(self.meta,date("%d.%m %H:%M",r.timestamp).." · "..ns.StartupScope(r))
            self.summary:Show();self.startup:Show();self.export:Show();self.rename:Show();self.pin:Show()
            K.Selected(self.pin,r.pinned);K.Text(self.pin,r.pinned and L("Открепить","Unpin")or L("Закрепить","Pin"))
            local s = r.startup
            local units = L(" с", " s")
            local function Seconds(v) return v and K.Value(v,"%.2f")..units or K.Value(nil) end
            SetStat(1,L("Измеренный интервал","Measured interval"),Seconds(r.duration),ns.StartupScope(r))
            SetStat(2,L("До PLAYER_LOGIN","Before PLAYER_LOGIN"),Seconds(s.beforeLogin),L("Время с начала работы Perf до события PLAYER_LOGIN. Включает работу клиента и загрузку аддонов в этом интервале.","Time from Perf's first code to PLAYER_LOGIN. Includes client and addon loading work within that interval."))
            SetStat(3,L("После PLAYER_LOGIN","After PLAYER_LOGIN"),Seconds(s.beforeLogin and math.max(0,r.duration-(s.reloadLead or 0)-s.beforeLogin)),L("Остаток от PLAYER_LOGIN до конца измеренного интервала.","Remaining time from PLAYER_LOGIN to the measurement endpoint."))
            Put(self.startup,ns.StartupDetails(r,true))
            return true
        end
        if waiting and not running then
            Put(self.title,L("Ожидание события","Waiting for event"));Put(self.meta,waiting.trigger=="boss"and L("Следующий босс","Next boss")or L("Следующий бой","Next combat"));self.empty:Show()
            Put(self.empty,L("Покадровый сбор пока выключен. Ожидание закончится через 5 минут.\nЗапись остановится после боя или по лимиту времени.","Per-frame collection is off while waiting. The wait expires after 5 minutes.\nRecording ends with the encounter or at its time limit."));return true
        end
        if not r then Put(self.title,L("Запишите проблемный момент","Record the slow moment"));Put(self.meta,ns.Available()and L("Готов к записи","Ready to record")or L("CPU-профайлер недоступен","CPU profiler unavailable"));self.empty:Show();Put(self.empty,L("Новый замер: вручную, следующий бой или босс.\nЛегкий режим подходит для первой проверки плавности.","New capture: manual, next combat or boss.\nLight mode is suitable for a first smoothness check."));return true end
        Put(self.title,r.name)
        local scope=current and L("идет запись","recording")or r.complete and L("полная запись","complete")or L("неполная / старая запись","partial / legacy")
        Put(self.meta,date("%d.%m %H:%M",r.timestamp).." · "..K.Value(current and ns.Elapsed()or r.duration,"%.1f")..L(" с · "," s · ")..Profile(r).." · "..scope..(r.reason=="overhead"and L(" · остановлена защитой"," · stopped by cost guard")or""))
        self.summary:Show();self.note:Show()
        SetStat(1,L("p99 кадра","Frame p99"),current and L("после записи","after capture")or K.Value(r.p99,"%.1f")..L(" мс"," ms"),L("99% наблюдавшихся интервалов кадров не длиннее этого значения. Верхняя граница корзины: 0,1 мс до 100 мс, 1 мс до 1 с, 10 мс до 10 с. Считается после записи. Не 1% low FPS и не GPU.","99% of observed frame intervals are no longer than this value. Bucket upper bound: 0.1 ms up to 100 ms, 1 ms up to 1 s, 10 ms up to 10 s. Calculated after recording. Not 1% low FPS or GPU time.").."\np95: "..K.Value(r.p95,"%.1f"))
        SetStat(2,L("Кадры клиента >50 мс","Client frames >50 ms"),K.Value(r.long50,"%d"),L("Число длинных интервалов всего клиента в этой записи. Не путайте с кадрами, где сами аддоны превысили 5 мс.","Long intervals of the whole client in this recording. Not the count of frames where addons alone exceeded 5 ms."))
        SetStat(3,L("CPU всех аддонов","All addon CPU"),K.Value(Mean(r),"%.3f")..L(" мс/кадр"," ms/frame"),L("Суммарное среднее время аддонов, включая Perf, за выбранную запись. Это не процент загрузки процессора.","Combined mean addon time, including Perf, over this recording. Not processor utilization."))
        for key,b in pairs(self.tabs)do b:Show();K.Selected(b,key==self.sub)end
        if current then self.mark:Show();self.progress:Show();self.progress:SetMinMaxValues(0,r.requested);self.progress:SetValue(ns.Elapsed())
        else self.export:Show();self.rename:Show();self.pin:Show();K.Selected(self.pin,r.pinned);K.Text(self.pin,r.pinned and L("Открепить","Unpin")or L("Закрепить","Pin"))end
        Put(self.note,L("Perf включен в общие показатели. Отсутствующие измерения обозначены н/д.","Perf remains in totals. Missing measurements are marked n/a."))
        if self.sub=="addons"then
            if r.profile=="light"and r.measurement then self.empty:Show();Put(self.empty,L("Отдельные аддоны не записывались в легком режиме.\nВ следующем замере выберите подробный режим.","Individual addons were not recorded in light mode.\nChoose detailed mode for the next capture."))
            else K.PaintTable(r.rows,180,self.root)end
        elseif self.sub=="memory"then
            self.graph:Show();self:Graph(r,true);self.context:Show()
            local points=r.memoryTrail or{};local first,last=points[1],points[#points]
            Put(self.context,first and L("Снимки сеанса: ","Session snapshots: ")..date("%H:%M:%S",first.timestamp).."–"..date("%H:%M:%S",last.timestamp).." · "..L("изменение ","change ")..("%+.2f"):format(last.total-first.total)..L(" МиБ. Это отдельный период, не только выбранный замер."," MiB. This is a separate period, not only the selected capture.")or L("Снимков памяти нет. Они появляются при безопасном обновлении на вкладке «Нагрузка».","No memory snapshots. They appear after a safe refresh on Load."))
        else
            if not r.measurement then self.empty:Show();Put(self.empty,L("В этой старой или фоновой записи нет данных о плавности.\nДоступные данные CPU находятся на вкладке «Аддоны».","This legacy or background report has no frame-time data.\nAvailable CPU data is on the Addons tab."));return true end
            self.graph:Show();self:Graph(r,false);self.context:Show();self.events:SetShown(not current)
            local c=r.context or{}
            Put(self.context,(c.zone or L("Зона неизвестна","Unknown zone")).." · "..(c.combat==nil and L("бой неизвестен","combat unknown")or c.combat and L("в бою","in combat")or L("вне боя","out of combat")).." · "..L("лимит FPS: ","FPS cap: ")..K.Value(c.fpsLimit,"%.0f").."\n"..L("Метки показывают контекст, а не доказанную причину паузы.","Markers show context, not a proven cause of a pause."))
            local markers=r.markers or{}
            Put(self.events,#markers>0 and L("Контекстные метки: ","Context markers: ")..#markers or L("Контекстных меток нет.","No context markers."))
            if not current and #markers>0 then
                self.markerOffset=math.max(0,math.min(self.markerOffset or 0,math.max(0,#markers-4)))
                for i,b in ipairs(self.markerButtons)do local m=markers[self.markerOffset+i];b.marker=m;b:SetShown(m~=nil);if m then K.Text(b,K.Clock(m.at).." · "..(ns.CleanText(m.text,32)or""))end end
                self.markerPrev:Show();self.markerNext:Show();K.Enable(self.markerPrev,self.markerOffset>0);K.Enable(self.markerNext,self.markerOffset+4<#markers)
            end
        end
        return true
    end

    function P:Setup(group)
        if select(2,ns.Capture())then return end
        if not self.setup then
            local f=K.Window(UIParent,"Sintezza_PerfCaptureSetup");f:SetSize(620,490);f:SetPoint("CENTER",ui,"CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true);self.setup=f
            UISpecialFrames[#UISpecialFrames+1]=f:GetName()
            local h=K.Header(f,L("Новый замер","New capture"),function()f:Hide()end);K.Describe(h.close,L("Закрыть","Close"),L("Закрыть настройку без запуска записи.","Close setup without starting a capture."))
            h:EnableMouse(true);h:SetScript("OnMouseDown",function(_,button)if button=="LeftButton"and not InCombatLockdown()then f:StartMoving()end end);h:SetScript("OnMouseUp",function()f:StopMovingOrSizing()end);f:HookScript("OnHide",function()f:StopMovingOrSizing();if f.scenario then f.scenario:ClearFocus()end end)
            Label(f,L("Название сценария","Scenario name"),18,66,12)
            f.scenario=K.Input(f);f.scenario:SetPoint("TOPLEFT",225,-59);f.scenario:SetSize(377,30);f.scenario:SetMaxLetters(60)
            K.Describe(f.scenario,L("Сценарий","Scenario"),L("Одно повторяемое действие, например открытие карты. Сравнение требует одинакового названия сценария, но само имя не гарантирует одинаковую нагрузку.","One repeatable action, such as opening the map. Comparisons require matching scenario names, but a name cannot guarantee identical load."))
            Label(f,L("Когда начать","When to start"),18,116,12)
            f.trigger=Button(f,"",375,106,227,function(b)K.Picker(b,{{value="manual",label=L("Вручную","Manual")},{value="combat",label=L("Следующий бой","Next combat")},{value="boss",label=L("Следующий босс","Next boss")}},P.options.trigger,function(v)P.options.trigger=v;P:RefreshSetup()end)end,L("Ожидание события не запускает покадровый сбор. Подготовленная запись отменяется через 5 минут ожидания. Автоматическая запись заканчивается вместе с боем или по лимиту времени.","Waiting for an event does not run per-frame collection. The armed capture expires after 5 minutes. Automatic recording ends with combat/encounter or its duration limit."))
            Label(f,L("Остановить не позднее","Stop no later than"),18,166,12)
            f.duration=Button(f,"",375,156,227,function(b)K.Picker(b,{{value=30,label="30"..L(" с"," s")},{value=60,label="60"..L(" с"," s")},{value=120,label="120"..L(" с"," s")}},P.options.duration,function(v)P.options.duration=v;P:RefreshSetup()end)end,L("Жесткий предел записи: до 120 секунд. Ручная или защитная остановка сохраняет неполную запись, исключенную из A/B.","Hard recording limit: up to 120 seconds. Manual or safety stops save a partial recording excluded from A/B."))
            Label(f,L("Что измерять","What to measure"),18,218,14)
            f.light=Button(f,L("Легкий замер","Light capture"),18,246,282,function()P.options.profile="light";P:RefreshSetup()end,L("Плавность, суммарный CPU и собственное время Perf. Два чтения метрик за кадр; без обхода всех аддонов.","Frame intervals, combined addon CPU and Perf's own time. Two metric reads per frame; no per-addon walk."))
            f.detailed=Button(f,L("Подробный","Detailed"),312,246,290,function()P.options.profile="detailed";P:RefreshSetup()end,L("Добавляет время каждого загруженного аддона. Больше работы у наблюдателя; используйте для поиска конкретного аддона.","Add timing for each loaded addon. More observer work; use to investigate a specific addon."))
            local note=Label(f,L("Память: редкие снимки сеанса, без обхода во время записи.\np95/p99 рассчитываются после записи, буфер ограничен.\nЗащита сборщика: 1 мс в среднем за 60 кадров.","Memory: rare session snapshots, no scan while recording.\np95/p99 are calculated after recording with a bounded buffer.\nCollector guard: 1 ms averaged over 60 frames."),18,302,12,T.muted,18);note:SetWordWrap(true)
            K.Hover(f,note,L("Нагрузка наблюдателя","Observer cost"),L("Легкий фон и ожидание не записывают кадры. Во время замера буферы числовые и ограничены, UI обновляется не чаще раза в секунду. Стоимость сборщика не включает все рисование окна.","Light background and waiting do not record frames. During capture buffers are numeric and bounded; UI refreshes at most once per second. Collector cost does not include all window drawing."))
            f.error=Label(f,"",18,386,11,T.accent,18);f.error:SetWordWrap(true)
            f.start=Button(f,"",392,436,210,function()
                local scenario=ns.CleanText(f.scenario:GetText(),160)
                if not scenario then Put(f.error,L("Введите название сценария.","Enter a scenario name."));return end
                local o=P.options;o.scenario=scenario
                ns.db.profile,ns.db.trigger,ns.db.duration,ns.db.scenario=o.profile,o.trigger,o.duration,scenario
                ui.reportID,ui.view=nil,"capture";P.sub="smooth"
                if ns.ArmCapture(o.duration,o)then f:Hide();Refresh()else Put(f.error,L("Не удалось подготовить запись. Счетчики или событие недоступны.","Cannot prepare recording. Counters or the event are unavailable."))end
            end,L("Подготовить ограниченную запись. Старые отчеты и настройки не удаляются.","Prepare a bounded recording. Existing reports and settings are not deleted."),true)
            f.scenario:SetScript("OnEnterPressed",function()f.start:Click()end);f.scenario:SetScript("OnEscapePressed",function()f:Hide()end)
        end
        local base=group and ns.Comparison().baseline
        if base and not ns.Eligible(base)then base=nil end
        self.options={profile=base and base.profile or ns.db.profile,trigger=base and base.trigger or ns.db.trigger,
            duration=base and (base.requested or math.min(120,math.max(5,math.floor(base.duration+.5))))or ns.db.duration,
            scenario=base and base.scenario or ns.db.scenario,group=group}
        K.BindDialog(self.setup);self.setup.scenario:SetText(self.options.scenario);Put(self.setup.error,"");self:RefreshSetup();self.setup:Show()
    end
    function P:RefreshSetup()
        local f,o=self.setup,self.options
        K.Text(f.trigger,o.trigger=="boss"and L("Следующий босс","Next boss")or o.trigger=="combat"and L("Следующий бой","Next combat")or L("Вручную","Manual"))
        K.Text(f.duration,o.duration..L(" с"," s"));K.Selected(f.light,o.profile=="light");K.Selected(f.detailed,o.profile=="detailed")
        K.Text(f.start,o.trigger=="manual"and L("Начать запись","Start recording")or L("Ждать события","Wait for event"))
    end
    function P:HideDialogs()if self.setup then self.setup:Hide()end end

    local compare=K.Button(ui,L("Сравнение","Compare"),function()K.Switch("compare")end,false,L("Медианы повторных записей A/B, их условия и нагрузка Perf. Несовместимые записи не дают процент улучшения.","Medians of repeated A/B recordings, conditions and Perf cost. Incompatible recordings do not produce improvement percentages."));compare:SetPoint("TOPLEFT",336,-64);ui.tabs.compare=compare
    P.cost=K.Button(ui.settings:GetParent(),"Perf",function(b)
        local r=K.Record()or ns.Capture()
        K.Tip(b,L("Нагрузка самого Perf","Perf's own cost"),L("Perf в наблюдавшихся кадрах: ","Perf in observed frames: ")..K.Value(Observer(r),"%.3f")..L(" мс/кадр\nЦикл сборщика: "," ms/frame\nCollector loop: ")..K.Value(r and(r.costAverage or r.costSamples and r.costSamples>0 and r.costTotal/r.costSamples),"%.3f")..L(" мс/кадр. Лимит относится только к сборщику. Работа окна внутри замера учитывается в строке Perf; подготовка и сохранение за его границами не учитываются."," ms/frame. The guard applies only to collection. Window work inside the capture is included in Perf; preparation and saving outside its boundaries are not."))
    end,false,L("Perf включен в общий итог. Нажмите для разделения полного времени и стоимости сборщика.","Perf is included in totals. Click to separate full time from collector cost."))
    P.cost:SetWidth(185);P.cost:SetPoint("RIGHT",ui.startupButton,"LEFT",-8,0)
    if ui.settings:GetParent().title then ui.settings:GetParent().title:SetPoint("RIGHT",P.cost,"LEFT",-8,0)end
    return P
end
