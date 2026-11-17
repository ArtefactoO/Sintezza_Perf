local _, ns = ...
local L = ns.Text
local reasons={
    busy={"Другой замер уже активен или ожидает события.","Another capture is active or waiting for an event."},
    memory_api={"Нативное измерение памяти не прошло проверку. Используйте счетчики или CPU.","Native memory measurement failed its probe. Use counters or CPU."},
    point_memory={"Не все точки выбранного модуля поддерживают память.","Not every point in the selected module supports memory."},
    no_points={"Выберите модуль с зарегистрированными точками.","Select a module with registered points."},
    unknown_point={"Точка отсутствует в выбранных модулях или еще не подключена.","The point is absent from the selected modules or is not connected yet."},
    scenario={"Введите название повторяемого сценария.","Enter a repeatable scenario name."},
    points_limit={"Выбрано больше 128 точек. Сократите список модулей.","More than 128 points selected. Select fewer modules."},
    clock={"Часы измерения недоступны или сброшены.","The measurement clock is unavailable or was reset."},
    complete={"Достигнута длительность записи.","Recording duration reached."},
    manual={"Запись остановлена вручную; отчет неполный.","Manually stopped; the report is partial."},
    limit={"Достигнут лимит 20 000 вызовов и сигналов.","The 20,000 call and signal limit was reached."},
    overhead={"Превышен бюджет служебной работы; отчет неполный.","Accounted service budget exceeded; the report is partial."},
    error={"Измеряемый вызов завершился ошибкой; она передана вызывающему коду.","A measured call raised an error; it was propagated to its caller."},
    metric={"API вернул недоступные или некорректные метрики.","The API returned unavailable or invalid metrics."},
    depth={"Вложенность превысила 32 измеряемых вызова.","Nesting exceeded 32 measured calls."},
    logout={"Выход из игры завершил запись досрочно.","Logout stopped the recording early."},
    partial={"Неполные записи не участвуют в процентном сравнении.","Partial recordings cannot produce percentage comparisons."},
    unknown={"Не хватает записанных условий.","Recorded conditions are incomplete."},
    missing={"В записях есть ошибки или пропуски метрик.","The recordings contain errors or missing metrics."},
    context={"Условия менялись внутри записи.","Conditions changed during a recording."},
    code={"Не указаны метки кода или внутри одной группы смешаны сборки.","Code labels are missing or builds are mixed within a group."},
    conditions={"Метод, сценарий, длительность или условия отличаются.","Method, scenario, duration or conditions differ."},
    points={"Набор или возможности точек учета отличаются.","The point set or capabilities differ."},
    empty={"Назначьте полные записи обеим группам A/B.","Assign complete recordings to both A/B groups."},
}
function ns.DevReason(code) local p=reasons[code];return p and L(p[1],p[2]) or L("Недоступно: ","Unavailable: ")..tostring(code or "?") end
local function PointCount(n)
    local tail=n%100;local word=tail>=11 and tail<=14 and "точек"or n%10==1 and "точка"or n%10>=2 and n%10<=4 and "точки"or "точек"
    return n.." "..L(word,n==1 and "point"or"points")
