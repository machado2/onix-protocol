## Estado e regras da campanha (porte de v2/js/ui.js, core.js e story.js): distritos, território,
## impostos e revoltas, agentes e implantes, loja, laboratório, mensagens interceptadas e salvamento.
## Autoload "Camp". Sem campanha ativa (testes com --mission), has() devolve false e nada é salvo.
extends Node

var save_path := "user://campanha.sav"
const RECRUTA := 4000
const MAXINV := 6
const CLINICA := 1200
const VERBA := 1500
const MAX_AGENTES := 8
const CIENT_PRECO := 2500
const CIENT_SAL := 150
const PD_POR_CIENT := 10
const MAX_CIENT := 20
const IMP_PRECO := [3500, 7000, 12000]

const IMP := {
	chassi = {nome = "Chassi blindado", desc = "+45 de integridade e 7% de blindagem por nível"},
	motor = {nome = "Servomotores", desc = "+12% de velocidade por nível"},
	otica = {nome = "Ótica tática", desc = "Mais precisão e alcance de disparo"},
	cortex = {nome = "Córtex estabilizado", desc = "Os mostradores neurais drenam menos estabilidade"},
}

## Itens do mercado cinza: preço, pesquisa exigida e descrição (o resto vem de GD.WD).
const SHOP := ["pistola", "smg", "escopeta", "chamas", "feixe", "serra", "granada", "incendiaria", "medkit", "chave", "sonda", "manto"]
const ITEM := {
	pistola = {preco = 600, desc = "Semiautomática leve. Discreta e precisa."},
	smg = {preco = 2800, desc = "Cadência alta, boa contra grupos."},
	escopeta = {preco = 4200, res = "escopeta", desc = "Seis projéteis por disparo. Devastadora de perto."},
	chamas = {preco = 6500, res = "chamas", desc = "Cone de fogo contínuo. Incendeia pessoas e veículos."},
	feixe = {preco = 12500, res = "feixe", desc = "Feixe que atravessa todos os alvos em linha."},
	serra = {preco = 17000, res = "serra", desc = "Muro de chumbo. Deixa o agente mais lento."},
	granada = {preco = 700, desc = "Arremessável. Explode em área e detona veículos."},
	medkit = {preco = 450, desc = "Restaura toda a integridade de um agente."},
	incendiaria = {preco = 900, res = "incend", desc = "Explosão menor, mas cobre a área de fogo por vários segundos."},
	manto = {preco = 3200, res = "manto", desc = "Deixa o agente invisível por até 25 s por missão. Com o manto ativo não dá para atirar."},
	chave = {preco = 2600, res = "chave", desc = "Invade torretas e drones do Consórcio e os vira contra ele."},
	sonda = {preco = 1800, desc = "Sequestra a mente de quem estiver por perto. Quanto mais seguidores, mais forte a sonda."},
}

