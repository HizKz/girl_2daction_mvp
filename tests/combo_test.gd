extends SceneTree

var game
var player
var stages: Array[int] = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		push_error("FAIL: " + description)
		failures.append(description)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func key(code: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code, true)
	await wait(0.025)
	key(code, false)

func clear_enemies() -> void:
	for enemy in game.enemies:
		enemy.queue_free()
	game.enemies.clear()
	game.enemy_limit = 0

func reset_player() -> void:
	player._cancel_normal_attack(true)
	player.character_index = 0
	player.attack_timer = 0.0
	player.switch_timer = 0.0
	player.dodge_timer = 0.0
	player.pending_attack_input = false
	game.freeze_timer = 0.0
	game.combat_frozen = false
	stages.clear()

func run_tests() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	player = game.player
	player.attack_started.connect(func(stage: int): stages.append(stage))
	clear_enemies()
	await tap(KEY_K)
	await wait(0.4)
	check(stages == [1], "one press produces only stage 1")

	reset_player()
	await tap(KEY_K)
	await wait(0.04)
	await tap(KEY_K)
	await wait(0.5)
	check(stages == [1, 2], "two presses buffer stage 2")

	reset_player()
	await tap(KEY_K)
	await wait(0.04)
	await tap(KEY_K)
	await wait(0.27)
	await tap(KEY_K)
	await wait(0.65)
	check(stages == [1, 2, 3] and player.attack_state == Fighter.AttackState.IDLE and player.combo_step == 0, "three presses finish at idle")
	await tap(KEY_K)
	await wait(0.05)
	check(stages == [1, 2, 3, 1], "next attack after finisher starts at 1")

	reset_player()
	await tap(KEY_K)
	await wait(1.2)
	await tap(KEY_K)
	await wait(0.05)
	check(stages == [1, 1], "late input resets combo")

	reset_player()
	key(KEY_K, true)
	await wait(0.1)
	key(KEY_K, true, true)
	await wait(0.6)
	key(KEY_K, false)
	check(stages == [1], "held key and key repeat do not chain")

	reset_player()
	await tap(KEY_K)
	await tap(KEY_S)
	await wait(0.1)
	check(player.character_index == 1 and player.attack_state == Fighter.AttackState.IDLE and player.combo_step == 1, "switch cancels attack and preserves chain")
	await tap(KEY_K)
	await wait(0.35)
	check(stages == [1, 2], "attack buffers during switch and continues chain")

	reset_player()
	var enemy := TrainingEnemy.new()
	enemy.speed = 0
	enemy.max_hp = 1000
	enemy.position = player.position + Vector2(45, 0)
	game.enemies.append(enemy)
	game.add_child(enemy)
	enemy.set_process(false)
	player.facing = Vector2.RIGHT
	await tap(KEY_K)
	check(enemy.hp == 1000 and player.attack_state == Fighter.AttackState.STARTUP, "startup has no hit")
	await wait(0.02)
	check(enemy.hp == 988 and game.freeze_timer > 0.0, "active hit applies damage and hit stop")
	await wait(0.35)
	check(enemy.hp == 988, "one active attack cannot hit the same enemy twice")
	reset_player()
	enemy.position = player.position + Vector2(-45, 0)
	player.facing = Vector2.RIGHT
	await tap(KEY_K)
	await wait(0.2)
	check(enemy.hp == 988, "attack respects facing direction")
	check(player.characters[0].damages[2] > player.characters[0].damages[1] and player.characters[0].knockbacks[2] > player.characters[0].knockbacks[1], "stage 3 power is configured")
	reset_player()
	enemy.hp = 1000
	enemy.position = player.position + Vector2(75, 0)
	player.facing = Vector2.RIGHT
	await tap(KEY_K)
	await wait(0.23)
	check(enemy.hp == 1000, "stage 1 misses outside its range")
	await tap(KEY_K)
	await wait(0.13)
	check(enemy.hp == 1000, "stage 2 also misses outside its range")
	await wait(0.2)
	enemy.position = player.position + Vector2(45, 0)
	await tap(KEY_K)
	await wait(0.15)
	check(enemy.hp == 980 and is_equal_approx(enemy.velocity.length(), 120.0), "stage 3 applies finisher damage and knockback")
	reset_player()
	enemy.hp = 1000
	enemy.apply_mark("", 0.0)
	enemy.position = player.position + Vector2(45, 0)
	await tap(KEY_K)
	await tap(KEY_S)
	await wait(0.4)
	check(enemy.hp == 1000 and player.attack_state == Fighter.AttackState.IDLE, "switch during startup cancels attack without an unearned combo")
	game._update_hud()
	check(game.status_label.text.contains("こはる") and game.status_label.text.contains("澪"), "HUD includes both heroines")
	reset_player()
	enemy.hp = 1000
	enemy.position = player.position + Vector2(45, 0)
	await tap(KEY_K)
	await wait(0.02)
	await tap(KEY_K)
	await wait(0.45)
	check(stages == [1, 2] and enemy.hp == 974, "input during hit stop is buffered for exactly one next attack")
	print("Combo tests: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
