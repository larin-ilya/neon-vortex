# main.gd - основной сценарий игры (Godot 3.6)
extends Node2D

# экран и масштаб
const VW = 1280.0
const VH = 720.0

# слои столкновений
const L_PLAYER = 1
const L_ASTEROID = 4
const L_ENEMY = 8
const L_EBULLET = 16
const L_POWERUP = 32
const L_BULLET = 2

# состояния игры
const STATE_TITLE = 0
const STATE_PLAY = 1
const STATE_OVER = 2
const STATE_PAUSE = 3

# префабы
const BgSc = preload("res://scripts/background.gd")
const PlayerSc = preload("res://scripts/player.gd")
const BulletSc = preload("res://scripts/bullet.gd")
const AsteroidSc = preload("res://scripts/asteroid.gd")
const EnemySc = preload("res://scripts/enemy.gd")
const PowerupSc = preload("res://scripts/powerup.gd")
const FxSc = preload("res://scripts/fx.gd")
const StarfieldSc = preload("res://scripts/starfield.gd")
const MenuUiSc = preload("res://scripts/menu_ui.gd")

# аудио: SFX — WAV (AudioStreamSample), loop_mode выключен в _sfx(); музыка — OGG.
# Меню-музыка: yd/XCVG ambient (OpenGameArt). Боевая: Bensound — House,
# лицензия: assets/audio/Bensound_House_LICENSE.txt (bensound.com, RKTVGSVKAAHGUL1P).
const S_MENU = preload("res://assets/audio/bgm_menu.ogg")
const S_BATTLE = preload("res://assets/audio/bgm_battle_house.ogg")
const S_SHOOT = preload("res://assets/audio/sfx_player_shoot.wav")
const S_ESHOOT = preload("res://assets/audio/sfx_enemy_shoot.wav")
const S_BOOM_S = preload("res://assets/audio/sfx_boom_small.wav")
const S_BOOM_B = preload("res://assets/audio/sfx_boom_big.wav")
const S_HURT = preload("res://assets/audio/sfx_hurt.wav")
const S_PICKUP = preload("res://assets/audio/sfx_pickup.wav")
const S_UI = preload("res://assets/audio/sfx_ui.wav")

var game
var player
var state = STATE_TITLE
var paused = false
var selftest = false
var score = 0
var hi = 0
var lives = 3
var time = 0.0

# спавн таймеры
var asteroid_timer = 0.0
var enemy_timer = 0.0
var powerup_timer = 0.0
var asteroid_base_interval = 3.0
var enemy_base_interval = 10.0
var powerup_base_interval = 1.0

# узлы
var starfield
var world
var fx_container
var hud_layer
var label_score
var label_lives
var label_hi
var label_title
var label_start
var label_pause
var label_game_over
var flash_rect
var music
var sfx_pool = []

# меню и настройки
var menu
var music_on = true
# диагностический прогон UI (NV_WALK=1): титул -> старт -> гибель -> game over -> выход
var walk = false
var walk_started = false
var walk_t = 0.0
var walk_file = null
var walk_over_logged = false

# --- диагностика аудио (NV_SELFTEST=1): пишет user://audiotest.log ---
var st_file = null
var st_list = []
var st_idx = 0
var st_t = 0.0
var st_phase = ""
var st_probe = null
var st_probe_start = 0.0
var st_cur_name = ""

func view_size():
	return Vector2(VW, VH)

func player_alive():
	return player != null and player.alive

func get_player_pos():
	if player != null and player.alive:
		return player.global_position
	return null