const RES_CATS := ["Armas", "Cibernética", "Neural", "Equipamento", "Operações"]
const RESEARCH := [
	{id = "escopeta", cat = "Armas", nome = "Escopeta Trovão", custo = 40, desc = "Libera a Escopeta Trovão no arsenal."},
	{id = "pentes", cat = "Armas", nome = "Pentes estendidos", custo = 60, desc = "+50% de munição por pente em todas as armas do esquadrão."},
	{id = "perfurante", cat = "Armas", nome = "Munição perfurante", custo = 70, req = ["escopeta"], desc = "Os disparos do esquadrão ignoram metade da blindagem inimiga."},
	{id = "chamas", cat = "Armas", nome = "Lança-chamas Brasa", custo = 80, req = ["escopeta"], desc = "Libera o lança-chamas."},
	{id = "incend", cat = "Armas", nome = "Granada incendiária", custo = 90, req = ["chamas"], desc = "Libera a granada que espalha fogo pela área."},
	{id = "feixe", cat = "Armas", nome = "Rifle de feixe Agulha", custo = 150, req = ["perfurante"], desc = "Libera o rifle de feixe, que atravessa alvos em linha."},
	{id = "serra", cat = "Armas", nome = "Minigun Serra", custo = 200, req = ["feixe", "pentes"], desc = "Libera a minigun."},
	{id = "impl2", cat = "Cibernética", nome = "Implantes Mk II", custo = 90, desc = "Permite instalar implantes de nível 2."},
	{id = "reparo", cat = "Cibernética", nome = "Reparo subdérmico", custo = 100, desc = "Agentes regeneram integridade depois de 5 s sem serem atingidos."},
	{id = "blindagem", cat = "Cibernética", nome = "Blindagem reativa", custo = 130, req = ["impl2"], desc = "+10% de blindagem em todos os agentes."},
	{id = "impl3", cat = "Cibernética", nome = "Implantes Mk III", custo = 220, req = ["impl2"], desc = "Permite instalar implantes de nível 3."},
	{id = "sonda2", cat = "Neural", nome = "Sonda amplificada", custo = 70, desc = "Alcance da sonda +1 e força +30%."},
	{id = "estab", cat = "Neural", nome = "Estabilizador neural", custo = 80, desc = "A sobrecarga drena 30% menos e gera metade da dependência."},
	{id = "armados", cat = "Neural", nome = "Seguidores armados", custo = 90, req = ["sonda2"], desc = "Civis recrutados pela sonda já vêm com uma pistola."},
	{id = "limpa", cat = "Neural", nome = "Sobrecarga limpa", custo = 170, req = ["estab"], desc = "O colapso dura metade e a sobrecarga não gera dependência."},
	{id = "sonda3", cat = "Neural", nome = "Sonda de massa", custo = 180, req = ["sonda2"], desc = "Força da sonda +60%. Até agentes do Consórcio cedem rápido."},
	{id = "chave", cat = "Equipamento", nome = "Chave Fantasma", custo = 50, desc = "Libera a ferramenta que invade torretas e drones."},
	{id = "nanomed", cat = "Equipamento", nome = "Nanomedkit", custo = 60, desc = "O kit médico cura todos os agentes num raio de 2,5."},
	{id = "manto", cat = "Equipamento", nome = "Manto óptico", custo = 160, req = ["chave"], desc = "Libera o manto: invisibilidade por 25 s por missão."},
	{id = "informantes", cat = "Operações", nome = "Rede de informantes", custo = 80, desc = "+20% de recompensa nas missões."},
	{id = "trafego", cat = "Operações", nome = "Hackers de tráfego", custo = 90, desc = "Reforços policiais demoram mais e a polícia desiste mais rápido."},
	{id = "lavagem", cat = "Operações", nome = "Lavagem de dinheiro", custo = 120, req = ["informantes"], desc = "+25% na renda dos distritos."},
	{id = "propaganda", cat = "Operações", nome = "Propaganda", custo = 100, desc = "+5 de lealdade por dia em todos os distritos da Ônix."},
]

