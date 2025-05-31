#gordo_lito.gd
extends NPCController

const ANIMATIONS := {
	"close": "idle",
	"mid":   "idle",
	"far":   "idle"
}

@onready var nav_agent := $NavigationAgent2D
var is_following := false
var follow_target: CharacterBody2D = null
var stop_distance := 48.0

# Velocidad base y velocidad actual
var base_walk_speed := 100.0
var walk_speed := 0.0    # ← Empieza en 0 para que no se mueva

var CLOSE_RANGE := 80.0
var MID_RANGE := 300.0
var time_accumulator := 0.0

func _ready():
	character_id = "gordo_lito"
	anim_config = {
		AnimState.CLOSE: ANIMATIONS.close,
		AnimState.MID:   ANIMATIONS.mid,
		AnimState.FAR:   ANIMATIONS.far
	}

	# 1) Forzamos el following, pero con walk_speed=0 no se desplaza
	set_following(true)
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		nav_agent.target_position = player.global_position
		print("🧪 Forzado path hacia jugador en _ready")

	# 2) Asignar mapa de navegación
	var nav_region = get_tree().root.get_node("tutorial_stage/NavigationRegion2D")
	if nav_region:
		nav_agent.set_navigation_map(nav_region.get_navigation_map())
		print("✅ NavigationMap asignado correctamente")
	else:
		push_error("❌ No se encontró NavigationRegion2D")
	nav_agent.debug_enabled = false

	super._ready()

func _physics_process(delta):
	time_accumulator += delta
	if time_accumulator >= 5.0:
		_print_debug()
		time_accumulator = 0.0

	if frozen:
		velocity = Vector2.ZERO
	else:
		update_behavior(delta)

	update_animation_state()
	move_and_slide()

func set_following(active: bool):
	is_following = active
	if active:
		follow_target = get_tree().get_first_node_in_group("Player")
		print("🔁 Gordo_Lito comienza a seguir al jugador")
	else:
		follow_target = null
		print("⛔ Gordo_Lito deja de seguir")

func update_behavior(delta: float) -> void:
	if not is_following or follow_target == null:
		velocity = Vector2.ZERO
		return

	var dist := global_position.distance_to(follow_target.global_position)
	if dist > stop_distance:
		if nav_agent.is_navigation_finished():
			nav_agent.target_position = follow_target.global_position
		else:
			var next_point: Vector2 = nav_agent.get_next_path_position()
			if next_point != Vector2.ZERO and next_point != global_position:
				# Aquí usamos walk_speed que puede ser 0 o base_walk_speed
				velocity = (next_point - global_position).normalized() * walk_speed
			else:
				velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

# -------------------------------------------------------------------
# Este método se llamará desde tu evento "start_following" para
# restaurar la velocidad de seguimiento.
func allow_movement(enable: bool = true):
	# restablece walk_speed o lo deja a 0
	walk_speed = base_walk_speed if enable else 0
	print("La walk_speed es:", walk_speed)
	# imprime el mensaje correspondiente
	print("🟢 Movimiento DESBLOQUEADO" if enable else "🔴 Movimiento BLOQUEADO")


# helper de debug
func _print_debug():
	#print("📌 Posición NPC:", global_position, " follow?", is_following, " speed:", walk_speed)
	if follow_target:
	#	print("🧭 Posición jugador:", follow_target.global_position)
		pass
	#print("🔥 NAVIGATION FINISHED:", nav_agent.is_navigation_finished())
	#print("🧵 Path actual:", nav_agent.get_current_navigation_path())

func determine_anim_state() -> AnimState:
	var main_scene = get_tree().root.get_node("tutorial_stage")
	var player = main_scene.get_node_or_null("player/CharacterBody2D")
	if not player or frozen:
		return AnimState.FAR

	var dist = global_position.distance_to(player.global_position)
	if dist <= CLOSE_RANGE:
		return AnimState.CLOSE
	elif dist <= MID_RANGE:
		return AnimState.MID
	return AnimState.FAR

func get_npc_id() -> String:
	return character_id
