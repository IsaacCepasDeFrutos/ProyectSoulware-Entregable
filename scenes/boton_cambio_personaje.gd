#boton_cambio_personaje.gd
extends Button

@export var chat_connector : NodePath     # arrástralo en el inspector
@export var info_label     : NodePath     # idem (el Label negro)

var _ids : PackedStringArray = []   # ["helena", "kai07", ...]
var _ix  : int = 0                  # índice actual

func _ready() -> void:
	_ids = NpcManager.npc.keys()        # ya está cargado en _ready() de NPCManager
	if _ids.is_empty():
		disabled = true
		push_warning("No hay NPC en NpcManager")
func _pressed() -> void:
	_ix = (_ix + 1) % _ids.size()       # siguiente personaje
	var id := _ids[_ix]

	# 1· ChatGPTConnector
	var cc := get_node(chat_connector) as Node
	if cc.has_method("set_npc"):
		cc.set_npc(id)

	# 2· Label de la ficha
	var lbl := get_node(info_label) as Label
	if lbl.has_method("show_npc"):
		lbl.show_npc(id)
