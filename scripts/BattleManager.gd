#BattleManager.gd
extends Node

signal player_ready
signal enemy_action
signal battle_ended(result)
signal health_updated
signal atb_updated

enum BattleState { IDLE,PROCESSING, WON, LOST }
var current_state: BattleState = BattleState.PROCESSING

var player: Combatant
var enemy: Combatant
var action_queue: Array = []

var npc_id: String = ""  # ID de referencia al JSON
var round_idx : int = 1          # empieza en 1


func _disconnect_signals() -> void:
	for c in [player, enemy]:
		if is_instance_valid(c):
			if c.stats_updated.is_connected(_on_stats_updated):
				c.stats_updated.disconnect(_on_stats_updated)
			if c.atb_ready.is_connected(_on_combatant_atb_ready):
				c.atb_ready.disconnect(_on_combatant_atb_ready)

func start_battle(player_ref: Combatant, enemy_ref: Combatant):
	_disconnect_signals()
	player = player_ref
	enemy = enemy_ref

	if NpcManager.npc.has(npc_id):
		var data = NpcManager.npc[npc_id]
		if data.has("combat_stats"):
			enemy.stats = data["combat_stats"].duplicate(true)  # Copia profunda para no compartir referencias
		if data.has("skills"):
			enemy.skills = data["skills"].duplicate(true)
	else:
		push_warning("NPC ID no encontrado: " + npc_id)

	for c in [player, enemy]:
		if is_instance_valid(c):
			c.stats.current_hp = c.stats.max_hp
			c.stats.current_mp = c.stats.get("max_mp", 0)
			c.can_charge = true
			c.reset_atb()

	player.stats_updated.connect(_on_stats_updated)
	enemy.stats_updated.connect(_on_stats_updated)
	player.atb_ready.connect(_on_combatant_atb_ready)
	enemy.atb_ready.connect(_on_combatant_atb_ready)

	health_updated.emit()
	current_state = BattleState.PROCESSING
	round_idx = 1                                # ← NUEVO
	for c in [player, enemy]:                    # ← NUEVO
		if is_instance_valid(c):                 # ← NUEVO
			c.reset_round_flags()                # necesita método nuevo en Combatant


func _process(delta):
	if current_state == BattleState.PROCESSING:
		atb_updated.emit()
		while action_queue.size() > 0:
			var next_combatant: Combatant = action_queue.pop_front()
			if next_combatant == player:
				emit_signal("player_ready")
			elif next_combatant == enemy:
				emit_signal("enemy_action")

func _on_combatant_atb_ready(combatant: Combatant) -> void:
	if is_instance_valid(combatant):
		action_queue.append(combatant)
	# NO marcamos aquí; se marca al ejecutar la acción

func _on_stats_updated():
	health_updated.emit()

func _on_combatant_died(combatant: Combatant):
	if combatant == player:
		player = null
	elif combatant == enemy:
		enemy = null
	_check_battle_status()

func execute_enemy_action() -> void:
	if not (is_instance_valid(player) and is_instance_valid(enemy)):
		return

	var selected_skill : Variant = _decide_enemy_action(enemy)
	if selected_skill == null:
		_basic_attack(enemy, player)
		_finalize_enemy_turn()
		return

	if enemy.stats.current_mp < selected_skill.cost:
		print("[IA] Sin MP, ataque básico.")
		_basic_attack(enemy, player)
		_finalize_enemy_turn()
		return

	enemy.take_mp(selected_skill.cost)

	match selected_skill.type:
		"heal":
			var heal_amount: int = selected_skill.power
			enemy.stats.current_hp = min(enemy.stats.current_hp + heal_amount, enemy.stats.max_hp)
			print("[IA] %s se cura %d HP con %s" % [enemy.name, heal_amount, selected_skill.name])
			enemy.emit_signal("stats_updated")

		"damage":
			var dmg: int = enemy.calculate_damage(player, selected_skill.power)
			player.take_damage(dmg)
			print("[IA] %s inflige %d daño con %s" % [enemy.name, dmg, selected_skill.name])

		"buff":
			print("[IA] %s activa %s (buff)" % [enemy.name, selected_skill.name])

		_:
			print("[IA] Tipo de habilidad desconocido: %s" % selected_skill.name)

	#-- Efecto adicional -----------------------------------------------------
	if selected_skill.has("effect") and selected_skill.effect != "none":
		var tgt: Combatant = enemy if selected_skill.type == "buff" else player
		apply_combat_effect(enemy, tgt, selected_skill)

	_finalize_enemy_turn()

