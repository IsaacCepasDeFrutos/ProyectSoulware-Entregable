#DisplayManager.gd
extends Node

var brightness := 1.0  # De 0.0 (oscuro) a 1.0 (claro)

func set_brightness(value: float) -> void:
	brightness = clamp(value, 0.0, 1.0)
	_update_brightness()

func _update_brightness():
	var filtro = _get_filtro_brillo()
	if filtro:
		var color = filtro.modulate
		color.a = 1.0 - brightness  # entre 1.0 (oscuro) y 0.0 (claro)
		color.a = clamp(color.a, 0.0, 0.6)  # máximo oscurecimiento: 60%
		filtro.modulate = color

func _get_filtro_brillo() -> ColorRect:
	var current_scene = get_tree().get_current_scene()
	if current_scene:
		return _find_node_recursive(current_scene, "FiltroBrillo")
	return null

func _find_node_recursive(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		if child is Node:
			var result = _find_node_recursive(child, target_name)
			if result:
				return result
	return null
