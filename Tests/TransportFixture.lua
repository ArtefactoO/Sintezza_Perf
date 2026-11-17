return function(ns)
    local api=Sintezza_PerfAPI
    local module=api:RegisterModule('Sintezza_UI','transport',{title='Transport timers',titleRu='Таймеры транспорта'})
    local visit=api:RegisterPoint(module,'next_visit',{title='Calculate dock departure',titleRu='Расчет отправления',memory=true})
    local cluster=api:RegisterPoint(module,'cluster_visit',{title='Choose cluster departure',titleRu='Выбор отправления группы',memory=true})
    local world=api:RegisterPoint(module,'world_refresh',{kind='counter',title='World map refreshes',titleRu='Обновления карты мира'})
    api:RegisterPoint(module,'minimap_refresh',{kind='counter',title='Minimap refreshes',titleRu='Обновления миникарты'})
    assert(ns.DevStart({mode='count',scenario='Hidden window check',duration=15,modules={'Sintezza_UI:transport'}}))
    local function operation()return true end
    for _=1,1000 do api:Call(visit,operation);api:Call(cluster,operation)end
    for _=1,231 do api:Count(world)end
    Mock.tick(.01);Mock.tick(14.99)
    return ns.DevCurrent()
end
