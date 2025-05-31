#BattleUI.gd
extends Control

@onready var player_hp_label = $PlayerPanel/PlayerHP
@onready var enemy_hp_label = $EnemyPanel/EnemyHP
@onready var action_buttons = $ActionButtons
@onready var battle_log = $BattleLog
@onready var player_atb = $PlayerPanel/ATBProgress
@onready var enemy_atb = $EnemyPanel/ATBProgress
@onready var player_mp_bar = $PlayerPanel/MPProgress
@onready var player_mp_label = $PlayerPanel/MPProgress/Label

func _ready():
	hide_actions()
	_connect_signals()
	_safe_update_stats()

func _connect_signals():
	BattleManager.health_updated.connect(self._safe_update_stats)
	BattleManager.battle_ended.connect(self._on_battle_ended)
	BattleManager.atb_updated.connect(self._update_atb_bars)
	
	# NUEVAS señales activas
	BattleManager.player_ready.connect(self._on_player_ready)
	BattleManager.enemy_action.connect(self._on_enemy_action)
	
	# Botón de Ataque
	$ActionButtons/AttackButton.pressed.connect(self._on_attack_button_pressed)
	
	# Botón de Huir
	$ActionButtons/RunButton.pressed.connect(self.on_run_button_pressed)
	
	#Boton de Habilidad
	$ActionButtons/SkillButton.pressed.connect(self._on_skill_button_pressed)
	
	#Boton de Objetos
	$ActionButtons/ItemButton.pressed.connect(self._on_item_button_pressed)

func _safe_update_stats():
	if is_instance_valid(BattleManager.player):
		player_hp_label.text = "HP: %d/%d" % [
			BattleManager.player.stats["current_hp"],
			BattleManager.player.stats["max_hp"]
		]
		
		# Actualizar MP en la barra y en el Label
		player_mp_bar.max_value = BattleManager.player.stats["max_mp"]
		player_mp_bar.value = BattleManager.player.stats["current_mp"]
		
		# Opcional: si quieres un texto sobre la barra
		player_mp_label.text = "MP: %d/%d" % [
			BattleManager.player.stats["current_mp"],
			BattleManager.player.stats["max_mp"]
		]
		
	if is_instance_valid(BattleManager.enemy):
		enemy_hp_label.text = "HP: %d/%d" % [
			BattleManager.enemy.stats["current_hp"],
			BattleManager.enemy.stats["max_hp"]
		]

func _update_atb_bars():
	if is_instance_valid(BattleManager.player):
		player_atb.value = BattleManager.player.atb_charge
	if is_instance_valid(BattleManager.enemy):
		enemy_atb.value = BattleManager.enemy.atb_charge

func show_actions():
	action_buttons.visible = true

func hide_actions():
	action_buttons.visible = false

func add_log_message(message: String):
	battle_log.text += "> " + message + "\n"
	battle_log.scroll_vertical = battle_log.get_v_scroll_bar().max_value

# Aviso de que la barra del jugador llegó a tope
func _on_player_ready():
	add_log_message("El jugador puede actuar.")
	show_actions()

# Aviso de que el enemigo va a atacar
func _on_enemy_action():
	add_log_message("¡El enemigo ataca!")
	BattleManager.execute_enemy_action()
	_update_atb_bars()

func _on_battle_ended(result: String):
	hide_actions()
	add_log_message("Batalla terminada. Resultado: " + ("Victoria" if result == "win" else "Derrota"))
	await get_tree().create_timer(2.0).timeout
	#get_tree().change_scene_to_file("res://World.tscn")

func _on_attack_button_pressed():
	$SkillPanel.visible = false
	$ItemPanel.visible = false
	$FramePanel.visible = false
	
	if is_instance_valid(BattleManager.player) and is_instance_valid(BattleManager.enemy):
		var damage = BattleManager.player.calculate_damage(BattleManager.enemy, 0)
		var is_crit = damage > (BattleManager.player.stats["attack"] - BattleManager.enemy.stats["defense"])  # Simple check
		
		add_log_message("El jugador ataca." + (" ¡CRÍTICO!" if is_crit else ""))
		if is_crit:
			show_critical_popup()
		BattleManager.enemy.take_damage(damage)
		
		BattleManager.player.reset_atb()
		hide_actions()
		BattleManager._mark_action_done(BattleManager.player)

		await get_tree().process_frame
		BattleManager._check_battle_status()


