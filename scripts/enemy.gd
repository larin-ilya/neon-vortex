# enemy.gd — простой вражеский корабль (Godot 3.6)
extends Area2D

const L_ENEMY = 8

const SpriteTex = preload("res://assets/textures/ship_enemy.png")

var game
var hp = 2
var vel = Vector2.ZERO
var t0 = 0.0
var amp = 40.0
var freq = 1.5
var base_y = 0.0
var dir = 1.0  # 1 = вправо, -1 = влево
var fire_t = 1.4
var fire_cd = 0.0
var blink = 0.0
var radius = 22.0

func init(g, pos, d):
	game = g
	global_position = pos
	base_y = pos.y
	dir = d
	fire_cd = rand_range(0.6, 2.0)  # не стрелять сразу при спавне
	var col = CollisionShape2D.new()
	var shp = CircleShape2D.new()
	shp.radius = radius
	col.shape = shp
	add_child(col)
	
	collision_layer = L_ENEMY
	collision_mask = 0  # только игрок обнаруживает врага (через area_entered игрока)
	
func _process(delta) -> void:
	if not game or not game.player_alive():
		queue_free()
		return
		
	t0 += delta
	var offset_y = amp * sin(freq * t0)
	global_position.x += 80.0 * dir * delta
	global_position.y = base_y + offset_y
	
	var vp = game.view_size()
	if global_position.x < -radius or global_position.x > vp.x + radius:
		queue_free()
	
	fire_cd -= delta
	# стреляем только когда корабль виден на экране (иначе «звук без действия»)
	var v = vp
	var visible = global_position.x > 30.0 and global_position.x < v.x - 30.0 \
		and global_position.y > 30.0 and global_position.y < v.y - 30.0
	if fire_cd <= 0.0 and visible:
		var player_pos = game.get_player_pos()
		if player_pos:
			var d = (player_pos - global_position).normalized()
			game.spawn_bullet(global_position, d, false)
			game.sfx_enemy_shoot()
			fire_cd = fire_t

func _draw() -> void:
	var a = 1.0
	if blink > 0.0:
		a = 0.3 if int(t0 * 10) % 2 == 0 else 1.0
		update()

	# мягкое красное свечение под текстурой
	draw_circle(Vector2.ZERO, radius * 1.15, Color(1.0, 0.2, 0.4, 0.10 * a))

	# текстура тарелки
	var tw = SpriteTex.get_width()
	var th = SpriteTex.get_height()
	var disp_h = radius * 2.6
	var s = disp_h / float(th)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_texture(SpriteTex, Vector2(-float(tw) / 2.0, -float(th) / 2.0), Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))