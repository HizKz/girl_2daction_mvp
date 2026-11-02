extends Node2D

@export var arena_size := Vector2(1500, 900)
@export var enemy_limit := 6
@export var enemy_spawn_interval := 1.6
@export var hit_stop_duration := 0.045
@export var hit_stop_heavy := 0.075
@export var shake_amount := 5.0
@export var shake_duration := 0.14
@export var hit_combo_timeout := 2.0

var player: Fighter
var camera: Camera2D
var hud: CanvasLayer
var status_label: Label
var instructions_label: Label
var enemies: Array[TrainingEnemy] = []
var effects: Array[Dictionary] = []
var spawn_timer := 0.0
var freeze_timer := 0.0
var combat_frozen := false
var shake_timer := 0.0
var combo_count := 0
var combo_timer := 0.0
var kills := 0
var game_over := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	_setup_inputs()
	rng.randomize()
	player = Fighter.new()
	player.position = arena_size / 2.0
	add_child(player)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	player.add_child(camera)
	_make_hud()
	for i in 4:
		_spawn_enemy()

func _setup_inputs() -> void:
	var keys := {"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D, "attack": KEY_J, "skill": KEY_K, "dodge": KEY_SPACE, "switch_character": KEY_L, "restart": KEY_R}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = keys[action]
		InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
	if game_over and Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	freeze_timer = maxf(0.0, freeze_timer - delta)
	combat_frozen = freeze_timer > 0.0
	shake_timer = maxf(0.0, shake_timer - delta)
	camera.offset = Vector2(rng.randf_range(-shake_amount, shake_amount), rng.randf_range(-shake_amount, shake_amount)) * (shake_timer / maxf(shake_duration, 0.001)) if shake_timer > 0.0 else Vector2.ZERO
	for effect in effects:
		effect.time -= delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.time > 0.0)
	if not game_over and not combat_frozen:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = enemy_spawn_interval
			if enemies.size() < enemy_limit:
				_spawn_enemy()
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0:
			combo_count = 0
	_update_hud()
	queue_redraw()

func perform_attack(origin: Vector2, direction: Vector2, attack_range: float, damage: int, knockback: float, color: Color, wide: bool) -> void:
	var hit_any := false
	# Duplicate because defeating an enemy removes it from the tracked array.
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var offset: Vector2 = enemy.global_position - origin
		if offset.length() <= attack_range + 17.0 and (wide or offset.length() < 24.0 or direction.dot(offset.normalized()) >= 0.25):
			var hit_direction: Vector2 = offset.normalized() if offset.length() > 1.0 else direction
			enemy.take_hit(damage, hit_direction, knockback)
			combo_count += 1
			combo_timer = hit_combo_timeout
			spawn_effect(enemy.global_position, Color.WHITE, 24.0)
			hit_any = true
	effects.append({"pos": origin, "direction": direction, "radius": attack_range, "time": 0.18, "duration": 0.18, "color": color, "wide": wide, "slash": true})
	if hit_any:
		freeze_timer = hit_stop_heavy if wide else hit_stop_duration
		shake_timer = shake_duration

func spawn_effect(pos: Vector2, color: Color, radius: float) -> void:
	effects.append({"pos": pos, "radius": radius, "time": 0.24, "duration": 0.24, "color": color, "slash": false})

func player_hit() -> void:
	shake_timer = shake_duration
	spawn_effect(player.global_position, Color(1, 0.25, 0.35), 40.0)
	if player.hp <= 0:
		game_over = true
		player.set_process(false)

func _spawn_enemy() -> void:
	var enemy := TrainingEnemy.new()
	var angle := rng.randf_range(0.0, TAU)
	var distance := rng.randf_range(260.0, 420.0)
	enemy.position = player.position + Vector2.from_angle(angle) * distance
	enemy.position.x = clampf(enemy.position.x, 30.0, arena_size.x - 30.0)
	enemy.position.y = clampf(enemy.position.y, 30.0, arena_size.y - 30.0)
	enemy.defeated.connect(_on_enemy_defeated)
	enemies.append(enemy)
	add_child(enemy)

func _on_enemy_defeated(enemy: TrainingEnemy) -> void:
	kills += 1
	enemies.erase(enemy)
	spawn_effect(enemy.global_position, Color(1.0, 0.8, 0.35), 46.0)

func _make_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	status_label = Label.new()
	status_label.position = Vector2(20, 16)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	status_label.add_theme_constant_override("shadow_offset_x", 2)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	hud.add_child(status_label)
	instructions_label = Label.new()
	instructions_label.position = Vector2(20, 482)
	instructions_label.add_theme_font_size_override("font_size", 17)
	instructions_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	instructions_label.add_theme_constant_override("shadow_offset_x", 2)
	instructions_label.add_theme_constant_override("shadow_offset_y", 2)
	instructions_label.text = "WASD: 移動   J: 攻撃   K: スキル   SPACE: 回避   L: 交代\n攻撃中に L で連携！  J は先行入力できます"
	hud.add_child(instructions_label)

func _update_hud() -> void:
	var switch_text := "READY" if player.switch_timer <= 0.0 else "%.1fs" % player.switch_timer
	var skill_time: float = player.skill_timers[player.character_index]
	var skill_text := "READY" if skill_time <= 0.0 else "%.1fs" % skill_time
	status_label.text = "HP  %d / %d     %s\nSWITCH  %s     SKILL  %s\n%d HIT COMBO     %d K.O." % [player.hp, player.max_hp, player.characters[player.character_index].display_name, switch_text, skill_text, combo_count, kills]
	if game_over:
		status_label.text += "\n\nGAME OVER  —  R: RESTART"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, arena_size), Color(0.13, 0.16, 0.22))
	for x in range(0, int(arena_size.x), 80):
		for y in range(0, int(arena_size.y), 80):
			if (x / 80 + y / 80) % 2 == 0:
				draw_rect(Rect2(x, y, 80, 80), Color(0.15, 0.19, 0.25))
	draw_rect(Rect2(Vector2.ZERO, arena_size), Color(0.5, 0.65, 0.75), false, 5.0)
	for effect in effects:
		var alpha: float = effect.time / effect.duration
		var color: Color = effect.color
		color.a = alpha * 0.8
		if effect.slash:
			var angle: float = effect.direction.angle()
			var half_angle := PI if effect.wide else 1.1
			draw_arc(effect.pos, effect.radius * (1.0 - 0.15 * alpha), angle - half_angle, angle + half_angle, 32, color, 7.0, true)
		else:
			draw_arc(effect.pos, effect.radius * (1.2 - alpha * 0.5), 0.0, TAU, 24, color, 3.0, true)
