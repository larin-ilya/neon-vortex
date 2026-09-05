# menu_ui.gd — неоновое меню игры: главный экран, Help, пауза, game over (Godot 3.6)
# Живёт на отдельном CanvasLayer поверх игрового мира. Управление:
# мышь (наведение/клик) + клавиатура (UP/DOWN или W/S, ENTER/Space — выбор, ESC/P — назад).
extends CanvasLayer

const VW = 1280.0
const VH = 720.0

# палитра
const C_CYAN = Color(0.35, 0.92, 1.0)
const C_MAG = Color(1.0, 0.22, 0.58)
const C_GOLD = Color(1.0, 0.86, 0.35)
const C_WHITE = Color(0.92, 0.95, 1.0)
const C_DIM = Color(0.0, 0.0, 0.0, 0.8)

var game = null
var backdrop = null          # Control c процедурным фоном (menu_bg.gd)
var dim = null               # затемнение для паузы
var music_on = true

var screens = {}             # имя экрана -> Control
var nav = {}                 # имя -> {buttons:[], idx:int}
var current = ""
var guard = 0                # кадры после открытия экрана (не глотать ввод)
var t = 0.0
var glow_labels = []         # подложки «свечения» заголовка (пульсация)
var title_front = null
var label_hi_main = null
var label_music = null
var label_over_score = null
var label_over_rec = null

func _ready():
	layer = 2

func setup(g) -> void:
	game = g
	backdrop = preload("res://scripts/menu_bg.gd").new()
	backdrop.rect_position = Vector2(0, 0)
	backdrop.rect_size = Vector2(VW, VH)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.visible = false

	dim = ColorRect.new()
	dim.color = C_DIM
	dim.rect_position = Vector2(0, 0)
	dim.rect_size = Vector2(VW, VH)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.visible = false

	_build_main()
	_build_controls()
	_build_pause()
	_build_over()
	close()

# ---------------------------------------------------------------- helpers

func _root() -> Control:
	var c = Control.new()
	c.rect_position = Vector2(0, 0)
	c.rect_size = Vector2(VW, VH)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _label(text, size, y, h, color) -> Label:
	var l = Label.new()
	l.text = text
	l.align = Label.ALIGN_CENTER
	l.valign = Label.VALIGN_CENTER
	l.rect_position = Vector2(0, y)
	l.rect_size = Vector2(VW, h)
	l.add_font_size_override("font", size)
	l.add_color_override("font_color", color)
	return l

func _line(x, y, text, size, color) -> Label:
	var l = Label.new()
	l.text = text
	l.align = Label.ALIGN_LEFT
	l.valign = Label.VALIGN_CENTER
	l.rect_position = Vector2(x, y)
	l.rect_size = Vector2(VW - x * 2.0, 40)
	l.add_font_size_override("font", size)
	l.add_color_override("font_color", color)
	return l

