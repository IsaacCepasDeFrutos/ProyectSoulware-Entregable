#ChatGPTConnector.gd
extends Control
class_name ChatGPTConnector

@export var http_request: HTTPRequest
@export var ai_text_label: RichTextLabel
@export var user_input_line_edit: TextEdit
@export var player_label_path: NodePath
@export var history_turn_limit: int = 3
@export_enum("full", "summary") var memory_mode: String = "full"
@export var memory_limit: int = 800

@onready var api_config_dialog = preload("res://scripts/api_config_dialog.gd").new()

@onready var boton_salir: TextureButton = $VBoxContainer/BotonSalir
@onready var boton_atacar: TextureButton = $VBoxContainer/BotonAtacar

signal response_received
signal exit_requested

var pending_request: bool = false
var api_key: String = ""
var current_npc_id: String = ""
var last_user_text: String = ""

# 🚀 Diccionario simple para clasificar sentimiento del input
var sentiment_keywords := {
	"positivo": [
		"gracias", "bien hecho", "me gusta", "aprecio", "amigo", "genial", "eres el mejor",
		"maestro", "crack", "fiera", "grande", "qué máquina", "buena onda", "lo estás petando",
		"te luciste", "qué bueno", "me caes bien", "qué risa", "buen chiste", "brutal",
		"legendario", "toma like", "te admiro", "me encantas", "qué estilo", "eres un artista"
	],
	"negativo": [
		"idiota", "estúpido", "odio", "asco", "inútil", "tonto", "molesto", "pesado", "cállate",
		"no sirves", "aburres", "qué asco das", "imbécil", "mierda", "patético", "asco de tipo",
		"me das pena", "ridículo", "vete ya", "me estorbas", "no te aguanto", "que te den",
		"gilipollas", "capullo", "vete al diablo"
	]
}

const AFFINITY_COMBAT_THRESHOLD := 5

# Inicializa conexiones, carga el diálogo para configurar la API-Key
# y establece conexiones con señales de botones e input del usuario.
func _ready() -> void:
	add_child(api_config_dialog)
	api_config_dialog.confirmed.connect(_on_api_key_confirmed)
	api_config_dialog.popup_centered()

	http_request.request_completed.connect(_on_api_response)

	var player_lbl := get_node_or_null(player_label_path) as RichTextLabel
	if player_lbl:
		player_lbl.message_sent.connect(send_message)
	else:
		push_error("❌ player_label_path NO válido: %s" % player_label_path)

	print("✅ ChatGPTConnector listo (NPC: %s)" % current_npc_id)
	boton_salir.pressed.connect(_on_BotonSalir_pressed)
	NpcManager.connect("trigger_event", Callable(self, "_on_npc_trigger_event"))


# Establece el NPC actual para la conversación y actualiza la interfaz
# con su información.
func set_npc(id: String) -> void:
	if !NpcManager.npc.has(id):
		push_warning("NPC no encontrado: " + id)
		return
	current_npc_id = id
	print("🔄 NPC activo ahora: %s" % id)

	if has_node("Container/Character_info_Label"):
		var label = get_node("Container/Character_info_Label")
		label.show_npc(current_npc_id)

# Envía el texto introducido por el jugador a la API de ChatGPT.
# Gestiona verificación de afinidad para iniciar combate automáticamente
# si es demasiado baja.
func send_message(user_input: String) -> void:
	if current_npc_id == "":
		push_warning("🚫 current_npc_id vacío al enviar mensaje.")

	if pending_request or api_key.is_empty():
		push_warning("🚫 petición en curso o API-key vacía")
		return

	last_user_text = user_input.strip_edges()

	if has_node("Container/Character_info_Label"):
		var label = get_node("Container/Character_info_Label")
		label.show_npc(current_npc_id)

	var last_messages := _get_recent_chat_history(current_npc_id, history_turn_limit)
	var messages := [
		{ "role": "system",    "content": NpcManager.system_prompt(current_npc_id) },
		{ "role": "assistant", "content": NpcManager.memory(current_npc_id) }
	] + last_messages + [
		{ "role": "user", "content": last_user_text }
	]

	if NpcManager.get_affinity(current_npc_id) <= 10:
		ai_text_label.text = "¡Tú lo has querido! Prepárate para morir..."
		await get_tree().create_timer(2.0).timeout

		var game_root := get_tree().root.get_node("tutorial_stage")
		if game_root.has_method("_start_combat_hostile"):
			game_root._start_combat_hostile()
		return

	pending_request = true
	ai_text_label.text = "Enviando …"

	var err := http_request.request(
		"https://api.openai.com/v1/chat/completions",
		[
			"Content-Type: application/json",
			"Authorization: Bearer %s" % api_key
		],
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"model": "gpt-3.5-turbo",
			"temperature": 0.7,
			"messages": messages
		})
	)
	if err != OK:
		push_error("http_request.request() => %d" % err)

