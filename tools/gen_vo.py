"""Gera as falas (barks) do Protocolo Ônix com as vozes SAPI pt-BR do Windows + ffmpeg.

Uso: python tools/gen_vo.py   (a partir da raiz do projeto)
Saída: v2/audio/vo/*.mp3 e v2/js/vo.js (manifesto com legendas)
"""
import json, os, subprocess, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'v2', 'audio', 'vo')
os.makedirs(OUT, exist_ok=True)

DANIEL, MARIA = 'Microsoft Daniel', 'Microsoft Maria Desktop'
# papel -> (voz, rate SAPI, fator de tom)
ROLES = {
    'ag_m': (DANIEL, 1, .96), 'ag_f': (MARIA, 1, 1.0),
    'pol': (DANIEL, 2, .9), 'grd': (DANIEL, 1, .82), 'ene': (MARIA, -1, .78),
    'civ_f': (MARIA, 3, 1.15), 'civ_m': (DANIEL, 3, 1.12),
    'vip': (DANIEL, 2, 1.05), 'sci': (MARIA, 1, 1.05), 'ctl': (MARIA, 0, .97),
    'riv_navalha': (DANIEL, 3, .92), 'riv_sibila': (MARIA, 0, .9), 'riv_ferro': (DANIEL, -2, .75),
    'riv_mariposa': (MARIA, 2, 1.08), 'riv_juiz': (DANIEL, -2, .85),
}
AGENT = {
    'sel': ['Na escuta.', 'Pronto.', 'Às ordens.', 'Aguardando instruções.'],
    'mov': ['Em movimento.', 'Entendido.', 'Positivo.', 'A caminho.'],
    'atk': ['Neutralizando.', 'Alvo na mira.', 'Fogo à vontade!', 'Abrindo fogo.'],
    'kill': ['Alvo abatido.', 'Neutralizado.', 'Um a menos.'],
    'hurt': ['Fui atingido!', 'Preciso de cobertura!', 'Estou ferido!'],
    'rel': ['Recarregando!', 'Trocando o pente!'],
    'down': ['Agente abatido!', 'Perdemos um!'],
    'crash': ['Minha cabeça... perdi o controle.'],
    'car': ['Pode dirigir.', 'Embarcando.'],
    'conv': ['Mais um pra nossa conta.', 'Mente capturada.'],
    'grn': ['Granada!', 'Lá vai granada!'],
    'over': ['Sobrecarga neural ativada.'],
}
OTHER = {
    'pol:warn': ('pol', ['Largue a arma!', 'Parado! Polícia!', 'Mãos pra cima!', 'Suspeito armado!']),
    'pol:fire': ('pol', ['Abrir fogo!', 'Atirem!']),
    'pol:reinf': ('pol', ['Central, precisamos de reforço!']),
    'grd:alert': ('grd', ['Intruso no setor!', 'Alerta geral!']),
    'grd:contact': ('grd', ['Contato! Atirem!', 'Eles estão ali!']),
    'grd:down': ('grd', ['Homem abatido!']),
    'ene:alert': ('ene', ['Ônix detectada.', 'Iniciando eliminação.', 'Alvo confirmado.']),
    'civ:f': ('civ_f', ['Socorro!', 'Meu Deus!']),
    'civ:m': ('civ_m', ['Corre!', 'Não atira!']),
    'vip:flee': ('vip', ['Segurança! Me tirem daqui!']),
    'sci:join': ('sci', ['Graças a Deus. Me tirem daqui!']),
    'ctl:ins': ('ctl', ['Controle na escuta. Boa caçada.']),
    'ctl:alarm': ('ctl', ['Atenção: o alarme foi disparado.']),
    'ctl:police': ('ctl', ['A polícia está atrás de vocês.']),
    'ctl:target': ('ctl', ['O alvo está fugindo!']),
    'ctl:term': ('ctl', ['Terminal comprometido.']),
    'ctl:lost': ('ctl', ['Perdemos um agente.']),
    'ctl:win': ('ctl', ['Objetivo cumprido. Excelente trabalho.']),
    'ctl:fail': ('ctl', ['Missão comprometida. Retirada.']),
    # missão Maré Baixa (Docas Velhas)
    'ctl:m1_intro1': ('ctl', ['Docas Velhas. Halvard Reis chega em comboio em pouco mais de um minuto.']),
    'ctl:m1_intro2': ('ctl', ['O guindaste dois fica sobre a área de descarga. Invadam a cabine, e o acidente se escreve sozinho.']),
    'ctl:m1_intro3': ('ctl', ['Há um buraco na cerca, a oeste. E os estivadores não amam o Consórcio.']),
    'ctl:m1_convoy': ('ctl', ['O comboio está entrando no porto.']),
    'ctl:m1_arrive': ('ctl', ['Reis desembarcou. Ele vai se encontrar com o contrabandista no armazém.']),
    'ctl:m1_crane': ('ctl', ['Cabine do guindaste sob controle. Soltem o contêiner quando quiserem.']),
    'ctl:m1_leaving': ('ctl', ['Reis está voltando para o carro. É agora ou nunca.']),
    'ctl:m1_accident': ('ctl', ['Acidente de trabalho. Que tragédia.']),
    'ctl:m1_exfil': ('ctl', ['Alvo confirmado. Voltem para a van, agora.']),
    'ctl:m1_reinf': ('ctl', ['Reforços do Consórcio no portão!']),
    'ctl:m1_boat': ('ctl', ['Ele vai correr para a lancha no píer leste!']),
    'ctl:m1_union': ('ctl', ['Os estivadores estão com a gente.']),
    'ctl:m1_gone': ('ctl', ['O comboio deixou o porto. Perdemos o alvo.']),
    'vip:meet': ('vip', ['Trouxe a carga? Ótimo. O Consórcio agradece.']),
    'civ:smug': ('civ_m', ['Tudo certo, doutor. Como combinado.']),
    # Ponteiros (rivais)
    'riv:navalha_intro': ('riv_navalha', ['Ônix... eu estava esperando por vocês.']),
    'riv:navalha_esc': ('riv_navalha', ['Isso não acaba aqui.']),
    'riv:navalha_death': ('riv_navalha', ['Rápido... demais...']),
    'riv:sibila_intro': ('riv_sibila', ['Vocês estão na minha mira há três quarteirões.']),
    'riv:sibila_esc': ('riv_sibila', ['Recuando. Já tenho os seus rostos.']),
    'riv:sibila_death': ('riv_sibila', ['Não vi... essa...']),
    'riv:ferro_intro': ('riv_ferro', ['Podem atirar. Eu espero.']),
    'riv:ferro_esc': ('riv_ferro', ['Blindagem comprometida. Saindo.']),
    'riv:ferro_death': ('riv_ferro', ['Ferro... enferruja...']),
    'riv:mariposa_intro': ('riv_mariposa', ['Que tal um pouco de calor?']),
    'riv:mariposa_esc': ('riv_mariposa', ['Vocês queimam outro dia.']),
    'riv:mariposa_death': ('riv_mariposa', ['Apaguem... a luz...']),
    'riv:juiz_intro': ('riv_juiz', ['A sentença já foi lida, Ônix.']),
    'riv:juiz_death': ('riv_juiz', ['O Consórcio... sobrevive a mim.']),
    'ctl:riv_spot': ('ctl', ['Cuidado: é um dos Ponteiros, a elite do Consórcio.']),
    'ctl:riv_kill': ('ctl', ['Um Ponteiro a menos. O Consórcio vai sentir.']),
    'ctl:riv_esc': ('ctl', ['Ele fugiu. Vamos vê-lo de novo.']),
    # missão Linha de Fuga (Vila Ferrugem)
    'ctl:m2_intro1': ('ctl', ['Vila Ferrugem. O Consórcio montou uma clínica clandestina no alto do morro. A doutora Tanaka está lá dentro.']),
    'ctl:m2_intro2': ('ctl', ['O gerador da clínica alimenta as torretas. Desliguem, e a clínica fica no escuro.']),
    'ctl:m2_intro3': ('ctl', ['Os moradores odeiam essa clínica. Não atirem neles, e eles vão lembrar.']),
    'ctl:m2_power': ('ctl', ['Gerador desligado. As torretas apagaram.']),
    'ctl:m2_navalha': ('ctl', ['Temos companhia na estrada sul. É o Navalha. A van está cercada.']),
    'ctl:m2_cable': ('ctl', ['Alternativa: o teleférico, a leste. Levem a doutora até a estação.']),
    'ctl:m2_help': ('ctl', ['Os moradores pegaram em armas. Eles estão com vocês.']),
    'ctl:m2_noh': ('ctl', ['Vocês atiraram em moradores. Ninguém vai ajudar agora.']),
    'ctl:m2_win': ('ctl', ['Doutora Tanaka a salvo. Bom trabalho.']),
    'sci:m2': ('sci', ['Eles me obrigaram a testar a sonda em gente.']),
    'civ:m2help': ('civ_m', ['A comunidade tá com vocês!']),
    # missão Pregão (Mercado Suspenso)
    'ctl:m3_intro1': ('ctl', ['Mercado Suspenso. O Consórcio vigia cada banca daqui. Três terminais mantêm a rede de pé.']),
    'ctl:m3_intro2': ('ctl', ['O terminal da Central de Vigilância desliga as câmeras. E as câmeras só reparam em armas: andem com elas guardadas.']),
    'ctl:m3_intro3': ('ctl', ['O trem passa a cada quarenta segundos. O barulho dele cobre tiros.']),
    'ctl:m3_cams': ('ctl', ['Câmeras do setor desligadas. Vocês sumiram do mapa deles.']),
    'ctl:m3_camspot': ('ctl', ['Uma câmera viu vocês!']),
    'ctl:m3_lock': ('ctl', ['O Consórcio decretou toque de recolher no mercado. Polícia de choque a caminho.']),
    'ctl:m3_exfil': ('ctl', ['Rede derrubada. Voltem ao ponto de inserção.']),
    'ctl:m3_win': ('ctl', ['O Mercado Suspenso está cego. Bom trabalho.']),
    # missão Clube Cobalto (Baixa Neon)
    'ctl:m4_intro1': ('ctl', ['Baixa Neon. Uma célula do Consórcio está escondida no Clube Cobalto, misturada à multidão.']),
    'ctl:m4_intro2': ('ctl', ['Eles parecem civis. Cheguem perto: o scanner de implantes revela quem são.']),
    'ctl:m4_intro3': ('ctl', ['Há um carro de fuga no beco atrás do clube. Não deixem ninguém chegar até ele.']),
    'ctl:m4_reveal': ('ctl', ['Implante detectado. É um deles.']),
    'ctl:m4_mari': ('ctl', ['A Mariposa entrou pelos fundos do clube. Cuidado com o fogo.']),
    'ctl:m4_flee': ('ctl', ['Eles estão correndo para o carro de fuga!']),
    'ctl:m4_fail': ('ctl', ['Um deles escapou. Perdemos a célula.']),
    'ctl:m4_win': ('ctl', ['Célula eliminada. A Baixa Neon é nossa.']),

    'ctl:drone': ('ctl', ['Um drone de segurança viu vocês!']),
    'ctl:m5_intro1': ('ctl', ['Setor Industrial 9. A Fundição Hélice abastece metade das fábricas do Consórcio. Três reatores mantêm tudo de pé.']),
    'ctl:m5_intro2': ('ctl', ['A tubulação solta vapor em ciclos. Quem estiver perto cozinha, seja de quem for. Usem isso a favor de vocês.']),
    'ctl:m5_intro3': ('ctl', ['Drones patrulham o pátio e o Ferro-Velho guarda o reator central. A Chave Fantasma invade os drones.']),
    'ctl:m5_charge': ('ctl', ['Carga instalada.']),
    'ctl:m5_last': ('ctl', ['Última carga armada. Reação em cadeia em quarenta e cinco segundos. Corram para o portão!']),
    'ctl:m5_vapor': ('ctl', ['Pressão no máximo. Todas as saídas de vapor vão disparar agora.']),
    'ctl:m5_drones': ('ctl', ['O hangar está lançando mais drones.']),
    'ctl:m5_win': ('ctl', ['Lá se vai a fundição. Belo espetáculo.']),
    'ctl:m5_fail': ('ctl', ['Vocês não saíram a tempo.']),

    'ctl:m6_intro1': ('ctl', ['Distrito Lúmen. Otávio Brandt, o contador do Consórcio, dá uma festa no pavilhão de vidro da praça.']),
    'ctl:m6_intro2': ('ctl', ['Ele trouxe dois sósias. De perto, o scanner mostra quem é o verdadeiro. O terminal da guarita revela os três.']),
    'ctl:m6_intro3': ('ctl', ['Se o alarme soar, ele corre para o helicóptero. E as paredes do pavilhão são de vidro: não seguram bala nenhuma.']),
    'ctl:m6_double': ('ctl', ['Esse é um sósia. Continuem procurando.']),
    'ctl:m6_real': ('ctl', ['É ele. Esse é o Brandt verdadeiro.']),
    'ctl:m6_booth': ('ctl', ['Guarita invadida. Marquei o alvo verdadeiro para vocês.']),
    'ctl:m6_wrong': ('ctl', ['Era um sósia! O verdadeiro está correndo para o helicóptero.']),
    'ctl:m6_sibila': ('ctl', ['A Sibila está no heliporto, cobrindo a fuga. Saiam da linha de tiro dela.']),
    'ctl:m6_win': ('ctl', ['Brandt está morto. O Consórcio vai precisar de outro contador.']),

    'ctl:laser': ('ctl', ['Vocês cortaram um feixe de alarme!']),
    'ctl:m7_intro1': ('ctl', ['Colinas de Vidro. O doutor Caio Ventura escreveu o firmware dos drones do Consórcio e quer trocar de lado. Ele está na estufa do Retiro.']),
    'ctl:m7_intro2': ('ctl', ['O jardim é cortado por feixes de alarme. Alguns piscam: esperem o momento certo. O gerador do lado de fora do muro apaga tudo.']),
    'ctl:m7_intro3': ('ctl', ['O VTOL pega vocês na zona de pouso, no topo do morro. Vão ter que segurar a posição até ele descer.']),
    'ctl:m7_dark': ('ctl', ['Gerador desligado. Feixes, câmeras e luzes do Retiro apagados. Alguém vai vir checar.']),
    'ctl:m7_hold': ('ctl', ['VTOL a caminho, trinta segundos. O Consórcio sabe onde vocês estão: segurem a zona de pouso!']),
    'ctl:m7_wave': ('ctl', ['Mais gente subindo o morro!']),
    'ctl:m7_vtol': ('ctl', ['VTOL pousando. Embarquem o doutor!']),
    'ctl:m7_win': ('ctl', ['Doutor a bordo. O Consórcio acabou de perder os próprios drones.']),
    'ctl:m7_fail': ('ctl', ['Perdemos o doutor.']),
    'sci:m7': ('sci', ['Finalmente. Os drones deles conhecem o meu rosto, então vamos rápido.']),

    'ctl:m8_intro1': ('ctl', ['Cais Aéreo. Uma célula do Consórcio está carregando aquele dirigível. Seis agentes, dois com armadura pesada.']),
    'ctl:m8_intro2': ('ctl', ['O dirigível parte em quatro minutos. No último minuto eles correm para a prancha de embarque. Ninguém pode embarcar.']),
    'ctl:m8_intro3': ('ctl', ['O terminal das amarras, na ponta do píer central, prende o dirigível no cais. Cuidado com as torretas.']),
    'ctl:m8_heavy': ('ctl', ['Armadura pesada. Bala comum mal arranha: usem explosivos ou munição perfurante.']),
    'ctl:m8_board': ('ctl', ['Eles estão correndo para a prancha de embarque!']),
    'ctl:m8_moor': ('ctl', ['Amarras travadas. Esse dirigível não sai daqui.']),
    'ctl:m8_gone': ('ctl', ['O dirigível partiu vazio. Terminem o serviço.']),
    'ctl:m8_fail': ('ctl', ['Um deles embarcou. Perdemos a célula.']),
    'ctl:m8_win': ('ctl', ['Célula eliminada. O Cais Aéreo é nosso.']),

    'ctl:mj_intro1': ('ctl', ['Jardins Altos. O senador Calvino vende ao Consórcio a segurança da cidade inteira. Toda noite ele passeia pelo labirinto de sebes da mansão.']),
    'ctl:mj_intro2': ('ctl', ['As sebes escondem vocês. Os holofotes das torres, não: eles enxergam qualquer um, armado ou não. Dá para derrubá-los a tiros.']),
    'ctl:mj_intro3': ('ctl', ['Ao primeiro alarme ele corre para o bunker. Se entrar, a porta fecha e ele prepara a fuga pelo túnel.']),
    'ctl:mj_flee': ('ctl', ['O senador está correndo para o bunker! Cortem o caminho dele!']),
    'ctl:mj_bunker': ('ctl', ['Ele entrou. Porta blindada fechada. Sobrecarreguem os dois relés do lado de fora antes que o túnel fique pronto!']),
    'ctl:mj_open': ('ctl', ['Porta arrombada. Ele não tem mais para onde correr.']),
    'ctl:mj_win': ('ctl', ['Calvino está morto. Os contratos do Consórcio acabaram de perder o dono.']),
    'ctl:mj_fail': ('ctl', ['Ele saiu pelo túnel. Perdemos o senador.']),
    'ctl:m9_intro1': ('ctl', ['Torre Central. É aqui que o Consórcio termina. A praça é um campo fortificado: torretas, drones e soldados pesados.']),
    'ctl:m9_intro2': ('ctl', ['O portão blindado só abre pelos dois terminais de segurança, um em cada ponta da praça.']),
    'ctl:m9_intro3': ('ctl', ['O Juiz espera no átrio. E quando ele cair, a Varga vai tentar apagar os servidores do andar noventa.']),
    'ctl:m9_term': ('ctl', ['Um terminal invadido. Falta o outro.']),
    'ctl:m9_breach': ('ctl', ['Portão arrombado. Entrem no átrio!']),
    'ctl:m9_juiz': ('ctl', ['Lá está o Juiz. Aqueles dois pilares projetam um escudo nele: derrubem ou invadam os pilares.']),
    'ctl:m9_rivals': ('ctl', ['Todos os Ponteiros que sobraram estão com ele. É o fim da linha para eles também.']),
    'ctl:m9_shield': ('ctl', ['O escudo caiu! Ele está exposto!']),
    'ctl:m9_reinf': ('ctl', ['Soldados pesados descendo pelos elevadores!']),
    'ctl:m9_laser': ('ctl', ['Feixe de contenção ativado no átrio. Saiam do caminho dele!']),
    'ctl:m9_servers': ('ctl', ['O Juiz caiu. A Varga mandou apagar os servidores. Vocês têm um minuto!']),
    'ctl:m9_win': ('ctl', ['Servidores nossos. Nova Aurora é da Ônix.']),
    'ctl:m9_wiped': ('ctl', ['Tarde demais. Os servidores viraram cinza. Mas a torre é nossa.']),
}

