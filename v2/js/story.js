/* História: os Ponteiros (agentes de elite do Consórcio) e as mensagens interceptadas entre missões. */

export const RIVALS=[
  {id:'navalha',nome:'Navalha',w:'escopeta',hp:320,armor:.3,spd:2.7,acc:.78,coat:'#1d1410',trim:'#ff9a3c',desc:'Caçador de rua. Rápido e cruel de perto.'},
  {id:'sibila',nome:'Sibila',w:'feixe',hp:260,armor:.25,spd:2.2,acc:.9,coat:'#14121c',trim:'#b07cff',desc:'Atiradora de feixe. Ataca de longe.'},
  {id:'ferro',nome:'Ferro-Velho',w:'serra',hp:520,armor:.45,spd:1.7,acc:.7,coat:'#2a2a2e',trim:'#d8d8d8',desc:'Muralha de blindagem com uma minigun.'},
  {id:'mariposa',nome:'Mariposa',w:'chamas',hp:300,armor:.3,spd:2.5,acc:.8,coat:'#2a1210',trim:'#ff5a2a',desc:'Incendiária. Transforma ruas em fornalhas.'},
  {id:'juiz',nome:'O Juiz',w:'feixe',hp:620,armor:.45,spd:2.1,acc:.9,coat:'#0c0c10',trim:'#ffd36b',desc:'Líder dos Ponteiros. Só deixa a Torre Central no fim.',hqOnly:true},
];

/* mensagens interceptadas: de, para, assunto, corpo (parágrafos separados por \n) */
export const MSGS={
  inicio:{de:'Abel Rocha · Conselho da Ônix',para:'Controle',assunto:'Operação Maré',corpo:'Autorizada a Operação Maré. Nova Aurora está loteada há vinte anos e o Hélice ficou preguiçoso.\nQuero os distritos, não os prédios. Prédios se compram. Lealdade se cobra.\nO esquadrão responde a você. Você responde a mim.'},
  docas:{de:'Ilse Varga · Presidência do Consórcio Hélice',para:'Os Ponteiros',assunto:'Reis',corpo:'Halvard Reis morreu nas Docas Velhas. Não foi acidente, por mais que o laudo diga isso.\nAcordem os Ponteiros. Quero nomes, rostos e o endereço de quem paga essa gente.'},
  tres:{de:'Abel Rocha · Conselho da Ônix',para:'Controle',assunto:'Resultados',corpo:'Três distritos e os investidores sorriem. Mantenham os impostos firmes: medo rende mais que gratidão.\nE parem de chamar os moradores de "civis" nos relatórios. São receita.'},
  tanaka:{de:'Dra. Sofia Tanaka · notas pessoais',para:'(arquivo cifrado)',assunto:'Projeto Coral',corpo:'Eles chamaram de Coral porque cresce em colônias. A sonda neural não lê mentes: ela as reorganiza.\nOs primeiros testes foram feitos na Vila Ferrugem, com voluntários que não sabiam que eram voluntários.\nO Hélice abandonou o projeto. Alguém comprou os dados. A sonda que me tirou daquela clínica foi construída com eles.'},
  cinco:{de:'Ilse Varga · Presidência do Consórcio Hélice',para:'O Juiz',assunto:'Coral',corpo:'A Ônix usa a nossa própria tecnologia contra nós. Cada seguidor que eles recrutam na rua é um teste do Coral que nós engavetamos.\nNão subestime o que eles pretendem fazer com a rede da cidade inteira.'},
  revolta:{de:'Rádio pirata · Vila Ferrugem',para:'Todas as frequências',assunto:'Troca de dono',corpo:'Trocaram o dono do morro e chamaram isso de libertação. O imposto subiu, a luz continua cortando e agora quem patrulha usa casaco preto em vez de vermelho.\nDesliguem a TV. Liguem o rádio. A rua é nossa.'},
  sete:{de:'Abel Rocha · Conselho da Ônix',para:'Controle',assunto:'Depois da Torre',corpo:'Quando a Torre Central cair, os servidores do Hélice passam a ser nossos. Coral roda neles.\nUma atualização na rede da cidade e Nova Aurora inteira concorda com a gente. Sem impostos atrasados, sem revoltas, sem rádio pirata.\nVocê vai receber a ordem no momento certo.'},
  hq:{de:'Ilse Varga · Presidência do Consórcio Hélice',para:'Segurança da Torre',assunto:'Protocolo final',corpo:'Se a Torre cair, apaguem os servidores do andar 90. Todos. Coral não pode cair nas mãos da Ônix.\nNão importa o que aconteça comigo.'},
  navalha_visto:{de:'Navalha',para:'Ilse Varga',assunto:'Contato',corpo:'Vi os seus fantasmas de casaco preto. Quatro, às vezes cinco. Andam como gente que já morreu uma vez.\nDa próxima vez eu escolho a rua.'},
  navalha_morto:{de:'Ilse Varga',para:'Os Ponteiros',assunto:'Navalha',corpo:'Navalha não volta. Não mandem flores. Mandem o Ferro-Velho.'},
  sibila_visto:{de:'Sibila',para:'Ilse Varga',assunto:'Telemetria',corpo:'Tenho as assinaturas térmicas dos quatro. Um deles manca da perna esquerda; implante barato.\nA próxima vez que olharem pela janela, vou estar do outro lado.'},
  sibila_morto:{de:'Ilse Varga',para:'Os Ponteiros',assunto:'Sibila',corpo:'Perdemos a Sibila e o rifle dela. Se a Ônix estiver usando aquele rifle, quero saber.'},
  ferro_visto:{de:'Ferro-Velho',para:'Ilse Varga',assunto:'Relatório',corpo:'Eles atiram bem. Não o bastante.'},
  ferro_morto:{de:'Ilse Varga',para:'Os Ponteiros',assunto:'Ferro-Velho',corpo:'Ferro-Velho caiu. Eu achava que isso era fisicamente impossível.'},
  mariposa_visto:{de:'Mariposa',para:'Ilse Varga',assunto:'Fumaça',corpo:'Eles correm do fogo como todo mundo. Gostei disso.'},
  mariposa_morto:{de:'Ilse Varga',para:'Os Ponteiros',assunto:'Mariposa',corpo:'Mariposa se foi. Restam poucos de vocês. Voltem para a Torre.'},
  juiz_morto:{de:'Rádio interno · Torre Central',para:'Todos os andares',assunto:'—',corpo:'O Juiz caiu no saguão. Repito: o Juiz caiu. Evacuem os andares inferiores.'},
  fim:{de:'Controle',para:'Esquadrão',assunto:'A ordem chegou',corpo:'A Torre é nossa. Os servidores do andar 90 sobreviveram, o Hélice não teve tempo de apagá-los.\nO Conselho mandou ativar o Coral na rede da cidade. Eu tenho a chave. Vocês têm as armas.\nA decisão é nossa, não deles.'},
};