func on_run_button_pressed():
	# Cierra skill e item panel
	$SkillPanel.visible = false
	$ItemPanel.visible = false
	$FramePanel.visible = false
	
	add_log_message("Has elegido huir, reseteando la batalla...")
	
	# Si el player existe, restaurar HP y resetear su ATB
	if is_instance_valid(BattleManager.player):
		BattleManager.player.stats["current_hp"] = BattleManager.player.stats["max_hp"]
		BattleManager.player.reset_atb()
		
	# Si el enemy existe, restaurar HP y resetear su ATB
	if is_instance_valid(BattleManager.enemy):
		BattleManager.enemy.stats["current_hp"] = BattleManager.enemy.stats["max_hp"]
		BattleManager.enemy.reset_atb()
		
	# Limpiar la cola de acciones
	BattleManager.action_queue.clear()
	
	# Volvemos al estado “PROCESSING” para que ambos recarguen sus ATBs
	BattleManager.current_state = BattleManager.BattleState.PROCESSING
	
	# Actualizar la interfaz (HP y barras ATB)
	_safe_update_stats()
	_update_atb_bars()
	
	# Además, ocultamos los botones (como si nadie tuviera turno)
	hide_actions()

func _on_skill_button_pressed():
	if BattleManager.player and BattleManager.player.active_effects.any(func(e): return e.name == "disable_skills"):
		add_log_message("🚫 ¡No puedes usar habilidades! Estás deshabilitado por efecto.")
		return  # Bloquea el uso de habilidades sin deshabilitar el botón

	$ItemPanel.visible = false
	$SkillPanel.visible = not $SkillPanel.visible

	if $SkillPanel.visible:
		# Si acabamos de mostrar el panel, podemos generar los botones
		# (si deseas crearlos dinámicamente)
		$FramePanel.visible = true
		_populate_skill_buttons()


func _populate_skill_buttons():
	var container = $SkillPanel/SkillList
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

	if BattleManager.player and BattleManager.player.skills:
		for skill_data in BattleManager.player.skills:
			var btn := Button.new()

			var cd_left := 0
			if BattleManager.player.is_skill_on_cooldown(skill_data.name):
				cd_left = BattleManager.player.skill_cooldowns[skill_data.name]

			var suffix := "  (CD %d)" % cd_left if cd_left > 0 else ""
			btn.text = "%s%s" % [skill_data.name, suffix]
			btn.disabled = cd_left > 0

			btn.pressed.connect(func(): _on_skill_chosen(skill_data))
			container.add_child(btn)


func _on_skill_chosen(skill_data: Dictionary) -> void:
	#-- Log inicial ----------------------------------------------------------
	add_log_message("¡Usaste %s!" % skill_data.name)

	#-- Comprobación de MP ---------------------------------------------------
	if BattleManager.player.stats.current_mp < skill_data.cost:
		add_log_message("No tienes suficiente MP para %s." % skill_data.name)
		return
	BattleManager.player.take_mp(skill_data.cost)
	
	if BattleManager.player.is_skill_on_cooldown(skill_data.name):
		add_log_message("❌ %s aún está en recarga." % skill_data.name)
		return


	#-- Resolución principal -------------------------------------------------
	match skill_data.type:
		"damage":
			var dmg: int = BattleManager.player.calculate_damage(
				BattleManager.enemy, skill_data.power
			)
			var is_crit: bool = dmg > (
				BattleManager.player.stats.attack + skill_data.power - BattleManager.enemy.stats.defense
			)
			add_log_message("Infliges %d daño%s." % [dmg, " ¡CRÍTICO!" if is_crit else ""])
			BattleManager.enemy.take_damage(dmg)

		"heal":
			var heal: int = skill_data.power
			BattleManager.player.stats.current_hp = clamp(
				BattleManager.player.stats.current_hp + heal,
				0,
				BattleManager.player.stats.max_hp
			)
			BattleManager.player.emit_signal("stats_updated")
			add_log_message("Te curas %d HP." % heal)

		"buff":
			pass  # El efecto se aplica más abajo

	#-- Efecto secundario ----------------------------------------------------
	if skill_data.has("effect") and skill_data.effect != "none":
		var tgt: Combatant = BattleManager.player if skill_data.type == "buff" else BattleManager.enemy
		BattleManager.apply_combat_effect(BattleManager.player, tgt, skill_data)
		
	if skill_data.has("cooldown"):
		BattleManager.player.trigger_skill_cooldown(skill_data.name, skill_data.cooldown)
	#-- Fin de turno ---------------------------------------------------------
	$SkillPanel.visible = false
	$FramePanel.visible = false
	
	hide_actions()
	BattleManager.player.reset_atb()
	BattleManager._mark_action_done(BattleManager.player)

	await get_tree().process_frame
	BattleManager._check_battle_status()



