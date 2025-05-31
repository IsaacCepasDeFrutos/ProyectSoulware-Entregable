# api_config_dialog.gd
extends ConfirmationDialog

var key_input: LineEdit

func _ready():
	title = "Configurar API Key"
	add_to_group("persistent")
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	var label = Label.new()
	label.text = "Ingresa tu API Key de OpenAI:"
	vbox.add_child(label)
	
	key_input = LineEdit.new()
	key_input.secret = true
	key_input.placeholder_text = "sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
	vbox.add_child(key_input)
	
	register_text_enter(key_input)

func get_api_key() -> String:
	return key_input.text.strip_edges()
