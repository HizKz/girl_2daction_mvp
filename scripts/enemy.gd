class_name TrainingEnemy
extends Node2D

signal defeated(enemy: TrainingEnemy)

@export var max_hp := 65
@export var speed := 85.0
@export var contact_damage := 10
@export var contact_cooldown := 1.0
@export var knockback_decay := 9.0
var hp := 65
var velocity := Vector2.ZERO
var hurt_flash := 0.0
var contact_timer := 0.0
var dead := false
var game
var mark := ""
var mark_timer := 0.0

func _ready() -> void:
	game = get_parent()
	hp = max_hp

func _process(delta: float) -> void:
	if game.combat_frozen or dead or game.game_over:
		return
	mark_timer = maxf(0.0, mark_timer - delta)
	if mark_timer <= 0.0:
		mark = ""
	hurt_flash = maxf(0.0, hurt_flash - delta)
	contact_timer = maxf(0.0, contact_timer - delta)
	var to_player: Vector2 = game.player.global_position - global_position
	velocity = velocity.move_toward(Vector2.ZERO, knockback_decay * 100.0 * delta)
	if velocity.length() < 20.0 and to_player.length() > 30.0:
		position += to_player.normalized() * speed * game.enemy_speed_multiplier(global_position) * delta
	position += velocity * delta
	position.x = clampf(position.x, 25.0, game.arena_size.x - 25.0)
	position.y = clampf(position.y, 25.0, game.arena_size.y - 25.0)
	if to_player.length() < 35.0 and contact_timer <= 0.0:
		contact_timer = contact_cooldown
		game.player.take_damage(contact_damage, global_position)
	queue_redraw()

func apply_mark(kind: String, duration: float) -> void:
	mark = kind
	mark_timer = duration
	queue_redraw()

func take_hit(damage: int, direction: Vector2, knockback: float) -> void:
	if dead:
		return
	hp -= damage
	velocity = direction.normalized() * knockback
	hurt_flash = 0.12
	if hp <= 0:
		dead = true
		defeated.emit(self)
		queue_free()
	queue_redraw()

func _draw() -> void:
	if mark != "":
		var mark_color := Color(1.0, 0.65, 0.25) if mark == "star" else Color(0.5, 0.85, 1.0)
		if mark == "star":
			draw_string(ThemeDB.fallback_font, Vector2(-6, -58), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, mark_color)
		else:
			draw_arc(Vector2(0, -64), 6.0, 0.8, 5.5, 16, mark_color, 3.0)
	# Keep the origin at the feet so Y sorting matches the floor contact point.
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 18, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := Color.WHITE if hurt_flash > 0.0 else Color(0.57, 0.43, 0.79)
	draw_line(Vector2(-10, -10), Vector2(-12, -2), body.darkened(0.3), 7.0, true)
	draw_line(Vector2(10, -10), Vector2(12, -2), body.darkened(0.3), 7.0, true)
	draw_circle(Vector2(0, -20), 18, body.darkened(0.22))
	draw_circle(Vector2(0, -23), 16, body)
	draw_circle(Vector2(-5, -22), 2.5, Color(0.12, 0.09, 0.18))
	draw_circle(Vector2(5, -22), 2.5, Color(0.12, 0.09, 0.18))
	draw_rect(Rect2(-20, -51, 40, 4), Color(0.12, 0.1, 0.17))
	draw_rect(Rect2(-20, -51, 40 * maxf(0.0, float(hp) / max_hp), 4), Color(1.0, 0.44, 0.5))
