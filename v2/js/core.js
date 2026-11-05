/* Núcleo: constantes, utilidades, dados do jogo e estado compartilhado (live bindings). */
export const TAU=Math.PI*2,P=11,NB=5,N=NB*P+2,FLOOR=.5;
export const T_ROAD=0,T_WALK=1,T_BLD=2,T_GRASS=3,T_PLAZA=4,T_TREE=5,T_WATER=6,T_FENCE=7,T_POST=8,T_GLASS=9;
export const DX8=[1,-1,0,0,1,1,-1,-1],DY8=[0,0,1,-1,1,-1,1,-1];
export const clamp=(v,a,b)=>v<a?a:v>b?b:v;
export const fmt=v=>'$'+Math.round(v).toLocaleString('pt-BR');
export const REDUCED=matchMedia('(prefers-reduced-motion: reduce)').matches;
export function RNG(seed){let s=(Math.imul(seed|0,2654435761)>>>0)||1;return()=>{s^=s<<13;s>>>=0;s^=s>>>17;s^=s<<5;s>>>=0;return s/4294967296;};}
export function gauss(){return (Math.random()+Math.random()+Math.random()-1.5)*1.15;}
export function shade(hex,f){const n=parseInt(hex.slice(1),16);let r=n>>16,g=n>>8&255,b=n&255;const k=f<0?0:255,t=Math.abs(f);r=Math.round(r+(k-r)*t);g=Math.round(g+(k-g)*t);b=Math.round(b+(k-b)*t);return '#'+((1<<24)|(r<<16)|(g<<8)|b).toString(16).slice(1);}
export const pick=(a,r=Math.random)=>a[(r()*a.length)|0];

/* estado compartilhado */
export let M=null,G=null,state='title';
export const setM=m=>{M=m;},setG=g=>{G=g;},setState=s=>{state=s;};
export const flags={hud:true};
export const hooks={log(){},end(){},decal(){},convert(){},vo(){},destroy(){}};
export const settings={q:1,ao:false,pix:2,bloom:true,shadows:true,mus:.6,sfx:1,vo:1,tips:true,seen:[]};
try{Object.assign(settings,JSON.parse(localStorage.getItem('onix-gfx')||'{}'));}catch(e){}
if(!(settings.q>0))settings.q=1;
export function saveSettings(){try{localStorage.setItem('onix-gfx',JSON.stringify(settings));}catch(e){}}

/* armas e equipamentos */
export const WD={
  pistola:{nome:'Pistola Vespa',ab:'VESPA',arma:1,dano:15,alcance:6,cad:.42,pente:12,recarga:1.1,disp:.05,preco:600,som:'pist',req:0,len:.16,desc:'Semiautomática leve. Discreta e precisa.'},
  smg:{nome:'Submetralhadora Enxame',ab:'ENXAME',arma:1,dano:8,alcance:6.5,cad:.085,pente:36,recarga:1.6,disp:.11,preco:2800,som:'smg',req:0,len:.26,desc:'Cadência alta, boa contra grupos.'},
  escopeta:{nome:'Escopeta Trovão',ab:'TROVÃO',arma:1,dano:10,pellets:6,alcance:4.5,cad:.8,pente:8,recarga:2,disp:.2,preco:4200,som:'shot',res:'escopeta',len:.34,desc:'Seis projéteis por disparo. Devastadora de perto.'},
  chamas:{nome:'Lança-chamas Brasa',ab:'BRASA',arma:1,flame:1,dano:2.4,alcance:3.2,cad:.05,pente:160,recarga:2.6,preco:6500,som:'flame',res:'chamas',len:.34,desc:'Cone de fogo contínuo. Incendeia pessoas e veículos.'},
  feixe:{nome:'Rifle de Feixe Agulha',ab:'AGULHA',arma:1,laser:1,dano:75,alcance:11,cad:1.5,pente:6,recarga:2.2,preco:12500,som:'laser',res:'feixe',len:.42,desc:'Feixe que atravessa todos os alvos em linha.'},
  serra:{nome:'Minigun Serra',ab:'SERRA',arma:1,dano:10,alcance:7.5,cad:.045,pente:220,recarga:3.4,disp:.13,peso:1,preco:17000,som:'smg',res:'serra',len:.4,desc:'Muro de chumbo. Deixa o agente mais lento.'},
  granada:{nome:'Granada PEM',ab:'GRANADA',throw:1,dano:85,raio:2.3,alcance:7,preco:700,req:0,desc:'Arremessável. Explode em área e detona veículos.'},
  medkit:{nome:'Kit Médico',ab:'MEDKIT',heal:1,preco:450,req:0,desc:'Restaura toda a integridade de um agente.'},
  incendiaria:{nome:'Granada incendiária',ab:'INCEND.',throw:1,incend:1,dano:35,raio:1.4,alcance:7,preco:900,res:'incend',desc:'Explosão menor, mas cobre a área de fogo por vários segundos.'},
  manto:{nome:'Manto óptico',ab:'MANTO',manto:1,preco:3200,res:'manto',desc:'Equipado, deixa o agente invisível por até 25 s por missão. Com o manto ativo não dá para atirar.'},
  chave:{nome:'Chave Fantasma',ab:'CHAVE',hack:1,alcance:3,preco:2600,res:'chave',desc:'Invade torretas do Consórcio e as vira contra ele.'},
  sonda:{nome:'Sonda Neural',ab:'SONDA',sonda:1,alcance:2.6,preco:1800,req:0,desc:'Sequestra a mente de quem estiver por perto. Quanto mais seguidores, mais forte a sonda.'},
};
export const SHOP=['pistola','smg','escopeta','chamas','feixe','serra','granada','incendiaria','medkit','chave','sonda','manto'];
export const equipable=t=>{const w=WD[t];return !!(w.arma||w.throw||w.hack||w.sonda||w.manto);};