end
function ns.BuildDeveloperUI(ui,K)
    local D={tab="modules",offset=0,setupOffset=0,selected={},mode="count",duration=15}
    local T=K.Theme
    local help={
        scope=L("Только добровольно зарегистрированные участки. Просмотр не включает сбор. Неподключенный код здесь не виден.","Only voluntarily registered sections. Viewing does not start collection. Uninstrumented code is outside this report."),
        time=L("Миллисекунды за запись, включая вложенные вызовы. Строки могут перекрываться; их нельзя складывать в CPU всего аддона. В модуле суммируются только его внешние измеренные вызовы.","Milliseconds over the recording, including nested calls. Rows overlap and cannot be summed into whole-addon CPU. A module sums only its outermost measured calls."),
        own=L("Вычтено время только известных вложенных измеренных участков. Неизмеренный код и часть стоимости проб остаются внутри. Ошибка часов или вложенности дает н/д.","Only known nested measured sections are subtracted. Unmeasured code and some probe overhead remain included. Clock or nesting errors produce n/a."),
        memory=L("Байты, выделенные или освобожденные во время вызова, включая вложенные участки. Это не оставшаяся память функции, не вся RAM и не доказательство утечки. Нативный API сам создает таблицу результатов на вызов.","Bytes allocated or freed during a call, including nested sections. Not retained function memory, total RAM or proof of a leak. The native API itself creates a results table per call."),
        hidden=L("Видимость сообщает интеграция. Без полного сигнала значение н/д. Скрытое окно может поддерживать нужный кеш; такие вызовы не объявляются ошибкой.","Visibility is supplied by the integration. Incomplete signals produce n/a. Hidden windows may maintain necessary caches; these calls are not automatically errors."),
        changes=L("Явные сигналы MarkChanged от автора. Это отдельные события, не число полезных вызовов. Из calls нельзя вычитать changes, чтобы доказать лишнюю работу.","Explicit MarkChanged signals from the author. Separate events, not a count of useful calls. Subtracting changes from calls cannot establish wasted work."),
        cost=L("Нативное время Perf и учтенная служебная работа могут перекрываться: не складывайте и не вычитайте их. Среднее по кадрам записи. Подготовка и сохранение вне интервала исключены; полная цена проб требует контрольного замера без них.","Native Perf time and accounted service work may overlap: do not add or subtract them. Mean per recorded frame. Preparation and saving outside the interval are excluded; total probe cost requires a control run without probes."),
        groups=L("Выберите сохраненный отчет и назначьте A или B. Сравниваются медианы совместимых полных записей. Нужны метки кода и одинаковые условия; желательно минимум три повтора на вариант.","Select a saved report and assign A or B. Compare medians of compatible complete recordings. Code labels and matching conditions are required; aim for at least three repeats per variant."),
    }
    local function Label(parent,text,x,y,w,size,color)
        local f=K.Label(parent,text,size or 12,color or T.text);f:SetPoint("TOPLEFT",x,-y);f:SetWidth(w);f:SetWordWrap(true);return f
    end
    local function Button(parent,text,x,y,w,click,tip,primary)
        local f=K.Button(parent,text,click,primary,tip);f:SetPoint("TOPLEFT",x,-y);f:SetWidth(w);return f
    end
    local function Refresh()K.Paint(false);K.Schedule()end
    local function Record()
        if ns.DevRunning() then return nil end
        local r=D.reportID and ns.DevFind(D.reportID) or ns.DevCurrent()
        if r and D.addon then
            for _,m in ipairs(r.modules)do if m.addon==D.addon then return r end end
            return nil
        end
        return r
    end
    local function Modules()
        local r=Record();local list={}
        for _,m in ipairs(r and r.modules or ns.DevModules()) do if not D.addon or m.addon==D.addon then list[#list+1]=m end end
        return list
    end
    local function Points()
        local r=Record();local list={}
        if not r then
            for _,m in ipairs(ns.DevModules())do
                if m.addon==D.addon and m.module==D.module then
                    for _,p in ipairs(m.points)do list[#list+1]=p end
                    break
                end
            end
            return list
        end
        for _,p in ipairs(r and r.points or {}) do if p.addon==D.addon and p.module==D.module then list[#list+1]=p end end
        return list
    end
    local function SelectedModule()
        local list=Modules()
        for _,m in ipairs(list)do if m.module==D.module then return m end end
        if list[1]then D.module=list[1].module end
        return list[1]
    end
    local function Dialog(name,height)
        D.dialogCount=(D.dialogCount or 0)+1
        local surface=K.Widgets and K.Window or K.Panel
        local f=surface(UIParent,"Sintezza_PerfDeveloperDialog"..D.dialogCount);f:SetSize(670,height);f:SetPoint("CENTER",ui,"CENTER");f:SetFrameStrata("FULLSCREEN_DIALOG");f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true)
        UISpecialFrames[#UISpecialFrames+1]=f:GetName()
        local h=K.Header(f,name,function()f:Hide()end);f.header=h
        h:EnableMouse(true);h:SetScript("OnMouseDown",function(_,button)if button=="LeftButton" and not InCombatLockdown()then f:StartMoving()end end)
        h:SetScript("OnMouseUp",function()f:StopMovingOrSizing()end)
        K.Describe(h,name,L("Перетаскивайте за заголовок вне боя. Закрытие не запускает запись.","Drag the header outside combat. Closing does not start recording."))
        f:SetScript("OnHide",function()f:StopMovingOrSizing();if f.edit then f.edit:ClearFocus()end;if K.Widgets and T.ClosePicker then T:ClosePicker()end end)
        f:Hide();return f
    end
    function D:ShowText(title,text,selectable,confirm)
        if not self.dialog then
            local f=Dialog(title,560);self.dialog=f
            f.edit=K.Input(f);f.edit:SetMultiLine(true);f.edit:SetWidth(600)
            f.scroll=K.Scroll(f,f.edit,true);f.scroll:SetPoint("TOPLEFT",20,-65);f.scroll:SetPoint("BOTTOMRIGHT",-40,65)
            f.edit:SetScript("OnEscapePressed",function()f:Hide()end)
            f.edit:SetScript("OnTextChanged",function(self,user)if user then self:SetText(f.output or "");self:HighlightText()end end)
            f.action=Button(f,"",20,510,220,function()if f.confirm then local action=f.confirm;f:Hide();action()else f.edit:SetFocus();f.edit:HighlightText()end end,L("Подтверждает указанное действие или выделяет отчет для Ctrl+C.","Confirm the named action or select the report for Ctrl+C."))
            Button(f,L("Закрыть","Close"),530,510,120,function()f:Hide()end,L("Закрыть окно без изменения отчета.","Close without changing the report."))
        end
        local f=self.dialog;f.header.title:SetText(title);f.confirm=confirm;f.output=text;f.edit:SetText(text)
        f.edit:SetHeight(math.max(400,(select(2,text:gsub("\n",""))+math.ceil(#text/65))*16+30));f.scroll:SetVerticalScroll(0)
        f.action:SetShown(selectable or confirm~=nil);K.Text(f.action,confirm and L("Удалить отчет","Delete report")or L("Выделить для Ctrl+C","Select for Ctrl+C"))
        K.BindDialog(f);f:Show()
    end
    local function CostText()
        local r=Record()
        return L("Нативное время Perf: ","Native Perf time: ")..K.Value(r and r.nativeMean,"%.3f")..L(" мс/кадр\nУчтенная служебная часть: "," ms/frame\nAccounted service work: ")..K.Value(r and r.serviceMean,"%.3f")..L(" мс/кадр\nПик служебной работы за кадр: "," ms/frame\nPeak service work per frame: ")..K.Value(r and r.servicePeak,"%.3f").."\n\n"..help.cost.."\n\n"..L("Без отчета значения недоступны. Сбор работает только во время записи. Скрытое окно не перерисовывается. Лимит: 1 мс в среднем за 60 кадров или 20 мс за проход/кадр учтенной работы. Он не гарантирует потолок всей нагрузки Perf.","Without a report values are unavailable. Collection runs only during recording. A hidden window does not redraw. Guard: 1 ms mean over 60 frames or 20 ms per accounted pass/frame. It does not guarantee a ceiling on all Perf overhead.")
    end
    function D:Ensure()
        if self.root then return end
        local root=CreateFrame("Frame",nil,ui);root:SetPoint("TOPLEFT",18,-112);root:SetPoint("BOTTOMRIGHT",-18,42);self.root=root
        self.title=Label(root,L("Разработка","Developer"),0,0,450,19,T.accent)
        self.report=Button(root,"",450,0,310,function(b)
            local choices={}
            for _,r in ipairs(ns.DevHistory())do choices[#choices+1]={value=r.id,label="#"..r.id.." "..r.scenario.." · "..r.mode}end
            if #choices>0 then K.Picker(b,choices,D.reportID,function(v)local r=ns.DevFind(v);D.reportID=v;D.addon=r.modules[1]and r.modules[1].addon;D.module=nil;D.offset=0;Refresh()end)end
        end,L("Сохраненные разработческие записи: последние 20, отдельно от обычной истории. Выбор не запускает сбор.","The last 20 developer recordings, separate from regular history. Selecting one does not start collection."))
        self.export=Button(root,L("Экспорт","Export"),770,0,94,function()D:ShowText(L("Экспорт JSON","JSON export"),ns.DevExport(Record(),"json",D.tab=="regressions" and ns.DevComparison(D.point)or nil),true)end,L("JSON с областью, пропусками, метками кода и нагрузкой инструмента. Нажмите выделение и Ctrl+C. Отправки в сеть нет.","JSON with scope, missing values, code labels and observer cost. Select and Ctrl+C; no network transmission."))
        self.connect=Button(root,L("API","API"),874,0,90,function()D:ShowText(L("Подключение аддона","Addon integration"),L("API v1: Sintezza_PerfAPI\n\n1. OptionalDeps: Sintezza_Perf в TOC аддона.\n2. RegisterModule и RegisterPoint один раз при загрузке.\n3. Call для синхронных вызовов, Count для счетчиков.\n4. SetVisible и MarkChanged для явных сигналов.\n5. Без Perf вызывайте исходную функцию напрямую.\n\nПолный контракт, готовый адаптер и приемка: README.md и Docs/DeveloperAPI.md в Sintezza_Perf.\n\nНе подключайте защищенные, секретные или yielding-пути. Не создавайте обертки и таблицы на каждом вызове. Sintezza_UI будет подключен отдельно.","API v1: Sintezza_PerfAPI\n\n1. Add OptionalDeps: Sintezza_Perf to the adopter TOC.\n2. RegisterModule and RegisterPoint once at load.\n3. Call for synchronous functions; Count for counters.\n4. SetVisible and MarkChanged for explicit signals.\n5. Without Perf, call the original function directly.\n\nFull contract, adapter and acceptance: README.md and Docs/DeveloperAPI.md in Sintezza_Perf.\n\nDo not instrument protected, secret or yielding paths. Do not create wrappers or tables per call. Sintezza_UI integration is a separate task."))end,help.scope)
        self.meta=Label(root,"",0,37,964,12,T.muted);K.Hover(root,self.meta,L("Область отчета","Report scope"),help.scope)
        self.tabs={}
        for i,e in ipairs({{"modules",L("Модули","Modules")},{"functions",L("Функции","Functions")},{"updates",L("Обновления","Updates")},{"regressions",L("Регрессии","Regressions")}})do
            local key=e[1];self.tabs[key]=Button(root,e[2],(i-1)*137,76,130,function()D.tab=key;D.offset=0;Refresh()end,key=="regressions"and help.groups or key=="updates"and help.hidden or help.scope)
        end
        self.addonPicker=Button(root,"",660,76,304,function(b)
            local choices,seen={},{}
            local r=Record()
            for _,m in ipairs(ns.DevModules())do if not seen[m.addon]then seen[m.addon]=true;choices[#choices+1]={value=m.addon,label=m.addon}end end
            for _,m in ipairs(r and r.modules or {})do if not seen[m.addon]then seen[m.addon]=true;choices[#choices+1]={value=m.addon,label=m.addon}end end
            if #choices>0 then K.Picker(b,choices,D.addon,function(v)D.addon=v;D.reportID=nil;D.module=nil;D.offset=0;Refresh()end)end
        end,help.scope)
        self.modulePicker=Button(root,"",0,116,330,function(b)
            local choices={};for _,m in ipairs(Modules())do choices[#choices+1]={value=m.module,label=ns.DevTitle(m)}end
            if #choices>0 then K.Picker(b,choices,D.module,function(v)D.module=v;D.offset=0;D.point=nil;Refresh()end)end
        end,L("Выберите модуль из этого отчета. Набор собираемых точек не меняется.","Select a module in this report. This does not change collection scope."))
        self.memory=Button(root,"",350,116,240,function()D.memoryView=not D.memoryView;Refresh()end,help.memory)
        self.focus=Button(root,L("Замерить эту точку","Record this point"),610,116,354,function()D:Setup(D.point)end,L("Новый замер только выбранной функции или счетчика. Остальные точки модуля не измеряются.","Start a capture of only the selected function or counter. Other module points are not measured."))
        self.headers={};for i=1,5 do
            local column=i;local f=Label(root,"",0,158,100,11,T.muted);self.headers[i]=f
            K.Hover(root,f,L("Показатель","Metric"),function()
                if D.tab=="functions"and D.memoryView then return help.memory end
                if D.tab=="updates"then return help.hidden.."\n"..help.changes end
                return column==4 and help.own or column==3 and help.time or help.scope
            end)
        end
        self.rows={}
        for i=1,8 do
            local b=Button(root,"",0,181+(i-1)*38,666,function(self)
                if self.module then D.module=self.module;D.point=nil elseif self.point then D.point=self.point end;Refresh()
            end,help.scope);b:SetHeight(36);b.text:Hide();b.cells={}
            for j=1,5 do b.cells[j]=Label(b,"",8,9,100,12,j==1 and T.text or T.muted)end
            self.rows[i]=b
        end
        self.detail=K.Sidebar(root);self.detail:SetPoint("TOPLEFT",698,-158);self.detail:SetSize(266,327)
        self.detailTitle=Label(self.detail,"",14,14,238,16,T.accent)
        self.detailBody=Label(self.detail,"",14,50,238,12,T.muted);K.Hover(self.detail,self.detailBody,L("Модуль","Module"),help.time.."\n"..help.hidden)
        self.recordCPU=Button(self.detail,L("Записать CPU","Record CPU"),14,204,238,function()D:Setup(nil,"cpu",D.addon..":"..D.module)end,
            L("Подготовить новый замер времени выбранного модуля. Старый отчет счетчиков не содержит миллисекунд. Запись начнется только после подтверждения в настройке замера.","Prepare a new timing capture for this module. The old counter report contains no milliseconds. Recording starts only when you press Start recording in setup."))
        self.toFunctions=Button(self.detail,L("Функции модуля","Module functions"),14,244,238,function()D.tab="functions";D.offset=0;Refresh()end,help.own)
        self.toUpdates=Button(self.detail,L("Разобрать обновления","Inspect updates"),14,284,238,function()D.tab="updates";D.offset=0;Refresh()end,help.hidden)
        self.note=Label(root,"",0,505,964,12,T.muted);K.Hover(root,self.note,L("Границы данных","Data limitations"),help.memory.."\n"..help.changes)
        self.prev=Button(root,"<",876,487,40,function()D.offset=math.max(0,D.offset-8);Refresh()end,L("Предыдущие строки.","Previous rows."))
        self.next=Button(root,">",924,487,40,function()D.offset=D.offset+8;Refresh()end,L("Следующие строки.","Next rows."))
        self.assignA=Button(root,L("В группу A","Assign A"),0,566,125,function()local r=Record();if r then ns.DevAssign(r.id,r.group~="A"and"A"or nil);Refresh()end end,help.groups)
        self.assignB=Button(root,L("В группу B","Assign B"),134,566,125,function()local r=Record();if r then ns.DevAssign(r.id,r.group~="B"and"B"or nil);Refresh()end end,help.groups)
        self.clearGroups=Button(root,L("Снять A/B","Clear A/B"),268,566,125,function()ns.DevClearGroups();Refresh()end,L("Убирает назначения групп. Сами отчеты сохраняются.","Remove group assignments. Reports are retained."))
        self.conditions=Button(root,L("Условия и код","Conditions / code"),402,566,160,function()
            local c=ns.DevComparison(D.point);D:ShowText(L("Условия записей","Recording conditions"),ns.DevExport(Record(),"text",D.tab=="regressions"and c or nil),true)
        end,L("Исходные условия только для чтения. Ручная метка кода не является проверенным хешем. Версия аддона не повышается ради сравнения.","Recorded conditions are read-only. A manual code label is not a verified hash. Comparison does not bump addon versions."))
        self.remove=Button(root,L("Удалить","Delete"),574,566,110,function()local r=Record();if r then local id=r.id;D:ShowText(L("Удалить отчет?","Delete report?"),"#"..id.." · "..r.scenario,false,function()ns.DevDelete(id);D.reportID=nil;Refresh()end)end end,L("Удаляет только выбранный разработческий отчет после подтверждения.","Delete only the selected developer report after confirmation."))
        self.cost=Button(root,L("Цена измерения","Measurement cost"),748,566,216,function()D:ShowText(L("Цена измерения","Measurement cost"),CostText())end,help.cost)
        self.empty=Label(root,"",32,220,900,16,T.muted)
    end
    local function Table(columns,entries)
        for i,f in ipairs(D.headers)do local c=columns[i];f:SetShown(c~=nil);if c then f:ClearAllPoints();f:SetPoint("TOPLEFT",c[2],-158);f:SetWidth(c[3]);f:SetText(c[1])end end
        D.offset=math.min(D.offset,math.max(0,math.floor((#entries-1)/8)*8))
        for i,b in ipairs(D.rows)do
            local e=entries[D.offset+i];b:SetShown(e~=nil);b.module=e and e.module;b.point=e and e.point
            if e then
                b:SetWidth(D.tab=="modules"and 666 or 964);K.Selected(b,e.module and e.module==D.module or e.point and e.point==D.point)
                b.perfTooltip[1]=e[1]or"";b.perfTooltip[2]=e.help or help.scope
                for j,f in ipairs(b.cells)do local c=columns[j];f:SetShown(c~=nil);if c then f:ClearAllPoints();f:SetPoint("TOPLEFT",c[2]+8,-9);f:SetWidth(c[3]-12);f:SetText(e[j]or"")end end
            end
        end
        D.prev:SetShown(#entries>8);D.next:SetShown(#entries>8);K.Enable(D.prev,D.offset>0);K.Enable(D.next,D.offset+8<#entries)
    end
    function D:Paint()
        if ui.view~="developer"then if self.root then self.root:Hide()end;self.headerCost:Hide();if ui.phase2 then ui.phase2.cost:Show()end;return false end
        self:Ensure();self.root:Show();ui.content:Hide();ui.historyPane:Hide();ui.tableFrame:Hide();ui.tableCount:Hide();ui.tableUp:Hide();ui.tableDown:Hide()
        if ui.phase2 then if ui.phase2.root then ui.phase2.root:Hide()end;ui.phase2.cost:Hide()end
        ui.duration:Hide();ui.durationLabel:Hide();for key,b in pairs(ui.tabs)do K.Selected(b,key=="developer")end
        local running=ns.DevRunning();local r=Record();local catalog=ns.DevModules()
        self.headerCost:Show();K.Text(self.headerCost,"Perf: "..K.Value(r and r.nativeMean,"%.3f")..L(" мс/кадр"," ms/frame"))
        if not self.addon then self.addon=r and r.modules[1]and r.modules[1].addon or catalog[1]and catalog[1].addon end
        local m=SelectedModule();local pointRows=Points();local found=false
        for _,p in ipairs(pointRows)do if p.key==self.point then found=true;break end end
        if not found then self.point=pointRows[1]and pointRows[1].key end
        local entries={};local columns
        K.Text(ui.start,running and L("Остановить","Stop")or L("Новый замер","New capture"));K.Enable(ui.start,running or #catalog>0)
        K.Text(self.report,r and "#"..r.id.." · "..(r.scenario or"")or L("Нет сохраненных записей","No saved recordings"));K.Enable(self.report,not running and #ns.DevHistory()>0)
        K.Text(self.addonPicker,self.addon or L("Нет подключенных аддонов","No connected addons"));K.Enable(self.addonPicker,not running and(#catalog>0 or r~=nil))
        for key,b in pairs(self.tabs)do K.Selected(b,key==self.tab)end
        self.meta:SetText(r and ("%.1f / %.0f"):format(r.duration,r.requested)..L(" с · "," s · ")..r.mode.." · "..ns.DevReason(r.reason) or help.scope)
        self.title:SetText(L("Разработка","Developer")..(self.addon and " · "..self.addon or""))
        for _,f in ipairs({self.export,self.assignA,self.assignB,self.conditions,self.remove})do f:SetShown(r~=nil and not running)end
        K.Selected(self.assignA,r and r.group=="A");K.Selected(self.assignB,r and r.group=="B")
        self.clearGroups:SetShown(not running and #ns.DevHistory()>0);self.detail:SetShown(self.tab=="modules"and m~=nil and not running)
        self.modulePicker:SetShown(self.tab~="modules"and m~=nil and not running);K.Text(self.modulePicker,m and ns.DevTitle(m)or"")
        self.memory:SetShown(self.tab=="functions"and not running);K.Text(self.memory,self.memoryView and L("Показать время","Show timing")or L("Выделения памяти","Memory allocations"))
        self.focus:SetShown(self.tab=="functions"and not running);K.Enable(self.focus,self.point~=nil)
        self.empty:Hide();self.note:SetText("")
        if running then
            self.empty:Show();self.empty:SetText(L("Идет запись выбранных участков: ","Recording selected sections: ")..K.Value(ns.DevElapsed(),"%.1f")..L(" с.\nПовторите сценарий. Окно можно скрыть; запись завершится по лимиту.\nОтчет появится после остановки."," s.\nRepeat the scenario. You may hide the window; the recording stops at its limit.\nThe report appears after recording stops."));Table({},{});return true
        end
        if not m then self.empty:Show();self.empty:SetText(L("Детализация еще не подключена.\nАвтор аддона должен зарегистрировать модули и точки через API.\nОбычные CPU и память доступны во вкладке «Нагрузка».\nКонтракт подключения: кнопка API и Docs/DeveloperAPI.md.","Detail is not connected yet.\nThe addon author must register modules and points through the API.\nRegular CPU and memory are available in Load.\nIntegration contract: API button and Docs/DeveloperAPI.md."));Table({},{});return true end
        if self.tab=="modules"then
            columns={{L("Модуль","Module"),0,300},{L("Вызовы","Calls"),300,94},{L("Всего, мс","Total, ms"),394,120},{r and L("Режим записи","Recorded mode")or L("Точки","Points"),514,150}}
            for _,row in ipairs(Modules())do entries[#entries+1]={ns.DevTitle(row),K.Value(r and row.calls,"%d"),r and r.mode=="count"and L("не записано","not recorded")or K.Value(r and row.totalMs),r and (r.mode=="count"and L("Счетчики","Counters")or r.mode=="cpu"and"CPU"or L("CPU + память","CPU + memory"))or PointCount(#row.points),module=row.module,help=help.time}end
            local timing
            if not r then timing=L("Еще нет записи.","No recording yet.")
            elseif not m.timing then timing=L("У модуля только счетчики.\nИзмерение времени не подключено.","This module has counters only.\nTiming is not connected.")
            elseif r.mode=="count"then timing=L("Время не записывалось.\nРежим: Счетчики.","Timing was not recorded.\nMode: Counters.")
            else timing=L("Корневые участки: ","Outermost sections: ")..K.Value(m.totalMs)..L(" мс\nПик вызова: "," ms\nPeak call: ")..K.Value(m.peakMs)..L(" мс"," ms")end
            local visibility=not m.visibility and L("Сигнал видимости не подключен.","Visibility signal is not connected.")or L("При скрытом окне: ","While hidden: ")..K.Value(r and m.hiddenCalls,"%d")
            local build=m.build and L("Метка кода: ","Code label: ")..m.build or L("Метка кода не передана.\nОна нужна для сравнения A/B.","No code label supplied.\nA/B comparison needs one.")
            self.detailTitle:SetText(ns.DevTitle(m));self.detailBody:SetText(timing.."\n\n"..visibility.."\n\n"..build)
            local canTime=false
            for _,live in ipairs(catalog)do if live.addon==self.addon and live.module==m.module then for _,p in ipairs(live.points)do if p.timing then canTime=true end end end end
            self.recordCPU:SetShown(r~=nil and r.mode=="count");K.Enable(self.recordCPU,canTime)
            self.note:SetText(r and r.mode=="count"and L("Счетчики записывают число вызовов, без времени. Для миллисекунд подготовьте новый CPU-замер. Старые данные останутся счетчиками.","Counters record call counts, without timing. Prepare a new CPU capture for milliseconds. Existing data remains a counter report.")or help.scope)
        elseif self.tab=="functions"then
            if self.memoryView then columns={{L("Точка учета","Measurement point"),0,360},{L("Вызовы","Calls"),360,120},{L("Выделено, КиБ","Allocated, KiB"),480,210},{L("Освобождено, КиБ","Freed, KiB"),690,270}}
            else columns={{L("Точка учета","Measurement point"),0,360},{L("Вызовы","Calls"),360,110},{L("Включая вложенные, мс","Inclusive, ms"),470,190},{L("Свое, мс","Known self, ms"),660,170},{L("Пик, мс","Peak, ms"),830,134}}end
            for _,p in ipairs(pointRows)do
                local e={ns.DevTitle(p),K.Value(p.calls,"%d"),point=p.key,help=p.key.."\n"..(self.memoryView and help.memory or help.own)}
                if self.memoryView then e[3]=K.Value(p.allocatedBytes and p.allocatedBytes/1024);e[4]=K.Value(p.freedBytes and p.freedBytes/1024)
                else e[3]=K.Value(p.totalMs);e[4]=K.Value(p.selfMs);e[5]=K.Value(p.peakMs)end;entries[#entries+1]=e
            end
            self.note:SetText(not self.memoryView and r and r.mode=="count"and L("В этой записи только счетчики: время не собиралось. Выберите точку и подготовьте новый замер в режиме CPU.","This is a counter recording: timing was not collected. Select a point and prepare a new capture in CPU mode.")or self.memoryView and help.memory or help.own)
        elseif self.tab=="updates"then
            columns={{L("Сигнал","Signal"),0,350},{L("За запись","In recording"),350,180},{L("Граница вывода","Interpretation"),530,434}}
            entries={{L("Вызовы операций","Operation calls"),K.Value(r and m.calls,"%d"),L("Сумма входов в точки модуля","Sum of module point entries")},
                {L("При скрытом окне","While hidden"),K.Value(r and m.hiddenCalls,"%d"),L("Только по сигналу видимости","Only with explicit visibility"),help=help.hidden},
                {L("Окно скрыто, с","Window hidden, s"),K.Value(r and m.hiddenSeconds),L("н/д при пробелах сигнала","n/a with visibility gaps"),help=help.hidden},
                {L("Отмечено изменений","Change signals"),K.Value(r and m.changes,"%d"),L("Отдельные сигналы, не полезные вызовы","Separate signals, not useful calls"),help=help.changes}}
            self.note:SetText(help.changes.."\n"..L("Проверьте необходимость обновлений скрытого окна отдельным коротким замером. Таймеры других аддонов не отключаются.","Check whether hidden-window updates are necessary with a separate short capture. Other addons' timers are not disabled."))
        else
            local c=ns.DevComparison(self.point)
            self.meta:SetText((c.compatible and L("Записанные условия сопоставимы","Recorded conditions match")or ns.DevReason(c.reason))..(" · A: %d / B: %d"):format(#c.A,#c.B))
            columns={{L("Показатель выбранной точки","Selected point metric"),0,410},{L("A: медиана","A: median"),410,170},{L("B: медиана","B: median"),580,170},{L("Изменение","Change"),750,214}}
            for _,e in ipairs({{"calls",L("Вызовы","Calls")},{"totalMs",L("Включенное время, мс","Inclusive time, ms")},{"hiddenCalls",L("Вызовы при скрытом окне","Calls while hidden")},{"nativeMean",L("Нативный Perf, мс/кадр","Native Perf, ms/frame")},{"serviceMean",L("Служебная работа, мс/кадр","Service work, ms/frame")}})do
                local metric=c.metrics[e[1]];entries[#entries+1]={e[2],K.Value(metric.A,"%.3f"),K.Value(metric.B,"%.3f"),metric.delta and ("%+.1f%%"):format(metric.delta)or L("не сравниваем","not compared"),help=help.groups}
            end
            self.note:SetText((self.point or L("Выберите точку во вкладке «Функции».","Select a point in Functions.")).."\n"..(c.repeated and ""or L("Меньше трех повторений: результат предварительный. ","Fewer than three repeats: preliminary result. "))..L("Изменение времени участка не равно выигрышу FPS. Подтвердите результат обычным замером без проб.","A section's timing change is not an FPS gain. Confirm with a regular capture without probes."))
        end
        Table(columns,entries)
        return true
    end
    function D:Setup(pointKey,preferredMode,moduleKey)
        if ns.DevRunning() or select(2,ns.Capture()) or ns.Armed() then return end
        local list=ns.DevModules();if #list==0 then return end
        if not self.setup then
            local f=Dialog(L("Запись выбранных участков","Record selected sections"),652);self.setup=f
            Label(f,L("Сценарий","Scenario"),20,65,630,12,T.muted);f.edit=K.Input(f);f.edit:SetPoint("TOPLEFT",20,-88);f.edit:SetWidth(630);f.edit:SetMaxLetters(160)
            f.modes={}
            for i,e in ipairs({{"count",L("Счетчики","Counters"),L("Вызовы и сигналы. Самый легкий режим.","Calls and signals. The lightest mode.")},{"cpu",L("CPU участков","Section CPU"),help.own},{"alloc",L("CPU + память","CPU + memory"),help.memory}})do
                local mode=e[1];f.modes[mode]=Button(f,e[2],20+(i-1)*214,135,206,function()D.mode=mode;D:RefreshSetup()end,e[3])
            end
            f.modeNote=Label(f,"",20,172,630,12,T.muted)
            Label(f,L("Только выбранные модули","Only selected modules"),20,215,600,14,T.accent)
            f.modules={}
            for i=1,6 do
                local b=Button(f,"",20,244+(i-1)*33,630,function(self)D.selected[self.key]=not D.selected[self.key];D:RefreshSetup()end,L("Включить или исключить модуль из новой записи. Список фиксируется при запуске.","Include or exclude this module in the new capture. Scope is fixed at start."));f.modules[i]=b
            end
            f.prev=Button(f,"<",560,448,40,function()D.setupOffset=math.max(0,D.setupOffset-6);D:RefreshSetup()end,L("Предыдущие модули.","Previous modules."))
            f.next=Button(f,">",610,448,40,function()D.setupOffset=D.setupOffset+6;D:RefreshSetup()end,L("Следующие модули.","Next modules."))
            Label(f,L("Остановить не позднее","Stop no later than"),20,457,350,12)
            f.duration=Button(f,"",390,448,150,function(b)K.Picker(b,{{value=15,label="15 s"},{value=30,label="30 s"},{value=60,label="60 s"}},D.duration,function(v)D.duration=v;D:RefreshSetup()end)end,L("Жесткий предел: до 60 секунд. Остановка по лимиту вызовов или нагрузки сохраняет частичный отчет.","Hard limit: up to 60 seconds. Call or overhead limits save a partial report."))
            f.limits=Label(f,L("Не более 20 000 вызовов/сигналов, 128 точек и 32 уровней вложенности.\nЗащита: 1 мс служебной работы в среднем за 60 кадров или 20 мс за проход/кадр.\nCPU/память участков не собираются вне записи. Режим памяти дороже.","At most 20,000 calls/signals, 128 points and 32 nesting levels.\nGuard: 1 ms mean service work over 60 frames or 20 ms per pass/frame.\nSection CPU/memory is not collected outside recording. Memory mode costs more."),20,494,630,12,T.muted)
            K.Hover(f,f.limits,L("Лимиты наблюдателя","Observer limits"),help.cost)
            f.error=Label(f,"",20,562,630,12,T.accent)
            f.start=Button(f,L("Начать запись","Start recording"),460,606,190,function()
                local selected={};for key,on in pairs(D.selected)do if on then selected[#selected+1]=key end end
                local ok,reason=ns.DevStart({scenario=f.edit:GetText(),mode=D.mode,duration=D.duration,modules=selected,points=D.focusPoint and {D.focusPoint}or nil})
                if ok then D.reportID=nil;D.tab="modules";f:Hide();Refresh()else f.error:SetText(ns.DevReason(reason))end
            end,L("Запускает ограниченный сбор только выбранных модулей. Старые отчеты сохраняются.","Start bounded collection for selected modules only. Existing reports are retained."),true)
            f.edit:SetScript("OnEnterPressed",function()f.start:Click()end);f.edit:SetScript("OnEscapePressed",function()f:Hide()end)
        end
        self.setupList={};self.selected={};self.setupOffset=0;self.focusPoint=pointKey
        for _,m in ipairs(list)do if not self.addon or m.addon==self.addon then self.setupList[#self.setupList+1]=m end end
        if pointKey then
            self.setupList={}
            for _,m in ipairs(list)do for _,p in ipairs(m.points)do if p.key==pointKey then self.setupList[1]=m end end end
            if #self.setupList==0 then self:ShowText(L("Точка недоступна","Point unavailable"),ns.DevReason("unknown_point"));return end
        end
        if #self.setupList==0 then self.setupList=list;self.addon=list[1].addon end
        local first=self.setupList[1]
        if moduleKey then for _,m in ipairs(self.setupList)do if m.key==moduleKey then first=m;break end end end
        if first then self.selected[first.key]=true end
        self.mode=preferredMode=="cpu"and"cpu"or"count";self.setup.edit:SetText(pointKey or L("Проверка скрытого окна","Hidden window check"));self.setup.error:SetText(pointKey and L("Только точка: ","Only point: ")..pointKey or "")
        self:RefreshSetup();K.BindDialog(self.setup);self.setup:Show()
    end
    function D:RefreshSetup()
        local f=self.setup;local caps=Sintezza_PerfAPI:GetCapabilities()
        f.modeNote:SetText(self.mode=="count"and L("Только число вызовов и сигналы состояния. Миллисекунды не записываются.","Call counts and state signals only. Milliseconds are not recorded.")or self.mode=="cpu"and L("Время call-точек в миллисекундах. Counter-точки сохраняют только число вызовов.","Call-point timing in milliseconds. Counter points keep call counts only.")or L("Время и выделения памяти. Более дорогой режим; нужна поддержка API и выбранных точек.","Timing and memory allocations. More expensive; requires API and selected-point support."))
        for key,b in pairs(f.modes)do K.Selected(b,key==self.mode);K.Enable(b,key=="alloc"and caps.memory or key~="alloc"and caps.cpu)end
        local dropped=false
        for _,m in ipairs(self.setupList)do
            local supported=#m.points>0
            if self.mode=="alloc"then for _,p in ipairs(m.points)do if (not self.focusPoint or p.key==self.focusPoint)and not p.memory then supported=false end end end
            if not supported and self.selected[m.key]then self.selected[m.key]=nil;dropped=true end
        end
        for i,b in ipairs(f.modules)do
            local m=self.setupList[self.setupOffset+i];b:SetShown(m~=nil)
            if m then
                local supported=#m.points>0;if self.mode=="alloc"then for _,p in ipairs(m.points)do if (not self.focusPoint or p.key==self.focusPoint)and not p.memory then supported=false end end end
                b.key=m.key;K.Text(b,(self.selected[m.key]and L("Вкл · ","On · ")or L("Выкл · ","Off · "))..ns.DevTitle(m).." · "..PointCount(self.focusPoint and 1 or #m.points));K.Selected(b,self.selected[m.key]);K.Enable(b,supported)
            end
        end
        if dropped then f.error:SetText(L("Неподдерживаемые модули исключены. Выберите доступные.","Unsupported modules were removed. Select supported ones."))end
        K.Text(f.duration,self.duration..L(" с"," s"));K.Enable(f.prev,self.setupOffset>0);K.Enable(f.next,self.setupOffset+6<#self.setupList)
    end
    function D:HideDialogs()if self.dialog then self.dialog:Hide()end;if self.setup then self.setup:Hide()end end
    ui.tabs.developer=Button(ui,L("Разработка","Developer"),442,64,126,function()K.Switch("developer")end,help.scope)
    D.headerCost=K.Button(ui.settings:GetParent(),"Perf",function()D:ShowText(L("Цена измерения","Measurement cost"),CostText())end,false,help.cost)
    D.headerCost:SetSize(185,28);D.headerCost:SetPoint("RIGHT",ui.startupButton,"LEFT",-8,0);D.headerCost:Hide()
    return D
end
