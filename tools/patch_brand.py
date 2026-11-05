"""Patch: identidade ÔNIX-OS na interface (logo, retratos, boot, mapa tático, dossiês, carimbos)."""
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
V2 = os.path.join(ROOT, 'v2')

def patch(path, marker, reps):
    s = open(path, encoding='utf-8').read()
    if marker in s:
        print('já aplicado:', os.path.basename(path)); return
    for a, b in reps:
        if a not in s:
            sys.exit(f'{path}: não achei: {a[:90]}')
        s = s.replace(a, b, 1)
    open(path, 'w', encoding='utf-8').write(s)
    print('ok:', os.path.basename(path))

GEM = '<svg class="gem" viewBox="0 0 40 46" aria-hidden="true"><path d="M20 1 38 12v22L20 45 2 34V12Z" fill="#0b0d14" stroke="#ffa53d" stroke-width="2"/><path d="M20 1v44M2 12l18 11 18-11M20 23v22" fill="none" stroke="#ffa53d" stroke-width="1" opacity=".55"/><path d="M20 23 38 12v22L20 45Z" fill="#ffa53d" opacity=".14"/></svg>'

patch(os.path.join(ROOT, 'tools', 'build_index.py'), 'theme.css', [
    ("body = open(os.path.join(root, 'v2', 'body.html'), encoding='utf-8').read()",
     "css += open(os.path.join(root, 'v2', 'theme.css'), encoding='utf-8').read()\nbody = open(os.path.join(root, 'v2', 'body.html'), encoding='utf-8').read()"),
])

patch(os.path.join(V2, 'body.html'), 'class="os"', [
    ('    <div class="eyebrow">Nova Aurora · 2091</div>\n',
     '    ' + GEM + '\n    <div class="eyebrow">Nova Aurora · 2091</div>\n    <div class="os">ÔNIX-OS 2.91 · TERMINAL DE CONTROLE · <b>ACESSO AUTORIZADO</b> <span class="cur"></span></div>\n'),
    ('<div id="scrMap" class="screen" hidden>', '<div class="serial">ONX // CONTROLE TÁTICO // BUILD 2091.11</div>\n\n<div id="scrMap" class="screen" hidden>'),
    ('<div class="mapsvgbox"><svg id="mapSvg"', '<div class="mapsvgbox"><div class="maplbl">MAPA TÁTICO · NOVA AURORA · NÍVEL DE ACESSO 4</div><svg id="mapSvg"'),
])

patch(os.path.join(V2, 'theme.css'), '.maplbl{', [
    ('.mapsvgbox::after{content:"MAPA TÁTICO · NOVA AURORA · NÍVEL DE ACESSO 4";position:absolute;',
     '.maplbl{position:absolute;'),
])

patch(os.path.join(V2, 'js', 'ui.js'), "from './brand.js'", [
    ("import {LANG,setLang} from './i18n.js';",
     "import {LANG,setLang,tr} from './i18n.js';\nimport {bootFx,decorateMap,tickerHtml,agentPortrait,rivalPortrait,dossierHtml} from './brand.js';"),
    ('b.innerHTML=`<span class="num">${u.num}</span>', 'b.innerHTML=`<span class="num"><img src="${agentPortrait(u.ag)}" alt=""><b>${u.num}</b></span>'),
    ("function showModal(html,esc){$('#mbox').innerHTML=html;",
     "function showModal(html,esc){$('#mbox').dataset.code='ONX-'+(1000+Math.random()*9000|0)+' · '+tr('CLASSIFICADO');$('#mbox').innerHTML=html;"),
    ("function fadeIn(){const f=$('#fade');", "function fadeIn(){bootFx((Math.random()*3)|0);const f=$('#fade');"),
    ("  $('#mapSvg').innerHTML=s;renderMapSide();", "  $('#mapSvg').innerHTML=s;decorateMap($('#mapSvg'),DIST,G.dono,avail);renderMapSide();"),
    ("  setState('menu');show('#scrMap');hideModal();\n", "  setState('menu');show('#scrMap');hideModal();\n  if(!$('#scrMap .tk'))$('#scrMap').insertAdjacentHTML('beforeend',tickerHtml());\n"),
    ("<h2>${d.nome}</h2><p>${briefLong(i,nm)}</p>", "<h2>${d.nome}</h2>${dossierHtml(d.mission)}<p>${briefLong(i,nm)}</p>"),
    ('<span class="nm">${q.nome}</span>', '<img class="pf sm" src="${agentPortrait(q)}" alt=""><span class="nm">${q.nome}</span>'),
    ('<div class="agh"><h2>${a.nome}</h2>', '<div class="agh"><img class="pf big" src="${agentPortrait(a)}" alt=""><h2>${a.nome}</h2>'),
    ('style="--c:${r.trim}">${r.nome}<small>', 'style="--c:${r.trim}"><img src="${rivalPortrait(r)}" alt="">${r.nome}<small>'),
    ("'Missão fracassada'}</h2><p>${M.reason}</p>", "'Missão fracassada'}</h2><div class=\"stamp ${win?'ok':'bad'}\">${win?'CUMPRIDA':'FRACASSO'}</div><p>${M.reason}</p>"),
])

