extends NPCController
class_name Soldado

const ANIMATIONS := {
	"close": "aim",
	"mid": "idle",
	"far": "idle"
}

# Rango a copiar de General (o ajusta a gusto)
var CLOSE_RANGE := 80.0
var MID_RANGE   := 300.0


func _ready() -> void:
	character_id = "soldado"
	# Pilla las animaciones correctas para cada estado
	anim_config = {
		AnimState.CLOSE: ANIMATIONS.close,
		AnimState.MID:   ANIMATIONS.mid,
		AnimState.FAR:   ANIMATIONS.far
	}
	add_to_group("squad_general_telas")
	super._ready()

func _physics_process(delta):
	# Si quieres debug (opcional) luego:
	super._physics_process(delta)

func determine_anim_state() -> AnimState:
	# Mismo cálculo de distancia que en GeneralTelas
	var main_scene = get_tree().root.get_node("tutorial_stage")
	var player = main_scene.get_node("player/CharacterBody2D") if main_scene else null
	if not player or frozen:
		return AnimState.FAR
	var d = global_position.distance_to(player.global_position)
	if d <= CLOSE_RANGE:
		return AnimState.CLOSE
	elif d <= MID_RANGE:
		return AnimState.MID
	return AnimState.FAR

func die() -> void:
	if is_dead:
		return
	# reenviar al jefe
	var leader := get_parent()
	while leader and not (leader is GeneralTelas):
		leader = leader.get_parent()
	if leader and not leader.is_dead:
		leader.die()
	else:
		_die_basic()
