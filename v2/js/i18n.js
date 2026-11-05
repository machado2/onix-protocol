/* Idioma: traduz o texto no ponto em que ele chega à tela (DOM e canvas), a partir do dicionário de en.js.
   Trocar de idioma salva a preferência e recarrega a página. */
import {settings,saveSettings} from './core.js';
import {EN,RULES} from './en.js';

export const LANG=settings.lang==='en'?'en':'pt';
const R=RULES.slice().sort((a,b)=>b[0].source.length-a[0].source.length);
const cache=new Map();
export function tr(s){
  if(LANG!=='en'||typeof s!=='string'||!s)return s;
  let r=cache.get(s);if(r!==undefined)return r;
  r=conv(s);if(cache.size>5000)cache.clear();cache.set(s,r);
  if(r===s&&/[ãõçáéíóúâêôà]|\b(de|do|da|em|para|com|não)\b/i.test(s))(window.__miss||(window.__miss=new Set())).add(s);
  return r;
}
function conv(s){
  if(EN[s]!==undefined)return EN[s];
  const m=s.match(/^(\s*[✓✗◆○▼·•]*\s*)([\s\S]*?)(\s*)$/);
  const pre=m[1],core=m[2],post=m[3];
  if(!core)return s;
  if(EN[core]!==undefined)return pre+EN[core]+post;
  for(const [re,f] of R){const g=core.match(re);if(g)return pre+f(g,tr)+post;}
  return s;
}
export function setLang(l){settings.lang=l;saveSettings();location.reload();}

const ATTR=['title','aria-label','placeholder'];
const seen=new WeakMap();
function trNode(n){
  if(n.nodeType===3){
    const v=n.nodeValue;if(!v||seen.get(n)===v||!/[A-Za-zÀ-ú$]/.test(v))return;
    const t=tr(v);seen.set(n,t);if(t!==v)n.nodeValue=t;
  }else if(n.nodeType===1){
    if(n.tagName==='SCRIPT'||n.tagName==='STYLE')return;
    for(const a of ATTR){const v=n.getAttribute(a);if(v){const t=tr(v);if(t!==v)n.setAttribute(a,t);}}
    for(const c of n.childNodes)trNode(c);
  }
}
if(LANG==='en'){
  document.documentElement.lang='en';
  const go=()=>{
    trNode(document.body);
    new MutationObserver(ms=>{for(const m of ms){if(m.type==='characterData')trNode(m.target);else for(const n of m.addedNodes)trNode(n);}})
      .observe(document.body,{childList:true,subtree:true,characterData:true});
  };
  if(document.body)go();else addEventListener('DOMContentLoaded',go);
  const P=CanvasRenderingContext2D.prototype;
  for(const k of ['fillText','strokeText','measureText']){const f=P[k];P[k]=function(t,...a){return f.call(this,tr(t),...a);};}
}
