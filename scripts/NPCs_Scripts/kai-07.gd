#kai-07.gd Todos los npc tienen un script similar
extends NPCController

@export var walk_speed: float = 18.0

# Rango de detección para cambiar animaciones cercanas/medias/lejos
const CLOSE_RANGE: float = 80.0
const MID_RANGE:   float = 300.0

# Animaciones de proximidad
const ANIMATIONS: Dictionary = {
	"close": "aim",
	"mid":   "idle",
	"far":   "idle"
}

# --- Estado interno de movimiento ---
var moving:          bool     = false
var target_position: Vector2  = Vector2.ZERO

# Acumulador para prints en _print_debug()
var time_accumulator: float   = 0.0

# Referencias a nodos hijos
@onready var nav_agent := $NavigationAgent2D as NavigationAgent2D
@onready var sprite    := $AnimatedSprite2D   as AnimatedSprite2D


func _ready() -> void:
	character_id = "kai07"
	anim_config = {
		AnimState.CLOSE: ANIMATIONS["close"],
		AnimState.MID:   ANIMATIONS["mid"],
		AnimState.FAR:   ANIMATIONS["far"]
	}

	# Ajustes opcionales de NavigationAgent2D
	nav_agent.target_desired_distance = 4.0
	nav_agent.path_max_distance     = 1000.0
	nav_agent.debug_enabled = false
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if moving:
		if nav_agent.is_navigation_finished():
			moving = false
			velocity = Vector2.ZERO
			sprite.play("idle")
			return

		# 1) Calcula la velocidad “ideal”
		var next_pt   = nav_agent.get_next_path_position()
		var ideal_dir = (next_pt - global_position).normalized()
		var ideal_vel = ideal_dir * walk_speed

		# 2) ¿Chocaría con algo?
		if test_move(global_transform, ideal_vel * delta):
			ideal_vel = avoid_obstacles(ideal_vel, delta)

		# 3) Asigna esa velocidad y llama a move_and_slide()
		velocity = ideal_vel
		move_and_slide()

		# 4) Comunícasela al agente (para que haga avoidance interno si lo tienes activado)
		nav_agent.set_velocity(velocity)

		
# --- STEERING LOCAL ------------------------------------------------

# Prueba varias rotaciones hasta encontrar un vector que no choque
func avoid_obstacles(vel: Vector2, delta: float) -> Vector2:
	var angles = [30, -30, 60, -60]
	for angle in angles:
		var try_vel = vel.rotated(deg_to_rad(angle))
		if not test_move(global_transform, try_vel * delta):
			return try_vel
	return Vector2.ZERO



# --------------------------------------------------------------------


func determine_anim_state() -> AnimState:
	var main_scene = get_tree().root.get_node("tutorial_stage")
	var player: CharacterBody2D = null
	if main_scene:
		player = main_scene.get_node_or_null("player/CharacterBody2D")
	if player == null or frozen:
		return AnimState.FAR

	var dist = global_position.distance_to(player.global_position)
	if dist <= CLOSE_RANGE:
		return AnimState.CLOSE
	elif dist <= MID_RANGE:
		return AnimState.MID
	return AnimState.FAR


func _print_debug() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player == null:
		print("No se encontró el nodo Player")
		return

	var dist = global_position.distance_to(player.global_position)
	var state = "CLOSE" if dist <= CLOSE_RANGE else ("MID" if dist <= MID_RANGE else "FAR")
	print("📍 Kai-07 distancia al jugador: %.2f px → Estado: %s" % [dist, state])


func start_pathfinding_move(dest: Dictionary, speed: float) -> void:
	print("[Kai-07] start_pathfinding_move llamado con:", dest, speed)
	# Extrae X e Y correctamente de dest
	var x = dest.get("x", global_position.x)
	var y = dest.get("y", global_position.y)
	target_position = Vector2(x, y)
	walk_speed = speed
	nav_agent.target_position = target_position
	moving = true
	sprite.play("walk")



func get_npc_id() -> String:
	return character_id
