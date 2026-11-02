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

func _ready() -> void:
	game = get_parent()
	hp = max_hp

func _process(delta: float) -> void:
	if game.combat_frozen or dead or game.game_over:
		return
	hurt_flash = maxf(0.0, hurt_flash - delta)
	contact_timer = maxf(0.0, contact_timer - delta)
	var to_player: Vector2 = game.player.global_position - global_position
	velocity = velocity.move_toward(Vector2.ZERO, knockback_decay * 100.0 * delta)
	if velocity.length() < 20.0 and to_player.length() > 30.0:
		position += to_player.normalized() * speed * delta
	position += velocity * delta
	position.x = clampf(position.x, 25.0, game.arena_size.x - 25.0)
	position.y = clampf(position.y, 25.0, game.arena_size.y - 25.0)
	if to_player.length() < 35.0 and contact_timer <= 0.0:
		contact_timer = contact_cooldown
		game.player.take_damage(contact_damage, global_position)
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
	draw_circle(Vector2(0, 12), 17, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, 17, Color.WHITE if hurt_flash > 0.0 else Color(0.57, 0.43, 0.79))
	draw_circle(Vector2(-5, -3), 2.5, Color(0.12, 0.09, 0.18))
	draw_circle(Vector2(5, -3), 2.5, Color(0.12, 0.09, 0.18))
	draw_rect(Rect2(-20, -28, 40, 4), Color(0.12, 0.1, 0.17))
	draw_rect(Rect2(-20, -28, 40 * maxf(0.0, float(hp) / max_hp), 4), Color(1.0, 0.44, 0.5))