# --en: gera as falas em inglês (voz Zira; papéis masculinos com tom mais grave) em audio/vo_en e js/vo_en.js
import sys
EN = '--en' in sys.argv
if EN:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from vo_en import AGENT_EN, OTHER_EN
    for k in AGENT:
        assert len(AGENT_EN[k]) == len(AGENT[k]), k
    for k in OTHER:
        assert len(OTHER_EN[k]) == len(OTHER[k][1]), k
    AGENT = {k: AGENT_EN[k] for k in AGENT}
    OTHER = {k: (OTHER[k][0], OTHER_EN[k]) for k in OTHER}
    ZIRA = 'Microsoft Zira Desktop'
    ROLES = {k: (ZIRA, r, p * (.8 if v == DANIEL else 1)) for k, (v, r, p) in ROLES.items()}
    OUT = os.path.join(ROOT, 'v2', 'audio', 'vo_en')
    os.makedirs(OUT, exist_ok=True)

jobs, manifest = [], {}
for key, lines in AGENT.items():
    for g in ('m', 'f'):
        k = f'ag:{key}:{g}'
        manifest[k] = []
        for i, text in enumerate(lines):
            f = f'ag_{g}_{key}{i+1}'
            jobs.append((f, 'ag_' + g, text)); manifest[k].append([f, text])
