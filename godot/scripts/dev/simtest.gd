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
	map.dyn_cars = true
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
	# carros: tráfego anda; agente entra, dirige pela rua e sai
	var traf: Array = M.cars.filter(func(c): return not c.scripted)
	ok(traf.size() >= 12, "tráfego virou veículos da simulação (%d)" % traf.size())
	var c0: Dictionary = traf[0]
	var p0 := Vector2(c0.x, c0.y)
	steps(sim, 2)
	ok(Vector2(c0.x, c0.y).distance_to(p0) > .5 or c0.stop_t > 0, "tráfego em movimento")
	var a1b: Unit = M.agents[1]
	var spot := sim._spot_near(c0.x, c0.y, 0)
	a1b.x = spot.x
	a1b.y = spot.y
	sim.set_sel([a1b])
	sim.issue_enter(c0)
	steps(sim, 3)
	ok(a1b.in_car == c0 and c0.player, "agente entrou no carro")
	var goal := Vector2(C.N / 2.0, C.N / 2.0)
	sim.issue_move(goal)
	ok(not c0.path.is_empty(), "rota pelas ruas (%d trechos)" % c0.path.size())
	var cp := Vector2(c0.x, c0.y)
	steps(sim, 4)
	ok(Vector2(c0.x, c0.y).distance_to(cp) > 2, "carro dirigido andou %.1f tiles" % Vector2(c0.x, c0.y).distance_to(cp))
	ok(Vector2(a1b.x, a1b.y).distance_to(Vector2(c0.x, c0.y)) < .5, "agente acompanha o carro")
	sim.exit_selected()
	ok(a1b.in_car == null and M.can_stand(a1b.x, a1b.y) and c0.occ.is_empty(), "agente saiu do carro")
	# mostradores neurais: sobrecarga leva ao colapso e gera dependência
	var a3: Unit = M.agents[3]
	sim.set_sel([a3])
	sim.set_preset(2)
	ok(a3.nr.r == .95 and sim.preset_of(a3) == 2, "predefinição SOBRECARGA aplicada")
	var e0 := a3.estab
	steps(sim, 1)
	ok(a3.estab < e0 and a3.neuro.spd > 1.4, "sobrecarga drena estabilidade (%.0f) e acelera (%.2f)" % [a3.estab, a3.neuro.spd])
	steps(sim, 30)
	ok(a3.colapso > 0 or a3.nr.r == .25, "colapso neural depois de sobrecarga longa")
	ok(a3.over > 5, "tempo em sobrecarga registrado (%.1f)" % a3.over)
	a0.over = 10
	# resultado na campanha
	M.win = true
	M.ended = true
	M.reason = "teste"
	var r: Dictionary = Camp.apply_result(M, 0, false)
	ok(Camp.G.dono[0] == "player" and r.win, "distrito conquistado no relatório")
	ok(Camp.G.dia == 2, "dia avançou")
	ok(Camp.agent(ag.id) == null or ag.dep == 15, "dependência neural acumulada (%d%%)" % ag.dep)
	print("FALHAS: %d" % fails)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Camp.save_path))
	get_tree().quit(fails)
