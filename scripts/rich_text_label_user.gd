# rich_text_label_user.gd
extends RichTextLabel

signal message_sent(text)

@onready var text_edit        : TextEdit = $TextEdit
@onready var typewriter_timer : Timer    = $TypewriterTimer
@onready var connector        : Node     = $"../../VBoxContainer3/RichTextLabel"

const MAX_CHARACTERS := 200
var full_text  : String = ""
var current_ix : int    = 0

func _ready() -> void:
	focus_mode     = FOCUS_ALL
	bbcode_enabled = true
	scroll_active  = true
	clear()
	
	# Evitar que afecte a los nodos hijos
	modulate = Color(1, 1, 1, 1)
	self.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Evita robar foco
	# Forzar el TextEdit a mostrarse bien desde el arranque
	var input_node = $TextEdit
	input_node.modulate = Color(1, 1, 1, 1)
	input_node.queue_redraw()

	text_edit.focus_entered.connect(_on_focus_entered)
	text_edit.focus_exited.connect(_on_focus_exited)
	text_edit.gui_input.connect(_on_text_input)
	typewriter_timer.timeout.connect(_on_typewriter_tick)

	await get_tree().process_frame
	if connector != null and connector.has_signal("response_received"):
		connector.connect("response_received", _on_ai_response_received)

# ───── Interacción teclado/ratón ─────
func _on_text_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER and !event.shift_pressed:
			get_viewport().set_input_as_handled()  # Evita el salto de línea
			_on_text_submitted(text_edit.text)
			event.pressed = false  # Para evitar doble entrada
		elif event.keycode == KEY_ENTER and event.shift_pressed:
			text_edit.insert_text_at_cursor("\n")

func _on_focus_entered():
	clear()
	text_edit.text = _clean_text()
	text_edit.grab_focus()

func _on_focus_exited():
	if text_edit.text.strip_edges() == "":
		clear()
	else:
		_start_typewriter_effect(text_edit.text)


func _on_text_submitted(new_text: String):
	var msg := new_text.strip_edges()
	if msg.length() > MAX_CHARACTERS:
		msg = msg.left(MAX_CHARACTERS)
		append_text("[color=red]Texto truncado por límite de caracteres.[/color]\n")

	if msg != "":
		emit_signal("message_sent", msg)

	_start_typewriter_effect(msg)
	text_edit.clear()
	text_edit.grab_focus()
	text_edit.editable = true
	text_edit.modulate = Color(1, 1, 1, 1)
	text_edit.queue_redraw()


# ───── Máquina de escribir ─────
func _start_typewriter_effect(txt: String):
	clear()
	full_text  = txt
	current_ix = 0
	typewriter_timer.start(0.05)

func _on_typewriter_tick():
	if current_ix < full_text.length():
		append_text(full_text[current_ix])
		current_ix += 1
		scroll_to_line(get_line_count())
	else:
		typewriter_timer.stop()

# ───── Util ─────
func _clean_text() -> String:
	return get_text().replace("[color=#999999]", "").replace("[/color]", "")

# ───── Señal del conector ─────
func _on_ai_response_received() -> void:
	text_edit.clear()
	text_edit.visible = true
	text_edit.grab_focus()
	text_edit.editable = true
	text_edit.modulate = Color(1, 1, 1, 1)
	text_edit.queue_redraw()
