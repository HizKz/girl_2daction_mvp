class_name Fighter
extends Node2D

signal damaged(hp: int)
signal attack_started(stage: int)

@export var max_hp := 100
@export var switch_cooldown := 1.0
@export var dodge_duration := 0.23
@export var dodge_speed := 520.0
@export var combo_reset_time := 0.8

enum AttackState { IDLE, STARTUP, ACTIVE, RECOVERY }

var characters: Array[CharacterStats] = [preload("res://resources/character_a.tres"), preload("res://resources/character_b.tres")]
var character_index := 0
var hp := 100
var hp_values: Array[int] = [120, 90]
var skill_dash_timer := 0.0
var skill_dash_direction := Vector2.RIGHT
var skill_dash_hits: Dictionary = {}
# Generated front-facing sprites. Source regions trim transparent margins while
# retaining the full silhouette; the destination is anchored at the feet.
const CHARACTER_SPRITES: Array[Texture2D] = [
	preload("res://sprites/koharu/idle_down.png"),
	preload("res://sprites/mio/idle_down.png"),
]
const SPRITE_REGIONS: Array[Rect2] = [
	Rect2(190, 25, 820, 1270),
	Rect2(320, 80, 730, 1070),
]
var visual_time := 0.0
var moving := false
var facing := Vector2.RIGHT
var attack_direction := Vector2.RIGHT
var attack_state := AttackState.IDLE
var state_timer := 0.0
# Separate lock for switch attacks and skills.
var attack_timer := 0.0
var combo_timer := 0.0
var combo_step := 0
var buffered_attack := false
var pending_attack_input := false
var hit_targets: Dictionary = {}
var switch_timer := 0.0
var skill_timers := [0.0, 0.0]
var dodge_timer := 0.0
var invulnerable := 0.0
var flash := 0.0
var game
var frozen_switch_input := false

func _ready() -> void:
	game = get_parent()
	hp_values = [characters[0].max_hp, characters[1].max_hp]
	hp = hp_values[character_index]
	max_hp = characters[character_index].max_hp

func _input(event: InputEvent) -> void:
	# Events are edges, not held-key state; key-repeat events are rejected.
	if event.is_action_pressed("attack"):
		pending_attack_input = true
	if game != null and game.combat_frozen and event.is_action_pressed("switch_character"):
		frozen_switch_input = true

