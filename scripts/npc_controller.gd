#npc_controller.gd
extends CharacterBody2D
class_name NPCController

enum AnimState { CLOSE, MID, FAR, CUSTOM }

@export var character_id: String = "default"
@export var anim_config: Dictionary = {
	AnimState.CLOSE: "idle_close",
	AnimState.MID: "idle_mid",
	AnimState.FAR: "idle_far",
	AnimState.CUSTOM: "idle"
}

var frozen := false
var current_anim_state: AnimState = AnimState.FAR
var force_anim_update: bool = true
var is_dead := false  # ← NUEVO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
signal died(npc_ref)

func _ready():
	add_to_group("character")

	animated_sprite.animation_looped.connect(_on_animation_looped)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	initialize_animations()

func _physics_process(delta):
	if frozen:
		velocity = Vector2.ZERO
		return
	
	update_behavior(delta)
	update_animation_state()
	move_and_slide()

func initialize_animations():
	var anim = anim_config[AnimState.FAR]
	if animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)
	else:
		push_error("[NPCController] Animación inicial '%s' no encontrada." % anim)

func update_animation_state():
	# Si ya está en animación "dead", no actualizar más
	if frozen and animated_sprite.animation == "dead":
		return

	var new_state = determine_anim_state()
	
	if new_state != current_anim_state or force_anim_update:
		print("🔄 Cambio de estado de animación: %s → %s" % [str(current_anim_state), str(new_state)])
		handle_animation_transition(new_state)
		current_anim_state = new_state
		force_anim_update = false


func determine_anim_state() -> AnimState:
	# Para ser sobrescrito
	return AnimState.FAR

func handle_animation_transition(new_state: AnimState):
	var target_anim = get_animation_name(new_state)

	if animated_sprite.animation == target_anim:
		return
	
	if animated_sprite.sprite_frames.has_animation(target_anim):
		if should_interrupt_anim():
			print("[NPCController] Reproduciendo animación: %s" % target_anim)
			animated_sprite.play(target_anim)
	else:
		push_error("[NPCController] ❌ Falta animación: %s" % target_anim)

func get_animation_name(state: AnimState) -> String:
	return anim_config.get(state, "idle")

func should_interrupt_anim() -> bool:
	return true

func _on_animation_looped():
	pass

func _on_animation_finished():
	pass

func update_behavior(delta: float) -> void:
	pass




#Funcion para que se mueran en el mapa
func _die_basic() -> void:
	if is_dead:
		return
	is_dead = true

	print("☠️ NPC ha muerto: ", character_id)
	# 1) animación ‘dead’
	if has_node("AnimatedSprite2D"):
		var sprite = $AnimatedSprite2D
		if sprite.sprite_frames.has_animation("dead"):
			sprite.play("dead")
	# 2) desactivar colisiones
	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = true
	if has_node("Area2D"):
		$Area2D.monitoring = false
		$Area2D.monitorable = false
	# 3) sacarlo de grupos para que PlayerController no lo vuelva a detectar
	remove_from_group("character")
	remove_from_group("squad_general_telas")
	# 4) congelar su lógica
	set_physics_process(false)
	set_process(false)
	frozen = true

	# 5) ¡emitimos señal!
	emit_signal("died", self)
	print("[DIED SIGNAL] emitido por:", self, "id=", character_id)

	
