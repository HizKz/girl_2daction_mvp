extends Control

var starting := false

func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 24)
	center.add_child(menu)

	var subtitle := Label.new()
	subtitle.text = "TWO HEROES  /  ONE COMBO"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 25)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	menu.add_child(subtitle)

	var title := Label.new()
	title.text = "SWITCH COMBO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 82)
	title.add_theme_color_override("font_color", Color(1.0, 0.94, 0.98))
	menu.add_child(title)

	var description := Label.new()
	description.text = "攻撃をつないで、交代攻撃！"
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 28)
	menu.add_child(description)

	var start := Button.new()
	start.text = "START"
	start.custom_minimum_size = Vector2(360, 82)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.add_theme_font_size_override("font_size", 35)
	start.pressed.connect(_start_game)
	menu.add_child(start)
	start.grab_focus()

	var hint := Label.new()
	hint.text = "Enter / Space / K：スタート"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.8, 0.82, 0.92))
	menu.add_child(hint)

func _input(event: InputEvent) -> void:
	# Accept input even if the button loses keyboard focus.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_K]:
			get_viewport().set_input_as_handled()
			_start_game()

func _start_game() -> void:
	if starting:
		return
	starting = true
	var error := get_tree().change_scene_to_file("res://scenes/main.tscn")
	if error != OK:
		starting = false
		push_error("Could not start the game: %s" % error)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.08, 0.15))
	draw_circle(size * Vector2(0.18, 0.28), size.y * 0.34, Color(0.34, 0.14, 0.27, 0.55))
	draw_circle(size * Vector2(0.82, 0.72), size.y * 0.39, Color(0.12, 0.26, 0.39, 0.55))
	draw_line(size * Vector2(0.18, 0.77), size * Vector2(0.82, 0.23), Color(1.0, 0.48, 0.68, 0.20), 8.0, true)
	draw_line(size * Vector2(0.25, 0.83), size * Vector2(0.89, 0.29), Color(0.46, 0.75, 1.0, 0.20), 8.0, true)
