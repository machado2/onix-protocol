## Constantes e utilidades compartilhadas (porte de v2/js/core.js).
class_name C

const P := 11          # período da malha de quadras (2 tiles de rua + 9 de quadra)
const NB := 5          # quadras por lado
const N := NB * P + 2  # 57 tiles por lado
const TILE := 3.0      # metros por tile
const FLOOR_H := 3.2   # metros por andar
const CURB := 0.15     # altura da calçada

enum T { ROAD, WALK, BLD, GRASS, PLAZA, TREE, WATER, FENCE, POST, GLASS }

const SIGNS := ["FARMÁCIA 24H", "NEURO+", "HOTEL", "CAFÉ", "BAR", "IMPLANTES", "LOTERIA", "KARAOKÊ", "RAMEN",
	"PENHORES", "CLÍNICA", "ACADEMIA", "CYBER", "MOTEL", "SUSHI", "AÇAÍ", "PASTEL", "BOTECO"]
const NEON := [Color("#ff3d8b"), Color("#38e8ff"), Color("#ffb13d"), Color("#a66bff")]


## Gerador pseudoaleatório xorshift32, idêntico ao RNG(seed) do jogo em JS.
class Rng:
	var s: int

	func _init(seed: int) -> void:
		s = (seed * 2654435761) & 0xFFFFFFFF
		if s == 0:
			s = 1

	func next() -> float:
		s ^= (s << 13) & 0xFFFFFFFF
		s ^= s >> 17
		s ^= (s << 5) & 0xFFFFFFFF
		return float(s) / 4294967296.0

	func pick(a: Array) -> Variant:
		return a[int(next() * a.size())]

	func range_i(n: int) -> int:
		return int(next() * n)


static func hash01(x: float, y: float, z: float = 0.0) -> float:
	var v := sin(x * 127.1 + y * 311.7 + z * 74.7) * 43758.5453
	return v - floor(v)


static func tile_to_world(x: float, y: float, h: float = 0.0) -> Vector3:
	return Vector3(x * TILE, h, y * TILE)
