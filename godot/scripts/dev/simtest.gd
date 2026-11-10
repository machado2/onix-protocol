## Teste da simulação sem gráficos: Chave Fantasma, manto óptico, granada incendiária e pesquisas.
## godot --headless --path godot -- --simtest  (main.gd cria este nó e sai com o número de falhas)
extends Node

var fails := 0


func ok(cond: bool, msg: String) -> void:
	print(("OK   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1


func steps(sim: Sim, s: float) -> void:
	for k in int(s * 30):
		sim.update(1.0 / 30)


func _ready() -> void:
	Camp.save_path = "user://teste.sav"
	Camp.new_game()
	Camp.G.pesq.done["pentes"] = true
	Camp.G.pesq.done["blindagem"] = true
	var map := CityGen.generate(5, .5, 1)
	var M := Mission.new()
	M.setup(map, "eliminacao", 6, 5)
	var ag: Dictionary = Camp.G.agentes[0]
	ag.imp.chassi = 2
	ag.inv = [{t = "chave"}, {t = "pistola"}]
	M.populate([ag, ["manto", "smg"], ["incendiaria", "smg"], ["granada"]])
	var sim := Sim.new(M)
	sim.log_msg.connect(func(t, _c): print("   log: ", t))
	var a0: Unit = M.agents[0]
	ok(a0.max_hp == 240 and is_equal_approx(a0.armor, .08 + .14 + .1), "implantes e blindagem: hp %d armor %.2f" % [a0.max_hp, a0.armor])
	ok(M.agents[1].inv[1].mun == 54, "pentes estendidos: smg com %d balas" % M.agents[1].inv[1].mun)
	# chave fantasma numa torreta
	var tur: Unit = null
	for u in M.units:
		if u.kind == "torre":
			tur = u
			break
	ok(tur != null, "há torreta no distrito")
	for u in M.units:
		if u != tur and (u.fac == "corp" or u.fac == "police"):
			u.dead = true
	if tur:
		a0.x = tur.x + 1.5
		a0.y = tur.y
		M.walk[int(a0.y) * C.N + int(a0.x)] = 1
		a0.eq = 0
		sim.set_sel([a0])
		sim.issue_attack(tur)
		ok(a0.ord != null and a0.ord.k == "hack", "ordem de invasão dada")
		steps(sim, 3)
		ok(tur.fac == "player", "torreta invadida (fac=%s)" % tur.fac)
	# manto
	var a1: Unit = M.agents[1]
	a1.eq = 0
	steps(sim, 1)
	ok(a1.cloak, "manto ativo")
	ok(absf(a1.inv[0].bat - 24.0) < .1, "bateria do manto drenando (%.1f)" % a1.inv[0].bat)
	# granada incendiária
	var a2: Unit = M.agents[2]
	a2.eq = 0
	sim.set_sel([a2])
	var p: Vector2 = M.random_near(a2.x + signf(C.N / 2.0 - a2.x) * 3, a2.y + signf(C.N / 2.0 - a2.y) * 2, 1.5)
	sim.issue_ground(p)
	steps(sim, .2)
	print("   ord=%s nades=%s tile=%d" % [a2.ord, M.nades.map(func(q): return [q.wt, q.T]), M.tile[int(p.y) * C.N + int(p.x)]])
	steps(sim, 1.3)
	ok(M.fires.size() > 0, "incêndio criado (%d focos)" % M.fires.size())
	ok(a2.inv.size() == 1, "granada consumida")
	steps(sim, 14)
	ok(M.fires.is_empty(), "fogo apagou sozinho")
	# resultado na campanha
	M.win = true
	M.ended = true
	M.reason = "teste"
	var r: Dictionary = Camp.apply_result(M, 0, false)
	ok(Camp.G.dono[0] == "player" and r.win, "distrito conquistado no relatório")
	ok(Camp.G.dia == 2, "dia avançou")
	print("FALHAS: %d" % fails)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Camp.save_path))
	get_tree().quit(fails)
