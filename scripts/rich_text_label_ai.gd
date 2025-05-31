#rich_text_label_ai.gd
extends RichTextLabel

@onready var typewriter_timer = get_node("TypewriterTimer")

var full_text: String = ""
var current_index: int = 0
var write_speed: float = 0.05

func _ready():
	clear()
	bbcode_enabled = true
	scroll_active = true
	typewriter_timer.timeout.connect(_on_typewriter_timer_timeout)

func start_typewriter_effect(text_to_display: String):
	clear()
	full_text = text_to_display
	current_index = 0
	typewriter_timer.wait_time = write_speed
	typewriter_timer.start()
	print("✍️ Iniciando máquina de escribir IA con texto:", full_text)

func _on_typewriter_timer_timeout():
	if current_index < full_text.length():
		append_text(full_text[current_index])
		current_index += 1
		scroll_to_line(get_line_count())
	else:
		typewriter_timer.stop()
		print("✅ Terminado de escribir respuesta")