## Distritos de Nova Aurora (polígonos no espaço 1000×620 do mapa da web).
const DIST := [
	{nome = "Docas Velhas", renda = 1500, dif = 1, tipo = "assassinato", riq = .2, mission = "docas",
	 brief = "Halvard Reis, diretor de logística do Consórcio, vem às Docas Velhas fechar um acordo com um contrabandista. Ele chega em comboio e passa sob o guindaste 2. Se a cabine do guindaste for invadida, o contêiner pendurado resolve o problema sem disparar um tiro. Mate Reis antes que ele volte ao carro ou fuja de lancha e retorne à van. Há um buraco na cerca a oeste.",
	 short = "Emboscada ao comboio de Halvard Reis no porto.", poly = [[40, 420], [250, 400], [280, 580], [40, 590]]},
	{nome = "Vila Ferrugem", renda = 1800, dif = 2, tipo = "extracao", riq = .25, mission = "favela",
	 brief = "O Consórcio montou uma clínica clandestina no alto da Vila Ferrugem. A Dra. Sofia Tanaka, pesquisadora de neuroimplantes, está presa lá dentro. Suba o morro, tire a doutora da clínica e leve-a à van na estrada sul ou à estação do teleférico a leste. O gerador da clínica alimenta as torretas. A polícia não sobe o morro, mas os moradores vão lembrar de quem atirar neles.",
	 short = "Resgate na favela, com duas rotas de fuga.", poly = [[40, 240], [230, 220], [250, 400], [40, 420]]},
	{nome = "Mercado Suspenso", renda = 2600, dif = 2, tipo = "sabotagem", riq = .4, mission = "mercado",
	 brief = "O Mercado Suspenso funciona debaixo do monotrilho e o Consórcio vigia cada banca com câmeras. Três terminais mantêm a rede de vigilância do distrito. O terminal da Central de Vigilância, ao norte, desliga todas as câmeras. As câmeras só reparam em armas à mostra. O trem passa a cada 40 segundos e o barulho dele cobre tiros. Depois de derrubar a rede, volte ao ponto de inserção.",
	 short = "Sabotagem sob o monotrilho, com câmeras de segurança.", poly = [[250, 400], [470, 380], [500, 580], [280, 580]]},
	{nome = "Baixa Neon", renda = 3000, dif = 3, tipo = "eliminacao", riq = .5, mission = "neon",
	 brief = "Uma célula de cinco agentes do Consórcio está escondida no Clube Cobalto e nas calçadas da avenida, vestida como gente comum. Chegue perto: o scanner de implantes do esquadrão revela quem é quem. Atirar no civil errado custa caro. Há um carro de fuga no beco atrás do clube: se algum agente chegar até ele, a missão falha.",
	 short = "Caça a agentes disfarçados numa casa noturna.", poly = [[230, 220], [450, 200], [470, 380], [250, 400]]},
	{nome = "Setor Industrial 9", renda = 2400, dif = 4, tipo = "sabotagem", riq = .3, mission = "fundicao",
	 brief = "A Fundição Hélice do Setor Industrial 9 abastece metade das fábricas do Consórcio. Instale cargas nos três reatores da planta. Depois da terceira carga, vocês têm 45 segundos para voltar ao portão antes da reação em cadeia. As saídas de vapor da tubulação disparam em ciclos e queimam quem estiver perto, aliado ou inimigo. Drones de segurança patrulham o pátio: a Chave Fantasma consegue invadi-los. O Ferro-Velho guarda o reator central.",
	 short = "Sabotagem numa fundição com vapor, drones e contagem regressiva.", poly = [[40, 40], [260, 40], [230, 220], [40, 240]]},
	{nome = "Distrito Lúmen", renda = 3600, dif = 5, tipo = "assassinato", riq = .7, mission = "lumen",
	 brief = "Otávio Brandt, diretor financeiro do Consórcio, dá uma festa no pavilhão de vidro da Praça Lúmen. Ele sabe que é alvo: dois sósias idênticos circulam com ele. De perto, o scanner de implantes do esquadrão distingue o verdadeiro. O terminal da guarita de segurança revela os três de uma vez. Atirar em qualquer um dispara o alarme, e o alvo corre para o helicóptero no heliporto. As paredes do pavilhão são de vidro e não seguram balas.",
	 short = "Assassinato numa festa, com sósias e helicóptero de fuga.", poly = [[260, 40], [480, 40], [450, 200], [230, 220]]},
	{nome = "Colinas de Vidro", renda = 4200, dif = 5, tipo = "extracao", riq = .8, mission = "retiro",
	 brief = "O Dr. Caio Ventura escreveu o firmware dos drones do Consórcio e quer mudar de lado. O Hélice o mantém no Retiro, uma mansão murada no alto das Colinas de Vidro, trabalhando numa estufa de vidro. Feixes de alarme cortam o jardim; alguns piscam em ciclos. O gerador fora do muro, a sudoeste, apaga feixes, câmeras e luzes. Leve o doutor até a zona de pouso no topo do morro, a noroeste, e segure a posição até o VTOL pousar.",
	 short = "Extração com feixes de alarme e defesa da zona de pouso.", poly = [[470, 380], [720, 360], [740, 580], [500, 580]]},
	{nome = "Cais Aéreo", renda = 3800, dif = 6, tipo = "eliminacao", riq = .6, mission = "doca",
	 brief = "Uma célula de seis agentes do Consórcio, dois deles com armadura pesada, está carregando um dirigível no Cais Aéreo. O dirigível parte em quatro minutos. No último minuto, a célula corre para a prancha de embarque: se algum agente embarcar, a missão falha. O terminal das amarras, na ponta do píer central, prende o dirigível no cais. Torretas automáticas vigiam os píeres.",
	 short = "Eliminação contra o relógio, com soldados pesados.", poly = [[450, 200], [700, 180], [720, 360], [470, 380]]},
	{nome = "Jardins Altos", renda = 5000, dif = 7, tipo = "assassinato", riq = .9, mission = "jardins",
	 brief = "O senador Augusto Calvino vende ao Consórcio os contratos de segurança da cidade inteira. Toda noite ele caminha pelo labirinto de sebes da própria mansão, com dois guarda-costas. As sebes escondem o esquadrão; os holofotes das torres, não: eles enxergam qualquer um, armado ou não, e podem ser derrubados a tiros. Ao primeiro alarme, Calvino corre para o bunker a nordeste. Se ele entrar, a porta blindada se fecha e um túnel de fuga começa a ser preparado: sobrecarreguem os dois relés do lado de fora para arrombar a porta antes que ele suma.",
	 short = "Assassinato num labirinto de sebes, com holofotes e bunker.", poly = [[480, 40], [730, 40], [700, 180], [450, 200]]},
	{nome = "Torre Central", renda = 8000, dif = 9, tipo = "eliminacao", riq = 1.0, hq = true, mission = "torre",
	 brief = "O último bastião do Consórcio. A praça da Torre Central é um campo fortificado: torretas, drones e soldados pesados guardam o portão blindado. Invadam os dois terminais de segurança da praça para arrombar o portão. No átrio, o Juiz espera com os Ponteiros que restarem; dois pilares de escudo o protegem enquanto estiverem de pé. Quando ele cair, Ilse Varga vai mandar apagar os servidores do andar 90. Cheguem lá antes.",
	 short = "Missão final: assalto à torre, o Juiz e os servidores do Coral.", poly = [[730, 40], [960, 40], [960, 330], [720, 360], [700, 180]]},
]
const BAY := [[740, 580], [720, 360], [960, 330], [960, 600]]

