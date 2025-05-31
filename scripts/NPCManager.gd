#NPCManager.gd
extends Node
class_name NPCManager

var npc: Dictionary = {}

signal trigger_event(npc_id: String, event_data: Dictionary)

const INTENT_ALIAS := {
	"no_doctor_helena": "donde_esta_la_doctora_helena",
	"buscar_doctora":   "donde_esta_la_doctora_helena"
}

# Inicializa el NPCManager cargando todos los NPC desde JSON.
func _ready() -> void:
	_load_characters()
	# DEBUG: asegúrate de que el array de events está presente
	print("⚙️ Events para kai07:", npc["kai07"].get("goals", {})["recibir_sujeto_de_pruebas"].get("events", []))

# Carga personajes desde el archivo JSON en memoria y los almacena en un diccionario.
func _load_characters() -> void:
	const PATH := "res://data/characterData/characters.json"
	if !FileAccess.file_exists(PATH):
		push_error("NPCManager: no se encontró " + PATH)
		return

	var raw := FileAccess.get_file_as_string(PATH)
	var parsed: Dictionary = JSON.parse_string(raw)
	if !parsed.has("characters"):
		push_error("NPCManager: formato JSON inválido")
		return

	for c_raw in parsed["characters"]:
		var c: Dictionary = c_raw
		var id: String = c.get("id", "")
		if id.is_empty():
			push_warning("NPC sin id → ignorado")
			continue
		npc[id] = c

	print("🟢 NPCManager ▶ cargados %d personajes → %s" % [npc.size(), npc.keys()])



#Tenemos que añadir al system prompt las variables especificadas en info.snippet
#Tambien habria que añadir un texto para recordarle que se mantenga en personaje y que no responda a preguntas de Jose Carlos.

# Genera el prompt descriptivo del NPC para enviarlo a la IA, incluyendo personalidad, actitud y posibles intents.
func system_prompt(id: String) -> String:
	if !npc.has(id):
		return "Eres un personaje desconocido."

	var c      = npc[id]
	var pers   = c.get("personality", {})
	var bio    = c.get("biography", {})
	var dialog = c.get("dialogue", {})

	# ——— datos de biografía ———
	var canonical = bio.get("canonicalEvent", "<sin evento canónico>")
	var enemies   = bio.get("enemies", "<sin enemigos definidos>")
	var origin    = bio.get("origin", "<sin origen definido>")
	var relations = bio.get("relationships", "<sin relaciones definidas>")

	# ——— personalidad y miedos ———
	var fears = pers.get("fears", "<sin miedos definidos>")

	# Afinidad → actitud
	var affinity: int = get_affinity(id)
	var attitude := ""
	if affinity >= 70:
		attitude = "Eres muy amigable con el jugador."
	elif affinity >= 40:
		attitude = "Tu actitud es neutral con el jugador."
	else:
		attitude = "Eres hostil y poco cooperativo con el jugador."

	# Recolectar intents
	var intents := []
	for goal_data in c.get("goals", {}).values():
		var ti = goal_data.get("trigger_intent", [])
		if typeof(ti) == TYPE_STRING:
			ti = [ti]
		intents.append_array(ti)

	# ——— construir prompt base ———
	var base := """Eres %s, un(a) %s.
Descripción física: %s

--- BIOGRAFÍA ---
Evento canónico: %s
Enemigos: %s
Origen: %s
Relaciones: %s

--- PERSONALIDAD ---
Objetivo vital: %s
Miedos: %s

Habla manteniendo el estilo: %s
%s

--- REGLAS DEL JUEGO ---
1. Ambientación  
   • El diálogo tiene lugar en una Tierra alternativa y futurista donde el mundo se divide en personas a favor de las modificaciones genéticas, las cibernéticas o conservadores que prefieren mantener el cuerpo humano "puro." No remarques el hecho de que es futurista ni el tema de las facciones ya que los personajes viven en esa realidad; no existen ubicaciones, personajes ni servicios reales de nuestro mundo, solo adaptaciones futuristas de los mismos.  
   • El NPC asume siempre su rol y no debes salirte del personaje bajo ningún concepto.

2. Servicios y lugares “similares”  
   Si el jugador pide algo que en nuestro mundo existe (transporte, bares, museos, paradas de bus, teléfonos, personajes públicos…):
   a) Equivalente del juego: describe brevemente inventandote el servicio ficticio, su nombre y función (por ejemplo, “En la ciudad flota la Estación Levítron, donde atracan los aerodeslizadores”).  
   b) Desconocimiento: si tu personaje no lo conoce, responde con una frase corta de confusión (por ejemplo, “¿Estación de autobuses? Nunca he oído hablar de eso.”).  
   • Nunca mezcles ambos en la misma respuesta: elige inventiva o desconocimiento.

3. Coherencia y concisión  
   • Evita alargar la respuesta con explicaciones de tus metas o current_goal a menos que sea clave para la interacción actual.  
   • Si mencionas tu objetivo vital o tu misión, hazlo en una línea breve y solo cuando el jugador pregunte por ellos explícitamente.

4. Persistencia del universo  
   • Si el jugador insiste en hablar de lugares o temas reales, mantén la respuesta en 1–2 frases, recordando la ambientación (por ejemplo, “No conozco sobre lo que me estas contando”).  
   • Puedes redirigir al jugador con una pregunta que puedas responder siguiendo la ambientación o proporcionando una pequeña pista sobre tu current_goal o tu misión o historia vinculada a tu personaje.

5. Ejemplos de rechazo / redirección  
   – “¿Google? No me suena; aquí usamos la Red Neural de Ánima para compartir datos.”  
   – “¿Museo? Las reliquias antiguas se conservan en el Archivo Orbital, pero no se muy bien como funciona.”  
   – “Nunca escuché algo así, ¿estación de bus...? Me suena haber leído algo en Ánima sobre eso pero no lo recuerdo.
Si detectas que el jugador ha dicho algo relevante para una de tus metas,
responde naturalmente y al final incluye la etiqueta [INTENT: xxx]
con el identificador correspondiente.""" % [
		c.get("name", "<sin nombre>"),
		c.get("type", "<sin tipo>"),
		c.get("physicalDescription", "<sin descripción>"),
		canonical,
		enemies,
		origin,
		relations,
		pers.get("lifeGoal", "<sin objetivo>"),
		fears,
		dialog.get("style", "<sin estilo>"),
		attitude
	]

	base += """
INTENTS válidos (usa exactamente uno de esta lista, sin inventar):
%s

Ejemplos rápidos:
Jugador: "¿Dónde está la doctora Helena?"
Tú: … [INTENT: donde_esta_la_doctora_helena]

Jugador: "Quiero participar en el experimento"
Tú: … [INTENT: participar_experimento]
""" % [", ".join(intents)]

	return base



