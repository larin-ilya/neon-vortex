# player.gd — корабль игрока (Godot 3.6)
extends Area2D

const L_PLAYER = 1
const L_ASTEROID = 4
const L_ENEMY = 8
const L_EBULLET = 16
const L_POWERUP = 32

const SpriteTex = preload("res://assets/textures/ship_player.png")

var game
var radius = 13.0
var speed = 460.0
var aim = Vector2(0, -1)
var max_hp = 3
var hp = 3
var shield = false
var iframes = 0.0
var alive = true
var fire_cd = 0.0
var spread = 0.0
var rapid = 0.0
var time = 0.0

func init(g, pos):
	game = g
	global_position = pos
	collision_layer = L_PLAYER
	collision_mask = L_ASTEROID | L_ENEMY | L_EBULLET | L_POWERUP
	var col = CollisionShape2D.new()
	var shp = CircleShape2D.new()
	shp.radius = radius
	col.shape = shp
	add_child(col)
	connect("area_entered", game, "_on_player_area_entered")
	
func _process(delta):
	if not alive: return
	
	time += delta
	if iframes > 0.0: iframes -= delta
	if spread > 0.0: spread -= delta
	if rapid > 0.0: rapid -= delta
	if fire_cd > 0.0: fire_cd -= delta
	
	var ax = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var ay = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var dir = Vector2(ax, ay)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	
	global_position += dir * speed * delta
	var vp = game.view_size()
	global_position.x = clamp(global_position.x, radius + 6.0, vp.x - radius - 6.0)
	global_position.y = clamp(global_position.y, radius + 40.0, vp.y - radius - 6.0)
	
	var m = get_global_mouse_position()
	aim = m - global_position
	if aim.length() > 4.0: aim = aim.normalized()
	
	rotation = aim.angle() + PI / 2.0  # корабль «смотрит» вверх (0,-1)
	
	if Input.is_action_pressed("fire") and fire_cd <= 0.0:
		fire_cd = 0.24 if rapid <= 0.0 else 0.10
		_game_fire()
	
	update()

func _game_fire() -> void:
	var n = 3 if spread > 0 else 1
	var base = aim.angle()
	for i in range(n):
		var off = 0.0
		if n == 3:
			off = (i - 1) * 0.22
		var d = Vector2(cos(base + off), sin(base + off))
		game.spawn_bullet(global_position + d * 20.0, d, true)
	if game != null:
		game.sfx_shoot()

func _draw() -> void:
	var blink = (iframes > 0.0 and int(time * 14) % 2 == 0)
	var a = 0.3 if blink else 1.0
	if not alive:
		return
	
	# двигательная струя (пламя)
	var fl = 10.0 + sin(time * 8.0) * 4.0
	var flame_pts = PoolVector2Array([
		Vector2(-4.0, radius + 2.0),
		Vector2(4.0, radius + 2.0),
		Vector2(0.0, radius + 2.0 + fl)
	])
	var flame_c = Color(1.0, 0.6, 0.2, 0.9 * a)
	draw_colored_polygon(flame_pts, flame_c)
	
	# текстура корабля (нос смотрит вверх, локально -y)
	var tw = SpriteTex.get_width()
	var th = SpriteTex.get_height()
	var disp_h = radius * 3.0
	var s = disp_h / float(th)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_texture(SpriteTex, Vector2(-float(tw) / 2.0, -float(th) / 2.0), Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
	
	# щит
	if shield:
		var shield_c = Color(0.4, 1.0, 0.6, 0.5 * a)
		draw_circle(Vector2.ZERO, radius + 8.0, shield_c)