const RIVAL_INFO := {
	navalha = {trim = "#ff9a3c", desc = "Caçador de rua. Rápido e cruel de perto."},
	sibila = {trim = "#b07cff", desc = "Atiradora de feixe. Ataca de longe."},
	ferro = {trim = "#d8d8d8", desc = "Muralha de blindagem com uma minigun."},
	mariposa = {trim = "#ff5a2a", desc = "Incendiária. Transforma ruas em fornalhas."},
	juiz = {trim = "#ffd36b", desc = "Líder dos Ponteiros. Só deixa a Torre Central no fim."},
}

const MSGS := {
	inicio = {de = "Abel Rocha · Conselho da Ônix", para = "Controle", assunto = "Operação Maré", corpo = "Autorizada a Operação Maré. Nova Aurora está loteada há vinte anos e o Hélice ficou preguiçoso.\nQuero os distritos, não os prédios. Prédios se compram. Lealdade se cobra.\nO esquadrão responde a você. Você responde a mim."},
	docas = {de = "Ilse Varga · Presidência do Consórcio Hélice", para = "Os Ponteiros", assunto = "Reis", corpo = "Halvard Reis morreu nas Docas Velhas. Não foi acidente, por mais que o laudo diga isso.\nAcordem os Ponteiros. Quero nomes, rostos e o endereço de quem paga essa gente."},
	tres = {de = "Abel Rocha · Conselho da Ônix", para = "Controle", assunto = "Resultados", corpo = "Três distritos e os investidores sorriem. Mantenham os impostos firmes: medo rende mais que gratidão.\nE parem de chamar os moradores de \"civis\" nos relatórios. São receita."},
	tanaka = {de = "Dra. Sofia Tanaka · notas pessoais", para = "(arquivo cifrado)", assunto = "Projeto Coral", corpo = "Eles chamaram de Coral porque cresce em colônias. A sonda neural não lê mentes: ela as reorganiza.\nOs primeiros testes foram feitos na Vila Ferrugem, com voluntários que não sabiam que eram voluntários.\nO Hélice abandonou o projeto. Alguém comprou os dados. A sonda que me tirou daquela clínica foi construída com eles."},
	cinco = {de = "Ilse Varga · Presidência do Consórcio Hélice", para = "O Juiz", assunto = "Coral", corpo = "A Ônix usa a nossa própria tecnologia contra nós. Cada seguidor que eles recrutam na rua é um teste do Coral que nós engavetamos.\nNão subestime o que eles pretendem fazer com a rede da cidade inteira."},
	revolta = {de = "Rádio pirata · Vila Ferrugem", para = "Todas as frequências", assunto = "Troca de dono", corpo = "Trocaram o dono do morro e chamaram isso de libertação. O imposto subiu, a luz continua cortando e agora quem patrulha usa casaco preto em vez de vermelho.\nDesliguem a TV. Liguem o rádio. A rua é nossa."},
	sete = {de = "Abel Rocha · Conselho da Ônix", para = "Controle", assunto = "Depois da Torre", corpo = "Quando a Torre Central cair, os servidores do Hélice passam a ser nossos. Coral roda neles.\nUma atualização na rede da cidade e Nova Aurora inteira concorda com a gente. Sem impostos atrasados, sem revoltas, sem rádio pirata.\nVocê vai receber a ordem no momento certo."},
	hq = {de = "Ilse Varga · Presidência do Consórcio Hélice", para = "Segurança da Torre", assunto = "Protocolo final", corpo = "Se a Torre cair, apaguem os servidores do andar 90. Todos. Coral não pode cair nas mãos da Ônix.\nNão importa o que aconteça comigo."},
	navalha_visto = {de = "Navalha", para = "Ilse Varga", assunto = "Contato", corpo = "Vi os seus fantasmas de casaco preto. Quatro, às vezes cinco. Andam como gente que já morreu uma vez.\nDa próxima vez eu escolho a rua."},
	navalha_morto = {de = "Ilse Varga", para = "Os Ponteiros", assunto = "Navalha", corpo = "Navalha não volta. Não mandem flores. Mandem o Ferro-Velho."},
	sibila_visto = {de = "Sibila", para = "Ilse Varga", assunto = "Telemetria", corpo = "Tenho as assinaturas térmicas dos quatro. Um deles manca da perna esquerda; implante barato.\nA próxima vez que olharem pela janela, vou estar do outro lado."},
	sibila_morto = {de = "Ilse Varga", para = "Os Ponteiros", assunto = "Sibila", corpo = "Perdemos a Sibila e o rifle dela. Se a Ônix estiver usando aquele rifle, quero saber."},
	ferro_visto = {de = "Ferro-Velho", para = "Ilse Varga", assunto = "Relatório", corpo = "Eles atiram bem. Não o bastante."},
	ferro_morto = {de = "Ilse Varga", para = "Os Ponteiros", assunto = "Ferro-Velho", corpo = "Ferro-Velho caiu. Eu achava que isso era fisicamente impossível."},
	mariposa_visto = {de = "Mariposa", para = "Ilse Varga", assunto = "Fumaça", corpo = "Eles correm do fogo como todo mundo. Gostei disso."},
	mariposa_morto = {de = "Ilse Varga", para = "Os Ponteiros", assunto = "Mariposa", corpo = "Mariposa se foi. Restam poucos de vocês. Voltem para a Torre."},
	juiz_morto = {de = "Rádio interno · Torre Central", para = "Todos os andares", assunto = "—", corpo = "O Juiz caiu no saguão. Repito: o Juiz caiu. Evacuem os andares inferiores."},
	fim = {de = "Controle", para = "Esquadrão", assunto = "A ordem chegou", corpo = "A Torre é nossa. Os servidores do andar 90 sobreviveram, o Hélice não teve tempo de apagá-los.\nO Conselho mandou ativar o Coral na rede da cidade. Eu tenho a chave. Vocês têm as armas.\nA decisão é nossa, não deles."},
}

