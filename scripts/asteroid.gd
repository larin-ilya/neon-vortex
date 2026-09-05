# asteroid.gd — астероиды трёх размеров с разделением при попадании (Godot 3.6)
extends Area2D

const L_ASTEROID = 4

const RockTex = preload("res://assets/textures/rock_asteroid.png")

var game
var radius = 20.0
var vel = Vector2.ZERO
var hp = 1
var tint_m = 1.0
var rot_speed = 0.0
var tier = 2

func init(g, t, pos, v):
	game = g
	global_position = pos
	tier = t
	if t == 0:
		radius = rand_range(10.0, 14.0)
	elif t == 1:
		radius = rand_range(16.0, 22.0)
	elif t == 2:
		radius = rand_range(26.0, 34.0)
	else:
		radius = 20.0
	vel = v
	rot_speed = rand_range(-1.8, 1.8)
	tint_m = rand_range(0.85, 1.1)

	var col = CollisionShape2D.new()
	var shp = CircleShape2D.new()
	shp.radius = radius * 0.85
	col.shape = shp
	add_child(col)
	
	collision_layer = L_ASTEROID
	collision_mask = 0  # только игрок обнаруживает астероиды (через area_entered игрока)
	
func _process(delta) -> void:
	global_position += vel * delta
	rotation += rot_speed * delta
	var vp = game.view_size()
	if global_position.y - radius > vp.y + 80.0:
		queue_free()

func _draw() -> void:
	# лёгкое свечение, чтобы силуэт читался на тёмном фоне
	draw_circle(Vector2.ZERO, radius * 1.15, Color(0.3, 0.9, 1.0, 0.06))

	# текстура породы (масштаб от текущего радиуса тира)
	var tw = RockTex.get_width()
	var th = RockTex.get_height()
	var disp = radius * 2.05
	var s = disp / float(th)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_texture(RockTex, Vector2(-float(tw) / 2.0, -float(th) / 2.0), Color(tint_m, tint_m, tint_m, 1.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))