func _process(delta: float) -> void:
	if game.combat_frozen:
		return
	switch_timer = maxf(0.0, switch_timer - delta)
	for i in skill_timers.size():
		skill_timers[i] = maxf(0.0, skill_timers[i] - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	flash = maxf(0.0, flash - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	dodge_timer = maxf(0.0, dodge_timer - delta)
	# The timeout runs only after an attack finishes, not during its phases.
	if attack_state == AttackState.IDLE and attack_timer <= 0.0 and combo_timer > 0.0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0:
			combo_step = 0

	var switch_pressed := Input.is_action_just_pressed("switch_character") or frozen_switch_input
	var attack_pressed := pending_attack_input
	frozen_switch_input = false
	pending_attack_input = false
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	moving = move.length() > 0.1 or dodge_timer > 0.0 or skill_dash_timer > 0.0
	visual_time += delta
	if move.length() > 0.1 and dodge_timer <= 0.0:
		facing = move.normalized()
	if switch_pressed and switch_timer <= 0.0 and hp_values[1 - character_index] > 0:
		_switch_character()
	elif Input.is_action_just_pressed("dodge") and dodge_timer <= 0.0:
		skill_dash_timer = 0.0
		dodge_timer = dodge_duration
		invulnerable = dodge_duration + 0.08
		_cancel_normal_attack(true)
		attack_timer = 0.0
		game.spawn_effect(global_position, characters[character_index].color, 36.0)
	elif Input.is_action_just_pressed("skill") and skill_timers[character_index] <= 0.0 and dodge_timer <= 0.0 and attack_state == AttackState.IDLE and attack_timer <= 0.0:
		_skill()
	elif attack_pressed and dodge_timer <= 0.0:
		if attack_state == AttackState.IDLE and attack_timer <= 0.0:
			_attack()
		elif combo_step < 3:
			# One pending press can advance at most one stage.
			buffered_attack = true

	if attack_state != AttackState.IDLE:
		_advance_attack(delta)
	elif buffered_attack and attack_timer <= 0.0 and dodge_timer <= 0.0:
		buffered_attack = false
		_attack()

	if skill_dash_timer > 0.0:
		var dash_step := minf(delta, skill_dash_timer)
		position += skill_dash_direction * characters[character_index].skill.distance / characters[character_index].skill.duration * dash_step
		skill_dash_timer -= dash_step
		game.perform_attack(global_position, skill_dash_direction, 24.0, characters[character_index].skill.damage, 50.0, characters[character_index].color, true, skill_dash_hits, false, characters[character_index].mark, characters[character_index].mark_duration)
	elif dodge_timer > 0.0:
		position += facing * dodge_speed * delta
	elif attack_timer <= 0.0 and attack_state == AttackState.IDLE:
		position += move * characters[character_index].speed * delta
	else:
		position += move * characters[character_index].speed * 0.22 * delta
	position.x = clampf(position.x, 35.0, game.arena_size.x - 35.0)
	position.y = clampf(position.y, 35.0, game.arena_size.y - 35.0)
	queue_redraw()

func _attack() -> void:
	combo_step = clampi(combo_step + 1, 1, 3)
	combo_timer = 0.0
	attack_direction = facing
	hit_targets.clear()
	attack_state = AttackState.STARTUP
	state_timer = characters[character_index].attack_startup[combo_step - 1]
	attack_started.emit(combo_step)

func _advance_attack(delta: float) -> void:
	var remaining := delta
	while attack_state != AttackState.IDLE:
		if attack_state == AttackState.ACTIVE:
			_check_normal_hits(false)
			if game.combat_frozen:
				return
		if remaining < state_timer:
			state_timer -= remaining
			return
		remaining -= state_timer
		var stats := characters[character_index]
		match attack_state:
			AttackState.STARTUP:
				attack_state = AttackState.ACTIVE
				state_timer = stats.attack_active[combo_step - 1]
				_check_normal_hits(true)
				if game.combat_frozen:
					return
			AttackState.ACTIVE:
				attack_state = AttackState.RECOVERY
				state_timer = stats.attack_recovery[combo_step - 1]
			AttackState.RECOVERY:
				attack_state = AttackState.IDLE
				if combo_step == 3:
					combo_step = 0
					combo_timer = 0.0
					buffered_attack = false
				else:
					combo_timer = combo_reset_time
					if buffered_attack:
						buffered_attack = false
						_attack()

func _check_normal_hits(show_effect: bool) -> void:
	var stats := characters[character_index]
	var index := combo_step - 1
	if stats.projectile:
		if show_effect:
			game.spawn_projectile(global_position, attack_direction, stats, stats.damages[index])
	else:
		game.perform_attack(global_position, attack_direction, stats.attack_ranges[index], stats.damages[index], stats.knockbacks[index], stats.color, false, hit_targets, show_effect, stats.mark, stats.mark_duration)

func _cancel_normal_attack(reset_combo: bool) -> void:
	attack_state = AttackState.IDLE
	state_timer = 0.0
	hit_targets.clear()
	buffered_attack = false
	if reset_combo:
		combo_step = 0
		combo_timer = 0.0

func _switch_character() -> void:
	if hp_values[1 - character_index] <= 0:
		return
	if combo_step == 3:
		_cancel_normal_attack(true)
	else:
		_cancel_normal_attack(false)
		combo_timer = combo_reset_time if combo_step > 0 else 0.0
	skill_dash_timer = 0.0
	character_index = 1 - character_index
	var stats := characters[character_index]
	hp = hp_values[character_index]
	max_hp = stats.max_hp
	switch_timer = switch_cooldown
	attack_timer = 0.28
	invulnerable = maxf(invulnerable, 0.18)
	var combo := stats.switch_attack
	var targets: Array[TrainingEnemy] = []
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.mark == combo.required_mark and enemy.mark_timer > 0.0 and global_position.distance_to(enemy.global_position) <= combo.range_px:
			targets.append(enemy)
	if targets.is_empty():
		game.spawn_effect(global_position, stats.color, 32.0)
		return
	if combo.kind == "dash_single":
		targets.sort_custom(func(a: TrainingEnemy, b: TrainingEnemy) -> bool: return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
		var target: TrainingEnemy = targets[0]
		var direction := (target.global_position - global_position).normalized()
		position = target.position - direction * 30.0
		target.apply_mark("", 0.0)
		game.hit_enemy(target, combo.damage, direction, 120.0)
	else:
		for target in targets:
			var direction := (target.global_position - global_position).normalized()
			target.apply_mark("", 0.0)
			game.hit_enemy(target, combo.damage, direction, 50.0)
	game.spawn_effect(global_position, stats.color, combo.range_px * 0.35)

func _skill() -> void:
	var stats := characters[character_index]
	var skill := stats.skill
	skill_timers[character_index] = skill.cooldown
	attack_timer = 0.42
	if skill.kind == "dash":
		skill_dash_timer = skill.duration
		skill_dash_direction = facing
		skill_dash_hits.clear()
	else:
		game.add_slow_field(global_position, skill)
		game.spawn_effect(global_position, stats.color, skill.radius)

func take_damage(amount: int, from: Vector2) -> void:
	if invulnerable > 0.0 or hp <= 0:
		return
	hp = maxi(0, hp - amount)
	hp_values[character_index] = hp
	invulnerable = 0.75
	flash = 0.2
	position += (global_position - from).normalized() * 20.0
	damaged.emit(hp)
	game.player_hit()
	if hp <= 0 and hp_values[1 - character_index] > 0:
		_switch_character()

func _draw() -> void:
	var color := characters[character_index].color
	# The origin is the floor contact point and remains unchanged by animation.
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, 19, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(facing * 20.0, facing * 29.0, color.lightened(0.4), 3.0, true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sprite: Texture2D = CHARACTER_SPRITES[character_index]
	var source: Rect2 = SPRITE_REGIONS[character_index]
	var height := 58.0
	var width := height * source.size.x / source.size.y
	var bob := -absf(sin(visual_time * 11.0)) * 2.5 if moving else -absf(sin(visual_time * 2.5)) * 0.7
	var lunge := attack_direction * 4.0 if attack_state == AttackState.ACTIVE else Vector2.ZERO
	var tint := Color(2.0, 2.0, 2.0, 1.0) if flash > 0.0 else Color.WHITE
	if invulnerable > 0.0 and flash <= 0.0 and int(invulnerable * 16.0) % 2 == 0:
		tint.a = 0.55
	# Only horizontal mirroring is available until directional sprites are drawn.
	var mirror := -1.0 if facing.x < -0.1 else 1.0
	draw_set_transform(Vector2(lunge.x, bob + lunge.y), 0.0, Vector2(mirror, 1.0))
	draw_texture_rect_region(sprite, Rect2(-width / 2.0, -height, width, height), source, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