func _ready():
	randomize()
	selftest = OS.get_environment("NV_SELFTEST") == "1"
	walk = OS.get_environment("NV_WALK") == "1"
	_register_actions()
	_hi_load()
	_settings_load()

	# текстурированный фон (добавляется первым — рисуется позади всех)
	var bg = BgSc.new()
	add_child(bg)

	# звёздное поле
	starfield = StarfieldSc.new()
	add_child(starfield)

	# мир (астероиды, враги, бонусы, пули)
	world = Node2D.new()
	add_child(world)

	# эффекты
	fx_container = Node2D.new()
	add_child(fx_container)

	# HUD
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)

	# счёт
	label_score = Label.new()
	label_score.text = "SCORE: 0"
	label_score.align = Label.ALIGN_LEFT
	label_score.rect_position = Vector2(10, 8)
	label_score.rect_size = Vector2(360, 30)
	hud_layer.add_child(label_score)

	# жизни
	label_lives = Label.new()
	label_lives.text = "LIVES: 3"
	label_lives.align = Label.ALIGN_LEFT
	label_lives.rect_position = Vector2(10, 34)
	label_lives.rect_size = Vector2(360, 30)
	hud_layer.add_child(label_lives)

	# рекорд
	label_hi = Label.new()
	label_hi.text = "HI: 0"
	label_hi.align = Label.ALIGN_RIGHT
	label_hi.anchor_left = 1.0
	label_hi.anchor_right = 1.0
	label_hi.margin_left = -360.0
	label_hi.margin_right = -10.0
	label_hi.margin_top = 8.0
	label_hi.margin_bottom = 38.0
	hud_layer.add_child(label_hi)

	# заголовок
	label_title = Label.new()
	label_title.text = "NEON VORTEX"
	label_title.align = Label.ALIGN_CENTER
	label_title.valign = Label.VALIGN_CENTER
	label_title.anchor_left = 0.5
	label_title.anchor_right = 0.5
	label_title.anchor_top = 0.5
	label_title.anchor_bottom = 0.5
	label_title.margin_left = -300.0
	label_title.margin_right = 300.0
	label_title.margin_top = -185.0
	label_title.margin_bottom = -95.0
	hud_layer.add_child(label_title)

	# подсказка старт
	label_start = Label.new()
	label_start.text = "PRESS SPACE TO START"
	label_start.align = Label.ALIGN_CENTER
	label_start.valign = Label.VALIGN_CENTER
	label_start.anchor_left = 0.5
	label_start.anchor_right = 0.5
	label_start.anchor_top = 0.5
	label_start.anchor_bottom = 0.5
	label_start.margin_left = -200.0
	label_start.margin_right = 200.0
	label_start.margin_top = -25.0
	label_start.margin_bottom = 25.0
	hud_layer.add_child(label_start)

	# пауза
	label_pause = Label.new()
	label_pause.text = "PAUSE"
	label_pause.align = Label.ALIGN_CENTER
	label_pause.valign = Label.VALIGN_CENTER
	label_pause.anchor_left = 0.5
	label_pause.anchor_right = 0.5
	label_pause.anchor_top = 0.5
	label_pause.anchor_bottom = 0.5
	label_pause.margin_left = -120.0
	label_pause.margin_right = 120.0
	label_pause.margin_top = -20.0
	label_pause.margin_bottom = 20.0
	label_pause.visible = false
	hud_layer.add_child(label_pause)

	# game over
	label_game_over = Label.new()
	label_game_over.text = "GAME OVER"
	label_game_over.align = Label.ALIGN_CENTER
	label_game_over.valign = Label.VALIGN_CENTER
	label_game_over.anchor_left = 0.5
	label_game_over.anchor_right = 0.5
	label_game_over.anchor_top = 0.5
	label_game_over.anchor_bottom = 0.5
	label_game_over.margin_left = -250.0
	label_game_over.margin_right = 250.0
	label_game_over.margin_top = 65.0
	label_game_over.margin_bottom = 135.0
	label_game_over.visible = false
	hud_layer.add_child(label_game_over)

	# вспышка при ударе
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 0, 0, 0.0)
	flash_rect.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(flash_rect)

	# аудио: фоновый плеер + пул SFX (старт музыки — в _enter_title/_start_game)
	music = AudioStreamPlayer.new()
	music.stream = S_MENU
	music.volume_db = -7.0
	add_child(music)
	music.connect("finished", self, "_on_music_finished")
	for i in range(16):
		var sp = AudioStreamPlayer.new()
		sp.volume_db = -2.0
		add_child(sp)
		sfx_pool.append(sp)

	# игрок
	player = PlayerSc.new()
	world.add_child(player)
	player.init(self, Vector2(VW / 2.0, VH - 100.0))

	# меню-интерфейс (CanvasLayer поверх HUD)
	menu = MenuUiSc.new()
	add_child(menu)
	menu.setup(self)
	menu.music_on = music_on

	# состояние
	state = STATE_TITLE
	_enter_title()

func _add_action(name):
	if not InputMap.has_action(name):
		InputMap.add_action(name)
	InputMap.action_erase_events(name)