for k, (role, lines) in OTHER.items():
    manifest[k] = []
    for i, text in enumerate(lines):
        f = k.replace(':', '_') + str(i + 1)
        jobs.append((f, role, text)); manifest[k].append([f, text])

tmp = tempfile.mkdtemp(prefix='onixvo')
tsv = os.path.join(tmp, 'jobs.tsv')
with open(tsv, 'w', encoding='utf-8') as fh:
    for f, role, text in jobs:
        voice, rate, _ = ROLES[role]
        fh.write(f'{os.path.join(tmp, f + ".wav")}\t{voice}\t{rate}\t{text}\n')
ps = r'''
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
foreach ($line in [System.IO.File]::ReadAllLines('%s', [System.Text.Encoding]::UTF8)) {
  $p = $line.Split("`t")
  $s.SelectVoice($p[1]); $s.Rate = [int]$p[2]
  $s.SetOutputToWaveFile($p[0], $fmt); $s.Speak($p[3])
}
$s.SetOutputToNull()
''' % tsv
ps1 = os.path.join(tmp, 'gen.ps1')
open(ps1, 'w', encoding='utf-8-sig').write(ps)
subprocess.run(['powershell', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ps1], check=True)

for f, role, text in jobs:
    p = ROLES[role][2]
    af = (f'asetrate={int(22050*p)},aresample=24000,atempo={1/p:.4f},'
          'silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,'
          'loudnorm=I=-16:TP=-1.5')
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', os.path.join(tmp, f + '.wav'), '-af', af,
                    '-ac', '1', '-ar', '24000', '-b:a', '48k', os.path.join(OUT, f + '.mp3')], check=True)

js = '/* Gerado por tools/gen_vo.py — falas e legendas. */\nexport const VO' + ('_EN' if EN else '') + '=' + json.dumps(manifest, ensure_ascii=False) + ';\n'
open(os.path.join(ROOT, 'v2', 'js', 'vo_en.js' if EN else 'vo.js'), 'w', encoding='utf-8').write(js)
print(len(jobs), 'falas geradas')
