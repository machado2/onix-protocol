/* Identidade visual: a interface é o sistema operacional tático da Ônix (ÔNIX-OS).
   Logo, retratos vetoriais, sequência de boot entre telas, decoração do mapa, letreiro de propaganda e dossiês. */
import {RNG,shade,SKIN,HAIR} from './core.js';

export const GEM=`<svg class="gem" viewBox="0 0 40 46" aria-hidden="true"><path d="M20 1 38 12v22L20 45 2 34V12Z" fill="#0b0d14" stroke="#ffa53d" stroke-width="2"/><path d="M20 1v44M2 12l18 11 18-11M20 23v22" fill="none" stroke="#ffa53d" stroke-width="1" opacity=".55"/><path d="M20 23 38 12v22L20 45Z" fill="#ffa53d" opacity=".14"/></svg>`;
export const HELIX=`<path d="M-6-9c12 6 0 12 12 18M6-9c-12 6 0 12-12 18" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M-4-4h8M-4 4h8" stroke="currentColor" stroke-width="1"/>`;

/* ---------- retratos (ilustração vetorial) ---------- */
const cache=new Map();
const HAIRS=[
  'M38 60C37 36 49 29 60 29C72 29 84 35 82 60C80 47 72 42 60 42C48 42 40 47 38 60Z',
  'M37 62C34 37 48 27 61 28C76 29 88 40 83 64L87 100C80 95 78 82 79 66C76 49 70 44 60 44C50 44 44 50 41 66C42 82 40 95 33 100Z',
  'M40 55C40 38 50 33 60 33C72 33 81 40 80 55C76 45 70 41 60 41C50 41 44 46 40 55Z',
  'M53 21C55 13 65 13 67 21L69 45C65 40 55 40 51 45ZM39 58C39 45 44 40 50 39L49 45C44 47 41 52 39 58ZM81 58C81 45 76 40 70 39L71 45C76 47 79 52 81 58Z',
];
export function portrait(o){
  const key=JSON.stringify(o);let url=cache.get(key);if(url)return url;
  const r=RNG(o.seed*97+13),id='p'+((o.seed*131+7)%100000);
  const skin=o.skin||SKIN[(o.seed*7)%SKIN.length],hair=o.gray?'#b8b4ac':(o.hair||HAIR[(o.seed*3)%HAIR.length]),coat=o.coat||'#1b1f2a',trim=o.trim||'#4fd8ff';
  const style=o.style??(o.fem?(r()<.6?1:0):((r()*5)|0)%4);
  let s=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 140"><defs>
<linearGradient id="${id}b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${o.bg||'#16233d'}"/><stop offset="1" stop-color="#05070c"/></linearGradient>
<radialGradient id="${id}r" cx=".5" cy=".42" r=".55"><stop offset="0" stop-color="${trim}" stop-opacity=".28"/><stop offset="1" stop-color="${trim}" stop-opacity="0"/></radialGradient>
<radialGradient id="${id}s" cx=".38" cy=".34" r=".8"><stop offset="0" stop-color="${shade(skin,.18)}"/><stop offset=".55" stop-color="${skin}"/><stop offset="1" stop-color="${shade(skin,-.32)}"/></radialGradient>
<linearGradient id="${id}c" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${shade(coat,.25)}"/><stop offset=".6" stop-color="${coat}"/><stop offset="1" stop-color="${shade(coat,-.4)}"/></linearGradient>
<linearGradient id="${id}h" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${shade(hair,.25)}"/><stop offset="1" stop-color="${shade(hair,-.25)}"/></linearGradient>
<filter id="${id}g" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2"/></filter></defs>
<rect width="120" height="140" fill="url(#${id}b)"/><rect width="120" height="140" fill="url(#${id}r)"/>
<path d="M0 104H120M0 120H120M30 0V140M90 0V140" stroke="#ffffff" stroke-opacity=".04"/>`;
  if(o.unknown){
    s+=`<ellipse cx="60" cy="62" rx="21" ry="26" fill="#1a2236"/><path d="M8 140C12 112 34 101 60 99C86 101 108 112 112 140Z" fill="#1a2236"/><text x="60" y="76" text-anchor="middle" font-family="Chakra Petch,sans-serif" font-weight="700" font-size="40" fill="#ffa53d">?</text></svg>`;
    url='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(s);cache.set(key,url);return url;
  }
  // ombros e roupa
  s+=`<path d="M8 140C12 112 34 101 60 99C86 101 108 112 112 140Z" fill="url(#${id}c)"/>`;
  if(o.kind==='sci')s+=`<path d="M8 140C12 112 34 101 50 99L58 140Z" fill="#e6edf4"/><path d="M112 140C108 112 86 101 70 99L62 140Z" fill="#cfd8e2"/>`;
  if(o.kind==='vip')s+=`<path d="M48 100L60 128L72 100Z" fill="#ece8e0"/><path d="M57 104L63 104L64 130L60 136L56 130Z" fill="${trim}"/><path d="M48 100L60 128L42 106ZM72 100L60 128L78 106Z" fill="${shade(coat,-.25)}"/>`;
  else if(o.kind!=='sci')s+=`<path d="M44 102L60 116L76 102" fill="none" stroke="${trim}" stroke-width="3" stroke-linecap="round"/><path d="M24 118L34 112M96 118L86 112" stroke="${trim}" stroke-opacity=".6" stroke-width="2"/>`;
  // pescoço, orelhas e cabeça
  s+=`<rect x="50" y="80" width="20" height="24" rx="7" fill="${shade(skin,-.22)}"/>
<ellipse cx="38.5" cy="63" rx="3.5" ry="6" fill="${shade(skin,-.15)}"/><ellipse cx="81.5" cy="63" rx="3.5" ry="6" fill="${shade(skin,-.25)}"/>
<ellipse cx="60" cy="62" rx="21" ry="26" fill="url(#${id}s)"/>`;
  if(style===1)s+=`<path d="${HAIRS[1]}" fill="url(#${id}h)"/>`;
  else if(HAIRS[style])s+=`<path d="${HAIRS[style]}" fill="url(#${id}h)"/>`;
  // rosto
  if(o.visor){const v=o.visorCol||trim;s+=`<rect x="37" y="53" width="46" height="12" rx="6" fill="#05070c"/><rect x="40" y="56.5" width="40" height="5" rx="2.5" fill="${v}" filter="url(#${id}g)"/><rect x="40" y="57.5" width="40" height="3" rx="1.5" fill="${v}"/><rect x="44" y="57.8" width="9" height="1.4" rx=".7" fill="#ffffff" opacity=".85"/>`;}
  else{const ec='#15171d';s+=`<path d="M45 53Q51 50 56 53M64 53Q69 50 75 53" fill="none" stroke="${shade(hair,-.1)}" stroke-width="2.2" stroke-linecap="round"/><ellipse cx="51" cy="60" rx="3" ry="2.2" fill="${ec}"/><ellipse cx="69" cy="60" rx="3" ry="2.2" fill="${ec}"/><circle cx="52" cy="59.3" r=".8" fill="#fff" opacity=".7"/><circle cx="70" cy="59.3" r=".8" fill="#fff" opacity=".7"/>`;}
  if(o.kind==='sci')s+=`<rect x="44" y="55" width="13" height="10" rx="3" fill="none" stroke="#c8ccd4" stroke-width="1.6"/><rect x="63" y="55" width="13" height="10" rx="3" fill="none" stroke="#c8ccd4" stroke-width="1.6"/><path d="M57 59H63" stroke="#c8ccd4" stroke-width="1.6"/>`;
  s+=`<path d="M60 62Q58 70 61 72" fill="none" stroke="${shade(skin,-.3)}" stroke-width="1.6" stroke-linecap="round"/>`;
  if(!o.mask)s+=`<path d="M53 78Q60 81 67 78" fill="none" stroke="${shade(skin,-.4)}" stroke-width="2" stroke-linecap="round"/>`;
  if(o.implant)s+=`<circle cx="80" cy="54" r="2.4" fill="#4fd8ff"/><circle cx="80" cy="54" r="4.5" fill="#4fd8ff" opacity=".35" filter="url(#${id}g)"/><path d="M80 57V68" stroke="#4fd8ff" stroke-opacity=".6" stroke-width="1.2"/>`;
  if(o.scar)s+=`<path d="M66 62L73 75" stroke="#7a2228" stroke-width="2" stroke-linecap="round"/><path d="M67 66L71 65M69 70L73 69" stroke="#7a2228" stroke-width="1.2"/>`;
  if(o.mask)s+=`<path d="M39 66C43 92 77 92 81 66Z" fill="#0c0c10"/><path d="M45 75H75" stroke="${trim}" stroke-width="2.2" stroke-linecap="round"/><path d="M45 75H75" stroke="${trim}" stroke-width="5" opacity=".35" filter="url(#${id}g)"/>`;
  s+='</svg>';
  url='data:image/svg+xml;charset=utf-8,'+encodeURIComponent(s);cache.set(key,url);return url;
}
export const agentPortrait=a=>portrait({seed:a.id,fem:a.voz==='f',visor:true,implant:true,coat:'#1b1f2a',trim:'#4fd8ff',style:a.voz==='f'?((a.id%3===0)?2:1):[0,2,3][a.id%3]});
export function rivalPortrait(R){
  const map={navalha:{scar:true,style:3},sibila:{visor:true,visorCol:'#b07cff',fem:true,style:1},ferro:{mask:true,style:2},mariposa:{fem:true,style:1,implant:true},juiz:{mask:true,style:2,gray:true}};
  return portrait(Object.assign({seed:R.id.length*17+R.hp,coat:R.coat,trim:R.trim,bg:'#1a0c12'},map[R.id]||{}));
}
/* alvos dos briefings: retrato + função (texto traduzível) */
export const DOSSIER={
  docas:{role:'ALVO',nome:'Halvard Reis',sub:'Diretor de logística do Consórcio',p:{seed:11,kind:'vip',gray:true,style:2,coat:'#d6cfbc',trim:'#8a1a22'}},
  favela:{role:'RESGATE',nome:'Dra. Sofia Tanaka',sub:'Pesquisadora de neuroimplantes',p:{seed:21,kind:'sci',fem:true,style:1,hair:'#1a1410',skin:'#f0cfae'}},
  mercado:{role:'SABOTAGEM',nome:'Rede de vigilância',sub:'Três terminais protegidos',icon:'net'},
  neon:{role:'CÉLULA',nome:'Cinco agentes disfarçados',sub:'Clube Cobalto · Baixa Neon',cell:5},
  fundicao:{role:'SABOTAGEM',nome:'Fundição Hélice',sub:'Três reatores',icon:'plant'},
  lumen:{role:'ALVO ×3',nome:'Otávio Brandt',sub:'Diretor financeiro do Consórcio',p:{seed:31,kind:'vip',style:0,hair:'#c9c0b0',coat:'#1c1c22',trim:'#ffd36b'},triple:true},
  retiro:{role:'EXTRAÇÃO',nome:'Dr. Caio Ventura',sub:'Engenheiro de firmware de drones',p:{seed:41,kind:'sci',style:0,hair:'#3a2416',skin:'#c48a62'}},
  doca:{role:'CÉLULA',nome:'Seis agentes, dois pesados',sub:'Píeres do Cais Aéreo',cell:6},
  jardins:{role:'ALVO',nome:'Senador Augusto Calvino',sub:'Senador da República',p:{seed:51,kind:'vip',style:2,gray:true,coat:'#2a2e3a',trim:'#ffd36b',skin:'#e0b48c'}},
  torre:{role:'ALVO',nome:'O Juiz',sub:'Líder dos Ponteiros',p:{seed:61,mask:true,style:2,gray:true,coat:'#0c0c10',trim:'#ffd36b',bg:'#1a0c12'}},
};
function iconUrl(kind){
  const body=kind==='plant'
    ?'<path d="M18 112V70l22 12V70l22 12V48h14v40l26 14v10Z" fill="none" stroke="#ffa53d" stroke-width="3" stroke-linejoin="round"/><path d="M69 48V30h7v18" fill="none" stroke="#ffa53d" stroke-width="3"/><path d="M72 22c-6-4 0-8-4-12" fill="none" stroke="#ffa53d" stroke-opacity=".5" stroke-width="2"/>'
    :'<circle cx="60" cy="70" r="30" fill="none" stroke="#ffa53d" stroke-width="3"/><circle cx="60" cy="70" r="16" fill="none" stroke="#ffa53d" stroke-opacity=".6" stroke-width="2"/><circle cx="60" cy="70" r="5" fill="#ffa53d"/><path d="M60 70L84 52" stroke="#ffa53d" stroke-width="3" stroke-linecap="round"/><path d="M60 30V22M60 118v-8M20 70h-8M108 70h-8" stroke="#ffa53d" stroke-width="2"/>';
  return 'data:image/svg+xml;charset=utf-8,'+encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 140"><rect width="120" height="140" fill="#101a2c"/>${body}</svg>`);
}
export function dossierHtml(key){
  const d=DOSSIER[key];if(!d)return '';
  let pics='';
  if(d.p){const u=portrait(d.p);pics=d.triple?`<span class="trio"><img class="pf" src="${u}"><img class="pf" src="${u}"><img class="pf" src="${u}"></span>`:`<img class="pf big" src="${u}">`;}
  else if(d.cell){pics=`<span class="trio">${Array.from({length:3},(_,k)=>`<img class="pf" src="${portrait({seed:70+k,unknown:true})}">`).join('')}</span>`;}
  else pics=`<img class="pf big" src="${iconUrl(d.icon)}">`;
  return `<div class="dossier">${pics}<div class="dtx"><span class="role">${d.role}</span><b>${d.nome}</b><small>${d.sub}</small></div><span class="conf">CONFIDENCIAL</span></div>`;
}

