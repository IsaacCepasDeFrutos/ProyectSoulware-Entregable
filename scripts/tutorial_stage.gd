#tutorial_stage.gd
extends Node2D

@onready var player_root = $player
@onready var player_scripted = player_root.get_node("CharacterBody2D")
@onready var social_interface = $player/CanvasLayer/Control
@onready var battle_scene = $player/CanvasLayer2/BattleScene
@onready var fade_out = $CanvasLayer/AnimationPlayer
@onready var fade_out_fondo = $CanvasLayer/ColorRect
@onready var exit_container = $ExitConfirmation
@onready var exit_dialog = exit_container.get_node("ConfirmationDialog")

var current_npc_ref: Node = null  # Referencia persistente al NPC en combate
var next_combat_hostile := false

func _ready() -> void:
	add_to_group("gameplay")
	fade_out.play("fade_out")
	fade_out_fondo.visible = false
	DisplayManager._update_brightness()
	
	# Verificación de nodos críticos
	for n in [player_scripted, social_interface, battle_scene]:
		if n == null:
			push_error("❌ Faltan nodos esenciales")
			return

	# Conexión de señales del jugador
	player_scripted.connect("interaction_started", _on_player_interaction_started)
	player_scripted.connect("interaction_ended", _on_player_interaction_ended)
	
	#Conexion de señalas para salir
	exit_dialog.connect("confirmed", Callable(self, "_on_exit_confirmation_confirmed"))
	exit_dialog.connect("canceled", Callable(self, "_on_exit_confirmation_canceled"))
	
	# 1) conectar died para TODOS los NPC de gameplay

	# Estado inicial de interfaces
	social_interface.hide()
	battle_scene.hide()
	
func _input(event):
	var ui_interaction := player_scripted.ui_interaction as Control

	if event.is_action_pressed("combatUI_interact") \
		and not social_interface.visible \
		and ui_interaction.visible:

		current_npc_ref = player_scripted.target_npc
		print("[DEBUG] id =", current_npc_ref.character_id)

		# ← Aquí engancho la señal died sólo para este NPC
		# ← Conectamos la señal died (sin argumentos extras) justo antes de abrir combate
		if current_npc_ref and not current_npc_ref.is_connected("died", Callable(self, "_on_npc_died")):
			current_npc_ref.connect("died", Callable(self, "_on_npc_died"), CONNECT_ONE_SHOT)
			print("[CONNECTED] tutorial_stage ahora escucha died de:", current_npc_ref, "id=", current_npc_ref.character_id)
			var conns = current_npc_ref.get_signal_connection_list("died")
			print("    → conexiones actuales a 'died':", conns)

		if battle_scene.visible:
			battle_scene._on_run_pressed()
		else:
			_freeze_everybody(true)
			ui_interaction.visible = false
			battle_scene.open_battle()
			if not battle_scene.battle_closed.is_connected(_on_battle_closed):
				battle_scene.battle_closed.connect(_on_battle_closed, CONNECT_ONE_SHOT)

func _on_npc_freed():
	current_npc_ref = null
func _get_real_npc_node(n : Node) -> NPCController:
	var cur := n
	while cur and not (cur is NPCController):
		cur = cur.get_parent()
	return cur      # será null sólo si tocas algo que NO es NPC
func _find_general_down(node: Node) -> GeneralTelas:
	if node is GeneralTelas:
		return node
	for child in node.get_children():
		var res := _find_general_down(child)
		if res:
			return res
	return null

# REGION INTERACCIÓN SOCIAL

