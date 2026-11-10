## Dados do jogo (porte de v2/js/core.js): armas, tipos de unidade, resistência à sonda neural.
## Distâncias em tiles (1 tile = 3 m). As velocidades foram multiplicadas por SPEED para combinar com a escala
## realista dos personagens (na versão web um tile tinha ~1,6 m).
class_name GD

const SPEED := 0.55

const WD := {
	pistola = {nome = "Pistola Vespa", ab = "VESPA", arma = true, dano = 15.0, alcance = 6.0, cad = .42, pente = 12, recarga = 1.1, disp = .05, som = "pist"},
	smg = {nome = "Submetralhadora Enxame", ab = "ENXAME", arma = true, dano = 8.0, alcance = 6.5, cad = .085, pente = 36, recarga = 1.6, disp = .11, som = "smg"},
	escopeta = {nome = "Escopeta Trovão", ab = "TROVÃO", arma = true, dano = 10.0, pellets = 6, alcance = 4.5, cad = .8, pente = 8, recarga = 2.0, disp = .2, som = "shot"},
	feixe = {nome = "Rifle de Feixe Agulha", ab = "AGULHA", arma = true, laser = true, dano = 75.0, alcance = 11.0, cad = 1.5, pente = 6, recarga = 2.2, som = "laser"},
	serra = {nome = "Minigun Serra", ab = "SERRA", arma = true, dano = 10.0, alcance = 7.5, cad = .045, pente = 220, recarga = 3.4, disp = .13, peso = true, som = "smg"},
	chamas = {nome = "Lança-chamas Brasa", ab = "BRASA", arma = true, flame = true, dano = 2.4, alcance = 3.2, cad = .05, pente = 160, recarga = 2.6, som = "flame"},
	granada = {nome = "Granada PEM", ab = "GRANADA", throw = true, dano = 85.0, raio = 2.3, alcance = 7.0},
	medkit = {nome = "Kit Médico", ab = "MEDKIT", heal = true},
	sonda = {nome = "Sonda Neural", ab = "SONDA", sonda = true, alcance = 2.6},
	incendiaria = {nome = "Granada incendiária", ab = "INCEND.", throw = true, incend = true, dano = 35.0, raio = 1.4, alcance = 7.0},
	manto = {nome = "Manto óptico", ab = "MANTO", manto = true},
	chave = {nome = "Chave Fantasma", ab = "CHAVE", hack = true, alcance = 3.0},
}

const KIND := {
	agente = {fac = "player", hp = 120.0, spd = 2.4},
	civil = {fac = "civ", hp = 30.0, spd = 1.1},
	policia = {fac = "police", hp = 60.0, spd = 1.5, w = "pistola", acc = .5},
	guarda = {fac = "corp", hp = 70.0, spd = 1.7, w = "pistola", acc = .5},
	inimigo = {fac = "corp", hp = 140.0, spd = 2.2, w = "smg", acc = .65, armor = .2},
	vip = {fac = "corp", hp = 55.0, spd = 1.5},
	cientista = {fac = "neutral", hp = 110.0, spd = 2.2, armor = .25},
	torre = {fac = "corp", hp = 160.0, spd = 0.0, w = "smg", acc = .6, armor = .3},
	drone = {fac = "corp", hp = 60.0, spd = 2.8, w = "smg", acc = .5, armor = .15},
}

## segundos de sonda (com força 1) para converter cada tipo
const RESIST := {civil = 1.2, policia = 3.0, guarda = 5.0, inimigo = 10.0}

const CODINOMES := ["Corvo", "Lince", "Víbora", "Mantis", "Falcão", "Garça", "Cobalto", "Sombra"]
const VIPS := ["Diretor Halvard Reis", "Executiva Mirela Kroft", "Vice-presidente Otto Sá", "Diretora Ines Vahl", "Conselheiro Rui Takeda"]
const CIENT := ["Dra. Lia Moraes", "Dr. Kenji Albuquerque", "Dra. Sofia Tanaka", "Dr. Bento Okafor"]
const TIPOS := {assassinato = "Assassinato", extracao = "Extração", sabotagem = "Sabotagem", eliminacao = "Eliminação"}

## Os Ponteiros: agentes de elite do Consórcio (v2/js/story.js)
const RIVALS := {
	navalha = {nome = "Navalha", w = "escopeta", hp = 320.0, armor = .3, spd = 2.7, acc = .78},
	sibila = {nome = "Sibila", w = "feixe", hp = 260.0, armor = .25, spd = 2.2, acc = .9},
	ferro = {nome = "Ferro-Velho", w = "serra", hp = 520.0, armor = .45, spd = 1.7, acc = .7},
	mariposa = {nome = "Mariposa", w = "chamas", hp = 300.0, armor = .3, spd = 2.5, acc = .8},
	juiz = {nome = "O Juiz", w = "feixe", hp = 620.0, armor = .45, spd = 2.1, acc = .9, hq_only = true},
}
