# label_character_info.gd – muestra la ficha del NPC en el recuadro negro
extends Label
@export var default_npc_id : String = "helena"

func _ready() -> void:
	vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	await get_tree().process_frame      # espera a que NPCManager haya corrido
	show_npc(default_npc_id)

func show_npc(id:String) -> void:
	text = NpcManager.info_snippet(id)