func _on_player_interaction_started():
	var npc = player_scripted.target_npc
	if npc:
		social_interface.show()
		player_scripted.interaction_locked = true

		# Congelar NPC si tiene variable o método frozen/set_frozen
		if npc.has_method("set_frozen"):
			npc.set_frozen(true)
		elif "frozen" in npc:
			npc.frozen = true
		else:
			print("Advertencia: NPC no tiene propiedad frozen o método set_frozen")
		
		# ASIGNAR NPC AL CONECTOR EXPLÍCITAMENTE
		if social_interface.has_method("set_npc"):
			social_interface.set_npc(npc.character_id)
		
		# Conectar señal de salida para cerrar interfaz social
		if social_interface.has_signal("exit_requested") and not social_interface.is_connected("exit_requested", _on_player_interaction_ended):
			social_interface.connect("exit_requested", _on_player_interaction_ended)

func _on_player_interaction_ended():
	var npc = player_scripted.target_npc
	social_interface.hide()
	player_scripted.interaction_locked = false

	# ─── NUEVO: limpiar referencia al NPC cuando terminas de hablar ───
	current_npc_ref = null
	player_scripted.clear_interaction()

	if npc:
		if npc.has_method("set_frozen"):
			npc.set_frozen(false)
		elif "frozen" in npc:
			npc.frozen = false


# REGION MECÁNICAS DE COMBATE

func _on_battle_closed() -> void:
	next_combat_hostile = false
	_freeze_everybody(false)

	# ─── NUEVO: si has combatido, borramos al target aunque no haya muerto ───
	current_npc_ref = null
	player_scripted.clear_interaction()

	# ahora decides si muestras o no el botón de interacción
#	if player_scripted.is_in_interaction_zone:
#		player_scripted.ui_interaction.visible = true
#	else:
#		player_scripted.ui_interaction.visible = false



func _start_combat_hostile() -> void:
	print("⚔️ Combate iniciado por afinidad hostil")
	next_combat_hostile = true
	_on_player_interaction_ended()
	_freeze_everybody(true)
	battle_scene.open_battle()

	if not battle_scene.battle_closed.is_connected(_on_battle_closed):
		battle_scene.battle_closed.connect(_on_battle_closed, CONNECT_ONE_SHOT)

func _start_combat_player() -> void:
	print("⚔️ Combate iniciado por el jugador")
	next_combat_hostile = false          #  ←  diferencia clave
	_on_player_interaction_ended()
	_freeze_everybody(true)
	battle_scene.open_battle()

	if not battle_scene.battle_closed.is_connected(_on_battle_closed):
		battle_scene.battle_closed.connect(_on_battle_closed, CONNECT_ONE_SHOT)

#endregion

# REGION UTILIDADES

func _freeze_everybody(state: bool) -> void:
	player_scripted.interaction_locked = state
	var npc = current_npc_ref if current_npc_ref else player_scripted.target_npc
	if npc:
		if npc.has_method("set_frozen"):
			npc.set_frozen(state)
		elif "frozen" in npc:
			npc.frozen = state

func get_current_npc_id() -> String:
	return current_npc_ref.character_id if current_npc_ref else ""

#Funcion para poder salir al menu principal
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") and not social_interface.visible and not battle_scene.visible:
		player_scripted.interaction_locked = true
		exit_dialog.popup_centered()
		
		# Forzar foco en el botón Cancelar tras mostrar
		await get_tree().process_frame  # Espera un frame para que el popup esté inicializado
		exit_dialog.get_cancel_button().grab_focus()
func _on_exit_confirmation_confirmed():
	# Eliminar el filtro oscuro si existe
	for child in get_tree().root.get_children():
		if child is CanvasModulate:
			child.queue_free()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
func _on_exit_confirmation_canceled():
	player_scripted.interaction_locked = false
	$ExitConfirmation.hide()


func _on_npc_died(npc_ref: NPCController) -> void:
	print("[ON_NPC_DIED] recibido para:", npc_ref, "id=", npc_ref.character_id)
	if current_npc_ref == npc_ref:
		print("    → Limpiando current_npc_ref porque coincide")
		current_npc_ref = null
		player_scripted.clear_interaction()
	else:
		print("    → Pero current_npc_ref es:", current_npc_ref, "por lo que NO limpia")
