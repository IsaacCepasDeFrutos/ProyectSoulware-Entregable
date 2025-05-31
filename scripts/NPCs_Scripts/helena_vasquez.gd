extends NPCController

const ANIMATIONS := {
	"close": "idle_1_close",
	"mid": "idle_2",
	"far": "idle_3"
}

var CLOSE_RANGE := 80.0  # 25% más cerca que antes
var MID_RANGE := 300.0    # 16.6% más cerca

var time_accumulator := 0.0  # Para contar tiempo

func _ready():
	
	character_id = "helena"
	anim_config = {
		AnimState.CLOSE: ANIMATIONS.close,
		AnimState.MID: ANIMATIONS.mid,
		AnimState.FAR: ANIMATIONS.far
	}
	super._ready()

func _physics_process(delta):
	time_accumulator += delta
	if time_accumulator >= 5.0:
		_print_debug()
		time_accumulator = 0.0
	
	# Llamada al método del padre para procesamiento principal
	super._physics_process(delta)

func determine_anim_state() -> AnimState:
	# Obtener referencia directa al jugador en tutorial_stage
	var main_scene = get_tree().root.get_node("tutorial_stage")
	var player = main_scene.get_node("player/CharacterBody2D") if main_scene else null
	
	if !player or frozen:
		return AnimState.FAR

	var distance = global_position.distance_to(player.global_position)
	
	if distance <= CLOSE_RANGE:
		return AnimState.CLOSE
	elif distance <= MID_RANGE:
		return AnimState.MID
	return AnimState.FAR
func _print_debug():
	var player = get_tree().get_first_node_in_group("Player")
	if !player:
		print("No se encontró el nodo Player")
		return

	var distance = global_position.distance_to(player.global_position)

	var state := ""
	if distance <= CLOSE_RANGE:  # Corregido con <=
		state = "CLOSE"
	elif distance <= MID_RANGE:   # Corregido con <=
		state = "MID"
	else:
		state = "FAR"

	var current_anim = animated_sprite.animation


	
func get_npc_id() -> String:
	return character_id
