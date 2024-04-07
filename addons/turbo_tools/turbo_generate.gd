@tool
class_name TurboGenerate
extends Control

var turbo: TurboScript

const ACTION_DIVIDER := "divider"
const ACTION_CAPITALIZE_COMMENT := "capitalize comment"
const ACTION_UPPERCASE_COMMENT := "uppercase comment"

var actions := [
	"tool",
	"export",
	"extends",
	"onready",
	"var class",
	"var local",
	"var export",
	"var onready",
	"func",
	"signal",
	ACTION_DIVIDER,
	ACTION_CAPITALIZE_COMMENT,
	ACTION_UPPERCASE_COMMENT,
]

@onready var results = %Results
var result
@onready var input = %Input

var current_action := ""


func _ready():
	result = load("res://addons/turbo_tools/generate_search_action_result.tscn").instantiate()


func open():
	visible = true
	input.text = ""
	input.grab_focus()
	%ActionSelect.visible = true
	%SetValue.visible = false


func close():
	visible = false
	turbo.code_editor.grab_focus()


func _on_line_edit_text_changed(query: String):
	search(query)
	

func search(query):
	for result in results.get_children():
		result.free()
	
	var search_list = []
	for action in actions:
		search_list.push_back([action, levenshtein_distance(query, action)])
	search_list.sort_custom(func (a, b):
		if a[0].begins_with(query):
			return true
		if b[0].begins_with(query):
			return false
		return a[1] > b[1]
	)
	
	for search_item in search_list:
		var action = search_item[0]
		add_result(action)
		
		if results.get_child_count() >= 3:
			break
	
	if search_list.size() > 0:
		current_action = search_list[0][0]


func get_selection() -> String:
	var code_editor = turbo.code_editor
	if code_editor.get_caret_count() == 1 and code_editor.has_selection(0):
		return code_editor.get_selected_text(0)
	return ""


func get_selection_term() -> String:
	var selection = get_selection().strip_edges()
	if selection.contains("\n"):
		return ""
	return selection


func add_result(action):
	var description := get_description(action)
	var new_result = result.duplicate()
	new_result.get_node("Action").text = action
	new_result.get_node("Description").text = description
	results.add_child(new_result)


func get_description(action) -> String:
	match action:
		# Class.
		"tool":
			if is_tool():
				return "Make this not a @tool script"
			else:
				return "Make this a @tool script"
		"extends":
			return "Set extends"
		
		# Variables.
		"var local":
			var term = get_selection_term()
			if term:
				return "Create local variable [color=pink]%s[/color]" % term
			else:
				return "Create new local variable"
		"var class":
			var term = get_selection_term()
			if term:
				return "Create class variable [color=pink]%s[/color]" % term
			else:
				return "Create new class variable"
		"export":
			return "Toggle variable @export"
		"onready":
			return "Toggle variable @onready"
		
		# Functions.
		"func":
			var selection = get_selection()
			if selection == "":
				return "Create new function"
			else:
				return "Generate function from selection"
		# Comments.
		ACTION_DIVIDER:
			return "Turn comment into a divider"
		ACTION_CAPITALIZE_COMMENT:
			return "Capitalizes comment"
		ACTION_UPPERCASE_COMMENT:
			return "Converts comment to uppercase"
	return ""


