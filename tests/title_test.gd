extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	for code in [KEY_ENTER, KEY_SPACE, KEY_K]:
		var title = load("res://scenes/title.tscn").instantiate()
		root.add_child(title)
		current_scene = title
		await process_frame
		# Starting must not depend on button focus.
		var button = title.find_children("*", "Button", true, false)[0]
		button.release_focus()
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		await process_frame
		if current_scene == null or current_scene.scene_file_path != "res://scenes/main.tscn":
			push_error("Start failed for key %s" % code)
			quit(1)
			return
		print("PASS: start from key ", code)
		current_scene.queue_free()
		await process_frame
	print("Title input tests passed")
	quit()
