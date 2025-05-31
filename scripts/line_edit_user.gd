#line_edit_user.gd
extends TextEdit

@export var max_characters := 200
@onready var char_counter = $CharacterCounter

func _ready() -> void:
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_placeholder_color", Color.WHITE)
	add_theme_color_override("font_selected_color", Color.WHITE)
	add_theme_color_override("selection_color", Color.WHITE)
	add_theme_color_override("caret_color", Color.WHITE)

	# Esto es clave: previene que RichTextLabel te ensucie la opacidad o modulate
	modulate = Color(1, 1, 1, 1)

	# Forzar foco y repintado al cargar
	grab_focus()
	queue_redraw()

	text_changed.connect(_on_text_changed)
	_on_text_changed()



func _on_text_changed():
	# Usa directamente `text`, ya que la señal no pasa parámetros
	if text.length() > max_characters:
		# Para evitar recursión infinita al cambiar `text`, desconectamos temporalmente
		text_changed.disconnect(_on_text_changed)
		text = text.left(max_characters)
		text_changed.connect(_on_text_changed)
	
	char_counter.text = str(text.length()) + "/" + str(max_characters)