const ENDINGS := {
	apagado = {titulo = "Cinzas no andar 90", texto = "Quando vocês arrombaram a sala dos servidores, as telas já estavam pretas. Ilse Varga cumpriu a última ordem: o Coral virou cinza junto com o Hélice.\nAbel Rocha chamou de fracasso. O Controle chamou de sorte. A Ônix ficou com a cidade, com as revoltas e com o rádio pirata, e ninguém precisou decidir nada."},
	ativar = {titulo = "Nova Aurora concorda", texto = "A atualização correu pela rede durante a madrugada. De manhã, os impostos foram pagos em dia, as rádios piratas ficaram mudas e ninguém soube explicar por que o sorriso das pessoas parecia ensaiado.\nO Conselho da Ônix chamou de estabilidade. Os seus agentes nunca mais conseguiram andar pela Vila Ferrugem sem que alguém os seguisse, em silêncio, a três passos de distância."},
	destruir = {titulo = "A chave quebrada", texto = "O Controle derreteu a chave e vocês explodiram os servidores do andar 90. O Coral acabou ali.\nA Ônix manteve a cidade por mais um ano, com impostos, revoltas e rádio pirata. O Conselho nunca perdoou. Abel Rocha mandou procurar o esquadrão em cada distrito que vocês mesmos tinham conquistado."},
}

