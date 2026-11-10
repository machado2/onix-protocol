## Missões feitas à mão por distrito (DIST de v2/js/core.js): nome, tipo, dificuldade e o script da missão.
class_name Missions

const DIST := {
	docas = {nome = "Docas Velhas", tipo = "assassinato", dif = 1},
	favela = {nome = "Vila Ferrugem", tipo = "extracao", dif = 2},
	mercado = {nome = "Mercado Suspenso", tipo = "sabotagem", dif = 2},
	neon = {nome = "Baixa Neon", tipo = "eliminacao", dif = 3},
	fundicao = {nome = "Setor Industrial 9", tipo = "sabotagem", dif = 4},
	lumen = {nome = "Distrito Lúmen", tipo = "assassinato", dif = 5},
	retiro = {nome = "Colinas de Vidro", tipo = "extracao", dif = 5},
	doca = {nome = "Cais Aéreo", tipo = "eliminacao", dif = 6},
	jardins = {nome = "Jardins Altos", tipo = "assassinato", dif = 7},
	torre = {nome = "Torre Central", tipo = "eliminacao", dif = 9},
}


static func script_for(id: String):
	match id:
		"docas": return MDocas
		"favela": return MFavela
		"mercado": return MMercado
		"neon": return MNeon
		"fundicao": return MFundicao
		"lumen": return MLumen
		"retiro": return MRetiro
		"doca": return MDoca
		"jardins": return MJardins
		"torre": return MTorre
	return null
