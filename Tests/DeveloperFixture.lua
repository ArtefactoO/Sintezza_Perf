return function(ns,catalogOnly)
    local api=Sintezza_PerfAPI
    local map=api:RegisterModule('Sintezza_UI','map',{title='Map and routes',titleRu='Карта и маршруты',visibility=true,changes=true,build='routes-before',buildSource='manual'})
    local refresh=api:RegisterPoint(map,'refresh',{title='Refresh route',titleRu='Обновление маршрута',memory=true})
    local search=api:RegisterPoint(map,'search',{title='Find route',titleRu='Поиск маршрута',memory=true})
    local markers=api:RegisterPoint(map,'markers',{title='Update markers',titleRu='Обновление меток',memory=true})
    local panels=api:RegisterModule('Sintezza_UI','panels',{title='Interface panels',titleRu='Панели интерфейса',build='panels-a',buildSource='manual'})
    api:RegisterPoint(panels,'refresh',{title='Refresh panels',titleRu='Обновление панелей'})
    local tips=api:RegisterModule('Sintezza_UI','tooltips',{title='Tooltips',titleRu='Подсказки'})
    api:RegisterPoint(tips,'update',{kind='counter',title='Update tooltip',titleRu='Обновление подсказки'})
    if catalogOnly then return end
    api:SetVisible(map,false)
    for i=1,6 do
        local group=i%2==1 and'A'or'B'
        api:SetBuildLabel(map,group=='A'and'routes-before'or'routes-cache','manual')
        assert(ns.DevStart({mode='cpu',scenario='Hidden map',duration=30,modules={'Sintezza_UI:map'}}))
        for call=1,(group=='A'and 20 or 4)do
            api:Call(refresh,function()
                Mock.now=Mock.now+.001
                api:Call(search,function()Mock.now=Mock.now+.003 end)
                api:Call(markers,function()Mock.now=Mock.now+.001 end)
            end)
        end
        api:MarkChanged(refresh);Mock.tick(.1);Mock.tick(30)
        ns.DevAssign(ns.DevCurrent().id,group)
    end
    return ns.DevCurrent()
end