var G := {}            # estado salvo da campanha
var active := false    # há uma campanha em andamento (missões lançadas pelo mapa)
var ADJ: Array = []    # vizinhança dos distritos (polígonos que dividem uma aresta)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--camptest"):
			save_path = "user://teste.sav"
	for i in DIST.size():
		var a: Array = DIST[i].poly
		var l: Array[int] = []
		for j in DIST.size():
			if j == i:
				continue
			var shared := 0
			for p in a:
				for q in DIST[j].poly:
					if p[0] == q[0] and p[1] == q[1]:
						shared += 1
			if shared >= 2:
				l.append(j)
		ADJ.append(l)


# ---------------------------------------------------------------- utilidades
static func fmt(v: float) -> String:
	var n := absi(roundi(v))
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + "$" + s + out


func reward(i: int) -> int:
	return 3000 + DIST[i].dif * 2000


func has(id: String) -> bool:
	return active and G.has("pesq") and G.pesq.done.has(id)


func owned() -> int:
	return G.dono.count("player")


func agent(id: int):
	for a in G.agentes:
		if a.id == id:
			return a
	return null


func squad() -> Array:
	var l := []
	for id in G.esq:
		var a = agent(id)
		if a != null:
			l.append(a)
	return l


# ---------------------------------------------------------------- salvamento
func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_var(G)


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func load_game() -> bool:
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	var g = f.get_var()
	if not (g is Dictionary) or not g.has("agentes"):
		return false
	G = g
	for k in ["rivais", "terr"]:
		if not G.has(k):
			G[k] = {}
	if not G.has("msgs"):
		G.msgs = []
	active = true
	return true


func novo_agente() -> Dictionary:
	var usados := {}
	for a in G.agentes:
		usados[a.nome] = true
	var nome := "Agente %d" % G.prox
	for n in GD.CODINOMES:
		if not usados.has(n):
			nome = n
			break
	var a := {id = G.prox, nome = nome, imp = {chassi = 0, motor = 0, otica = 0, cortex = 0}, inv = [{t = "pistola"}], missoes = 0, abates = 0, dep = 0}
	G.prox += 1
	return a


func new_game() -> void:
	var dono := []
	for d in DIST:
		dono.append("corp")
	G = {v = 3, dinheiro = 18000, dia = 1, prox = 1, agentes = [], esq = [], dono = dono, abates = 0, vitoria = false,
		rivais = {}, msgs = [], cientistas = 3, pesq = {done = {}, prog = {}, ativo = "escopeta"}, terr = {}, final = "", wiped = false}
	for k in 4:
		G.agentes.append(novo_agente())
	G.agentes[0].inv.append({t = "granada"})
	G.agentes[1].inv.append({t = "medkit"})
	G.agentes[2].inv.append({t = "sonda"})
	for a in G.agentes:
		G.esq.append(a.id)
	active = true
	unlock("inicio")
	save()


func unlock(id: String) -> bool:
	if not MSGS.has(id):
		return false
	for m in G.msgs:
		if m.id == id:
			return false
	G.msgs.append({id = id, dia = G.dia, lida = false})
	return true


func unread() -> int:
	return G.msgs.filter(func(m): return not m.lida).size()


func rival_dead(id: String) -> bool:
	return active and G.rivais.has(id) and G.rivais[id].get("morto", false)


# ---------------------------------------------------------------- território
func terr(i: int) -> Dictionary:
	if not G.terr.has(i):
		G.terr[i] = {imposto = .3, lealdade = 60, revolta = 0}
	return G.terr[i]


func dist_income(i: int) -> int:
	var t := terr(i)
	if t.revolta:
		return 0
	var v: float = DIST[i].renda * t.imposto / .3
	if t.lealdade < 25:
		v *= .5
	return roundi(v * (1.25 if has("lavagem") else 1.0))


func total_income() -> int:
	var s := 0
	for i in DIST.size():
		if G.dono[i] == "player":
			s += dist_income(i)
	return s


func loyalty_delta(i: int) -> int:
	var t := terr(i)
	var d: float = (.3 - t.imposto) * 40 + 3
	var corp_n: int = ADJ[i].filter(func(j): return G.dono[j] == "corp").size()
	d -= mini(4, corp_n * 2)
	if has("propaganda"):
		d += 5
	return roundi(d)


func avail(i: int) -> bool:
	if G.dono[i] == "player":
		return false
	if not "player" in G.dono:
		return i == 0
	return ADJ[i].any(func(j): return G.dono[j] == "player")


