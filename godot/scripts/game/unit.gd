## Uma unidade da simulação (porte do objeto criado por mkUnit em v2/js/world.js).
## Posição em tiles (x, y); y do mapa vira z no mundo 3D.
class_name Unit
extends RefCounted

var id := 0
var kind := ""
var fac := ""
var x := 0.0
var y := 0.0
var hp := 100.0
var max_hp := 100.0
var armor := 0.0
var spd := 1.0
var acc := .5
var w := ""            # arma da IA
var mun := 0
var face := 0.0
var path: Array = []
var pidx := 0
var cur_spd := 0.0     # velocidade no último quadro (tiles/s), para a animação
var cool := 0.0
var rel := 0.0
var rel_st = null      # dicionário do item (agentes) ou a própria unidade
var rel_w := ""
var tgt: Unit = null
var alerted := false
var dead := false
var death_t := 0.0
var panic_t := 0.0
var pfx := 0.0
var pfy := 0.0
var idle_t := 0.0
var rep_t := 0.0
var perc_t := 0.0
var scan_t := 0.0
var burn := 0.0
var burn_src: Unit = null
var flash := 0.0
var hit_t := 0.0
var aim_t := 0.0
var lost_t := 0.0
var hunt_t := 0.0
var hj := 0.0          # progresso da sonda neural
var hj_t := 0.0
var follower := false
var owner: Unit = null
var home = null        # Vector2 ou null
var lkp = null         # última posição conhecida do esquadrão
var cover = null
var cover_t := -1.0
var retreated := false
var nades := 0
var nade_t := 0.0
var supp := 0.0
var supp_p := 0.0
var contact := false
var warned := false
var warn_t := 0.0
var seeing: Unit = null
var lost := 0.0
var invest := false
var escort: Unit = null
var mech := false
var heavy := false
var nome := ""
var last_hit := -99.0
var kb = null          # empurrão de explosão {x, y, p}
var still := false
# VIP
var route: Array = []
var ri := 0
var fleeing := false
# cientista
var follow := false
# agentes
var num := 0
var inv: Array = []    # [{t, mun}]
var eq := -1
var ord = null         # dicionário da ordem atual
var auto_t: Unit = null
var kills := 0
var sel := false
var rng_mul := 1.0
var probing := false
var pulse_t := 0.0
var cov_t := 0.0
var covered := false
var seed := 0
var view = null        # Character3D
# missões feitas à mão
var tags := {}         # marcas livres usadas pelos roteiros (worker, morador, cell, clinic...)
var off := false       # torreta/drone desligado
var dance := false
var disguise := false
var reveal_p := 0.0
var cand := false      # candidato a alvo (sósias)
var double := false
var scanned := false
var scan_p := 0.0
var pylon := false
var shield := false
var boss := false
var hold := false
var safe_room := false
var safe := false
var flee_msg := ""
var flee_to = null
var board_t := 0.0
var vanished := false
var rival := ""
var escaping := false
var esc_t := 0.0
var in_car = null      # dicionário do carro
var scripted := false
var fly := false
var view_kind := ""    # força o modelo 3D (ex.: "enemy" para rivais)


func pos2() -> Vector2:
	return Vector2(x, y)


func dist_to(o: Unit) -> float:
	return Vector2(o.x - x, o.y - y).length()
