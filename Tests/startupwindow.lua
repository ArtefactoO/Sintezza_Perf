local checks=0
local function check(value,label)assert(value,label);checks=checks+1 end
for _,themed in ipairs({false,true})do
    assert(loadfile(ADDON_ROOT..'/Tests/FrameMock.lua'))()
    Sintezza_Theme=nil
    if themed then
        Mock.installTheme()
        assert(loadfile(ADDON_ROOT..'/../Sintezza_Theme/Minimap.lua'))('Sintezza_Theme',Sintezza_Theme)
    end
    local ns={}
    for _,file in ipairs({'History','Analytics','Perf','DeveloperHistory','Developer','Window','Phase2Window','DeveloperWindow'})do
        assert(loadfile(ADDON_ROOT..'/'..file..'.lua'))('Sintezza_Perf',ns)
    end
    Sintezza_PerfDB={};Mock.event('ADDON_LOADED','Sintezza_Perf')
    local launcher=Sintezza_PerfMinimapButton
    check(launcher.clicks[1]=='LeftButtonUp'and launcher.clicks[2]=='RightButtonUp','both minimap buttons registered')
    launcher.scripts.OnEnter(launcher)
    check(GameTooltip.detail:find('ПКМ',1,true),'minimap tooltip includes right-click hint')
    launcher.scripts.OnClick(launcher,'RightButton')
    local window=Sintezza_PerfStartupWindow
    check(window:IsShown()and not ns.window,'right-click opens report without creating main window')
    check(window.reportPicker.text:GetText():find('пока нет',1,true),'empty loading window explains missing report')
    check(not window.copy:IsEnabled(),'copy disabled without report')
    check(window.select==nil and window.copy.text:GetText()=='Копировать текст','one copy action replaces separate selection')
    check(window.reportPicker:GetWidth()<window:GetWidth()*.6,'report selector is compact')
    launcher.scripts.OnClick(launcher,'RightButton');check(not window:IsShown(),'second right-click closes report')
    check(themed and window.themeSurface=='window'or not themed and not window.themeSurface,'window uses selected appearance route')
    local report=ns.SaveRecord({kind='startup',duration=12,name='First login',startup={type='login',endpoint='screen',beforeLogin=8,gaps={{duration=2,after='AddonA',before='AddonB'},{duration=1,after='AddonB',before='PLAYER_LOGIN'}}}})
    launcher.scripts.OnClick(launcher,'RightButton')
    check(window.recordID==report.id and window.values[1]:GetText()=='12.00 с','latest loading report populated')
    check(window.values[2]:GetText()=='8.00 с'and window.values[3]:GetText()=='4.00 с','phase values displayed')
    check(window.copy:IsEnabled()and not window.output.selectedText,'copy available immediately without selection')
    check(window.reportText:find('2.00 с\nНачало: AddonA\nКонец: AddonB',1,true),'gap duration and markers use separate labeled lines')
    check(window.reportText:find('Конец: AddonB\n\n1.00',1,true),'blank line separates adjacent gap entries')
    check(not window.chainTab:IsEnabled()and window.scroll:IsShown(),'legacy reports keep details without fabricated chronology')
    local clipboardCalls=0
    CopyToClipboard=function()clipboardCalls=clipboardCalls+1;error('restricted')end
    window.copy:Click()
    local copyDialog=Sintezza_PerfDialog
    check(copyDialog:IsShown()and copyDialog.record.id==report.id,'Copy action opens a dialog for the chosen report')
    check(copyDialog.body.output:HasFocus()and copyDialog.body.output.selectedText and clipboardCalls==0,'copy dialog focuses selected report without restricted calls')
    check(copyDialog.body.output:GetText():find('First login',1,true)and copyDialog.body.output:GetText():find('12.00',1,true),'copy dialog includes report identity and duration')
    copyDialog.body.output.scripts.OnEscapePressed(copyDialog.body.output)
    check(not copyDialog:IsShown()and window:IsShown(),'Escape closes copy dialog and retains loading window')
    window.output:ClearFocus()
    check(window.copy:IsEnabled(),'moving focus to the copy action retains report availability')
    window.copy:Click();check(copyDialog:IsShown()and copyDialog.body.output:HasFocus(),'copy still opens after original field loses focus');copyDialog:Hide()
    check(window.output.scripts.OnKeyDown==nil,'original report does not intercept native keyboard selection or copying')
    window.output:SetText('changed');window.output.scripts.OnTextChanged(window.output,true)
    check(window.output:GetText()==window.reportText,'report text read-only')
    check(window.copy:IsEnabled(),'read-only reset keeps valid report copy available')
    local second=ns.SaveRecord({kind='startup',duration=7,name='Reload',startup={type='reload',endpoint='world',reloadLead=1,beforeLogin=3,gaps={}}})
    check(window.recordID==second.id and window.values[1]:GetText()=='7.00 с','open window updates on new loading report')
    check(window.copy:IsEnabled(),'new report can be copied immediately')
    window.reportPicker:Click();check(window.recordID==report.id,'saved loading report selectable')
    window.copy:Click()
    check(copyDialog.record.id==report.id and copyDialog.body.output.selectedText,'cached copy dialog refreshes and selects the chosen older report')
    window.output.scripts.OnEscapePressed(window.output)
    check(not copyDialog:IsShown(),'closing loading report also closes its copy dialog')
    ns.ToggleStartup()
    window:Refresh()
    check(window.copy:IsEnabled()and not window.output.selectedText,'refresh clears highlight while retaining direct report copy')
    window.output.scripts.OnEscapePressed(window.output);check(not window:IsShown(),'Escape in output closes window')
    local objectCount=#Mock.objects
    for _=1,50 do ns.ToggleStartup();ns.ToggleStartup()end
    check(#Mock.objects==objectCount,'startup window reused across 50 toggles')
    launcher.scripts.OnClick(launcher,'LeftButton');local ui=ns.window
    check(ui:IsShown()and not window:IsShown(),'left-click still toggles main window')
    ui.startupButton:Click();check(window:IsShown(),'header opens same cached report window')
    launcher.scripts.OnClick(launcher,'RightButton');check(not window:IsShown()and ui:IsShown(),'right-click closes header-opened report only')
    SlashCmdList.SINTEZZAPERF('startup');check(window:IsShown(),'startup command opens same window')
    SlashCmdList.SINTEZZAPERF('startup');check(not window:IsShown(),'startup command toggles window closed')
    launcher.scripts.OnClick(launcher,'LeftButton');check(not ui:IsShown(),'main window left-click closes')
    local running=0;for _,frame in ipairs(Mock.objects)do if frame.scripts.OnUpdate then running=running+1 end end
    check(running==0,'closed report has no update callback')
    local registered=0;for _,name in ipairs(UISpecialFrames)do if name=='Sintezza_PerfStartupWindow'then registered=registered+1 end end
    check(registered==1,'Escape frame registered once')
    local trace={{kind='start',at=0}}
    for i=1,80 do trace[#trace+1]={kind='addon',name='Step'..i,at=i*.01}end
    trace[#trace+1]={kind='finish',at=3}
    local traced=ns.SaveRecord({kind='startup',duration=3,name='Traced',startup={type='login',endpoint='screen',beforeLogin=2,gaps={},traceVersion=1,trace=trace}})
    window.recordID=traced.id
    ns.ToggleStartup()
    check(window.view=='chain'and window.chainPanel:IsShown()and not window.scroll:IsShown(),'new report defaults to separate chain view')
    local units=window.chainUnits
    check(#units==#window.chainNodes and units[2].name:GetText()=='Step1','chain uses one reusable native unit per marker')
    check(units[2].time:GetText():find('мс',1,true)and units[2].points[1][5]==units[1].points[1][5],'name and milliseconds share a compact horizontal row')
    local ranked=0;for _,rank in pairs(window.chainRanks)do ranked=ranked+1 end
    check(ranked==3 and window.chainRanks[81]==1,'rank longest links over the whole report rather than visible cells')
    check(units[81].name:GetText()=='Step80'and units[81].time:GetText():find('#1',1,true),'longest link stays in its original late unit, not moved to a summary')
    check(window.chainBody:GetHeight()<window.chainScroll:GetHeight()*2,'eighty short marker names need less than two viewports')
    local objects=#Mock.objects
    window.chainScroll:SetVerticalScroll(60)
    check(units[2].step==window.chainNodes[2]and #Mock.objects==objects,'scrolling native units creates no frames')
    local selectedID,reportText,selectedNodes=window.recordID,window.reportText,window.chainNodes
    local historyCount=#ns.History()
    for _=1,20 do window.detailsTab:Click();window.chainTab:Click()end
    check(window.recordID==selectedID and window.chainNodes==selectedNodes and window.reportText==reportText and #ns.History()==historyCount,'tab switches preserve selected report and data without reselecting history')
    check(window.reportPicker:IsEnabled()and window.chainTab:IsEnabled()and window.chainScroll:GetVerticalScroll()==60,'tabs retain report choices and chain scroll position')
    window.detailsTab:Click();check(window.scroll:IsShown()and window.reportText:find('Step1 --',1,true),'text details retain copyable chain')
    window.reportPicker:Click();check(window.recordID~=selectedID and window.reportPicker:IsEnabled(),'report picker remains usable from Details')
    window.recordID=selectedID;window:Refresh();window.detailsTab:Click()
    window.chainTab:Click();window.copy:Click()
    check(copyDialog.record.id==traced.id and copyDialog.body.output:GetText():find('Step80',1,true)and not copyDialog.body.output:GetText():find('|cff',1,true),'copy includes full plain chain independently of scroll, formatting and view')
    copyDialog:Hide()
    check(units[81].highlight:IsShown()and units[81].time:GetText():find('#1',1,true),'longest unit has a highlighted surface and textual rank')
    local terminal=units[#window.chainNodes]
    check(terminal.name:GetText()=='Вошел в игру'and not terminal.time:IsShown()and not terminal.arrow:IsShown(),'terminal marker has no outgoing time or arrow')
    local bodyWidth=window.chainBody:GetWidth()
    Mock.fontWidthFactor=.8;window.chainBody:SetWidth(320);window:PaintChain()
    local contained=true
    for _,unit in ipairs(units)do
        if unit.step then
            local x=unit.points[1][4]
            contained=contained and x+unit:GetWidth()<=320.001 and unit.arrow:GetParent()==unit
            if unit.arrow:IsShown()then contained=contained and unit:GetWidth()==unit.card:GetWidth()+18 end
        end
    end
    check(contained,'wide font metrics and narrow rows keep every arrow in its whole unit')
    Mock.fontWidthFactor=nil;window.chainBody:SetWidth(bodyWidth);window:PaintChain()
    check(#Mock.objects==objects,'reflow reuses existing unit frames')
    local longName='Sintezza_'..string.rep('VeryLongAddonName',6)
    local longReport=ns.SaveRecord({kind='startup',duration=1,name='Long name',startup={type='login',endpoint='screen',traceVersion=1,trace={{kind='start',at=0},{kind='addon',name=longName,at=.5},{kind='finish',at=1}},traceOmitted=2}})
    check(units[2].name:GetText()==longName,'long marker names remain complete in their native unit')
    window.chainBody:SetWidth(240);window:PaintChain()
    check(units[2]:GetWidth()<=240 and units[2].name:GetHeight()>24 and units[2].arrow:GetParent()==units[2],'exceptional long names wrap inside one contained unit')
    window.chainBody:SetWidth(bodyWidth);window:PaintChain()
    check(ns.StartupChainText(longReport):find(longName,1,true)and ns.StartupChainText(longReport):find('пропущено отметок: 2',1,true),'copy retains full unshortened names and omitted-marker information')
    check(window.chainHelp.perfTooltip[2]:find('всю работу между событиями',1,true)and window.chainNote:GetText():find('2',1,true),'heading tooltip explains link scope and omission count remains visible')
    check(units[3].name:GetText()=='Вошел в игру'and not units[3].time:IsShown(),'short-chain terminal has no timing label')
    check(units[2].card.perfTooltip[2]():find(longName,1,true)and units[2].card.perfTooltip[2]():find('2',1,true),'unit tooltip retains full names and omission count')
    for _=1,25 do ns.SaveRecord({kind='background',duration=5,rows={},timeline={}})end
    window.detailsTab:Click();window.chainTab:Click()
    check(ns.FindRecord(longReport.id)and window.recordID==longReport.id and window.reportPicker:IsEnabled(),'background episodes cannot evict loading reports when switching views')
    window.reportPicker:Click()
    check(window.recordID~=longReport.id and window.chainTab:IsEnabled(),'loading selection still offers earlier traces after background activity')
    ns.ToggleStartup()
    ns.ToggleStartup();check(window.chainNodes and window.reportPicker:IsEnabled(),'reopening keeps retained loading choices')
    local cappedTrace={{kind='start',at=0}}
    for i=1,126 do cappedTrace[#cappedTrace+1]={kind='addon',name='Bound'..i,at=i*.001}end
    cappedTrace[#cappedTrace+1]={kind='finish',at=1}
    ns.SaveRecord({kind='startup',duration=2,startup={type='reload',endpoint='screen',reloadLead=1,traceVersion=1,trace=cappedTrace}})
    check(#window.chainUnits==129 and #window.chainNodes==129,'unit pool is bounded by trace cap plus reload command')
    local cappedObjects=#Mock.objects
    for _=1,20 do window.chainScroll:SetVerticalScroll(20);window.chainScroll:SetVerticalScroll(0);window.detailsTab:Click();window.chainTab:Click()end
    check(#Mock.objects==cappedObjects,'maximum-size scrolling and tab switching allocate no frames')
    ns.ToggleStartup()
end
print(('Startup window: PASS (%d checks)'):format(checks))