# Recupera los últimos intercambios de mensajes con el NPC, para proveer
# contexto a ChatGPT en la siguiente respuesta.
func _get_recent_chat_history(id: String, turns: int) -> Array:
	var mem := NpcManager.memory(id).split("\n")
	var chat_history := []
	var user_turns := 0

	for i in range(mem.size() - 1, -1, -1):
		if mem[i].begins_with("-User:"):
			user_turns += 1
		if user_turns > turns:
			break
		var role = "user" if mem[i].begins_with("-User:") else "assistant"
		var content := mem[i].substr(mem[i].find(":") + 1).strip_edges()
		chat_history.insert(0, { "role": role, "content": content })

	return chat_history

# Procesa la respuesta obtenida desde la API de ChatGPT, detecta intents,
# actualiza la memoria, ajusta la afinidad y gestiona posibles combates.
func _on_api_response(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	pending_request = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_show_error("Conn error %d" % result)
		return

	var j := JSON.new()
	if j.parse(body.get_string_from_utf8()) != OK:
		_show_error("JSON parse error")
		return

	var data: Dictionary = j.get_data()
	if code != 200:
		_show_error("HTTP %d" % code)
		return

	var answer: String = data["choices"][0]["message"]["content"]

	# 🧠 Detectar intents del tipo [INTENT: xyz]
	var intent_regex := RegEx.new()
	# Captura todo lo que venga después de “[INTENT:” hasta el siguiente ‘]’
	intent_regex.compile("\\[INTENT:\\s*([^\\]]+)\\]")
	var match := intent_regex.search(answer)
	if match:
		var detected_intent := match.get_string(1).strip_edges()
		print("🎯 INTENT detectado: %s" % detected_intent)
		NpcManager.process_intent(current_npc_id, detected_intent)
	else:
		# Fallback: si el GPT no etiquetó, chequeamos las trigger_phrases
		NpcManager.process_goal(current_npc_id, last_user_text)

	_show_ai_response(answer)

	NpcManager.append_memory_custom(
		current_npc_id,
		"-User: %s\n-NPC: %s" % [last_user_text, answer],
		memory_mode,
		memory_limit
	)
	NpcManager.save_dialog_line(current_npc_id, last_user_text, answer)

	var affinity_delta := evaluate_affinity_change(last_user_text)
	NpcManager.adjust_affinity(current_npc_id, affinity_delta)

	var current_affinity := NpcManager.get_affinity(current_npc_id)
	print("🧭 Afinidad actual con %s: %d (Δ %d)" % [current_npc_id, current_affinity, affinity_delta])

	if has_node("Container/Character_info_Label"):
		var label = get_node("Container/Character_info_Label")
		label.show_npc(current_npc_id)

	if has_node("HBoxContainer/HBoxContainer/TextureProgressBar"):
		var bar = get_node("HBoxContainer/HBoxContainer/TextureProgressBar")
		bar.set_real_time_value(current_affinity)

	if current_affinity < AFFINITY_COMBAT_THRESHOLD:
		print("⚠️ Afinidad demasiado baja. Iniciando combate…")
		emit_signal("exit_requested")
		get_tree().call_group("gameplay", "_start_combat_hostile")

	emit_signal("response_received")

# Evalúa el mensaje introducido por el usuario y modifica la afinidad
# según palabras clave positivas o negativas.
func evaluate_affinity_change(user_input: String) -> int:
	var change := 0
	var text_lower := user_input.to_lower()

	for word in sentiment_keywords["positivo"]:
		if text_lower.findn(word) != -1:
			change += 5

	for word in sentiment_keywords["negativo"]:
		if text_lower.findn(word) != -1:
			change -= 5

	return change

# Guarda la API-Key introducida por el usuario tras confirmarla en
# la ventana emergente de configuración.
func _on_api_key_confirmed() -> void:
	api_key = api_config_dialog.get_api_key()
	print("🔑 API-key guardada")

# Muestra visualmente la respuesta del NPC en pantalla, usando un
# efecto de escritura si está disponible.
func _show_ai_response(text: String) -> void:
	if ai_text_label.has_method("start_typewriter_effect"):
		ai_text_label.start_typewriter_effect(text)
	else:
		ai_text_label.text = text

# Muestra un mensaje de error en la interfaz y registra una advertencia
# en consola.
func _show_error(msg: String) -> void:
	ai_text_label.text = "[color=red]Error: %s[/color]" % msg
	push_warning(msg)

# Emite la señal para cerrar la interfaz de conversación cuando el
# usuario pulsa el botón de salir.
func _on_BotonSalir_pressed() -> void:
	print("👋 Botón 'Salir' pulsado")
	emit_signal("exit_requested")

# Emite la señal para cerrar la interfaz e inicia un combate dirigido por el jugador.
func _on_boton_atacar_pressed() -> void:
	print("⚔️  Botón 'Atacar' pulsado (jugador inicia)")
	emit_signal("exit_requested")
	get_tree().call_group("gameplay", "_start_combat_player")

# Devuelve el identificador actual del NPC en conversación.
func get_current_npc_id() -> String:
	return current_npc_id

# -------------------------------------------------------------------
# Called whenever NPCManager emite un evento para este NPC.
# @param npc_id  Identificador del NPC que originó el evento.
# @param ev      Dictionary con al menos la clave "type" y
#                otros parámetros específicos de cada evento.

# Maneja eventos especiales enviados desde el NPC Manager, incluyendo
# cerrar conversación, iniciar movimiento del NPC o hacer que un NPC siga al jugador.
func _on_npc_trigger_event(npc_id: String, ev: Dictionary) -> void:
	print("[ChatGPTConnector] ◀ Got event:", ev)
	match ev.get("type", ""):
		"close_conversation_ui":
			visible = false
			# ——————> 1) DESCONGELAR AL NPC
			var scene = get_tree().root.get_node("tutorial_stage")
			var root_npc = scene.get_node_or_null(ev.get("target", ""))
			if root_npc:
				if root_npc.has_method("set_frozen"):
					root_npc.set_frozen(false)
			# ——————> 2) DESBLOQUEAR AL JUGADOR
			emit_signal("exit_requested")

		"npc_movement":
			var node_name   = ev.get("target", "")
			var scene_root  = get_tree().root.get_node_or_null("tutorial_stage")
			if not scene_root:
				push_warning("No encontré el nodo tutorial_stage")
				return

			# 1) Intentamos en el nodo raíz
			var mover = scene_root.get_node_or_null(node_name)
			if mover == null:
				push_warning("No encontré NPC '%s' bajo tutorial_stage" % node_name)
				return

			# 2) Si ese nodo no tiene el método, bajamos a CharacterBody2D
			if not mover.has_method("start_pathfinding_move"):
				mover = mover.get_node_or_null("CharacterBody2D")
				if mover == null or not mover.has_method("start_pathfinding_move"):
					push_warning("start_pathfinding_move no existe ni en '%s' ni en su hijo CharacterBody2D" % node_name)
					return

			# 3) Llamamos deferred para no mezclar con el frame actual
			mover.call_deferred(
				"start_pathfinding_move",
				ev.get("destination"),
				ev.get("speed")
			)
			
		"start_following":
			var node_name = ev.get("target", "")
			
			var scene_root = get_tree().root.get_node("tutorial_stage")
			var inst = scene_root.get_node_or_null(node_name)
			print("🔍 Hijos de tutorial_stage:", scene_root.get_children().map(func(c): return c.name))
			var npc_base = scene_root.get_node_or_null(node_name)
			if not npc_base:
				push_warning("⛔ Nodo '%s' no encontrado bajo tutorial_stage" % node_name)
				return

			 # 1) busca el CharacterBody2D que tiene los métodos:
			var controller = inst as CharacterBody2D
			if not controller:
				# si la raíz no lo tiene, baja a CharacterBody2D:
				controller = inst.get_node_or_null("CharacterBody2D") as CharacterBody2D
				if not controller:
					push_warning("⛔ No hallé CharacterBody2D bajo '%s'" % node_name)
					return

			# 2) ahora sí podemos llamar a ambos métodos:
			if controller.has_method("allow_movement"):
				controller.call_deferred("allow_movement", true)
			if controller.has_method("set_following"):
				controller.call_deferred("set_following", true)

		_:
			push_warning("Evento desconocido: " + ev.get("type", ""))
