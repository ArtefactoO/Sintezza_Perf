return function(ns)
    local rows={
        {name='Sintezza_UI',average=.64,peak=18.2,five=4,ten=1,fifty=0,memory=24.6,version='1.6.0'},
        {name='Sintezza_Rivals',average=.29,peak=6.1,five=2,ten=0,fifty=0,memory=7.2,version='1.1.0'},
        {name='Sintezza_Loot',average=.21,peak=4.7,five=0,ten=0,fifty=0,memory=4.8,version='1.6.0'},
        {name='Sintezza_Vendor',average=.10,peak=3.6,five=0,ten=0,fifty=0,memory=8.6,version='2.2.0'},
        {name='Sintezza_Disenchant',average=.08,peak=2.8,five=0,ten=0,fifty=0,memory=6.3,version='1.1.0'},
        {name='OtherAddon',average=.06,peak=1.3,five=0,ten=0,fifty=0,memory=136.2,version='1.0'},
        {name='Sintezza_Perf',average=.04,peak=.7,five=0,ten=0,fifty=0,memory=1.9,version='0.8.0'},
    }
    local timeline={}
    for i=1,30 do
        local count=i==8 and 2 or i==13 and 6 or i==22 and 3 or i==26 and 1 or 0
        local peak=i==8 and 12.2 or i==13 and 8.7 or i==22 and 26.4 or i==26 and 6.9 or 2
        timeline[i]={from=i-1,to=i,frames=120,samples=120,frameSamples=120,framePeak=i==13 and 86 or i==8 and 61.4 or i==22 and 68 or i==26 and 54 or 14,cpuAtFramePeak=i==13 and 3.2 or 1.42,perfAtFramePeak=.06,long50=count>0 and 1 or 0,five=count,ten=i==22 and 1 or 0,fifty=0,peak=peak,average=1.42,
            individualFive=(i==8 or i==22)and 3 or 0,contributors=(i==8 or i==22)and{{name='Sintezza_UI',value=2},{name='Sintezza_Rivals',value=1}}or{}}
    end
    local now=time()
    ns.SaveRecord({kind='background',name=ns.Text('Фоновый эпизод','Background episode'),timestamp=now-2900,duration=5,five=7,ten=2,fifty=0,rows={{name='Sintezza_UI',five=3,ten=1,fifty=0},{name='Sintezza_Perf',five=0,ten=0,fifty=0}},timeline={{from=0,to=5,five=7,ten=2,fifty=0,individualFive=3,contributors={{name='Sintezza_UI',value=3}}}}})
    ns.SaveRecord({kind='capture',name=ns.Text('После смены настроек','After changing settings'),timestamp=now-360,duration=30,frames=3600,samples=3600,five=12,ten=1,fifty=0,average=1.42,peak=26.4,rows=rows,timeline=timeline,pinned=true,memoryTimestamp=now-380,memoryAge=20})
    local selected=ns.SaveRecord({kind='capture',name=ns.Text('Проверка карты','Map check'),timestamp=now,duration=30,frames=3600,samples=3600,five=12,ten=1,fifty=0,average=1.42,peak=26.4,rows=rows,timeline=timeline,memoryTimestamp=now-18,memoryAge=18,costAverage=.015,costPeak=.08})
    for _,r in ipairs(ns.History())do
        if r.kind=='capture'then
            r.profile='detailed';r.trigger='manual';r.scenario='Map';r.measurement=ns.MEASUREMENT;r.context=ns.ReadContext();r.complete=true;r.requested=30;r.build='1.60.1.70938'
            r.p95,r.p99,r.long50,r.framePeak,r.frameSamples=18.2,28.4,4,86,3600
            r.memoryTrail={{timestamp=now-240,total=182.8},{timestamp=now-180,total=184.2},{timestamp=now-60,total=187.1},{timestamp=now,total=189.6}}
            r.markers={{at=7,kind='manual',text=ns.Text('Ручная метка','Manual marker')},{at=12,kind='manual',text=ns.Text('Открытие карты','Opening the map')}}
            r.group=r.id==selected.id and 'A'or'B'
        end
    end
    ns.InitCollector(ns.db)
    return selected
end
