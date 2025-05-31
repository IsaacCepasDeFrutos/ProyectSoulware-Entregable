# Door.gd
extends Area2D

@export var target_scene: String = ""
@onready var lbl_prompt: Label = $Label

var player_in_range := false

func _ready():
	print("[Door.gd] _ready() cargado")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if lbl_prompt:
		lbl_prompt.visible = false

func _on_body_entered(body: Node) -> void:
	# Imprime siempre el nombre y grupos del body que entró
	print("[Door.gd] _on_body_entered recibió:", body.name, "grupos:", body.get_groups())
	# Comprueba si quisieras filtrar luego por grupo—but por ahora, deja sólo el print
	if body.is_in_group("Player"):
		player_in_range = true
		if lbl_prompt:
			lbl_prompt.visible = true
		print("[Door.gd] → EL cuerpo es del grupo 'player'")

func _on_body_exited(body: Node) -> void:
	print("[Door.gd] _on_body_exited recibió:", body.name, "grupos:", body.get_groups())
	if body.is_in_group("Player"):
		player_in_range = false
		if lbl_prompt:
			lbl_prompt.visible = false
		print("[Door.gd] → El jugador ha salido del área")

func _process(delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("ui_interact"):
		print("[Door.gd] Pulsaste E dentro del área de la puerta")
		if target_scene != "":
			var ok = get_tree().change_scene_to_file(target_scene)
			if ok != OK:
				push_error("[Door.gd] No se pudo cambiar a la escena: " + target_scene)
			else:
				print("[Door.gd] Cambiando a escena:", target_scene)
		else:
			push_error("[Door.gd] target_scene no asignado")
