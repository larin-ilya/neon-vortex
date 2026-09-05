# starfield.gd — многослойный параллакс-фон: три слоя звёзд с разной скоростью (Godot 3.6)
extends Node2D

const W = 1280.0
const H = 720.0

# базовые скорости слоёв (дальний медленнее, ближний быстрее)
const base_speed = 16.0

# конфигурация слоёв: count, множитель скорости, размеры, альфа, цвет
var layer_cfg = [
	{"count": 85, "spd": 0.8, "rmin": 0.5, "rmax": 1.3, "amin": 0.2, "amax": 0.55, "c": Color(0.7, 0.8, 1.0)},
	{"count": 50, "spd": 2.2, "rmin": 0.8, "rmax": 1.9, "amin": 0.35, "amax": 0.8, "c": Color(1, 1, 1)},
	{"count": 24, "spd": 4.4, "rmin": 1.4, "rmax": 2.8, "amin": 0.6, "amax": 1.0, "c": Color(1.0, 0.95, 0.85)}
]

var stars = []  # каждый: {l: индекс слоя, pos, r, sp, a}

func _ready():
	randomize()
	for li in range(layer_cfg.size()):
		var cfg = layer_cfg[li]
		for i in range(cfg.count):
			stars.append({
				"l": li,
				"pos": Vector2(randf() * W, randf() * H),
				"r": rand_range(cfg.rmin, cfg.rmax),
				"sp": rand_range(0.6, 1.5),
				"a": rand_range(cfg.amin, cfg.amax)
			})

func _process(delta):
	for s in stars:
		var cfg = layer_cfg[s.l]
		s["pos"].y += base_speed * cfg.spd * s["sp"] * delta
		if s["pos"].y > H + 10.0:
			s["pos"].y = -10.0
			s["pos"].x = randf() * W
	update()

func _draw():
	for s in stars:
		var cfg = layer_cfg[s.l]
		var c = cfg.c
		draw_circle(s["pos"], s["r"], Color(c.r, c.g, c.b, s["a"]))