func _add_key(name, code):
	_add_action(name)
	var ev = InputEventKey.new()
	ev.scancode = code
	InputMap.action_add_event(name, ev)

func _add_key_events(name, codes) -> void:
	_add_action(name)
	for c in codes:
		var ev = InputEventKey.new()
		ev.scancode = c
		InputMap.action_add_event(name, ev)

func _register_actions() -> void:
	# движение: WASD + стрелки
	_add_key_events("move_left", [KEY_A, KEY_LEFT])
	_add_key_events("move_right", [KEY_D, KEY_RIGHT])
	_add_key_events("move_up", [KEY_W, KEY_UP])
	_add_key_events("move_down", [KEY_S, KEY_DOWN])
	# пауза: Esc + P
	_add_key_events("pause_game", [KEY_ESCAPE, KEY_P])
	# старт/выбор: Space + Enter
	_add_key_events("start", [KEY_SPACE, KEY_ENTER])
	# огонь: мышь (ЛКМ) + пробел
	_add_action("fire")
	var mouse = InputEventMouseButton.new()
	mouse.button_index = BUTTON_LEFT
	InputMap.action_add_event("fire", mouse)
	var space = InputEventKey.new()
	space.scancode = KEY_SPACE
	InputMap.action_add_event("fire", space)

func _hi_load() -> void:
	var f = File.new()
	if f.file_exists("user://hi.save"):
		f.open("user://hi.save", File.READ)
		var s = f.get_line().strip_edges()
		f.close()
		if s.is_valid_integer():
			hi = int(s)
		else:
			hi = 0
	else:
		hi = 0

func _hi_save() -> void:
	var f = File.new()
	f.open("user://hi.save", File.WRITE)
	f.store_line(str(hi))
	f.close()

func _settings_load() -> void:
	music_on = true
	var f = File.new()
	if f.file_exists("user://settings.save"):
		f.open("user://settings.save", File.READ)
		var s = f.get_line().strip_edges()
		f.close()
		if s.begins_with("music_on="):
			music_on = int(s.get_slice("=", 1)) != 0

func _settings_save() -> void:
	var f = File.new()
	f.open("user://settings.save", File.WRITE)
	f.store_line("music_on=" + str(int(music_on)))
	f.close()

func _set_flash(a) -> void:
	flash_rect.color = Color(1, 0, 0, a)

func _on_music_finished() -> void:
	if music != null and music_on:
		music.play()

func _play_music(stream) -> void:
	# ставим нужный трек всегда (чтобы при включении звука заиграл правильный);
	# играет только если музыка включена.
	if music == null:
		return
	if music.stream != stream:
		music.stream = stream
	if music_on:
		music.play()
	else:
		music.stop()

# --- SFX ---
func _sfx(stream, vol, pitch) -> void:
	# WAV-сэмплы: жёстко отключаем зацикливание на уровне ресурса —
	# это работает в рантайме и не зависит от настроек импорта.
	if stream is AudioStreamSample:
		stream.loop_mode = AudioStreamSample.LOOP_DISABLED
	var sp = null
	for p in sfx_pool:
		if not p.playing:
			sp = p
			break
	if sp == null:
		sp = sfx_pool[0]
	sp.stop()  # гарантия: любой хвост предыдущего воспроизведения обрывается
	sp.stream = stream
	sp.volume_db = vol
	sp.pitch_scale = pitch
	sp.play()  # ровно один проигрыш; зацикливание выключено на ресурсе

func sfx_shoot() -> void:
	_sfx(S_SHOOT, -12.0, rand_range(0.95, 1.05))

func sfx_enemy_shoot() -> void:
	_sfx(S_ESHOOT, -12.0, rand_range(0.9, 1.1))

func sfx_boom_small() -> void:
	_sfx(S_BOOM_S, -5.0, rand_range(0.9, 1.1))

func sfx_boom_big() -> void:
	_sfx(S_BOOM_B, -4.0, 1.0)

func sfx_hurt() -> void:
	_sfx(S_HURT, -4.0, 1.0)

func sfx_pickup() -> void:
	_sfx(S_PICKUP, -7.0, rand_range(0.95, 1.1))

func sfx_ui() -> void:
	_sfx(S_UI, -8.0, 1.0)