func submit():
	var code_editor = turbo.code_editor
	match current_action:
		"tool":
			if is_tool():
				for line_num in code_editor.get_line_count():
					if code_editor.get_line(line_num).begins_with("@tool"):
						code_editor.remove_text(line_num, 0, line_num + 1, 0)
			else:
				code_editor.insert_line_at(0, "@tool")
				close()
		"onready":
			for line_num in get_selected_line_nums():
				var line = code_editor.get_line(line_num)
				if line.begins_with("@onready"):
					code_editor.set_line(line_num, line.substr("@onready ".length()))
				elif line.begins_with("var"):
					code_editor.set_line(line_num, "@onready " + line)
			close()
		"export":
			for line_num in get_selected_line_nums():
				var line = code_editor.get_line(line_num)
				if line.begins_with("@export"):
					code_editor.set_line(line_num, line.substr("@export ".length()))
				elif line.begins_with("var"):
					code_editor.set_line(line_num, "@export " + line)
			close()
		"var local":
			var term = get_selection_term()
			if term:
				var line_num = code_editor.get_selection_line(0)
				while line_num > 0:
					line_num -= 1
					if code_editor.get_line(line_num).begins_with("func "):
						var l = code_editor.get_line_count()
						while line_num < l:
							#todo: This would break if the function initializer is multi-lined and
							# A line contains a comment with a colon.
							if code_editor.get_line(line_num).contains(":"):
								code_editor.insert_line_at(line_num + 1, "	var %s" % term)
								return
							
							line_num += 1
		"func":
			var selection: String = get_selection()
			if selection:
				var selection_from_line = code_editor.get_selection_from_line()
				var selection_from_column = code_editor.get_selection_from_column()
				var selection_to_line = code_editor.get_selection_to_line()
				var selection_to_column = code_editor.get_selection_to_column()
				
				var selection_lines = selection.split("\n")
				
				# Remove indentations and put 1 back (to make it also work for the first line).
				var min_indent = 999
				for line_num in selection_lines.size():
					var line = selection_lines[line_num]
					var indent = get_indentation(line)
					if indent == 0:
						continue
					min_indent = min(min_indent, indent)
				if min_indent == 999:
					min_indent = 0
				for line_num in selection_lines.size():
					var line = selection_lines[line_num]
					for j in min(min_indent, line.length()):
						if line[0] == "	":
							line = line.erase(0)
					selection_lines[line_num] = line
				
				for line_num in selection_lines.size():
					selection_lines[line_num] = "	" + selection_lines[line_num]
				
				# Reverse for easier adding the lines back in.
				selection_lines.reverse()
				
				var line_num = code_editor.get_selection_from_line()
				
				code_editor.remove_text(
						selection_from_line, selection_from_column,
						selection_to_line, selection_to_column
				)
				
				while line_num < code_editor.get_line_count() - 1:
					line_num += 1
					if code_editor.get_line(line_num).begins_with("func "):
						break
				line_num -= 1
				
				for line in selection_lines:
					code_editor.insert_line_at(line_num, line)
				
				code_editor.insert_line_at(line_num, "func ():")
				
				for i in 2:
					code_editor.insert_line_at(line_num, "")
				
				code_editor.deselect(0)
				code_editor.set_line(selection_from_line, code_editor.get_line(selection_from_line) + "()")
				code_editor.add_caret(selection_from_line, selection_from_column)
				code_editor.add_caret(line_num + 2, 5)
				
				close()
		ACTION_DIVIDER:
			for caret in code_editor.get_caret_count():
				var is_region := false
				
				var line_num := code_editor.get_caret_line(caret)
				var line := code_editor.get_line(line_num)
				var indentation := get_indentation(line)
				line = line.strip_edges()
				
				if line.begins_with("#region"):
					is_region = true
					line = line.substr(7)
				elif line.begins_with("#"):
					line = line.substr(1)
				
				var text: String = line
				
				text = text.strip_edges()
				if text.ends_with("."):
					text = text.substr(0, text.length() -1)
				
				var comment = "#region" if is_region else "#"
				var line_width = 100 - 5 - text.length() - indentation * 4 - comment.length()
				var new_line: String
				for i in indentation:
					new_line += "	"
				var divide_line_left: String
				for i in line_width / 2:
					divide_line_left += "-"
				
				var divide_line_right = divide_line_left
				if (comment + text).length() % 2 == 0:
					divide_line_right += "-"
				
				if is_region:
					divide_line_left = divide_line_left.substr(3)
					divide_line_right += "---"
				
				new_line += "%s %s %s %s #" % [comment, divide_line_left, text, divide_line_right]
				code_editor.set_line(line_num, new_line)
		ACTION_CAPITALIZE_COMMENT:
			for caret in code_editor.get_caret_count():
				var line_num := code_editor.get_caret_line(caret)
				var line := code_editor.get_line(line_num)
				var comment_start = line.find("#")
				
				var before_comment = line.substr(0, comment_start + 1)
				var comment := line.substr(comment_start + 1)
				comment = comment.strip_edges().capitalize()
				
				var new_line = before_comment + " " + comment
				code_editor.set_line(line_num, new_line)


func get_indentation(string: String) -> int:
	var indentation := 0
	for char in string:
		if char == "	":
			indentation += 1
		else:
			break
	return indentation


func get_selected_line_nums() -> Array:
	var code_editor = turbo.code_editor
	var selected_lines := []
	for caret in code_editor.get_caret_count():
		if code_editor.has_selection(caret):
			for line in range(
					code_editor.get_selection_from_line(caret),
					code_editor.get_selection_to_line(caret) + 1
			):
				if not selected_lines.has(line):
					selected_lines.push_back(line)
		else:
			var line = code_editor.get_caret_line(caret)
			if not selected_lines.has(line):
				selected_lines.push_back(line)
	return selected_lines


func _on_input_text_submitted(query):
	if current_action != "":
		submit()
	search(query)


func _on_input_focus_exited():
	close()


func is_tool():
	for i in turbo.code_editor.get_line_count():
		var line_text: String = turbo.code_editor.get_line(i).strip_edges()
		if line_text.begins_with("#"):
			continue
		if line_text.begins_with("@tool"):
			return true
		return false


func levenshtein_distance(query: String, target: String) -> float:
	var len_query: float = query.length()
	var len_target: float = target.length()
	
	if len_query == 0 or len_target == 0:
		return - 1.0
	
	var distance_matrix := []
	for x in len_target + 1:
		var row = []
		for y in len_query + 1:
			row.push_back(0.0)
		distance_matrix.push_back(row)
		
	for i in range(len_target + 1):
		distance_matrix[i][0] = i
	
	for j in range(len_query + 1):
		distance_matrix[0][j] = j
	
	for i in range(1, len_target + 1):
		for j in range(1, len_query + 1):
			var substitution_cost := 1.0 if query[j - 1] != target[i - 1] else 0
			
			distance_matrix[i][j] = min(
				distance_matrix[i - 1][j] + 1,
				distance_matrix[i][j - 1] + 1,
				distance_matrix[i - 1][j - 1] + substitution_cost
			)
	
	var max_distance: float = float(max(len_query, len_target))
	var similarity: float = 1.0 - (distance_matrix[len_target][len_query] / max_distance)
	return similarity
