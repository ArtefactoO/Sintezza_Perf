"""Render production Lua frame geometry against isolated data, not a WoW screenshot."""
import argparse
import base64
import html
import json
import io
import re
from pathlib import Path
import sys
from PIL import Image, ImageFont

p=argparse.ArgumentParser()
p.add_argument('--runtime',required=True)
p.add_argument('--output',required=True)
p.add_argument('--developer',action='store_true')
p.add_argument('--transport',action='store_true',help='Counters/theme regression fixtures for both locales and appearances')
p.add_argument('--startup',action='store_true',help='Loading report, history and button hover fixtures')
args=p.parse_args()
sys.path.insert(0,args.runtime)
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
font_root=root.parent/'Sintezza_Theme'/'Media'
glyph_buffer=io.BytesIO()
Image.open(font_root/'settings-glyphs.tga').save(glyph_buffer,format='PNG')
glyph_url='data:image/png;base64,'+base64.b64encode(glyph_buffer.getvalue()).decode()
measure_fonts={}
def measure_width(value,font_path,size):
    family='Spectral-Medium.ttf'if 'Spectral'in(font_path or'')or size>=22 else'FiraSans Medium.ttf'
    key=(family,int(size))
    if key not in measure_fonts:measure_fonts[key]=ImageFont.truetype(str(font_root/family),int(size))
    return measure_fonts[key].getlength(value)
fonts=''.join("@font-face{font-family:'%s';src:url(data:font/ttf;base64,%s);font-weight:500}"%(family,base64.b64encode((font_root/name).read_bytes()).decode()) for family,name in [('Fira','FiraSans Medium.ttf'),('Spectral','Spectral-Medium.ttf')])
def convert(v, path='root', depth=0):
    if depth>8:raise ValueError('Unexpected nested widget at '+path)
    if hasattr(v,'items'):
        items=list(v.items())
        if items and all(isinstance(k,int)for k,_ in items):return[convert(v[i],path+f'[{i}]',depth+1)for i in range(1,len(items)+1)]
        return{k:convert(x,path+'.'+str(k),depth+1)for k,x in items}
    return v
def color(v):
    if not v:return 'transparent'
    return 'rgba(%d,%d,%d,%s)'%(int(v[0]*255),int(v[1]*255),int(v[2]*255),v[3]if len(v)>3 else 1)
def font_text(value):
    pieces=[];cursor=0;opened=False
    for match in re.finditer(r'\|c([0-9a-fA-F]{8})|\|r',value):
        pieces.append(html.escape(value[cursor:match.start()]))
        if opened:pieces.append('</span>');opened=False
        if match.group(1):pieces.append('<span style="color:#'+match.group(1)[2:]+'">');opened=True
        cursor=match.end()
    pieces.append(html.escape(value[cursor:]))
    if opened:pieces.append('</span>')
    return ''.join(pieces)