func _finalize_enemy_turn() -> void:
	enemy.reset_atb()               # se vacía su barra
	_mark_action_done(enemy)        # ← marca que ya actuó
	_check_battle_status()

func apply_combat_effect(user: Combatant, target: Combatant, effect_data: Dictionary) -> void:
	#────────────────────────────────────────────────────────
	if not is_instance_valid(target):
		return

	# Godot 4: si el destino del get() es String, tipamos explícito
	var eff: String = String(effect_data.get("effect", "none"))

	match eff:
		"poison":
			target.apply_effect({
				"name": "poison",
				"duration": effect_data.get("duration", 3),
				"power": effect_data.get("effect_power", 5)
			})
			_log_effect("[VENENO] %s ha sido envenenado por %d turnos.",
				[target.name, effect_data.get("duration", 3)])

		"disable_skills":
			target.apply_effect({
				"name": "disable_skills",
				"duration": effect_data.get("duration", 2)
			})
			_log_effect("[DESACTIVACIÓN] %s no puede usar habilidades por %d turnos.",
				[target.name, effect_data.get("duration", 2)])

		"increase_attack","increase_defense","increase_speed","lower_attack","lower_defense","lower_speed":
			# 1 ─ stat afectada --------------------------------------------------------
			var stat_target: String = String(effect_data.get("stat_target", ""))
			if stat_target == "":
				if eff.ends_with("attack"):
					stat_target = "attack"
				elif eff.ends_with("defense"):
					stat_target = "defense"
				else:
					stat_target = "speed"

			# 2 ─ modificador con signo ----------------------------------------------
			var base_mod: int = int(effect_data.get("modifier", 10))       # siempre +
			var final_mod: int = -base_mod if eff.begins_with("lower_") else base_mod

			# 3 ─ aplicar efecto ------------------------------------------------------
			target.apply_effect({
				"name": eff,
				"duration": effect_data.get("duration", 3),
				"modifier": final_mod,
				"stat_target": stat_target
			})

			# 4 ─ log ----------------------------------------------------------------
			var tag: String = "[DEBUFF]" if eff.begins_with("lower_") else "[BUFF]"
			_log_effect("%s %s %s en %+d durante %d turnos.",
				[tag, target.name, stat_target, final_mod, effect_data.get("duration", 3)])

		"buff_all":
			var clone := effect_data.duplicate(true)
			target.apply_effect(clone)  # ya incluye duration + modifiers
			_log_effect("[OVERDRIVE] %s usa %s y potencia todas sus estadísticas durante %d rondas.",
				[target.name, effect_data.get("name", "Overdrive"), effect_data.get("duration", 3)])

		_:
			pass  # efecto no contemplado





func _log_effect(message: String, args: Array) -> void:
	if has_node("/root/BattleUI"):
		var ui = get_node("/root/BattleUI")
		ui.add_log_message(message % args)

func should_use_skill(combatant: Combatant, skill: Dictionary) -> bool:
	var hp_ratio = float(combatant.stats.current_hp) / combatant.stats.max_hp
	var player_hp_ratio = float(player.stats["current_hp"]) / player.stats["max_hp"]

	match skill.type:
		"heal":
			return hp_ratio < 0.6  # Ahora se cura incluso si no está en crítico, es más precavido

		"buff":
			if hp_ratio > 0.5:
				return true  # Buff cuando se siente seguro
			return skill.effect in ["increase_defense", "increase_evasion"] and hp_ratio > 0.3

		"damage":
			if player_hp_ratio < 0.3:
				return true  # Remata si puede
			return skill.cost <= (combatant.stats.current_mp * 0.5)  # Si es asequible

	return false