func _enter_title() -> void:
	# титульный экран: мир заморожен, HUD скрыт, открыто неоновое меню
	state = STATE_TITLE
	paused = false
	_world_set_paused(true)
	label_title.visible = false
	label_start.visible = false
	label_pause.visible = false
	label_game_over.visible = false
	label_score.visible = false
	label_lives.visible = false
	label_hi.visible = false
	_set_flash(0.0)
	if menu != null:
		menu.open_main()
	_play_music(S_MENU)

func _enter_play_ui() -> void:
	label_title.visible = false
	label_start.visible = false
	label_pause.visible = false
	label_game_over.visible = false
	label_score.visible = true
	label_lives.visible = true
	label_hi.visible = true
	_set_flash(0.0)

func _open_pause() -> void:
	if state != STATE_PLAY or paused:
		return
	paused = true
	_world_set_paused(true)
	if menu != null:
		menu.open_pause()

# --- колбэки из menu_ui ---
func menu_start() -> void:
	var f = File.new()
	if f.open("user://menu_start.log", File.WRITE):
		f.store_line("menu_start called at " + str(OS.get_unix_time()))
		f.close()
	_start_game()

func menu_controls() -> void:
	if menu != null:
		menu.open_controls()

func menu_resume() -> void:
	paused = false
	_world_set_paused(false)
	if menu != null:
		menu.close()

func menu_restart() -> void:
	paused = false
	_start_game()

func menu_to_menu() -> void:
	# сброс игрока и очистка мира, затем титул
	for c in world.get_children():
		if c != player:
			c.queue_free()
	for c in fx_container.get_children():
		c.queue_free()
	player.global_position = Vector2(VW / 2.0, VH - 100.0)
	player.rotation = PI / 2.0
	player.alive = true
	player.hp = player.max_hp
	player.iframes = 0.0
	player.shield = false
	player.fire_cd = 0.0
	player.spread = 0.0
	player.rapid = 0.0
	player.time = 0.0
	_enter_title()

func menu_quit() -> void:
	get_tree().quit()

func menu_toggle_music(on) -> void:
	music_on = on
	_settings_save()
	if music != null:
		if music_on:
			if not music.playing:
				music.play()
		else:
			music.stop()

func _world_set_paused(p) -> void:
	# приостановить/восстановить обработку мира и fx
	world.set_process(!p)
	world.set_physics_process(!p)
	fx_container.set_process(!p)
	fx_container.set_physics_process(!p)
	for c in world.get_children():
		if c.has_method("set_process"):
			c.set_process(!p)
			c.set_physics_process(!p)

func _spawn_asteroid(tier) -> void:
	var sx = randf() * VW
	var a = AsteroidSc.new()
	world.add_child(a)
	a.init(self, tier, Vector2(sx, -50.0), Vector2(0.0, rand_range(30.0, 80.0)))
	a.add_to_group("asteroid")

func _spawn_enemy() -> void:
	var side = randf() < 0.5
	var x = -40.0 if side else VW + 40.0
	var y = randf() * (VH - 100.0) + 50.0
	var dir = 1.0 if side else -1.0
	var e = EnemySc.new()
	world.add_child(e)
	e.init(self, Vector2(x, y), dir)
	e.add_to_group("enemy")

func _spawn_powerup() -> void:
	var sx = randf() * VW
	var p = PowerupSc.new()
	world.add_child(p)
	p.init(self, randi() % 4)
	p.global_position = Vector2(sx, -40.0)
	p.add_to_group("powerup")

func spawn_bullet(pos, dir, friendly) -> void:
	var b = BulletSc.new()
	world.add_child(b)
	b.init(self, pos, dir, friendly)
	if friendly:
		b.add_to_group("bullet")
	else:
		b.add_to_group("ebullet")

func _spawn_fx(kind, pos, col, dur) -> void:
	var f = FxSc.new()
	fx_container.add_child(f)
	f.init(kind, pos, col, dur)

func _hurt_player(pos) -> void:
	if lives <= 0:
		return
	if player != null and player.iframes > 0.0:
		return
	if player != null and player.shield:
		player.shield = false
	else:
		lives -= 1
		label_lives.text = "LIVES: " + str(lives)
	if lives > 0:
		if player != null:
			player.iframes = 1.2
		_spawn_fx(FxSc.Kind.SPARKS, pos, Color(1, 0.5, 0, 0.8), 0.6)
		_set_flash(0.35)
		sfx_hurt()
	else:
		_spawn_fx(FxSc.Kind.SPARKS, pos, Color(1, 0.5, 0, 0.9), 0.9)
		sfx_boom_big()
		# рекорд
		var is_rec = false
		if score > hi:
			hi = score
			is_rec = true
			_hi_save()
		# экран game over через меню
		state = STATE_OVER
		_world_set_paused(true)
		if menu != null:
			menu.open_over(score, is_rec)
		_play_music(S_MENU)

