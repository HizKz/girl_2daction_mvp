class_name Fighter
extends Node2D

signal damaged(hp: int)

@export var max_hp := 100
@export var switch_cooldown := 1.35
@export var dodge_duration := 0.23
@export var dodge_speed := 520.0
@export var combo_reset_time := 0.85
@export var input_buffer_time := 0.20

var characters: Array[CharacterStats] = [preload("res://resources/character_a.tres"), preload("res://resources/character_b.tres")]
var character_index := 0
var hp := 100
var facing := Vector2.RIGHT
var attack_timer := 0.0
var combo_timer := 0.0
var combo_step := 0
var buffered_attack := 0.0
var switch_timer := 0.0
var skill_timers := [0.0, 0.0]
var dodge_timer := 0.0
var invulnerable := 0.0
var flash := 0.0
var game
var frozen_attack_input := false
var frozen_switch_input := false

func _ready() -> void:
	game = get_parent()
	hp = max_hp

func _input(event: InputEvent) -> void:
	if game != null and game.combat_frozen:
		if event.is_action_pressed("attack"):
			frozen_attack_input = true
		if event.is_action_pressed("switch_character"):
			frozen_switch_input = true

func _process(delta: float) -> void:
	if game.combat_frozen:
		return
	switch_timer = maxf(0.0, switch_timer - delta)
	for i in skill_timers.size():
		skill_timers[i] = maxf(0.0, skill_timers[i] - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	flash = maxf(0.0, flash - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0:
		combo_step = 0
	buffered_attack = maxf(0.0, buffered_attack - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	dodge_timer = maxf(0.0, dodge_timer - delta)

	var switch_pressed := Input.is_action_just_pressed("switch_character") or frozen_switch_input
	var attack_pressed := Input.is_action_just_pressed("attack") or frozen_attack_input
	frozen_switch_input = false
	frozen_attack_input = false
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move.length() > 0.1 and dodge_timer <= 0.0:
		facing = move.normalized()
	# Switch has priority and cancels normal attacks, preserving the hit combo.
	if switch_pressed and switch_timer <= 0.0:
		_switch_character()
	elif Input.is_action_just_pressed("dodge") and dodge_timer <= 0.0:
		dodge_timer = dodge_duration
		invulnerable = dodge_duration + 0.08
		attack_timer = 0.0
		buffered_attack = 0.0
		game.spawn_effect(global_position, characters[character_index].color, 36.0)
	elif Input.is_action_just_pressed("skill") and skill_timers[character_index] <= 0.0 and dodge_timer <= 0.0 and attack_timer <= 0.0:
		_skill()
	elif attack_pressed and dodge_timer <= 0.0:
		if attack_timer <= 0.0:
			_attack()
		else:
			buffered_attack = input_buffer_time
	if buffered_attack > 0.0 and attack_timer <= 0.0 and dodge_timer <= 0.0:
		buffered_attack = 0.0
		_attack()

	if dodge_timer > 0.0:
		position += facing * dodge_speed * delta
	elif attack_timer <= 0.0:
		position += move * characters[character_index].speed * delta
	else:
		position += move * characters[character_index].speed * 0.22 * delta
	position.x = clampf(position.x, 35.0, game.arena_size.x - 35.0)
	position.y = clampf(position.y, 35.0, game.arena_size.y - 35.0)
	queue_redraw()

func _attack() -> void:
	var stats := characters[character_index]
	combo_step = combo_step % 3 + 1
	combo_timer = combo_reset_time
	attack_timer = stats.attack_durations[combo_step - 1]
	game.perform_attack(global_position, facing, stats.attack_range, stats.damages[combo_step - 1], stats.knockbacks[combo_step - 1], stats.color, false)

func _switch_character() -> void:
	character_index = 1 - character_index
	var stats := characters[character_index]
	switch_timer = switch_cooldown
	attack_timer = 0.28
	buffered_attack = 0.0
	combo_timer = combo_reset_time
	invulnerable = maxf(invulnerable, 0.18)
	game.perform_attack(global_position, facing, stats.attack_range + 25.0, stats.switch_damage, 330.0, stats.color, true)

func _skill() -> void:
	var stats := characters[character_index]
	skill_timers[character_index] = stats.skill_cooldown
	attack_timer = 0.42
	game.perform_attack(global_position, facing, stats.attack_range + 35.0, stats.skill_damage, 380.0, stats.color, true)

func take_damage(amount: int, from: Vector2) -> void:
	if invulnerable > 0.0 or hp <= 0:
		return
	hp = maxi(0, hp - amount)
	invulnerable = 0.75
	flash = 0.2
	position += (global_position - from).normalized() * 20.0
	damaged.emit(hp)
	game.player_hit()

func _draw() -> void:
	var c := characters[character_index].color
	if flash > 0.0 or (invulnerable > 0.0 and int(invulnerable * 16.0) % 2 == 0):
		c = Color.WHITE
	draw_circle(Vector2(0, 14), 18, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, 17, c)
	draw_circle(Vector2(0, -5), 8, c.lightened(0.45))
	draw_line(facing * 12.0, facing * 26.0, Color.WHITE, 3.0)