func _divider(y, alpha) -> ColorRect:
	var r = ColorRect.new()
	r.color = Color(C_MAG.r, C_MAG.g, C_MAG.b, alpha)
	r.rect_position = Vector2(420, y)
	r.rect_size = Vector2(440, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _btn(text, act, w, h) -> Button:
	var b = Button.new()
	b.text = text
	b.rect_min_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_font_size_override("font", 23)
	b.add_color_override("font_color", C_CYAN)
	b.add_color_override("font_color_hover", Color(1, 1, 1, 1))
	b.add_color_override("font_color_pressed", C_GOLD)

	var n = StyleBoxFlat.new()
	n.bg_color = Color(0.02, 0.01, 0.07, 0.9)
	n.border_color = Color(1.0, 0.3, 0.7, 0.55)
	n.set_border_width_all(2)
	n.set_corner_radius_all(9)
	n.content_margin_left = 18.0
	n.content_margin_right = 18.0
	n.content_margin_top = 8.0
	n.content_margin_bottom = 8.0

	var hv = StyleBoxFlat.new()
	hv.bg_color = Color(0.14, 0.02, 0.3, 0.96)
	hv.border_color = Color(0.4, 0.95, 1.0, 0.95)
	hv.set_border_width_all(2)
	hv.set_corner_radius_all(9)
	hv.content_margin_left = 18.0
	hv.content_margin_right = 18.0
	hv.content_margin_top = 8.0
	hv.content_margin_bottom = 8.0

	var pr = StyleBoxFlat.new()
	pr.bg_color = Color(0.05, 0.16, 0.25, 0.98)
	pr.border_color = C_GOLD
	pr.set_border_width_all(2)
	pr.set_corner_radius_all(9)
	pr.content_margin_left = 18.0
	pr.content_margin_right = 18.0
	pr.content_margin_top = 8.0
	pr.content_margin_bottom = 8.0

	b.add_stylebox_override("normal", n)
	b.add_stylebox_override("hover", hv)
	b.add_stylebox_override("pressed", pr)
	b.set_meta("sb_normal", n)
	b.set_meta("sb_hover", hv)
	b.set_meta("act", act)
	return b

func _make_button_list(acts_text, w, h, x, y, sep) -> Array:
	# acts_text: [ [text, act], ... ]; возвращает [контейнер, кнопки]
	var v = VBoxContainer.new()
	v.rect_position = Vector2(x, y)
	v.rect_size = Vector2(w, 20)
	v.add_constant_override("separation", sep)
	var out = []
	for pair in acts_text:
		var b = _btn(pair[0], pair[1], w, h)
		v.add_child(b)
		b.set_meta("i", out.size())
		b.connect("pressed", self, "_on_pressed", [b])
		b.connect("mouse_entered", self, "_on_hover", [b])
		out.append(b)
	return [v, out]

func _add_glow(parent, text, size, y, h, color, dx) -> Label:
	var l = _label(text, size, y, h, color)
	l.rect_position.x += dx
	parent.add_child(l)
	return l

# ---------------------------------------------------------------- экраны

func _build_main() -> void:
	var s = _root()
	screens["main"] = s

	# неоновый заголовок: 2 подложки (хроматическое свечение) + фронт
	var back_l = _add_glow(s, "NEON VORTEX", 100, 42, 140, Color(C_MAG.r, C_MAG.g, C_MAG.b, 0.55), -4.0)
	var back_r = _add_glow(s, "NEON VORTEX", 100, 42, 140, Color(0.2, 0.4, 1.0, 0.4), 4.0)
	glow_labels.append(back_l)
	glow_labels.append(back_r)
	var front = _label("NEON VORTEX", 100, 42, 140, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.98))
	s.add_child(front)
	title_front = front

	s.add_child(_label("PROCEDURAL SPACE SHOOTER", 20, 176, 34, Color(0.55, 0.85, 1.0, 0.75)))
	s.add_child(_divider(216, 0.4))

	label_hi_main = _label("", 23, 228, 36, C_GOLD)
	s.add_child(label_hi_main)

	# кнопки
	var acts = [
		["START GAME", "start"],
		["HOW TO PLAY", "controls"],
		["MUSIC : ON", "music"],
		["QUIT", "quit"]
	]
	var res = _make_button_list(acts, 430, 58, (VW - 430.0) / 2.0, 296, 14)
	s.add_child(res[0])
	nav["main"] = {"buttons": res[1], "idx": 0}
	label_music = res[1][2]

	s.add_child(_label("MOUSE: hover + click      KEYBOARD: UP/DOWN or W/S  |  ENTER/Space select  |  ESC back",
		16, 668, 30, Color(0.55, 0.62, 0.85, 0.9)))
	add_child(s)

func _build_controls() -> void:
	var s = _root()
	screens["controls"] = s
	s.add_child(_label("HOW TO PLAY", 56, 60, 76, C_CYAN))
	s.add_child(_divider(142, 0.35))

	# тёмная подложка для читаемости
	var panel = ColorRect.new()
	panel.color = Color(0.0, 0.0, 0.0, 0.42)
	panel.rect_position = Vector2(180, 165)
	panel.rect_size = Vector2(920, 420)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.add_child(panel)

	var y = 196.0
	var lines = [
		["MOVE ........ W A S D  /  ARROW KEYS", C_WHITE],
		["AIM ........ MOUSE", C_WHITE],
		["FIRE ........ LEFT CLICK / SPACE   (hold = auto)", C_WHITE],
		["PAUSE ....... ESC / P", C_WHITE],
		["", C_WHITE],
		["POWER-UPS", C_MAG],
		["TRIPLE SHOT      RAPID FIRE      SHIELD      EXTRA LIFE", C_WHITE],
		["", C_WHITE],
		["TIP: asteroids split when shot - big rocks score more", C_GOLD]
	]
	for ln in lines:
		if ln[0] != "":
			s.add_child(_line(240, y, ln[0], 21, ln[1]))
		y += 38.0

	var res = _make_button_list([["BACK TO MENU", "back"]], 340, 58, (VW - 340.0) / 2.0, 596, 0)
	s.add_child(res[0])
	nav["controls"] = {"buttons": res[1], "idx": 0}
	add_child(s)

func _build_pause() -> void:
	var s = _root()
	screens["pause"] = s
	s.add_child(_label("PAUSED", 64, 120, 90, C_CYAN))
	var acts = [
		["RESUME", "resume"],
		["RESTART", "restart"],
		["MAIN MENU", "to_menu"]
	]
	var res = _make_button_list(acts, 380, 58, (VW - 380.0) / 2.0, 260, 16)
	s.add_child(res[0])
	nav["pause"] = {"buttons": res[1], "idx": 0}
	s.add_child(_label("ESC or P - resume", 16, 650, 30, Color(0.6, 0.7, 0.9, 0.9)))
	add_child(s)