/* pesquisa e desenvolvimento */
export const RESEARCH=[
  {id:'escopeta',cat:'Armas',nome:'Escopeta Trovão',custo:40,desc:'Libera a Escopeta Trovão no arsenal.'},
  {id:'pentes',cat:'Armas',nome:'Pentes estendidos',custo:60,desc:'+50% de munição por pente em todas as armas do esquadrão.'},
  {id:'perfurante',cat:'Armas',nome:'Munição perfurante',custo:70,req:['escopeta'],desc:'Os disparos do esquadrão ignoram metade da blindagem inimiga.'},
  {id:'chamas',cat:'Armas',nome:'Lança-chamas Brasa',custo:80,req:['escopeta'],desc:'Libera o lança-chamas.'},
  {id:'incend',cat:'Armas',nome:'Granada incendiária',custo:90,req:['chamas'],desc:'Libera a granada que espalha fogo pela área.'},
  {id:'feixe',cat:'Armas',nome:'Rifle de feixe Agulha',custo:150,req:['perfurante'],desc:'Libera o rifle de feixe, que atravessa alvos em linha.'},
  {id:'serra',cat:'Armas',nome:'Minigun Serra',custo:200,req:['feixe','pentes'],desc:'Libera a minigun.'},
  {id:'impl2',cat:'Cibernética',nome:'Implantes Mk II',custo:90,desc:'Permite instalar implantes de nível 2.'},
  {id:'reparo',cat:'Cibernética',nome:'Reparo subdérmico',custo:100,desc:'Agentes regeneram integridade depois de 5 s sem serem atingidos.'},
  {id:'blindagem',cat:'Cibernética',nome:'Blindagem reativa',custo:130,req:['impl2'],desc:'+10% de blindagem em todos os agentes.'},
  {id:'impl3',cat:'Cibernética',nome:'Implantes Mk III',custo:220,req:['impl2'],desc:'Permite instalar implantes de nível 3.'},
  {id:'sonda2',cat:'Neural',nome:'Sonda amplificada',custo:70,desc:'Alcance da sonda +1 e força +30%.'},
  {id:'estab',cat:'Neural',nome:'Estabilizador neural',custo:80,desc:'A sobrecarga drena 30% menos e gera metade da dependência.'},
  {id:'armados',cat:'Neural',nome:'Seguidores armados',custo:90,req:['sonda2'],desc:'Civis recrutados pela sonda já vêm com uma pistola.'},
  {id:'limpa',cat:'Neural',nome:'Sobrecarga limpa',custo:170,req:['estab'],desc:'O colapso dura metade e a sobrecarga não gera dependência.'},
  {id:'sonda3',cat:'Neural',nome:'Sonda de massa',custo:180,req:['sonda2'],desc:'Força da sonda +60%. Até agentes do Consórcio cedem rápido.'},
  {id:'chave',cat:'Equipamento',nome:'Chave Fantasma',custo:50,desc:'Libera a ferramenta que invade torretas.'},
  {id:'nanomed',cat:'Equipamento',nome:'Nanomedkit',custo:60,desc:'O kit médico cura todos os agentes num raio de 2,5.'},
  {id:'manto',cat:'Equipamento',nome:'Manto óptico',custo:160,req:['chave'],desc:'Libera o manto: invisibilidade por 25 s por missão.'},
  {id:'informantes',cat:'Operações',nome:'Rede de informantes',custo:80,desc:'+20% de recompensa nas missões.'},
  {id:'trafego',cat:'Operações',nome:'Hackers de tráfego',custo:90,desc:'Reforços policiais demoram mais e a polícia desiste mais rápido.'},
  {id:'lavagem',cat:'Operações',nome:'Lavagem de dinheiro',custo:120,req:['informantes'],desc:'+25% na renda dos distritos.'},
  {id:'propaganda',cat:'Operações',nome:'Propaganda',custo:100,desc:'+5 de lealdade por dia em todos os distritos da Ônix.'},
];
export const RES_CATS=['Armas','Cibernética','Neural','Equipamento','Operações'];
export const CIENT_PRECO=2500,CIENT_SAL=150,PD_POR_CIENT=10,MAX_CIENT=20;
export const has=id=>!!(G&&G.pesq&&G.pesq.done[id]);
export const penteOf=(u,wk)=>Math.round(WD[wk].pente*(u&&u.kind==='agente'&&has('pentes')?1.5:1));
export const IMP={chassi:{nome:'Chassi blindado',desc:'+45 de integridade e 7% de blindagem por nível'},motor:{nome:'Servomotores',desc:'+12% de velocidade por nível'},otica:{nome:'Ótica tática',desc:'Mais precisão e alcance de disparo'},cortex:{nome:'Córtex estabilizado',desc:'Os mostradores neurais drenam menos estabilidade'}};
export const IMP_PRECO=[3500,7000,12000];
export const RECRUTA=4000,MAXINV=6,CLINICA=1200,VERBA=1500;
export const PRESETS=[{n:'CONTIDO',r:.25,p:.45,c:.85},{n:'PADRÃO',r:.5,p:.5,c:.5},{n:'SOBRECARGA',r:.95,p:.95,c:.55}];
export const CODINOMES=['Corvo','Lince','Víbora','Mantis','Falcão','Garça','Cobalto','Sombra','Neblina','Ferrão','Quartzo','Rapina','Brisa','Faísca','Âmbar','Tétis'];
export const VIPS=['Diretor Halvard Reis','Executiva Mirela Kroft','Vice-presidente Otto Sá','Diretora Ines Vahl','Conselheiro Rui Takeda'];
export const CIENT=['Dra. Lia Moraes','Dr. Kenji Albuquerque','Dra. Sofia Tanaka','Dr. Bento Okafor'];
export const TIPOS={assassinato:'Assassinato',extracao:'Extração',sabotagem:'Sabotagem',eliminacao:'Eliminação'};
export const SIGNS=['FARMÁCIA 24H','NEURO+','HOTEL','CAFÉ','BAR','IMPLANTES','LOTERIA','KARAOKÊ','RAMEN','PENHORES','CLÍNICA','ACADEMIA','CYBER','MOTEL','SUSHI','AÇAÍ','PASTEL','BOTECO'];
export const DIST=[
  {nome:'Docas Velhas',renda:1500,dif:1,tipo:'assassinato',riq:.2,mission:'docas',
   brief:'Halvard Reis, diretor de logística do Consórcio, vem às Docas Velhas fechar um acordo com um contrabandista. Ele chega em comboio e passa sob o guindaste 2. Se a cabine do guindaste for invadida, o contêiner pendurado resolve o problema sem disparar um tiro. Mate Reis antes que ele volte ao carro ou fuja de lancha e retorne à van. Há um buraco na cerca a oeste.',
   short:'Missão roteirizada: emboscada ao comboio de Halvard Reis no porto.',poly:[[40,420],[250,400],[280,580],[40,590]]},
  {nome:'Vila Ferrugem',renda:1800,dif:2,tipo:'extracao',riq:.25,mission:'favela',
   brief:'O Consórcio montou uma clínica clandestina no alto da Vila Ferrugem. A Dra. Sofia Tanaka, pesquisadora de neuroimplantes, está presa lá dentro. Suba o morro, tire a doutora da clínica e leve-a à van na estrada sul ou à estação do teleférico a leste. O gerador da clínica alimenta as torretas. A polícia não sobe o morro, mas os moradores vão lembrar de quem atirar neles.',
   short:'Missão roteirizada: resgate na favela, com duas rotas de fuga.',poly:[[40,240],[230,220],[250,400],[40,420]]},
  {nome:'Mercado Suspenso',renda:2600,dif:2,tipo:'sabotagem',riq:.4,mission:'mercado',
   brief:'O Mercado Suspenso funciona debaixo do monotrilho e o Consórcio vigia cada banca com câmeras. Três terminais mantêm a rede de vigilância do distrito. O terminal da Central de Vigilância, ao norte, desliga todas as câmeras. As câmeras só reparam em armas à mostra. O trem passa a cada 40 segundos e o barulho dele cobre tiros. Depois de derrubar a rede, volte ao ponto de inserção.',
   short:'Missão roteirizada: sabotagem sob o monotrilho, com câmeras de segurança.',poly:[[250,400],[470,380],[500,580],[280,580]]},
  {nome:'Baixa Neon',renda:3000,dif:3,tipo:'eliminacao',riq:.5,mission:'neon',
   brief:'Uma célula de cinco agentes do Consórcio está escondida no Clube Cobalto e nas calçadas da avenida, vestida como gente comum. Chegue perto: o scanner de implantes do esquadrão revela quem é quem. Atirar no civil errado custa caro. Há um carro de fuga no beco atrás do clube: se algum agente chegar até ele, a missão falha.',
   short:'Missão roteirizada: caça a agentes disfarçados numa casa noturna.',poly:[[230,220],[450,200],[470,380],[250,400]]},
  {nome:'Setor Industrial 9',renda:2400,dif:4,tipo:'sabotagem',riq:.3,mission:'fundicao',
   brief:'A Fundição Hélice do Setor Industrial 9 abastece metade das fábricas do Consórcio. Instale cargas nos três reatores da planta. Depois da terceira carga, vocês têm 45 segundos para voltar ao portão antes da reação em cadeia. As saídas de vapor da tubulação disparam em ciclos e queimam quem estiver perto, aliado ou inimigo. Drones de segurança patrulham o pátio: a Chave Fantasma consegue invadi-los. O Ferro-Velho guarda o reator central.',
   short:'Missão roteirizada: sabotagem numa fundição com vapor, drones e contagem regressiva.',poly:[[40,40],[260,40],[230,220],[40,240]]},
  {nome:'Distrito Lúmen',renda:3600,dif:5,tipo:'assassinato',riq:.7,mission:'lumen',
   brief:'Otávio Brandt, diretor financeiro do Consórcio, dá uma festa no pavilhão de vidro da Praça Lúmen. Ele sabe que é alvo: dois sósias idênticos circulam com ele. De perto, o scanner de implantes do esquadrão distingue o verdadeiro. O terminal da guarita de segurança revela os três de uma vez. Atirar em qualquer um dispara o alarme, e o alvo corre para o helicóptero no heliporto. As paredes do pavilhão são de vidro e não seguram balas.',
   short:'Missão roteirizada: assassinato numa festa, com sósias e helicóptero de fuga.',poly:[[260,40],[480,40],[450,200],[230,220]]},
  {nome:'Colinas de Vidro',renda:4200,dif:5,tipo:'extracao',riq:.8,mission:'retiro',
   brief:'O Dr. Caio Ventura escreveu o firmware dos drones do Consórcio e quer mudar de lado. O Hélice o mantém no Retiro, uma mansão murada no alto das Colinas de Vidro, trabalhando numa estufa de vidro. Feixes de alarme cortam o jardim; alguns piscam em ciclos. O gerador fora do muro, a sudoeste, apaga feixes, câmeras e luzes. Leve o doutor até a zona de pouso no topo do morro, a noroeste, e segure a posição até o VTOL pousar.',
   short:'Missão roteirizada: extração com feixes de alarme e defesa da zona de pouso.',poly:[[470,380],[720,360],[740,580],[500,580]]},
  {nome:'Cais Aéreo',renda:3800,dif:6,tipo:'eliminacao',riq:.6,mission:'doca',
   brief:'Uma célula de seis agentes do Consórcio, dois deles com armadura pesada, está carregando um dirigível no Cais Aéreo. O dirigível parte em quatro minutos. No último minuto, a célula corre para a prancha de embarque: se algum agente embarcar, a missão falha. O terminal das amarras, na ponta do píer central, prende o dirigível no cais. Torretas automáticas vigiam os píeres.',
   short:'Missão roteirizada: eliminação contra o relógio, com soldados pesados.',poly:[[450,200],[700,180],[720,360],[470,380]]},
  {nome:'Jardins Altos',renda:5000,dif:7,tipo:'assassinato',riq:.9,mission:'jardins',
   brief:'O senador Augusto Calvino vende ao Consórcio os contratos de segurança da cidade inteira. Toda noite ele caminha pelo labirinto de sebes da própria mansão, com dois guarda-costas. As sebes escondem o esquadrão; os holofotes das torres, não: eles enxergam qualquer um, armado ou não, e podem ser derrubados a tiros. Ao primeiro alarme, Calvino corre para o bunker a nordeste. Se ele entrar, a porta blindada se fecha e um túnel de fuga começa a ser preparado: sobrecarreguem os dois relés do lado de fora para arrombar a porta antes que ele suma.',
   short:'Missão roteirizada: assassinato num labirinto de sebes, com holofotes e bunker.',poly:[[480,40],[730,40],[700,180],[450,200]]},
  {nome:'Torre Central',renda:8000,dif:9,tipo:'eliminacao',riq:1,hq:true,mission:'torre',
   brief:'O último bastião do Consórcio. A praça da Torre Central é um campo fortificado: torretas, drones e soldados pesados guardam o portão blindado. Invadam os dois terminais de segurança da praça para arrombar o portão. No átrio, o Juiz espera com os Ponteiros que restarem; dois pilares de escudo o protegem enquanto estiverem de pé. Quando ele cair, Ilse Varga vai mandar apagar os servidores do andar 90. Cheguem lá antes.',
   short:'Missão final roteirizada: assalto à torre, o Juiz e os servidores do Coral.',poly:[[730,40],[960,40],[960,330],[720,360],[700,180]]},
];
export const BAY=[[740,580],[720,360],[960,330],[960,600]];
DIST.forEach(d=>{d.recompensa=3000+d.dif*2000;});
export const ADJ=DIST.map((a,i)=>DIST.map((b,j)=>j).filter(j=>j!==i&&a.poly.filter(p=>DIST[j].poly.some(q=>q[0]===p[0]&&q[1]===p[1])).length>=2));