## Avança um dia nos distritos da Ônix; devolve as notas [texto, cor] para o relatório.
func territory_tick(skip: int) -> Array:
	var out := []
	for i in DIST.size():
		if G.dono[i] != "player" or i == skip:
			continue
		var d: Dictionary = DIST[i]
		var t := terr(i)
		if t.revolta:
			t.revolta -= 1
			if t.revolta <= 0:
				G.dono[i] = "corp"
				G.terr.erase(i)
				out.append(["%s se rebelou e voltou ao Consórcio." % d.nome, "red"])
			else:
				out.append(["%s continua em revolta: %d dia para reprimir." % [d.nome, t.revolta], "red"])
			continue
		var before: int = t.lealdade
		t.lealdade = clampi(t.lealdade + loyalty_delta(i), 0, 100)
		if t.lealdade <= 0:
			t.revolta = 2
			out.append(["%s entrou em revolta! Reprima-a em até 2 dias ou o distrito volta ao Consórcio." % d.nome, "red"])
		elif t.lealdade < 25 and before >= 25:
			out.append(["%s está agitado: a renda do distrito caiu pela metade." % d.nome, "amber"])
	return out


# ---------------------------------------------------------------- laboratório
func res_by_id(id: String) -> Dictionary:
	for r in RESEARCH:
		if r.id == id:
			return r
	return {}


func res_avail(r: Dictionary) -> bool:
	if has(r.id):
		return false
	for q in r.get("req", []):
		if not has(q):
			return false
	return true


func pd_dia() -> int:
	return G.cientistas * PD_POR_CIENT


func lab_line() -> String:
	var a := res_by_id(G.pesq.ativo) if G.pesq.ativo else {}
	if a.is_empty():
		return "ocioso"
	var p: int = G.pesq.prog.get(a.id, 0)
	return "%s · %d dia(s)" % [a.nome, ceili(float(a.custo - p) / maxi(1, pd_dia()))]


func research_tick(extracted: bool) -> Array:
	var out := []
	if extracted:
		G.cientistas = mini(MAX_CIENT, G.cientistas + 2)
		out.append(["+2 cientistas desertaram com a extraída e se juntaram ao laboratório.", "cyan"])
	var saiu := 0
	while G.cientistas > 1 and G.dinheiro < G.cientistas * CIENT_SAL:
		G.cientistas -= 1
		saiu += 1
	if saiu:
		out.append(["Sem verba para salários: %d cientista(s) deixou o laboratório." % saiu, "red"])
	var sal := mini(G.dinheiro, G.cientistas * CIENT_SAL)
	G.dinheiro = maxi(0, G.dinheiro - sal)
	var a := res_by_id(G.pesq.ativo) if G.pesq.ativo else {}
	if not a.is_empty():
		G.pesq.prog[a.id] = G.pesq.prog.get(a.id, 0) + pd_dia()
		if G.pesq.prog[a.id] >= a.custo:
			G.pesq.done[a.id] = true
			G.pesq.ativo = ""
			out.append(["Pesquisa concluída: %s. %s" % [a.nome, a.desc], "green"])
			for r in RESEARCH:
				if res_avail(r):
					G.pesq.ativo = r.id
					out.append(["O laboratório começou %s." % r.nome, ""])
					break
		else:
			out.append(["Laboratório: +%d PD em %s (%d/%d)." % [pd_dia(), a.nome, G.pesq.prog[a.id], a.custo], ""])
	else:
		out.append(["O laboratório ficou ocioso. Escolha uma pesquisa.", "amber"])
	out.append(["Salários de %d cientistas: %s." % [G.cientistas, fmt(sal)], ""])
	return out


func imp_cap() -> int:
	return 1 + (1 if has("impl2") else 0) + (1 if has("impl3") else 0)


