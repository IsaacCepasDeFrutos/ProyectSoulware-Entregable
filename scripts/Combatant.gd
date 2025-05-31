#Combatant.gd
extends Node2D
class_name Combatant

signal stats_updated
signal atb_ready(combatant)

func _ready() -> void:
	set_process(true)

var npc_id: String = ""

var has_acted_this_round: bool = false              # ← bandera de ronda
var skill_cooldowns: Dictionary = {}                # nombre → turnos restantes

var stats = {
	"max_hp": 120,
	"current_hp": 120,
	"max_mp": 60,
	"current_mp": 60,
	"attack": 500,
	"defense": 15,
	"speed": 25,
	"critical_chance": 0.1  # 10% probabilidad de crítico
}
var stat_modifiers = {
	"attack": 0,
	"defense": 0,
	"speed": 0,
	"critical_chance" : 0,
}


var skills = [
	{
		"name": "Plasma Slash",
		"cost": 12,
		"type": "damage",
		"power": 35,
		"effect": "none"
	},
	{
		"name": "Neuro Boost",
		"cost": 10,
		"type": "buff",
		"effect": "increase_speed",
		"modifier": 50,  # Aumento de velocidad
		"stat_target": "speed",
		"duration": 3
	},
	{
		"name": "Overload Shot",
		"cost": 20,
		"type": "damage",
		"power": 50,
		"effect": "critical_hit"
	},
	{
		"name": "Quick Patch",
		"cost": 15,
		"type": "heal",
		"power": 30,
		"effect": "heal"
	},
	{
		"name": "Poison Strike",
		"cost": 15,
		"type": "damage",
		"power": 20,
		"effect": "poison",
		"duration": 3,
		"effect_power": 5
	},
	{
		"name": "Data Breach",
		"cost": 15,
		"type": "damage",
		"power": 30,
		"effect": "lower_defense",
		"stat_target": "defense",
		"modifier": 10,
		"duration": 3
	},
	{
		"name": "Sunlight Yellow Overdrive",
		"type": "buff",
		"cost": 0,
		"cooldown": 10,              # en rondas
		"effect": "buff_all",
		"duration": 3,
		"modifiers": {               # se aplican los 4 a la vez
			"attack": 20,
			"defense": 20,
			"speed": 50,
			"critical_chance": 0.1
		}
	},
]

var items = [
	{
		"name": "Poción",
		"quantity": 3,
		"type": "heal",
		"power": 20
	},
	{
		"name": "Ether",
		"quantity": 2,
		"type": "restore_mp",
		"power": 10
	}
]

var active_effects: Array = []  # Lista de efectos activos: { "name": "poison", "duration": 3, "power": 10 }

var atb_charge: float = 0.0
var atb_max: float = 100.0
var can_charge: bool = true
var speed_factor = log(stats.speed + 1) * 10  # Escalado logarítmico para evitar crecimientos absurdos

func _process(delta: float):
	if BattleManager.current_state not in [
		BattleManager.BattleState.WON,
		BattleManager.BattleState.LOST
	] and can_charge:
		atb_charge += speed_factor * delta
		atb_charge = clamp(atb_charge, 0, atb_max)
		
		if atb_charge >= atb_max:
			emit_signal("atb_ready", self)
			can_charge = false

func reset_round_flags() -> void:
	has_acted_this_round = false
	# el ATB vuelve a cargarse automáticamente; nada más aquí

func reset_atb():
	atb_charge = 0.0
	can_charge = true

func take_damage(amount: int):
	var final_damage = max(1, amount - stats.defense)
	stats.current_hp = clamp(stats.current_hp - final_damage, 0, stats.max_hp)
	emit_signal("stats_updated")
	
	print("%s recibió %d de daño. HP restante: %d" % [name, final_damage, stats.current_hp])
	
	if stats.current_hp <= 0:
		can_charge = false             # ya no carga ATB
		emit_signal("stats_updated")   # fuerza refresco a 0 HP
		BattleManager._on_combatant_died(self)

func take_mp(cost: int):
	stats.current_mp = clamp(stats.current_mp - cost, 0, stats.max_mp)
	emit_signal("stats_updated")