cases=[('ruRU',True),('enUS',False)] if not (args.transport or args.startup) else [('ruRU',True),('enUS',True),('ruRU',False),('enUS',False)]
generated=0
for locale,themed in cases:
    lua=LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ADDON_ROOT=root.as_posix();lua.globals().TEST_LOCALE=locale
    lua.execute((root/'Tests'/'FrameMock.lua').read_text(encoding='utf-8'))
    lua.globals().Mock.measureWidth=measure_width
    if themed:lua.execute('Mock.installTheme()')
    lua.execute("ns={}; for _,f in ipairs({'Startup.lua','History.lua','Analytics.lua','Perf.lua','DeveloperHistory.lua','Developer.lua','Window.lua','Phase2Window.lua','DeveloperWindow.lua'}) do assert(loadfile(ADDON_ROOT..'/'..f))('Sintezza_Perf',ns) end; Sintezza_PerfDB={}; Mock.event('ADDON_LOADED','Sintezza_Perf'); selected=assert(loadfile(ADDON_ROOT..'/Tests/Fixture.lua'))()(ns); ns.Toggle(); Mock.layout()")
    if args.startup:
        lua.execute("rootFrame=ns.window")
        views=['startup-empty-window','startup-hover','startup-history','startup-report','startup-window','startup-chain-typical','startup-chain-long','startup-chain-end','startup-details','startup-copy-dialog']
        if themed:views.insert(-1,'startup-picker-tooltip')
    elif args.transport:
        lua.execute("transportSelected=assert(loadfile(ADDON_ROOT..'/Tests/TransportFixture.lua'))()(ns);ns.window.tabs.developer:Click();ns.window.developer.reportID=transportSelected.id;ns.OnDataChanged();Mock.layout();rootFrame=ns.window")
        views=['transport-count','transport-cpu-setup','transport-cost','transport-export','transport-live','transport-frame-graph','transport-memory','transport-regular-setup']
    elif args.developer:
        lua.execute("ns.window.tabs.developer:Click(); rootFrame=ns.window")
        views=['dev-empty','dev-catalog-functions','dev-modules','dev-functions','dev-updates','dev-regressions','dev-setup','dev-cost','dev-export']
    else:views=['capture','history','compare','memory','live','export','settings','setup']
    for view in views:
        if view=='startup-empty-window':lua.execute('ns.ToggleStartup();rootFrame=Sintezza_PerfStartupWindow')
        elif view=='startup-hover':lua.execute("Sintezza_PerfStartupWindow:Hide(); Mock.now=1.5; Mock.event('ADDON_LOADED','Sintezza_UI'); Mock.now=2.2; Mock.event('ADDON_LOADED','Sintezza_Vendor'); Mock.now=3.4; Mock.event('ADDON_LOADED','Sintezza_Loot'); Mock.now=4.4;Mock.event('ADDON_LOADED','Sintezza_Rivals');Mock.now=5.8; Mock.event('PLAYER_LOGIN'); Mock.now=9.1; Mock.event('LOADING_SCREEN_DISABLED'); Mock.event('PLAYER_ENTERING_WORLD',true,false);rootFrame=ns.window;local tab=ns.window.tabs.live;if tab.scripts.OnEnter then tab.scripts.OnEnter(tab) end")
        elif view=='startup-history':lua.execute('ns.window.tabs.history:Click();Mock.layout()')
        elif view=='startup-report':lua.execute('ns.window.phase2.historyRows[1]:Click();Mock.layout()')
        elif view=='startup-window':lua.execute('ns.window.startupButton:Click();rootFrame=Sintezza_PerfStartupWindow;Mock.layout()')
        elif view=='startup-chain-typical':lua.execute(r"""
            local trace={{kind='start',at=0}};local at,before=0,nil
            local events={{'Sintezza_Perf',.001},{'Sintezza_UI',.03},{'Sintezza_Execute',.03},{'Sintezza_Loot',.01},{'Sintezza_Rivals',.03},{'Sintezza_Vendor',.002},{'TacoTip',.03},{'TalentsForeverBook',.09},{'Tust_EUI',.05},{'WarEffortScout',.05},{'WayfarerRU',.05},{'Wayfarer_Radio',.06},{'Wayfarer_Voices_Alliance',.03},{'Wayfarer_Voices_Narrator',.01},{'Wayfarer_Voices_Shared',.02},{'WaypointUI',.03},{'WhereYouAtUniversal',.002},{'Blizzard_TimeManager',.27},{'Blizzard_CombatLog',.01},{'Mastercraft_Inbox',.4},{'PLAYER_LOGIN',.72},{'Blizzard_CombatText',.14},{'Blizzard_GroupFinder_VanillaStyle',.15},{'DandersFrames_Options',.08},{'PLAYER_ENTERING_WORLD',.03}}
            for _,event in ipairs(events)do
                at=at+event[2]
                local kind=event[1]=='PLAYER_LOGIN'and'login'or event[1]=='PLAYER_ENTERING_WORLD'and'world'or'addon'
                trace[#trace+1]={kind=kind,name=kind=='addon'and event[1]or nil,at=at}
                if kind=='login'then before=at end
            end
            trace[#trace+1]={kind='finish',at=at+.02}
            ns.SaveRecord({kind='startup',duration=at+.02,name=ns.Text('Пример по скриншоту','Screenshot example'),startup={type='reload',endpoint='screen',beforeLogin=before,traceVersion=1,trace=trace}})
            rootFrame=Sintezza_PerfStartupWindow;Mock.layout()
        """)
        elif view=='startup-chain-long':lua.execute(r"""
            local trace={{kind='start',at=0}};local at=0
            local names={'Sintezza_UI','Sintezza_Execute','Sintezza_Loot','Sintezza_Rivals','Sintezza_Vendor','TacoTip','TalentsForeverBook','Tust_EUI','WarEffortScout','WayfarerRU','Blizzard_CombatLog','Mastercraft_Inbox','WhereYouAtUniversal','Blizzard_ProfessionsCustomerOrders','Questie','OpenXP','DandersFrames','HorizonSuite','Syndicator','EllesmereUIUnitFrames'}
            for i=1,80 do
                at=at+(i==23 and .69 or i==8 and .42 or i==68 and .29 or .02)
                trace[#trace+1]={kind='addon',name=names[(i-1)%#names+1]..'_'..i,at=at}
            end
            trace[#trace+1]={kind='login',at=at+.02};trace[#trace+1]={kind='finish',at=at+.1}
            ns.SaveRecord({kind='startup',duration=at+.1,name=ns.Text('80 аддонов (пример)','80 addons (fixture)'),startup={type='reload',endpoint='screen',beforeLogin=at+.02,traceVersion=1,trace=trace}})
            rootFrame=Sintezza_PerfStartupWindow;Mock.layout()
        """)
        elif view=='startup-chain-end':lua.execute('local w=Sintezza_PerfStartupWindow;w.chainScroll:SetVerticalScroll(math.max(0,w.chainBody:GetHeight()-w.chainScroll:GetHeight()));rootFrame=w;Mock.layout()')
        elif view=='startup-details':lua.execute('Sintezza_PerfStartupWindow.detailsTab:Click();rootFrame=Sintezza_PerfStartupWindow;Mock.layout()')
        elif view=='startup-picker-tooltip':lua.execute(r"""
            local methods=getmetatable(UIParent).__index
            function methods:GetEffectiveScale()return self:GetScale()end
            function methods:GetBottom()return 600 end
            function methods:IsMouseOver()return true end
            function methods:GetStringHeight()
                local count=0
                for line in (self:GetText()..'\n'):gmatch('(.-)\n')do
                    local text=line:gsub('[\128-\191]','')
                    count=count+math.max(1,math.ceil(#text*(self.fontSize or 12)*.62/(self.width or 240)))
                end
                return count*(self.fontSize or 12)*1.3
            end
            assert(loadfile(ADDON_ROOT..'/../Sintezza_Theme/Help.lua'))('Sintezza_Theme',Sintezza_Theme)
            local owner=Sintezza_PerfStartupWindow.reportPicker
            owner.scripts.OnEnter(owner)
            for _,frame in ipairs(Mock.objects)do if frame.note and frame.owner==owner then
                frame.note:SetHeight(frame.note:GetStringHeight());rootFrame=frame;break
            end end
        """)
        elif view=='startup-copy-dialog':lua.execute('Sintezza_PerfStartupWindow.copy:Click();Mock.layout();rootFrame=Sintezza_PerfDialog')
        elif view=='transport-count':pass
        elif view=='transport-cpu-setup':lua.execute('ns.window.developer.recordCPU:Click();rootFrame=ns.window.developer.setup')
        elif view=='transport-cost':lua.execute('ns.window.developer.setup:Hide();ns.window.developer.cost:Click();rootFrame=ns.window.developer.dialog')
        elif view=='transport-export':lua.execute('ns.window.developer.dialog:Hide();ns.window.developer.export:Click();rootFrame=ns.window.developer.dialog')
        elif view=='transport-live':lua.execute('ns.window.developer.dialog:Hide();ns.window.tabs.live:Click();Mock.layout();rootFrame=ns.window')
        elif view=='transport-frame-graph':lua.execute('ns.window.tabs.capture:Click();ns.window.reportID=selected.id;ns.window.phase2.sub="smooth";ns.OnDataChanged();Mock.layout();rootFrame=ns.window')
        elif view=='transport-memory':lua.execute('ns.window.phase2.sub="memory";ns.OnDataChanged();Mock.layout();rootFrame=ns.window')
        elif view=='transport-regular-setup':lua.execute('ns.window.start:Click();rootFrame=ns.window.phase2.setup')
        elif view=='dev-empty':pass
        elif view=='dev-catalog-functions':lua.execute("assert(loadfile(ADDON_ROOT..'/Tests/DeveloperFixture.lua'))()(ns,true);ns.window.tabs.developer:Click();ns.window.developer.tabs.functions:Click();Mock.layout();rootFrame=ns.window")
        elif view=='dev-modules':lua.execute("devSelected=assert(loadfile(ADDON_ROOT..'/Tests/DeveloperFixture.lua'))()(ns); ns.window.developer.reportID=devSelected.id;ns.window.developer.tab='modules';ns.window.tabs.developer:Click();Mock.layout();rootFrame=ns.window")
        elif view in ['dev-functions','dev-updates','dev-regressions']:lua.execute("ns.window.developer.tabs.%s:Click();Mock.layout();rootFrame=ns.window"%view[4:])
        elif view=='dev-setup':lua.execute("ns.window.developer:Setup();rootFrame=ns.window.developer.setup")
        elif view=='dev-cost':lua.execute("ns.window.developer.setup:Hide();ns.window.developer.cost:Click();rootFrame=ns.window.developer.dialog")
        elif view=='dev-export':lua.execute("ns.window.developer.dialog:Hide();ns.window.developer.export:Click();rootFrame=ns.window.developer.dialog")
        elif view=='settings':lua.execute('ns.window.settings:Click();rootFrame=Sintezza_PerfDialog')
        elif view=='export':lua.execute('ns.window.tabs.capture:Click();ns.window.reportID=selected.id;ns.OnDataChanged();ns.window.phase2.export:Click();rootFrame=Sintezza_PerfDialog')
        elif view=='setup':lua.execute('if Sintezza_PerfDialog then Sintezza_PerfDialog:Hide() end;ns.window.phase2:Setup();rootFrame=ns.window.phase2.setup')
        elif view=='memory':lua.execute('ns.window.tabs.capture:Click();ns.window.reportID=selected.id;ns.window.phase2.sub="memory";ns.OnDataChanged();Mock.layout();rootFrame=ns.window')
        else:lua.execute("if Sintezza_PerfDialog then Sintezza_PerfDialog:Hide() end; ns.window.tabs.%s:Click();if ns.window.view=='capture'then ns.window.reportID=selected.id end; ns.window.phase2.selected=13;ns.OnDataChanged();Mock.layout();rootFrame=ns.window"%view)
        data=convert(lua.eval('Mock.snapshot(rootFrame)'))
        root_width=lua.eval('rootFrame:GetWidth()');root_height=lua.eval('rootFrame:GetHeight()')
        elements=[]
        for f in data:
            if f.get('line'):
                line=f['line'];w,h=f['width'],f['height'];x1,x2=(0,w)if line['right']else(w,0);y1,y2=(h,0)if line['up']else(0,h)
                clipping=''
                if f.get('clip'):
                    cx,cy,cw,ch=f['clip'];x,y=f['x'],f['y']
                    clipping=f'clip-path:inset({max(0,cy-y)}px {max(0,x+w-cx-cw)}px {max(0,y+h-cy-ch)}px {max(0,cx-x)}px);'
                elements.append(f'<svg class="node" style="left:{f["x"]}px;top:{f["y"]}px;width:{w}px;height:{h}px;opacity:{f.get("alpha",1)};overflow:visible;{clipping}"><line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color(f.get("fill"))}" stroke-width="{line["thickness"]}"/></svg>')
                continue
            style=f"left:{f['x']}px;top:{f['y']}px;width:{f['width']}px;height:{f['height']}px;"
            if f.get('autoWidth'):
                anchor=f.get('anchorX',0)
                style+=f"width:max-content;left:{f['x']+f['width']*anchor}px;transform:translateX({-100*anchor}%);"
            if f.get('autoHeight'):style+='height:auto;'
            style+=f"background:{color(f.get('fill'))};color:{color(f.get('color'))};font-size:{f.get('fontSize') or 12}px;opacity:{f.get('alpha',1)};"
            if (f.get('texture')or'').endswith('settings-glyphs.tga')and f.get('texCoord'):
                left,right,top,bottom=f['texCoord'];cell=right-left
                style+=f'background:{color(f.get("color"))};mask-image:url({glyph_url});mask-size:{100/cell}% 100%;mask-position:{left/(1-cell)*100}% center;mask-repeat:no-repeat;'
            if f.get('spacing') is not None:style+=f'line-height:{(f.get("fontSize")or 12)*1.3+f["spacing"]}px;'
            if f.get('border'):style+='border:1px solid '+color(f['border'])+';'
            if f.get('align'):style+='text-align:'+f['align'].lower()+';'
            if f.get('fontSize',0)>=22:style+="font-family:'Spectral';"
            style+='white-space:'+('pre-wrap'if f.get('wrap')else'pre')+';'
            if f.get('clip'):
                cx,cy,cw,ch=f['clip'];x,y,w,h=f['x'],f['y'],f['width'],f['height']
                style+=f'clip-path:inset({max(0,cy-y)}px {max(0,x+w-cx-cw)}px {max(0,y+h-cy-ch)}px {max(0,cx-x)}px);'
            text=font_text(f.get('text',''))if f['kind']=='FontString'else html.escape(f.get('text',''))
            elements.append(f'<div data-id="{f["id"]}" class="node {f["kind"]}" style="{style}">{text}</div>')
        label=locale+' · '+('Theme geometry adapter'if themed else'Standalone')+' · '+view+' · synthetic fixture'
        page=f'<!doctype html><html lang="{locale[:2]}"><meta charset="utf-8"><title>Perf Lua layout fixture</title><style>{fonts}*{{box-sizing:border-box}}body{{margin:16px;background:#100c09;color:#fae9d9;font:500 12px Fira,sans-serif}}main{{position:relative;width:{root_width}px;height:{root_height}px;margin-top:12px;overflow:hidden}}.node{{position:absolute;overflow:hidden}}.FontString{{background:transparent!important;line-height:1.3}}.EditBox{{line-height:1.3;overflow-wrap:anywhere}}</style><p>{label}</p><main>'+''.join(elements)+'</main></html>'
        name=locale+('-themed'if themed else'-standalone')+'-'+view if args.transport or args.startup else locale+'-'+view
        (out/(name+'.html')).write_text(page,encoding='utf-8')
        (out/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
        generated+=1
print(f'Lua geometry fixtures: {generated} views generated')
