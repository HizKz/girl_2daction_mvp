extends SceneTree

var failures := 0
var game
var player

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func make_enemy(offset: Vector2) -> TrainingEnemy:
	var enemy := TrainingEnemy.new()
	enemy.max_hp = 1000
	enemy.speed = 0
	enemy.position = player.position + offset
	game.enemies.append(enemy)
	game.add_child(enemy)
	return enemy

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	player = game.player
	for enemy in game.enemies:
		enemy.queue_free()
	game.enemies.clear()
	game.enemy_limit = 0
	player.set_process(false)
	check(player.hp_values == [120, 90], "separate initial HP")
	check(player.characters[0].damages == [12, 14, 20] and player.characters[1].damages == [10, 12, 16], "character damage data")
	var a := make_enemy(Vector2(40, 0))
	var b := make_enemy(Vector2(80, 0))
	game.perform_attack(player.position, Vector2.RIGHT, 48.0, 12, 0, Color.WHITE, false, null, true, "star", 3.0)
	check(a.hp == 988 and a.mark == "star" and b.mark == "", "melee gives star to enemy in range")
	b.apply_mark("star", 3.0)
	player._switch_character()
	check(player.character_index == 1 and a.hp == 966 and b.hp == 978 and a.mark == "" and b.mark == "", "switch to Mio consumes all stars for 22 damage")
	game.combat_frozen = false
	game.freeze_timer = 0
	player._switch_character()
	check(a.hp == 966 and b.hp == 978, "unmarked switch does not deal damage")
	a.apply_mark("moon", 3.0)
	b.apply_mark("moon", 3.0)
	player._switch_character() # Mio, no stars
	player._switch_character() # Koharu, nearest moon
	check(a.hp == 931 and a.mark == "" and b.hp == 978 and b.mark == "moon", "switch to Koharu consumes nearest moon only")
	player.invulnerable = 0
	player.take_damage(25, player.position + Vector2.LEFT)
	check(player.hp_values == [95, 90], "damage affects active character only")
	player._switch_character()
	check(player.hp == 90 and player.max_hp == 90, "switch restores other character HP")
	game.combat_frozen = false
	player._skill()
	check(game.fields.size() == 1 and game.enemy_speed_multiplier(player.position) == 0.5, "Mio slow field")
	check(game.enemy_speed_multiplier(player.position + Vector2(500, 0)) == 1.0, "slow field is bounded")
	player._switch_character()
	player._skill()
	check(is_equal_approx(player.skill_dash_timer, 0.2) and player.skill_timers[0] == 5.0, "Koharu dash and cooldown")
	game.combat_frozen = false
	game.freeze_timer = 0.0
	a.apply_mark("", 0.0)
	b.apply_mark("", 0.0)
	a.position = player.position + Vector2(90, 0)
	b.position = player.position + Vector2(160, 0)
	var a_before: int = a.hp
	var b_before: int = b.hp
	game.spawn_projectile(player.position, Vector2.RIGHT, player.characters[1], 10)
	await create_timer(0.3).timeout
	check(a.hp == a_before - 10 and a.mark == "moon" and b.hp == b_before, "Mio projectile hits only the first enemy and applies moon")
	b.apply_mark("star", 0.01)
	game.combat_frozen = false
	await create_timer(0.1).timeout
	check(b.mark == "", "marks expire")
	print("Heroine tests: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
