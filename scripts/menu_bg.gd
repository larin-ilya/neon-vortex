# menu_bg.gd — сгенерированный анимированный фон для экранов меню (Godot 3.6)
# Полностью процедурный «ретро-неон»: градиентное небо, закатное солнце с полосами,
# перспективная сетка-пол (synthwave), мерцающие звёзды и виньетка.
# Никаких внешних текстур — всё рисуется кодом.
extends Control

const W = 1280.0
const H = 720.0
const HORIZON = 470.0
const SUN_R = 150.0
const SUN_CX = W / 2.0

const COL_SKY_TOP = Color(0.016, 0.004, 0.055)
const COL_SKY_MID = Color(0.09, 0.03, 0.22)
const COL_SKY_HZ = Color(0.22, 0.05, 0.36)
const COL_FLOOR_TOP = Color(0.03, 0.008, 0.09)
const COL_FLOOR_BOT = Color(0.12, 0.03, 0.24)
const COL_SUN_TOP = Color(1.0, 0.93, 0.42)
const COL_SUN_MID = Color(1.0, 0.5, 0.28)
const COL_SUN_BOT = Color(1.0, 0.16, 0.48)
const COL_SLAT = Color(0.03, 0.012, 0.08)   # цвет прорезей солнца (близок к небу)
const COL_GRID_V = Color(1.0, 0.18, 0.55, 0.5)
const COL_GRID_H = Color(0.55, 0.25, 1.0, 0.55)
const COL_GLOW = Color(1.0, 0.35, 0.25)

var t = 0.0
var stars_pos = []   # Vector2
var stars_ph = []    # float фаза мерцания
var stars_r = []     # float радиус
var stars_c = []     # Color

func _ready():
	# статичные звёзды над горизонтом
	randomize()
	for i in range(90):
		var x = randf() * W
		var y = randf() * (HORIZON - 150.0)
		stars_pos.append(Vector2(x, y))
		stars_ph.append(randf() * 6.283)
		stars_r.append(rand_range(0.6, 2.2))
		var cold = randf() < 0.7
		if cold:
			stars_c.append(Color(0.75, 0.85, 1.0, 1.0))
		else:
			stars_c.append(Color(1.0, 0.7, 0.85, 1.0))
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta):
	t += delta
	update()

func _lerp3(a, b, c, g) -> Color:
	# g в [0,1]: a->b->c (двухступенчатый lerp)
	if g < 0.5:
		return a.linear_interpolate(b, g * 2.0)
	return b.linear_interpolate(c, (g - 0.5) * 2.0)

func _draw():
	_draw_sky()
	_draw_stars()
	_draw_sun()
	_draw_floor()
	_draw_grid()
	_draw_vignette()

func _draw_sky() -> void:
	# вертикальный градиент неба, линия на строку
	for y in range(int(HORIZON) + 1):
		var g = float(y) / HORIZON
		var c = COL_SKY_TOP
		if g < 0.55:
			c = COL_SKY_TOP.linear_interpolate(COL_SKY_MID, g / 0.55)
		else:
			c = COL_SKY_MID.linear_interpolate(COL_SKY_HZ, (g - 0.55) / 0.45)
		draw_line(Vector2(0, y), Vector2(W, y), c, 1.0)

func _draw_stars() -> void:
	for i in range(stars_pos.size()):
		var tw = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * 2.6 + stars_ph[i]))
		var c = stars_c[i]
		draw_circle(stars_pos[i], stars_r[i], Color(c.r, c.g, c.b, 0.85 * tw))

func _draw_sun() -> void:
	var cy = HORIZON
	# свечение вокруг солнца
	for i in range(7, 0, -1):
		var rr = SUN_R * 0.85 + float(i) * 26.0
		var a = 0.05 / float(i)
		draw_circle(Vector2(SUN_CX, cy), rr, Color(COL_GLOW.r, COL_GLOW.g, COL_GLOW.b, a * 0.5))
	# диск с прорезями (строки сверху вниз к горизонту)
	var top = int(cy - SUN_R * 2.0)
	for yy in range(top, int(cy)):
		var off = float(cy - yy)                 # 2R вверху .. 0 у горизонта
		var half = sqrt(max(0.0, SUN_R * SUN_R - (off - SUN_R) * (off - SUN_R)))
		var g = float(cy - yy) / (SUN_R * 2.0)   # 0 верх .. 1 низ
		var col = _lerp3(COL_SUN_TOP, COL_SUN_MID, COL_SUN_BOT, g)
		# прорези: пропускаем часть строк
		var slat = int(g * 30.0) % 4 == 3
		if slat:
			col = COL_SLAT
		draw_line(Vector2(SUN_CX - half, yy), Vector2(SUN_CX + half, yy), col, 1.0)

func _draw_floor() -> void:
	for y in range(int(HORIZON) + 1, int(H) + 1):
		var g = float(y - HORIZON) / (H - HORIZON)
		var c = COL_FLOOR_TOP.linear_interpolate(COL_FLOOR_BOT, g)
		draw_line(Vector2(0, y), Vector2(W, y), c, 1.0)

func _draw_grid() -> void:
	var vx = SUN_CX + sin(t * 0.35) * 14.0
	var vy = HORIZON + 2.0
	# вертикальные лучи, сходящиеся к точке схода
	var spread = 720.0
	for i in range(-9, 10):
		var xb = SUN_CX + float(i) * spread / 9.0
		draw_line(Vector2(vx, vy), Vector2(xb, H), COL_GRID_V, 1.0)
	# горизонтальные линии «едут» на зрителя
	for idx in range(16):
		var z = fmod(float(idx) / 16.0 + t * 0.14, 1.0)
		var y = vy + (H - vy) * pow(z, 2.4)
		var a = 0.12 + 0.4 * (1.0 - z)
		var c = Color(COL_GRID_H.r, COL_GRID_H.g, COL_GRID_H.b, a)
		draw_line(Vector2(0, y), Vector2(W, y), c, 1.0)

func _draw_vignette() -> void:
	var steps = 26
	# тёмные края по периметру
	for i in range(steps):
		var a = 0.012 * (float(i) + 1.0)
		var d = float(i) * 3.0
		draw_rect(Rect2(0, 0, d, H), Color(0, 0, 0, a), true)
		draw_rect(Rect2(W - d, 0, d, H), Color(0, 0, 0, a), true)
		draw_rect(Rect2(0, 0, W, d), Color(0, 0, 0, a), true)
		draw_rect(Rect2(0, H - d, W, d), Color(0, 0, 0, a), true)