/* aparência */
export const BPAL=[['#4a5468','#2a3142','#353d50'],['#3d5c63','#1f343a','#28434a'],['#55496c','#2e263f','#3a3050'],['#5c4f47','#332a25','#41362f'],['#2a3240','#121822','#1a2230'],['#6b5a3d','#3a2f1f','#4a3b27'],
  ['#7a5a64','#b8607a','#c97a90'],['#4a6a6a','#3f8a86','#52a09a'],['#7a6a4a','#c9a040','#d8b45a'],['#5a5a7a','#7a6aa8','#8e80bc'],['#5a4038','#8a4a38','#9a5a46']];
export const NEON=['#ff3d8b','#38e8ff','#ffb13d','#a66bff'];
export const WINLIT=['#ffcf7a','#ffd99a','#9fe8ff','#ff8ad8','#f6f0c8'];
export const SKIN=['#e0b48c','#c48a62','#8d5a3b','#f0cfae','#6b4029','#b07850'];
export const HAIR=['#1a1410','#3a2416','#6b4a2a','#c9c0b0','#0d0d10','#7a2a2a'];
export const KIND={
  agente:{fac:'player',hp:120,spd:2.4},
  civil:{fac:'civ',hp:30,spd:1.1},
  policia:{fac:'police',hp:60,spd:1.5,w:'pistola',acc:.5},
  guarda:{fac:'corp',hp:70,spd:1.7,w:'pistola',acc:.5},
  inimigo:{fac:'corp',hp:140,spd:2.2,w:'smg',acc:.65,armor:.2},
  vip:{fac:'corp',hp:55,spd:1.5},
  cientista:{fac:'neutral',hp:110,spd:2.2,armor:.25},
  torre:{fac:'corp',hp:160,spd:0,w:'smg',acc:.6,armor:.3},
  drone:{fac:'corp',hp:60,spd:2.8,w:'smg',acc:.5,armor:.15},
};
/* resistência ao sequestro neural (segundos com 1 de força) */
export const RESIST={civil:1.2,policia:3,guarda:5,inimigo:10};
