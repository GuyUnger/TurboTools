@tool
class_name TurboScript extends EditorPlugin

const ICON_CLEAR = preload("res://addons/turbo_tools/icons/Clear.svg")
const ICON_PIN = preload("res://addons/turbo_tools/icons/Pin.svg")

const TURBO_OPEN = preload("res://addons/turbo_tools/turbo_open.tscn")

const TURBO_GENERATE = preload("res://addons/turbo_tools/turbo_generate.tscn")
const STREAM_MODIFIED_NOTIFICATION = preload("res://addons/turbo_tools/modified_notification.wav")

var script_editor: ScriptEditor
var code_editor: CodeEdit
var caret_lines: Array[int] = []

var audio_modified: AudioStreamPlayer = AudioStreamPlayer.new()

var format: TurboFormat = TurboFormat.new()
@onready var generate: TurboGenerate

var turbo_open_window: Window


# Run Scene Pin
var run_scene_button: Button
var pinned_scene: String
var run_scene_callable
var popup_menu: PopupMenu




func _enter_tree():
	EditorInterface.get_script_editor().editor_script_changed.connect(_on_editor_script_changed)
	
	find_and_add_run_scene_pin()
	generate = TURBO_GENERATE.instantiate()
	generate.turbo = self
	generate.visible = false
	
	format.turbo = self
	
	add_child(audio_modified)
	audio_modified.stream = STREAM_MODIFIED_NOTIFICATION
	_on_editor_script_changed(null)
	
	scene_changed.connect(_on_scene_changed)


func _exit_tree():
	generate.queue_free()
	audio_modified.queue_free()
	
	
	
	run_scene_button.pressed.connect(run_scene_callable)
	run_scene_button.pressed.disconnect(_on_run_scene_pressed)
	run_scene_button.gui_input.disconnect(_on_run_scene_button_gui_input)


func _on_editor_script_changed(_script):
	if is_instance_valid(generate) and generate.get_parent():
		generate.get_parent().remove_child(generate)
	if is_instance_valid(code_editor):
		code_editor.caret_changed.disconnect(_on_caret_changed)
	
	script_editor = EditorInterface.get_script_editor()
	if script_editor.get_current_editor() and script_editor.get_current_editor().get_base_editor():
		code_editor = script_editor.get_current_editor().get_base_editor()
		code_editor.add_child(generate)
		
		code_editor.caret_changed.connect(_on_caret_changed)


func _on_scene_changed(root: Node):
	var scene_name = root.scene_file_path.get_file().get_basename().to_pascal_case()
	if root.name != scene_name:
		print_rich("[color=webgray]Root Node Renamed from[/color] %s [color=webgray]to[/color] %s." % [root.name, scene_name])
		root.name = scene_name


func _on_caret_changed():
	if not is_instance_valid(code_editor):
		return
	if not EditorInterface.get_script_editor().get_current_script():
		return
	var caret_lines_current: Array[int] = []
	for caret_index in code_editor.get_caret_count():
		var line = code_editor.get_caret_line(caret_index)
		if not caret_lines_current.has(line):
			caret_lines_current.push_back(line)
	
	for line_num in caret_lines:
		if not caret_lines_current.has(line_num):
			if format.format_line(line_num):
				audio_modified.play()
	
	caret_lines = caret_lines_current


func _input(event):
	if event is InputEventKey and event.is_pressed():
		if turbo_open_window and event.keycode == KEY_ESCAPE:
			turbo_open_window.queue_free()
		
		if Input.is_key_pressed(KEY_CTRL):
			if event.keycode == KEY_SEMICOLON:
				generate.open()
			if event.keycode == KEY_T:
				if turbo_open_window:
					return
				turbo_open_window = Window.new()
				turbo_open_window.size = Vector2(600, 800)
				turbo_open_window.always_on_top = true
				add_child(turbo_open_window)
				turbo_open_window.position = get_window().position
				turbo_open_window.move_to_center()
				var turbo_open = TURBO_OPEN.instantiate()
				turbo_open_window.add_child(turbo_open)
				
				if EditorInterface.get_editor_main_screen().get_child(2).visible:
					turbo_open.load_scripts()
				else:
					turbo_open.load_scenes()


func find_and_add_run_scene_pin():
	run_scene_button = get_tree().root.find_children("", "EditorRunBar", true, false)[0].get_child(0).get_child(0).get_child(4)
	run_scene_callable = run_scene_button.pressed.get_connections()[0].callable
	run_scene_button.pressed.disconnect(run_scene_callable)
	run_scene_button.pressed.connect(_on_run_scene_pressed)
	run_scene_button.gui_input.connect(_on_run_scene_button_gui_input)
	
	popup_menu = PopupMenu.new()
	popup_menu.add_icon_item(ICON_PIN, "Pin Current Scene")
	popup_menu.id_pressed.connect(_on_popup_pressed)
	
	run_scene_button.add_child(popup_menu)


func _on_run_scene_pressed():
	if pinned_scene:
		get_editor_interface().play_custom_scene(pinned_scene)
	else:
		get_editor_interface().play_custom_scene(get_editor_interface().get_edited_scene_root().scene_file_path)

func _on_run_scene_button_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if popup_menu.item_count > 1:
				popup_menu.remove_item(1)
			if pinned_scene != "":
				popup_menu.add_icon_item(ICON_CLEAR, "Clear Pin (%s)" % pinned_scene)
			popup_menu.popup(Rect2(run_scene_button.get_screen_position(), Vector2.ZERO))

func _on_popup_pressed(id):
	if id == 0:
		pinned_scene = get_editor_interface().get_edited_scene_root().scene_file_path
	else:
		pinned_scene = ""