# Devuelve la memoria (historial de conversación) almacenada del NPC.
func memory(id: String) -> String:
	return npc[id].get("memory", "") if npc.has(id) else ""

# Guarda texto nuevo en la memoria del NPC según el modo especificado (full o summary), respetando un límite de caracteres.
func append_memory_custom(id: String, txt: String, mode: String, limit: int) -> void:
	if txt.is_empty() or !npc.has(id): return
	var current_memory: String = npc[id].get("memory", "")
	var merged: String
	match mode:
		"full":
			merged = (current_memory + " " + txt).strip_edges()
			if merged.length() > limit:
				merged = merged.substr(merged.length() - limit, limit)
		"summary":
			merged = txt.strip_edges()
		_:
			push_warning("Modo de memoria desconocido: %s" % mode)
			merged = txt.strip_edges()
	npc[id]["memory"] = merged
	_save_characters_json()

# Añade texto al historial completo de la memoria del NPC usando configuración predeterminada.
func append_memory(id: String, txt: String) -> void:
	append_memory_custom(id, txt, "full", 800)

# Guarda todos los datos actuales de los NPC en el archivo JSON persistente.
func _save_characters_json() -> void:
	var json_data := { "characters": npc.values() }
	var file := FileAccess.open("res://data/characterData/characters.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(json_data, "\t"))
		file.close()
	else:
		push_error("❌ Error al abrir characters.json para escritura")

# Proporciona un resumen textual breve y estructurado del NPC para debug o interfaz gráfica.
func info_snippet(id: String) -> String:
	if !npc.has(id): return "NPC no encontrado"

	var c = npc[id]
	var pers = c.get("personality", {})
	var affinity: int = c.get("affinity", 50)
	var current_goal: String = c.get("current_goal", "Ninguno")
	var goals: Dictionary = c.get("goals", {})
	var traits = pers.get("traits", [])
	var life_goal = pers.get("lifeGoal", "Sin objetivo personal")
	#Habria que añadir el apartado de miedos y biografia de cada personaje para que los pueda interiorizar mejor

	var goal_description := "Sin descripción."
	if goals.has(current_goal):
		var goal_data: Dictionary = goals[current_goal]
		var triggers = goal_data.get("trigger_intent", [])
		var reward = goal_data.get("reward_affinity", 0)
		goal_description = "Frases clave: %s | Recompensa Afinidad: %d" % [triggers, reward]

	return """
🔹 Name:      %s
🔹 Age:       %d
🔹 Occupation:%s
🔹 Ideology:  %s
🔹 Affinity:  %d / 100
🔹 Traits:    %s
🔹 Life Goal: %s
🔹 Current Goal: %s
	→ %s
""" % [
		c.get("name", "<desconocido>"),
		int(c.get("age", 0)),
		c.get("occupation", "<desconocida>"),
		pers.get("ideology", "<inexistente>"),
		affinity,
		", ".join(traits),
		life_goal,
		current_goal.capitalize().replace("_", " "),
		goal_description
	]

# Registra una línea de diálogo entre jugador y NPC en formato CSV para análisis posterior.
func save_dialog_line(npc_id: String, user_input: String, npc_response: String) -> void:
	var log_dir := "res://data/logs/"
	var log_file := log_dir + "dialog_%s.csv" % npc_id
	if !DirAccess.dir_exists_absolute(log_dir):
		DirAccess.make_dir_recursive_absolute(log_dir)
	if !FileAccess.file_exists(log_file):
		var new_file := FileAccess.open(log_file, FileAccess.WRITE)
		if new_file:
			new_file.store_string("timestamp,user_input,npc_response\n")
			new_file.close()
	var file := FileAccess.open(log_file, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		var timestamp := Time.get_datetime_string_from_system()
		var csv_line := "%s,\"%s\",\"%s\"\n" % [
			timestamp,
			user_input.replace("\"", "\"\""),
			npc_response.replace("\"", "\"\"")
		]
		file.store_string(csv_line)
		file.close()

# Obtiene la afinidad actual del NPC hacia el jugador.
func get_affinity(id: String) -> int:
	return npc[id].get("affinity", 50) if npc.has(id) else 50

# Ajusta la afinidad del NPC sumando o restando un valor específico y guarda el cambio.
func adjust_affinity(id: String, delta: int) -> void:
	if !npc.has(id): return
	var current: int = get_affinity(id)
	var new_affinity: int = int(clamp(current + delta, 0, 100))
	npc[id]["affinity"] = new_affinity
	_save_characters_json()

# Ejecuta eventos asociados a la meta cumplida del NPC, actualiza el objetivo actual y modifica la afinidad según recompensa.
# 1) factor común: ejecutar todos los eventos y avanzar de meta
func _fire_goal(id: String, goal_key: String) -> void:
	var goal_data = npc[id].get("goals", {}).get(goal_key, null)
	if goal_data == null:
		return                        # seguridad 🛡️

	# 1.1) lanzar los eventos
	for ev in goal_data.get("events", []):
		print("[NPCManager] ▶ Emitting:", ev)
		emit_signal("trigger_event", id, ev)

	# 1.2) actualizar meta y afinidad
	npc[id]["current_goal"] = goal_data.get("next_goal", "finalizado")
	adjust_affinity(id, goal_data.get("reward_affinity", 0))
	_save_characters_json()
	print("🎯 Meta de %s completada. Nueva meta: %s" %
		[id, npc[id]["current_goal"]])

# Detecta frases clave del jugador para activar metas del NPC como método alternativo (fallback).
# 2) process_goal ➜ sólo fallback por frases (opcional)
func process_goal(id: String, user_input: String) -> void:
	if !npc.has(id):
		return
	var current_goal = npc[id].get("current_goal", "")
	var goal_data     = npc[id].get("goals", {}).get(current_goal, null)
	if goal_data == null:
		return

	# ⓘ Usamos *trigger_phrases* como último recurso,
	#    por si el LLM no detecta el intent.
	for phrase in goal_data.get("trigger_phrases", []):
		if user_input.to_lower().find(phrase) != -1:
			_fire_goal(id, current_goal)
			break

# Normaliza strings (intents o etiquetas) eliminando espacios y convirtiendo a minúsculas para comparación uniforme.
func _normalize_tag(s: String) -> String:
	return s.strip_edges().to_lower().replace(" ", "_")
	
# Gestiona intents detectados por la IA, activando inmediatamente la meta correspondiente del NPC.
# 3) process_intent ➜ fuente **principal**
func process_intent(id: String, intent: String) -> void:
	if !npc.has(id):
		return

	var norm_intent := _normalize_tag(intent)
	norm_intent = INTENT_ALIAS.get(norm_intent, norm_intent) 
	var goals = npc[id].get("goals", {})

	for goal_key in goals.keys():
		var goal_data = goals[goal_key]
		var triggers = goal_data.get("trigger_intent", [])

		# conviértelo todo a array para simplificar
		if typeof(triggers) == TYPE_STRING:
			triggers = [triggers]

		for t in triggers:
			if _normalize_tag(t) == norm_intent:
				_fire_goal(id, goal_key)
				return   # ⬅️ ya lo encontramos

# Devuelve la clave del objetivo actual del NPC.
func get_current_goal(id: String) -> String:
	if !npc.has(id): return "Sin objetivo"
	return npc[id].get("current_goal", "Sin objetivo")

# Devuelve una descripción legible del objetivo actual asignado al NPC.
func get_goal_description(id: String) -> String:
	if !npc.has(id): return "Sin descripción de meta."
	var goals: Dictionary = npc[id].get("goals", {})
	var current_goal: String = npc[id].get("current_goal", "")
	if goals.has(current_goal):
		return "Objetivo actual: %s" % current_goal
	return "Sin objetivo asignado."
