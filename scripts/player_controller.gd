#player_controller.gd
extends CharacterBody2D
class_name PlayerController

const SPEED = 155.0

var is_in_interaction_zone = false
var interaction_locked := false
var target_npc: Node = null
var candidates : Array[Node] = []     # ← todos los NPC dentro del Área

# 0 = vuelo libre; >0 = gravedad activa
var gravity_scale := 0.0

@onready var animated_sprite = $AnimatedSprite2D
@onready var interaction_zone = $Area2D
@onready var ui_interaction = $Control
@onready var camera = $Camera2D

signal interaction_started
signal interaction_ended

func _ready():
	interaction_zone.body_entered.connect(_on_interaction_zone_body_entered)
	interaction_zone.body_exited.connect(_on_interaction_zone_body_exited)

	var scene = get_tree().get_current_scene()
	if scene.has_method("get_scene_file_path") and scene.get_scene_file_path().ends_with("tutorial_outside.tscn"):
		gravity_scale = 4.0
		camera.zoom = Vector2(8, 8)  # 2× de acercamiento
		print("→ Zoom activado en tutorial_outside")
	else:
		gravity_scale = 0.0
		camera.zoom = Vector2(5, 5)      # zoom normal
		print("→ Zoom restablecido")

func _physics_process(delta):
	if gravity_scale > 0.0:
		apply_gravity(delta)
		handle_movement_horizontal()
	else:
		handle_movement_free(delta)

	handle_animations()
	handle_interactions()
	move_and_slide()

func apply_gravity(delta):
	var g = ProjectSettings.get_setting("physics/2d/default_gravity")
	velocity.y += g * gravity_scale * delta

func handle_movement_horizontal():
	if interaction_locked:
		velocity.x = 0
		return
	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity.x = dir.x * SPEED

func handle_movement_free(delta):
	if interaction_locked:
		velocity = Vector2.ZERO
		return
	var dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir.normalized() * SPEED

# ----------------------
# Nueva versión de animaciones
func handle_animations():
	var anim = "idle"

	if gravity_scale > 0.0:
		# Con gravedad, sólo animar "run" si hay velocidad X
		if velocity.x != 0:
			anim = "run"
	else:
		# Sin gravedad, animar "run" si nos movemos en cualquier dirección
		if velocity.length() > 0:
			anim = "run"

	# Voltear sprite sólo según el eje X
	if velocity.x != 0:
		animated_sprite.flip_h = velocity.x < 0

	animated_sprite.play(anim)

func handle_interactions():
	if is_in_interaction_zone and Input.is_action_just_pressed("ui_interact"):
		# ← conecta la señal died justo antes de emitir interaction_started
		if target_npc and not target_npc.is_connected("died", Callable(self, "_on_npc_died")):
			target_npc.connect("died", Callable(self, "_on_npc_died"), CONNECT_ONE_SHOT)
		emit_signal("interaction_started")
		print("Interacción iniciada con NPC")

func _on_interaction_zone_body_entered(body):
	if body is NPCController and not body.is_dead and body.is_in_group("character"):
		candidates.append(body)
		_update_target()                 # ← NUEVO	
		is_in_interaction_zone = true
		ui_interaction.visible = true

func _on_interaction_zone_body_exited(body):
	if body == target_npc:
		# si el que sale era el objetivo, borramos también la conexión
		if target_npc.is_connected("died", Callable(self, "_on_npc_died")):
			target_npc.disconnect("died", Callable(self, "_on_npc_died"))
		candidates.erase(body)
		_update_target()
		is_in_interaction_zone = false
		ui_interaction.visible = false
		emit_signal("interaction_ended")


func _update_target() -> void:
	if candidates.is_empty():
		target_npc = null
		ui_interaction.hide()
		return

	# 1º el General, 2º el más cercano al jugador
	candidates.sort_custom(Callable(self, "_cmp_npc"))   # ← llamada correcta

	target_npc = candidates[0]
	ui_interaction.show()

## --- comparador para sort_custom -------------------------------
func _cmp_npc(a: Node, b: Node) -> bool:
	var a_gen: bool = (a is NPCController) and a.character_id == "general_telas"
	var b_gen: bool = (b is NPCController) and b.character_id == "general_telas"

	if a_gen and !b_gen:
		return true            # a primero
	if b_gen and !a_gen:
		return false           # b primero

	# - si los dos son / no son el General → el más cercano al jugador primero
	return position.distance_to(a.position) < position.distance_to(b.position)
	
# ← Nuevo método para limpiar el target cuando muere
# cuando un NPC muere
func _on_npc_died(npc_ref):
	if npc_ref == target_npc:
		candidates.erase(npc_ref)
		clear_interaction()

# fuerza el “salir” de todos
func clear_interaction():
	target_npc = null
	candidates.clear()
	is_in_interaction_zone = false
	ui_interaction.hide()
