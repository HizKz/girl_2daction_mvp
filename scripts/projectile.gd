extends Node2D

var direction := Vector2.RIGHT
var speed := 650.0
var remaining := 260.0
var damage := 10
var mark := "moon"
var mark_duration := 3.0
var game

func _process(delta: float) -> void:
	if game.combat_frozen or game.game_over:
		return
	var travel := minf(speed * delta, remaining)
	var start := global_position
	var end := start + direction * travel
	var target: TrainingEnemy = null
	var nearest := INF
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var along: float = (enemy.global_position - start).dot(direction)
		var closest: Vector2 = start + direction * clampf(along, 0.0, travel)
		if enemy.global_position.distance_to(closest) <= 17.0 and along < nearest:
			nearest = along
			target = enemy
	if target != null:
		target.apply_mark(mark, mark_duration)
		game.hit_enemy(target, damage, direction, 35.0)
		queue_free()
		return
	global_position = end
	remaining -= travel
	if remaining <= 0.0 or end.x < 0.0 or end.y < 0.0 or end.x > game.arena_size.x or end.y > game.arena_size.y:
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(-direction * 12.0, direction * 5.0, Color(0.6, 0.9, 1.0), 4.0, true)
