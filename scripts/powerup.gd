# powerup.gd - бонусы (Godot 3.6)
extends Area2D

const L_POWERUP = 32
const PU_TRIPLE = 0
const PU_RAPID = 1
const PU_LIFE = 2
const PU_SHIELD = 3

const GemTex = preload("res://assets/textures/gem_powerup.png")

var game
var kind = PU_TRIPLE
var radius = 16.0
var speed = 60.0
var ttl = 14.0
var phase = 0.0

func init(g, k):
	game = g
	kind = k
	var col = CollisionShape2D.new()
	var shp = CircleShape2D.new()
	shp.radius = radius
	col.shape = shp
	add_child(col)

	collision_layer = L_POWERUP
	collision_mask = 0  # только игрок обнаруживает бонус

func _process(delta) -> void:
	ttl -= delta
	if ttl <= 0.0:
		queue_free()
		return

	phase += delta * 2.0
	global_position.y += speed * delta
	var vp = game.view_size()
	if global_position.y > vp.y + 50.0:
		queue_free()
	update()

func _draw() -> void:
	var a = clamp(ttl / 14.0, 0.0, 1.0)
	var base_c = Color(0.2, 0.6, 1.0)
	if kind == PU_TRIPLE:
		base_c = Color(0.2, 0.8, 0.2)
	elif kind == PU_RAPID:
		base_c = Color(0.9, 0.8, 0.2)
	elif kind == PU_LIFE:
		base_c = Color(0.9, 0.25, 0.25)
	elif kind == PU_SHIELD:
		base_c = Color(0.7, 0.3, 0.9)

	var fade = 0.5 + 0.5 * sin(phase * 5.0)
	var col = Color(base_c.r, base_c.g, base_c.b, a * fade)

	# внешнее свечение
	draw_circle(Vector2.ZERO, radius * 1.7, Color(col.r, col.g, col.b, col.a * 0.15))

	# кристалл-текстура, тонированная цветом типа бонуса
	var tw = GemTex.get_width()
	var th = GemTex.get_height()
	var disp_h = radius * 2.3
	var s = disp_h / float(th)
	var tcol = base_c.linear_interpolate(Color(1, 1, 1), 0.3)
	tcol.a = col.a
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_texture(GemTex, Vector2(-float(tw) / 2.0, -float(th) / 2.0), tcol)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))

	# внутренний символ по типу бонуса
	var ic = Color(1, 1, 1, col.a)
	if kind == PU_TRIPLE:
		draw_line(Vector2(0, -6), Vector2(0, 6), ic, 2.0, true)
		draw_line(Vector2(-5, -3), Vector2(5, 3), ic, 2.0, true)
		draw_line(Vector2(-5, 3), Vector2(5, -3), ic, 2.0, true)
	elif kind == PU_RAPID:
		draw_line(Vector2(-6, -5), Vector2(-6, 5), ic, 2.0, true)
		draw_line(Vector2(-2, -5), Vector2(-2, 5), ic, 2.0, true)
		draw_line(Vector2(2, -5), Vector2(2, 5), ic, 2.0, true)
		draw_line(Vector2(6, -5), Vector2(6, 5), ic, 2.0, true)
	elif kind == PU_LIFE:
		draw_line(Vector2(0, -6), Vector2(0, 6), ic, 2.0, true)
		draw_line(Vector2(-6, 0), Vector2(6, 0), ic, 2.0, true)
	elif kind == PU_SHIELD:
		draw_arc(Vector2.ZERO, 7.0, 0.0, 6.28318530718, 24, ic, 2.0, true)
