# Soldado.gd  (ahora hereda directamente de NPCController)
extends NPCController

func _ready() -> void:
	character_id = "soldado"          # o "soldado_1", "soldado_2"…
	add_to_group("squad_general_telas")
	super._ready()                    # inicializa animaciones, etc.

func die() -> void:
	_die_basic()                      # sólo su propia muerte
