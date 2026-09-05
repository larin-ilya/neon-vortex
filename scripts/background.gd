# background.gd — текстурированный космический фон (Godot 3.6)
extends Node2D

const W = 1280.0
const H = 720.0
const Tex = preload("res://assets/textures/bg_nebula.jpg")

func _draw() -> void:
	draw_texture_rect(Tex, Rect2(0, 0, W, H), false)