func _collect_powerup(p) -> void:
	if p == null:
		return
	var kind = p.kind
	if kind == PowerupSc.PU_TRIPLE:
		if player != null:
			player.spread = 2.5
	elif kind == PowerupSc.PU_RAPID:
		if player != null:
			player.rapid = 8.0
	elif kind == PowerupSc.PU_LIFE:
		if lives < 3:
			lives += 1
			label_lives.text = "LIVES: " + str(lives)
	elif kind == PowerupSc.PU_SHIELD:
		if player != null:
			player.shield = true
	_spawn_fx(FxSc.Kind.RING, p.global_position, Color(0.5, 0.5, 1, 0.6), 0.8)
	sfx_pickup()
	p.queue_free()

func _on_player_area_entered(area) -> void:
	if area == null:
		return
	if area.is_in_group("asteroid"):
		_hurt_player(area.global_position)
		sfx_boom_small()
		var tier = area.tier
		if tier > 0:
			_spawn_asteroid(tier - 1)
			_spawn_asteroid(tier - 1)
		area.queue_free()
	elif area.is_in_group("enemy"):
		sfx_boom_big()
		area.queue_free()
		_hurt_player(global_position)
	elif area.is_in_group("ebullet"):
		area.queue_free()
		_hurt_player(global_position)
	elif area.is_in_group("powerup"):
		_collect_powerup(area)

func _on_bullet_area_entered(hit, bullet) -> void:
	if hit == null or bullet == null:
		return
	if hit.is_in_group("asteroid"):
		score += 10 * (hit.tier + 1)
		label_score.text = "SCORE: " + str(score)
		_spawn_fx(FxSc.Kind.SPARKS, hit.global_position, Color(0, 1, 0.5, 0.7), 0.6)
		sfx_boom_small()
		var tier = hit.tier
		if tier > 0:
			_spawn_asteroid(tier - 1)
			_spawn_asteroid(tier - 1)
		hit.queue_free()
		bullet.queue_free()
	elif hit.is_in_group("enemy"):
		score += 50
		label_score.text = "SCORE: " + str(score)
		_spawn_fx(FxSc.Kind.SPARKS, hit.global_position, Color(0, 0.8, 1, 0.7), 0.8)
		sfx_boom_big()
		hit.queue_free()
		bullet.queue_free()
	elif hit.is_in_group("powerup"):
		_collect_powerup(hit)
		bullet.queue_free()

func _game_update(delta) -> void:
	time += delta
	asteroid_timer -= delta
	if asteroid_timer <= 0.0:
		asteroid_timer = rand_range(0.5, 2.0) * asteroid_base_interval
		var t = randi() % 4
		if t == 3:
			t = 2
		_spawn_asteroid(t)

	enemy_timer -= delta
	if enemy_timer <= 0.0:
		enemy_timer = rand_range(2.0, 5.0) * enemy_base_interval
		_spawn_enemy()

	powerup_timer -= delta
	if powerup_timer <= 0.0:
		powerup_timer = rand_range(10.0, 20.0) * powerup_base_interval
		_spawn_powerup()

	# HUD мигание рекорда если побит
	if score > hi:
		label_hi.modulate = Color(1, 1, 0, 0.5 + 0.5 * sin(time * 4.0))
	else:
		label_hi.modulate = Color(1, 1, 1, 1.0)

	# затухание вспышки
	if flash_rect.color.a > 0.0:
		var na = flash_rect.color.a - delta * 1.5
		if na < 0.0:
			na = 0.0
		_set_flash(na)

func _process(delta) -> void:
	if selftest:
		_selftest_process(delta)
		return
	if walk:
		_walk_process(delta)
		return

	# затухание вспышки и в остальных состояниях
	if flash_rect.color.a > 0.0:
		var na = flash_rect.color.a - delta * 1.5
		if na < 0.0:
			na = 0.0
		_set_flash(na)

	# пока открыто меню — вводом занимается menu_ui
	if menu != null and menu.is_open():
		return

	if state == STATE_PLAY:
		_game_update(delta)
		if Input.is_action_just_pressed("pause_game"):
			_open_pause()