/* ---------- boot entre telas ---------- */
const BOOT=[['ÔNIX-OS 2.91','AUTENTICANDO CONTROLE…','ACESSO CONCEDIDO'],['UPLINK DO ESQUADRÃO…','CRIPTOGRAFIA ATIVA','OK'],['SINCRONIZANDO REDE ÔNIX…','MAPA TÁTICO CARREGADO','OK']];
let bootEl=null,lastBoot=0;
export function bootFx(kind=0){
  const now=performance.now();if(now-lastBoot<2500)return;lastBoot=now;
  if(!bootEl){bootEl=document.createElement('div');bootEl.id='boot';document.body.appendChild(bootEl);}
  const L=BOOT[kind%BOOT.length];
  bootEl.innerHTML=`<div class="bt">${GEM}${L.map((t,i)=>`<p style="animation-delay:${i*110}ms">${t}</p>`).join('')}</div>`;
  bootEl.style.display='flex';bootEl.classList.remove('go');void bootEl.offsetWidth;bootEl.classList.add('go');
  clearTimeout(bootEl._t);bootEl._t=setTimeout(()=>{bootEl.style.display='none';},850);
}

/* ---------- mapa ---------- */
export function decorateMap(svg,DIST,owner,availFn){
  let s='<g class="ticks">';
  for(let x=0;x<=1000;x+=50)s+=`<line x1="${x}" y1="0" x2="${x}" y2="${x%250?6:14}"/><line x1="${x}" y1="620" x2="${x}" y2="${x%250?614:606}"/>${x%250===0?`<text x="${x+3}" y="24">${String(x/10).padStart(3,'0')}</text>`:''}`;
  for(let y=0;y<=620;y+=50)s+=`<line x1="0" y1="${y}" x2="${y%250?6:14}" y2="${y}"/><line x1="1000" y1="${y}" x2="${y%250?994:986}" y2="${y}"/>`;
  s+='</g><g class="radar"><path d="M500 310 L1100 310 A600 600 0 0 0 1019.6 10 Z" fill="url(#sweep)"/></g>';
  DIST.forEach((d,i)=>{
    const cx=d.poly.reduce((a,p)=>a+p[0],0)/d.poly.length,cy=d.poly.reduce((a,p)=>a+p[1],0)/d.poly.length;
    if(owner[i]==='player')s+=`<g class="mk own" transform="translate(${cx} ${cy-32}) scale(.42)"><path d="M0-22 18-11v22L0 23-18 11v-22Z"/><path class="f" d="M-18-11 0 0 18-11M0 0v23"/></g><text class="stampmap" x="${cx}" y="${cy+46}" transform="rotate(-7 ${cx} ${cy+46})">CONQUISTADO</text>`;
    else s+=`<g class="mk enemy${d.hq?' hq':''}${availFn(i)?' av':''}" transform="translate(${cx} ${cy-30})">${HELIX}</g>`;
  });
  const defs=svg.querySelector('defs');
  if(defs&&!defs.querySelector('#sweep'))defs.insertAdjacentHTML('beforeend','<linearGradient id="sweep" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ffa53d" stop-opacity=".09"/><stop offset="1" stop-color="#ffa53d" stop-opacity="0"/></linearGradient>');
  svg.insertAdjacentHTML('beforeend',s);
}
export const TICKER=['ÔNIX · SEGURANÇA QUE VOCÊ NÃO PRECISA PEDIR','LEMBRETE DO CONSELHO: LEALDADE É UM INVESTIMENTO','IMPLANTES NEURAIS EM 12X SEM JUROS NAS CLÍNICAS ÔNIX','TOQUE DE RECOLHER NA BAIXA NEON PRORROGADO POR TEMPO INDETERMINADO','RÁDIO PIRATA DA VILA FERRUGEM SEGUE NO AR · DENUNCIE','COTAÇÃO: ÔNIX EM ALTA · HÉLICE EM QUEDA','NOVA AURORA MERECE ORDEM','SEU DISTRITO ESTÁ SOB PROTEÇÃO? CONSULTE O CONTROLE'];
export function tickerHtml(){const t=TICKER.map(x=>`<span>${x}</span>`).join('<i>◆</i>');return `<div class="tk"><div class="tkin">${t}<i>◆</i>${t}<i>◆</i></div></div>`;}