func _on_item_button_pressed():
	# Primero cierra el panel de habilidades (por si estaba abierto)
	$SkillPanel.visible = false
	
	$ItemPanel.visible = not $ItemPanel.visible
	
	if $ItemPanel.visible:
		$FramePanel.visible = true
		_populate_item_buttons()

func _populate_item_buttons():
	var container = $ItemPanel/ItemList
	
	# Eliminar antiguos botones
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
	
	# Crear un botón por cada ítem
	if BattleManager.player and BattleManager.player.items:
		for item_data in BattleManager.player.items:
			# Solo creamos botón si quantity > 0
			if item_data.quantity > 0:
				var btn = Button.new()
				btn.text = "%s (x%d)" % [item_data.name, item_data.quantity]
				
				# Conectamos la señal pressed pasando la info del item
				btn.pressed.connect(func():
					_on_item_chosen(item_data)
				)
				
				container.add_child(btn)

func _on_item_chosen(item_data):
	# Ejemplo
	add_log_message("Usas " + item_data.name + "!")
	
	if item_data.quantity <= 0:
		add_log_message("No te quedan " + item_data.name)
		return
	
	# Aplica efecto
	match item_data.type:
		"heal":
			var heal_amount = item_data.power
			var new_hp = min(
				BattleManager.player.stats["current_hp"] + heal_amount,
				BattleManager.player.stats["max_hp"]
			)
			BattleManager.player.stats["current_hp"] = new_hp
			BattleManager.player.emit_signal("stats_updated")
		
		"restore_mp":
			var mp_amount = item_data.power
			var new_mp = min(
				BattleManager.player.stats["current_mp"] + mp_amount,
				BattleManager.player.stats["max_mp"]
			)
			BattleManager.player.stats["current_mp"] = new_mp
			BattleManager.player.emit_signal("stats_updated")
		
		# Podrías tener más tipos: “revive”, “buff”, “cure_poison”, etc.
	
	# Resta 1 a la cantidad
	item_data.quantity -= 1
	
	 # Cierra el panel
	$ItemPanel.visible = false
	$FramePanel.visible = false
	
	# Consumir la acción (igual que atacar/habilidad)
	hide_actions()
	BattleManager.player.reset_atb()
	
	BattleManager._mark_action_done(BattleManager.player)
	# Chequea si la batalla terminó
	await get_tree().process_frame
	BattleManager._check_battle_status()


func show_critical_popup():
	var crit_label = $CriticalLabel
	crit_label.visible = true
	crit_label.modulate.a = 1.0
	crit_label.scale = Vector2(1, 1)  # Reset scale
	
	var tween = create_tween()
	tween.tween_property(crit_label, "scale", Vector2(1.5, 1.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(crit_label, "scale", Vector2(1, 1), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(crit_label, "modulate:a", 0.0, 0.5).set_delay(0.3)  # <- Esta es la línea corregida
	tween.connect("finished", Callable(self, "_on_critical_popup_finished"))

func _on_critical_popup_finished():
	$CriticalLabel.visible = false