patch(os.path.join(V2, 'js', 'en.js'), "'CLASSIFICADO'", [
    ("  'CONTROLE':'CONTROL',",
     "  'CONTROLE':'CONTROL','CLASSIFICADO':'CLASSIFIED','CONFIDENCIAL':'CONFIDENTIAL','CONQUISTADO':'CONQUERED','CUMPRIDA':'ACCOMPLISHED','FRACASSO':'FAILED',\n"
     "  'ÔNIX-OS 2.91 · TERMINAL DE CONTROLE ·':'ÔNIX-OS 2.91 · CONTROL TERMINAL ·','ACESSO AUTORIZADO':'ACCESS GRANTED','ONX // CONTROLE TÁTICO // BUILD 2091.11':'ONX // TACTICAL CONTROL // BUILD 2091.11',\n"
     "  'MAPA TÁTICO · NOVA AURORA · NÍVEL DE ACESSO 4':'TACTICAL MAP · NOVA AURORA · ACCESS LEVEL 4',\n"
     "  'AUTENTICANDO CONTROLE…':'AUTHENTICATING CONTROL…','ACESSO CONCEDIDO':'ACCESS GRANTED','UPLINK DO ESQUADRÃO…':'SQUAD UPLINK…','CRIPTOGRAFIA ATIVA':'ENCRYPTION ACTIVE','SINCRONIZANDO REDE ÔNIX…':'SYNCING ÔNIX NETWORK…','MAPA TÁTICO CARREGADO':'TACTICAL MAP LOADED',\n"
     "  'ÔNIX · SEGURANÇA QUE VOCÊ NÃO PRECISA PEDIR':'ÔNIX · SECURITY YOU NEVER HAVE TO ASK FOR','LEMBRETE DO CONSELHO: LEALDADE É UM INVESTIMENTO':'A REMINDER FROM THE COUNCIL: LOYALTY IS AN INVESTMENT',\n"
     "  'IMPLANTES NEURAIS EM 12X SEM JUROS NAS CLÍNICAS ÔNIX':'NEURAL IMPLANTS IN 12 INTEREST-FREE PAYMENTS AT ÔNIX CLINICS','TOQUE DE RECOLHER NA BAIXA NEON PRORROGADO POR TEMPO INDETERMINADO':'BAIXA NEON CURFEW EXTENDED INDEFINITELY',\n"
     "  'RÁDIO PIRATA DA VILA FERRUGEM SEGUE NO AR · DENUNCIE':'VILA FERRUGEM PIRATE RADIO STILL ON THE AIR · REPORT IT','COTAÇÃO: ÔNIX EM ALTA · HÉLICE EM QUEDA':'MARKETS: ÔNIX UP · HÉLICE DOWN',\n"
     "  'NOVA AURORA MERECE ORDEM':'NOVA AURORA DESERVES ORDER','SEU DISTRITO ESTÁ SOB PROTEÇÃO? CONSULTE O CONTROLE':'IS YOUR DISTRICT PROTECTED? ASK CONTROL',\n"
     "  'ALVO':'TARGET','RESGATE':'RESCUE','SABOTAGEM':'SABOTAGE','CÉLULA':'CELL','ALVO ×3':'TARGET ×3','EXTRAÇÃO':'EXTRACTION',\n"
     "  'Diretor de logística do Consórcio':'Consortium head of logistics','Pesquisadora de neuroimplantes':'Neuro-implant researcher','Rede de vigilância':'Surveillance network','Três terminais protegidos':'Three guarded terminals',\n"
     "  'Cinco agentes disfarçados':'Five disguised agents','Clube Cobalto · Baixa Neon':'Clube Cobalto · Baixa Neon','Fundição Hélice':'Hélice Foundry','Três reatores':'Three reactors',\n"
     "  'Diretor financeiro do Consórcio':'Consortium finance director','Engenheiro de firmware de drones':'Drone firmware engineer','Seis agentes, dois pesados':'Six agents, two heavies','Píeres do Cais Aéreo':'Cais Aéreo piers',\n"
     "  'Senador da República':'Senator of the Republic','Líder dos Ponteiros':'Leader of the Pointers',\n"),
])