func _walk_process(delta) -> void:
	# авто-прогон UI (NV_WALK=1): титул -> старт -> гибель -> game over -> выход
	walk_t += delta
	if walk_file == null:
		walk_file = File.new()
		walk_file.open("user://uiwalk.log", File.WRITE)
		walk_file.store_line("NV_WALK begin (boot + menu ok)")
	if walk_t > 0.8 and not walk_started:
		walk_started = true
		_start_game()
		if walk_file != null:
			walk_file.store_line("start_game ok -> battle music on")
	elif walk_started and state == STATE_PLAY and walk_t > 1.5:
		score = 150
		label_score.text = "SCORE: 150"
		lives = 1
		_hurt_player(player.global_position)
		if walk_file != null:
			walk_file.store_line("damage applied, lives=" + str(lives))
	if state == STATE_OVER and not walk_over_logged:
		walk_over_logged = true
		if walk_file != null:
			walk_file.store_line("game over screen open, hi=" + str(hi))
	if walk_t > 2.6:
		if walk_file != null:
			walk_file.store_line("NV_WALK done")
			walk_file.close()
			walk_file = null
		get_tree().quit()

func _start_game() -> void:
	state = STATE_PLAY
	paused = false
	score = 0
	lives = 3
	time = 0.0
	label_score.text = "SCORE: 0"
	label_lives.text = "LIVES: 3"
	label_hi.text = "HI: " + str(hi)
	label_hi.modulate = Color(1, 1, 1, 1.0)
	label_title.visible = false
	label_start.visible = false
	label_pause.visible = false
	label_game_over.visible = false

	# очистить мир
	for c in world.get_children():
		if c != player:
			c.queue_free()
	# очистить fx
	for c in fx_container.get_children():
		c.queue_free()

	# респавн игрока в центр низа (init вызывается только при первом создании)
	player.global_position = Vector2(VW / 2.0, VH - 100.0)
	player.rotation = PI / 2.0
	player.alive = true
	player.hp = player.max_hp
	player.iframes = 0.0
	player.shield = false
	player.fire_cd = 0.0
	player.spread = 0.0
	player.rapid = 0.0
	player.time = 0.0

	_world_set_paused(false)
	if menu != null:
		menu.close()
	_enter_play_ui()
	_play_music(S_BATTLE)
	sfx_ui()

# --- диагностика аудио: один прогон каждого SFX на отдельном плеере ---
func _selftest_begin() -> void:
	st_file = File.new()
	st_file.open("user://audiotest.log", File.WRITE)
	st_file.store_line("NV_SELFTEST audio diagnostics begin")
	st_list = [
		["S_SHOOT", S_SHOOT],
		["S_ESHOOT", S_ESHOOT],
		["S_BOOM_S", S_BOOM_S],
		["S_BOOM_B", S_BOOM_B],
		["S_HURT", S_HURT],
		["S_PICKUP", S_PICKUP],
		["S_UI", S_UI]
	]
	st_idx = 0
	st_t = 0.0
	st_phase = "next"
	music.stop()

func _selftest_done() -> void:
	if st_file != null:
		st_file.store_line("audio diagnostics done")
		st_file.close()
		st_file = null
	get_tree().quit()

func _selftest_process(delta) -> void:
	if st_file == null:
		_selftest_begin()
	st_t += delta

	if st_phase == "next":
		if st_idx >= st_list.size():
			_selftest_done()
			return
		st_cur_name = st_list[st_idx][0]
		st_probe = AudioStreamPlayer.new()
		st_probe.stream = st_list[st_idx][1]
		st_probe.volume_db = -6.0
		add_child(st_probe)
		st_probe.play()
		st_probe_start = st_t
		st_phase = "probe"
	elif st_phase == "probe":
		var elapsed = st_t - st_probe_start
		if st_probe != null and not st_probe.playing:
			st_file.store_line(st_cur_name + " stopped_after=" + str(elapsed))
			st_probe.queue_free()
			st_probe = null
			st_idx += 1
			st_phase = "next"
		elif elapsed > 6.0:
			st_file.store_line(st_cur_name + " LOOPED! still playing after 6s")
			if st_probe != null:
				st_probe.queue_free()
				st_probe = null
			st_idx += 1
			st_phase = "next"