# ---------------------------------------------------------------- resultado da missão
## Aplica o resultado da missão M no distrito di e devolve o relatório para a tela de resultado.
func apply_result(M: Mission, di: int, revolta: bool) -> Dictionary:
	var D: Dictionary = DIST[di]
	var win := M.win
	var lost := []
	for u in M.agents:
		var a = u.ag
		if a == null:
			continue
		if u.dead:
			lost.append(a.nome)
			G.agentes.erase(a)
			G.esq.erase(a.id)
		else:
			a.inv = u.inv.map(func(it): return {t = it.t})
			a.missoes += 1
			a.abates += u.kills
	var rep := 0
	var bonus := 0
	for b in M.bonus:
		bonus += b.val
	var notes := []
	if win and revolta:
		var t := terr(di)
		t.revolta = 0
		t.lealdade = clampi(45 - 2 * M.stats.civis, 10, 60)
		rep = 1500
		notes.append(["A revolta em %s foi contida. Lealdade: %d." % [D.nome, t.lealdade], "green"])
	elif win:
		G.dono[di] = "player"
		rep = roundi((reward(di) + bonus) * (1.2 if has("informantes") else 1.0))
		var t := terr(di)
		t.imposto = .3
		t.revolta = 0
		t.lealdade = clampi(55 - 2 * M.stats.civis - 3 * M.stats.policiais, 10, 85)
		notes.append(["%s começa com lealdade %d%s." % [D.nome, t.lealdade, " (as vítimas civis pesaram)" if M.stats.civis else ""], ""])
	G.dinheiro += rep
	var renda := total_income() + VERBA
	G.dinheiro += renda
	var lab := research_tick(win and D.tipo == "extracao" and not revolta)
	G.dia += 1
	G.abates += M.stats.abates
	notes.append_array(territory_tick(di if win else -1))
	var novas := []
	var U := func(id: String):
		if unlock(id):
			novas.append(id)
	for id in M.rival_seen:
		U.call(id + "_visto")
	for id in M.rival_dead:
		U.call(id + "_morto")
		var s: Dictionary = G.rivais.get(id, {})
		s.morto = true
		G.rivais[id] = s
	for id in M.rival_esc:
		var s: Dictionary = G.rivais.get(id, {})
		s.fugas = s.get("fugas", 0) + 1
		G.rivais[id] = s
	if win and not revolta:
		if di == 0: U.call("docas")
		if di == 1: U.call("tanaka")
	var own := owned()
	if own >= 3: U.call("tres")
	if own >= 5: U.call("cinco")
	if own >= 7: U.call("sete")
	for i in DIST.size():
		if DIST[i].get("hq", false) and avail(i):
			U.call("hq")
	for k in G.terr:
		if G.terr[k].revolta:
			U.call("revolta")
			break
	var riv := []
	for id in M.rival_dead:
		riv.append(["%s está morto. Os Ponteiros perderam um dos seus." % GD.RIVALS[id].nome, "green"])
	for id in M.rival_esc:
		riv.append(["%s escapou e vai voltar." % GD.RIVALS[id].nome, "amber"])
	var vitoria: bool = win and D.get("hq", false) and not revolta
	if vitoria:
		G.vitoria = true
		G.wiped = M.flags.get("wiped", false)
		if not G.wiped:
			unlock("fim")
	var novos := []
	while G.agentes.size() < 3:
		var n := novo_agente()
		G.agentes.append(n)
		if G.esq.size() < 4:
			G.esq.append(n.id)
		novos.append(n.nome)
	if not novos.is_empty():
		riv.append(["A Ônix enviou %s de reposição: %s." % ["agentes" if novos.size() > 1 else "um agente", ", ".join(novos)], "cyan"])
	if not novas.is_empty():
		notes.append(["%d nova(s) mensagem(ns) interceptada(s). Veja em Interceptações no mapa." % novas.size(), "cyan"])
	save()
	var rows := [["Abates do esquadrão", str(M.stats.abates)], ["Seguidores recrutados", str(M.stats.seguidores)],
		["Civis atingidos", str(M.stats.civis)], ["Policiais abatidos", str(M.stats.policiais)],
		["Agentes perdidos", ", ".join(lost) if not lost.is_empty() else "nenhum"]]
	if win:
		for b in M.bonus:
			rows.append(["Bônus · " + b.text, fmt(b.val)])
	rows.append(["Recompensa total", fmt(rep)])
	rows.append(["Renda dos distritos + verba do Conselho", fmt(renda)])
	rows.append(["Fundos", fmt(G.dinheiro)])
	var title := "NOVA AURORA É DA ÔNIX" if vitoria else (("Revolta contida" if revolta else "Missão cumprida") if win else "Missão fracassada")
	return {win = win, title = title, dist = D.nome, dia = G.dia - 1, reason = M.reason, rows = rows,
		notes = riv + lab + notes, vitoria = vitoria, game_over = G.agentes.is_empty() and G.dinheiro < RECRUTA}