func calculate_damage(target: Combatant, base_power: int) -> int:
	var damage = stats.attack + base_power - target.stats.defense
	damage = max(1, damage)

	# ¿Golpe crítico?
	if randf() < stats.critical_chance:
		damage *= 1.5
		print("[CRÍTICO] ¡Golpe crítico inflige %d de daño!" % damage)
	else:
		print("Golpe normal inflige %d de daño." % damage)

	return int(damage)

# ---------------------------------------------------------------------------
# Recalcula el factor de carga de ATB en función de la velocidad actual
func recalc_speed_factor() -> void:
	speed_factor = log(stats.speed + 1.0) * 10.0
# ---------------------------------------------------------------------------

func apply_effect(effect: Dictionary) -> void:
	# ▸ evita duplicados – solo refresca duración
	for e in active_effects:
		if e.name == effect.name:
			e.duration = max(e.duration, effect.get("duration", 1))
			return
	
	active_effects.append(effect)
	print("[Efecto Aplicado] %s durante %d turnos a %s"
		% [effect.name, effect.duration, name])

	# ▸ ¿buff/debuff de stat?
	if effect.has("stat_target") and effect.has("modifier"):
		var stat: String = effect.stat_target
		var delta := float(effect.modifier)
		if stats.has(stat):
			_add_stat_modifier(stat, delta)
			print("[BUFF/DEBUFF] %s %+d → %s" % [stat, delta, str(stats[stat])])
			
			emit_signal("stats_updated")
	if effect.has("modifiers"):
		for stat in effect.modifiers.keys():
			var delta := float(effect.modifiers[stat])
			if stats.has(stat):
				_add_stat_modifier(stat, delta)
		emit_signal("stats_updated")


func _revert_stat_modifier(effect: Dictionary) -> void:
	if effect.has("modifiers"):
		for stat in effect.modifiers.keys():
			var delta := -float(effect.modifiers[stat])
			if stats.has(stat):
				_add_stat_modifier(stat, delta)
	elif effect.has("stat_target") and effect.has("modifier"):
		var stat: String = effect.stat_target
		var delta := -float(effect.modifier)
		if stats.has(stat):
			_add_stat_modifier(stat, delta)
			print("[BUFF/DEBUFF Expirado] %s %+d → %s"
				% [stat, delta, str(stats[stat])])

	emit_signal("stats_updated")

func _log_effect(message: String, args: Array):
	if has_node("/root/BattleUI"):
		var ui = get_node("/root/BattleUI")
		ui.add_log_message(message % args)

func process_round_effects() -> void:
	# -- 1. bajar cooldowns de skills ------------------------------
	for name in skill_cooldowns.keys():
		skill_cooldowns[name] -= 1
		if skill_cooldowns[name] <= 0:
			skill_cooldowns.erase(name)

	# -- 2. procesar efectos de estado -----------------------------
	for effect in active_effects.duplicate():
		match effect.name:
			"poison":
				take_damage(effect.power)
				_log_effect("[VENENO] %s recibe %d de daño por veneno.", [name, effect.power])

			"disable_skills":
				_log_effect("[DESACTIVACIÓN] %s no puede usar habilidades (quedan %d turnos).",
					[name, effect.duration])

		# ↓ cuenta atrás y expiración
		effect.duration -= 1
		if effect.duration <= 0:
			_revert_stat_modifier(effect)
			active_effects.erase(effect)
			_log_effect("[Efecto Expirado] %s ha perdido el efecto %s.", [name, effect.name])

func is_skill_on_cooldown(skill_name: String) -> bool:
	return skill_cooldowns.has(skill_name)
	
func trigger_skill_cooldown(skill_name: String, turns: int) -> void:
	skill_cooldowns[skill_name] = turns

func _add_stat_modifier(stat: String, delta: float) -> void:
	# añade la key si no existe y acumula
	stat_modifiers[stat] = stat_modifiers.get(stat, 0) + delta
	stats[stat] += delta
	if stat == "speed":
		recalc_speed_factor()
