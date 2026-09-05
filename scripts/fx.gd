# fx.gd - эффекты (взрывы, кольца, следы) (Godot 3.6)
extends Node2D

enum Kind { SPARKS, RING, TRAIL }

var kind
var t = 0.0
var duration = 0.5
var color = Color(1, 1, 1)
var particles = []   # каждый: {p: Vector2, v: Vector2, life: float, maxlife: float, size: float}
var ring_radius = 0.0
var ring_max = 40.0
var offset = Vector2.ZERO

func init(k, pos, col, dur):
	kind = k
	global_position = pos
	color = col
	duration = dur
	if kind == Kind.SPARKS:
		t = 0.0
		var count = 12 + randi() % 9
		for j in range(count):
			var a = randf() * 6.28318530718
			var sp = rand_range(60.0, 150.0)
			var v = Vector2(cos(a), sin(a)) * sp
			var p = Vector2.ZERO
			var life = rand_range(0.3, 0.8)
			var size = rand_range(2.0, 4.0)
			particles.append({"p": p, "v": v, "life": life, "maxlife": life, "size": size})
	elif kind == Kind.RING:
		ring_radius = 0.0
		ring_max = 60.0
	elif kind == Kind.TRAIL:
		pass

func _process(delta) -> void:
	t += delta
	if t >= duration:
		queue_free()
		return

	if kind == Kind.SPARKS:
		for p in particles:
			p["p"] += p["v"] * delta
			p["life"] -= delta
		update()
	elif kind == Kind.RING:
		ring_radius += 300.0 * delta
		update()
	elif kind == Kind.TRAIL:
		offset += Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0) * 50.0 * delta
		update()

func _draw() -> void:
	if kind == Kind.SPARKS:
		for p in particles:
			var life = p["life"]
			if life <= 0.0:
				continue
			var ml = p["maxlife"]
			var a = life / ml if ml > 0.0 else 0.0
			if a > 0.0:
				var c = Color(color.r, color.g, color.b, color.a * a)
				draw_circle(p["p"], p["size"] * a, c)
	elif kind == Kind.RING:
		var a = 1.0 - (ring_radius / ring_max)
		if a > 0.0:
			var c = Color(color.r, color.g, color.b, color.a * a)
			draw_circle(Vector2.ZERO, ring_radius, c)
	elif kind == Kind.TRAIL:
		var a = 1.0 - (t / duration)
		if a > 0.0:
			var c = Color(color.r, color.g, color.b, color.a * a)
			draw_rect(Rect2(offset.x - 2.0, offset.y - 2.0, 4.0, 4.0), c)