/* desbloqueia uma mensagem (uma vez); retorna true se for nova */
export function unlock(G,id){
  if(!MSGS[id])return false;
  G.msgs=G.msgs||[];
  if(G.msgs.some(m=>m.id===id))return false;
  G.msgs.push({id,dia:G.dia,lida:false});
  return true;
}

export const ENDINGS={
  apagado:{titulo:'Cinzas no andar 90',texto:'Quando vocês arrombaram a sala dos servidores, as telas já estavam pretas. Ilse Varga cumpriu a última ordem: o Coral virou cinza junto com o Hélice.\nAbel Rocha chamou de fracasso. O Controle chamou de sorte. A Ônix ficou com a cidade, com as revoltas e com o rádio pirata, e ninguém precisou decidir nada.'},
  ativar:{titulo:'Nova Aurora concorda',texto:'A atualização correu pela rede durante a madrugada. De manhã, os impostos foram pagos em dia, as rádios piratas ficaram mudas e ninguém soube explicar por que o sorriso das pessoas parecia ensaiado.\nO Conselho da Ônix chamou de estabilidade. Os seus agentes nunca mais conseguiram andar pela Vila Ferrugem sem que alguém os seguisse, em silêncio, a três passos de distância.'},
  destruir:{titulo:'A chave quebrada',texto:'O Controle derreteu a chave e vocês explodiram os servidores do andar 90. O Coral acabou ali.\nA Ônix manteve a cidade por mais um ano, com impostos, revoltas e rádio pirata. O Conselho nunca perdoou. Abel Rocha mandou procurar o esquadrão em cada distrito que vocês mesmos tinham conquistado.'},
};
