# bullet.gd — пули игрока и врага (Godot 3.6)
extends Area2D

# слои
const L_BULLET = 2
const L_ASTEROID = 4
const L_ENEMY = 8
const L_EBULLET = 16
const L_PLAYER = 1
const L_POWERUP = 32

var game
var vel = Vector2.ZERO
var friendly = true
var life = 3.0
var dmg = 1
var radius = 5.0  # увеличил радиус для надёжного столкновения

func init(g, pos, dir, is_friendly):
	game = g
	global_position = pos
	vel = dir.normalized() * (720.0 if is_friendly else 300.0)
	friendly = is_friendly

	var col = CollisionShape2D.new()
	var shp = CircleShape2D.new()
	if friendly:
		shp.radius = radius
	else:
		shp.radius = 8.0  # вражеские пули чуть крупнее для видимости
	col.shape = shp
	add_child(col)

	collision_layer = L_BULLET if friendly else L_EBULLET
	if friendly:
		collision_mask = L_ASTEROID | L_ENEMY | L_POWERUP
	else:
		collision_mask = L_PLAYER

	if friendly:
		connect("area_entered", game, "_on_bullet_area_entered", [self])

func _process(delta):
	life -= delta
	if life <= 0.0:
		queue_free()

func _physics_process(delta):
	global_position += vel * delta
	var vp = game.view_size()
	if global_position.x < -radius or global_position.x > vp.x + radius or global_position.y < -radius or global_position.y > vp.y + radius:
		queue_free()

func _draw() -> void:
	var glow_c = Color(0.2, 0.9, 1.0, 0.2) if friendly else Color(1.0, 0.3, 0.8, 0.2)
	draw_circle(Vector2.ZERO, radius + 4.0, glow_c)
	var core_c = Color(0.2, 0.9, 1.0, 0.9) if friendly else Color(1.0, 0.3, 0.8, 0.9)
	draw_circle(Vector2.ZERO, radius, core_c)