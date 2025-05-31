##  BattleScene.gd – interfaz de combate superpuesta  #########################
extends Control
signal battle_closed

@onready var ui         := $BattleUI
@onready var player     := $"BattleUI/player"     as Combatant
@onready var enemy      := $"BattleUI/character"  as Combatant
@onready var run_button := $BattleUI/ActionButtons/RunButton

func _enter_tree() -> void:
	hide()

func _ready() -> void:
	var dbg_children = get_children()
	print("--- BattleScene children:", dbg_children)
	print("--- node names:", dbg_children.map(func(n): return n.name))
	print("--- player =", player, "enemy =", enemy)

	if not player or not enemy:
		push_error("Error: Player / Enemy faltan")
		return

	BattleManager.battle_ended.connect(_on_battle_end)
	run_button.pressed.connect(_on_run_pressed)

func open_battle() -> void:
	if visible: return
	print("🟢 [open_battle] Iniciando batalla...")
	show()
	BattleManager.npc_id = get_tree().root.get_node("tutorial_stage").get_current_npc_id()
	BattleManager.start_battle(player, enemy)

	call_deferred("_check_hostile_combat")

func _check_hostile_combat() -> void:
	var game_root = get_tree().root.get_node("tutorial_stage")
	if game_root and "next_combat_hostile" in game_root and game_root.next_combat_hostile:
		print("⚠️ Combate hostil detectado. Cargando ATB del enemigo al 90%.")
		if is_instance_valid(enemy):
			enemy.atb_charge = enemy.atb_max * 0.9
			enemy.can_charge = true
			BattleManager.atb_updated.emit()

			if enemy.atb_charge >= enemy.atb_max:
				print("💥 ATB al máximo. Forzando acción enemiga inmediata...")
				enemy.emit_signal("atb_ready", enemy)
	else:
		print("✅ Combate normal. ATB del enemigo inicia a 0.")


func _on_run_pressed() -> void:
	_close_battle()

func _on_battle_end(result: String) -> void:
	if result == "win":
		var root := get_tree().root.get_node("tutorial_stage")
		if root and root.current_npc_ref:
			# → 1. intenta die() si existe
			if root.current_npc_ref.has_method("die"):
				root.current_npc_ref.die()
			# → 2. si NO existe die(), usa la rutina mínima
			elif root.current_npc_ref.has_method("_die_basic"):
				root.current_npc_ref._die_basic()

	await get_tree().create_timer(1.0).timeout
	_close_battle()

func _close_battle() -> void:
	if is_instance_valid(player):
		player.stats.current_hp = player.stats.max_hp
		player.reset_atb()
	if is_instance_valid(enemy):
		enemy.stats.current_hp = enemy.stats.max_hp
		enemy.reset_atb()
	BattleManager._disconnect_signals()
	BattleManager.action_queue.clear()
	BattleManager.current_state = BattleManager.BattleState.PROCESSING

	var game_root = get_tree().root.get_node("tutorial_stage")
	if game_root:
		game_root.next_combat_hostile = false  # Reset flag

		if game_root.has_method("get_current_npc_id"):
			var npc_id: String = game_root.get_current_npc_id()
			if NpcManager.npc.has(npc_id):
				NpcManager.npc[npc_id]["affinity"] = 5
				NpcManager._save_characters_json()

	hide()
	battle_closed.emit()