func _decide_enemy_action(combatant: Combatant) -> Variant:
	var personality = NpcManager.npc.get(combatant.npc_id, {}).get("combat_personality", "neutral")
	var state = evaluate_combat_state(combatant)

	var usable_skills = combatant.skills.filter(
		func(s): return combatant.stats.current_mp >= s.cost and should_use_skill(combatant, s)
	)
	print("DEBUG IA - usable_skills:", usable_skills)

	if usable_skills.is_empty():
		return null  # Sin habilidades adecuadas, ataque normal

	if state == "danger":
		var heal_skills = usable_skills.filter(func(s): return s.type == "heal")
		if heal_skills:
			return heal_skills[randi() % heal_skills.size()]  # CURARSE SIN DISCUTIR

		var defensive_buffs = usable_skills.filter(func(s): 
			return s.type == "buff" and s.effect in ["increase_defense", "increase_evasion"]
		)
		if defensive_buffs:
			return defensive_buffs[randi() % defensive_buffs.size()]

		# Como último recurso, atacar
		var damage_skills = usable_skills.filter(func(s): return s.type == "damage")
		if damage_skills:
			return damage_skills[randi() % damage_skills.size()]

		return null  # Ataque básico

	if state == "caution":
		if personality == "defensive":
			var buff_skills = usable_skills.filter(func(s): return s.type == "buff")
			if buff_skills:
				return buff_skills[randi() % buff_skills.size()]

	if state == "safe":
		match personality:
			"aggressive":
				var dmg_skills = usable_skills.filter(func(s): return s.type == "damage")
				if dmg_skills:
					return dmg_skills[randi() % dmg_skills.size()]
			"defensive":
				var buff_skills = usable_skills.filter(func(s): return s.type == "buff")
				if buff_skills:
					return buff_skills[randi() % buff_skills.size()]
			"evasive":
				var debuff_skills = usable_skills.filter(func(s): return s.effect != "none")
				if debuff_skills:
					return debuff_skills[randi() % debuff_skills.size()]

	return usable_skills[randi() % usable_skills.size()]

func _basic_attack(attacker: Combatant, target: Combatant):
	var damage = attacker.calculate_damage(target, 0)  # 0 power -> daño base
	target.take_damage(damage)
	print("[IA] Enemigo realizó ataque básico.")

func evaluate_combat_state(combatant: Combatant) -> String:
	var hp_ratio = float(combatant.stats.current_hp) / combatant.stats.max_hp
	var affinity = NpcManager.get_affinity(combatant.name)

	if hp_ratio < 0.3:
		return "danger"  # Vida baja, riesgo inminente
	elif hp_ratio < 0.6:
		return "caution"  # Vida a la mitad, mejor actuar con precaución
	else:
		return "safe"  # Todo bien, puede actuar con normalidad

# ─── Helpers de ronda ───────────────────────────────────────────────
func _mark_action_done(combatant: Combatant) -> void:
	combatant.has_acted_this_round = true
	if _all_combatants_acted():
		_begin_new_round()

func _all_combatants_acted() -> bool:
	for c in [player, enemy]:
		if is_instance_valid(c) and not c.has_acted_this_round:
			return false
	return true

func _begin_new_round() -> void:
	round_idx += 1
	for c in [player, enemy]:
		if is_instance_valid(c):
			c.process_round_effects()   # nuevo en Combatant
			c.reset_round_flags()
# --------------------------------------------------------------------
func _check_battle_status():
	var enemy_alive = is_instance_valid(enemy) and enemy.stats.current_hp > 0
	var player_alive = is_instance_valid(player) and player.stats.current_hp > 0

	if not enemy_alive:
		current_state = BattleState.WON
		battle_ended.emit("win")
	elif not player_alive:
		current_state = BattleState.LOST
		battle_ended.emit("lose")