func _build_over() -> void:
	var s = _root()
	screens["over"] = s
	var g1 = _add_glow(s, "GAME OVER", 68, 110, 92, Color(C_MAG.r, C_MAG.g, C_MAG.b, 0.5), -3.0)
	var g2 = _add_glow(s, "GAME OVER", 68, 110, 92, Color(0.3, 0.3, 1.0, 0.35), 3.0)
	glow_labels.append(g1)
	glow_labels.append(g2)
	s.add_child(_label("GAME OVER", 68, 110, 92, Color(1.0, 0.75, 0.92, 0.98)))
	s.add_child(_label("FINAL SCORE", 22, 218, 30, Color(0.7, 0.78, 1.0, 0.9)))
	label_over_score = _label("0", 46, 248, 56, C_GOLD)
	s.add_child(label_over_score)
	label_over_rec = _label("NEW RECORD !", 24, 306, 34, C_CYAN)
	s.add_child(label_over_rec)
	label_over_rec.visible = false
	s.add_child(_divider(352, 0.3))

	var acts = [
		["PLAY AGAIN", "start"],
		["MAIN MENU", "to_menu"]
	]
	var res = _make_button_list(acts, 380, 58, (VW - 380.0) / 2.0, 380, 16)
	s.add_child(res[0])
	nav["over"] = {"buttons": res[1], "idx": 0}
	add_child(s)

# ---------------------------------------------------------------- открытие/закрытие

func _show_only(name) -> void:
	for k in screens.keys():
		screens[k].visible = (k == name)
	current = name
	guard = 3
	if nav.has(name):
		nav[name]["idx"] = 0
	_paint_selection()

func open_main() -> void:
	_sync_hi()
	_sync_music_label()
	_show_only("main")
	backdrop.visible = true
	dim.visible = false

func open_pause() -> void:
	_show_only("pause")
	backdrop.visible = false
	dim.visible = true

func open_over(score, is_rec) -> void:
	if label_over_score != null:
		label_over_score.text = str(score)
	if label_over_rec != null:
		label_over_rec.visible = is_rec
	_show_only("over")
	backdrop.visible = true
	dim.visible = false

func open_controls() -> void:
	_show_only("controls")
	backdrop.visible = true
	dim.visible = false

func close() -> void:
	current = ""
	for k in screens.keys():
		screens[k].visible = false
	backdrop.visible = false
	dim.visible = false

func is_open() -> bool:
	return current != ""

func _sync_hi() -> void:
	if label_hi_main != null and game != null:
		label_hi_main.text = "HIGH SCORE    " + ("%06d" % game.hi)

func _sync_music_label() -> void:
	if label_music != null:
		if music_on:
			label_music.text = "MUSIC : ON"
		else:
			label_music.text = "MUSIC : OFF"

# ---------------------------------------------------------------- навигация

func _paint_selection() -> void:
	if not nav.has(current):
		return
	var btns = nav[current]["buttons"]
	for b in btns:
		b.add_stylebox_override("normal", b.get_meta("sb_normal"))
	var sel = btns[nav[current]["idx"]]
	sel.add_stylebox_override("normal", sel.get_meta("sb_hover"))

func _on_hover(b) -> void:
	if current == "" or guard > 0:
		return
	var i = int(b.get_meta("i"))
	if i != nav[current]["idx"]:
		nav[current]["idx"] = i
		_paint_selection()
		if game != null:
			game.sfx_ui()

func _on_pressed(b) -> void:
	if guard > 0:
		return
	var act = b.get_meta("act")
	_do_action(act)

func _sfx() -> void:
	if game != null:
		game.sfx_ui()

func _do_action(act) -> void:
	if current == "":
		return
	if act == "start":
		_sfx()
		if game != null:
			game.menu_start()
	elif act == "controls":
		_sfx()
		open_controls()
	elif act == "music":
		music_on = not music_on
		_sync_music_label()
		_sfx()
		if game != null:
			game.menu_toggle_music(music_on)
	elif act == "back":
		if current == "controls":
			_sfx()
			open_main()
	elif act == "resume":
		_sfx()
		if game != null:
			game.menu_resume()
	elif act == "restart":
		_sfx()
		if game != null:
			game.menu_restart()
	elif act == "to_menu":
		_sfx()
		if game != null:
			game.menu_to_menu()
	elif act == "quit":
		_sfx()
		if game != null:
			game.menu_quit()

func _process(delta) -> void:
	t += delta
	if guard > 0:
		guard -= 1
	# пульсация свечения заголовков
	var pulse = 0.5 + 0.5 * sin(t * 2.4)
	for l in glow_labels:
		if l != null and is_instance_valid(l):
			l.modulate.a = 0.4 * pulse + 0.25
	if current == "":
		return
	# клавиатура
	var up = Input.is_action_just_pressed("ui_up") or Input.is_action_just_pressed("move_up")
	var dn = Input.is_action_just_pressed("ui_down") or Input.is_action_just_pressed("move_down")
	var ok = Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("start")
	var back = Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("pause_game")
	if guard > 0:
		return
	var btns = nav[current]["buttons"]
	var idx = nav[current]["idx"]
	if up:
		idx -= 1
		if idx < 0:
			idx = btns.size() - 1
		nav[current]["idx"] = idx
		_paint_selection()
		_sfx()
	elif dn:
		idx += 1
		if idx >= btns.size():
			idx = 0
		nav[current]["idx"] = idx
		_paint_selection()
		_sfx()
	elif ok:
		var act = btns[idx].get_meta("act")
		_do_action(act)
	elif back:
		if current == "pause":
			_do_action("resume")
		elif current == "controls":
			_do_action("back")
