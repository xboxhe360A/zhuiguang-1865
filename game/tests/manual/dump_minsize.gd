extends SceneTree
## QA helper: print minimum widths of every Control in a scene under a locale.
## godot --headless --path game -s res://../tools/dump_minsize.gd -- --scene=res://scenes/archive_desk.tscn --lang=en

var _frames := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := "res://scenes/archive_desk.tscn"
	var lang := "en"
	for arg in args:
		if arg.begins_with("--scene="):
			scene_path = arg.trim_prefix("--scene=")
		elif arg.begins_with("--lang="):
			lang = arg.trim_prefix("--lang=")
	TranslationServer.set_locale(lang)
	var packed := load(scene_path) as PackedScene
	if packed == null:
		print("FAILED to load ", scene_path)
		quit(1)
		return
	var desk := packed.instantiate()
	root.add_child(desk)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	var viewport_size := root.get_visible_rect().size
	print("viewport=", viewport_size)
	_dump(root, 0)
	return true


func _dump(node: Node, depth: int) -> void:
	if node is Control:
		var c := node as Control
		var line := "%s%s (%s) pos=%s size=%s min=%s" % [
			"  ".repeat(depth),
			c.name,
			c.get_class(),
			c.position,
			c.size,
			c.get_combined_minimum_size(),
		]
		if c is Label:
			line += " text_size=%s font=%s" % [
				c.get_theme_font("font").get_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, -1, c.get_theme_font_size("font_size")),
				c.get_theme_font_size("font_size"),
			]
		print(line)
	for child in node.get_children():
		_dump(child, depth + 1)
