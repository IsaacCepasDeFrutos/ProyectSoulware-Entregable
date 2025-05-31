extends Control
const MUSIC_BUS = 2
const SFX_BUS = 1
# Configuración audio
var sound_effects_bus := 1
var loading_screen = preload("res://scenes/components/loading_screen.tscn")

# Animación labels
var label_original_states = {}
@export var hover_offset := Vector2(0, 3)
@export var hover_scale := Vector2(0.97, 0.97)
@export var press_offset := Vector2(0, 5)
@export var press_scale := Vector2(0.95, 0.95)

func _ready():
	_conectar_botones()
	DisplayManager._update_brightness()

func _conectar_botones():
	var botones = [
		$VBoxContainer/NewGame,
		$VBoxContainer/LoadGame,
		$VBoxContainer/Settings,
		$VBoxContainer/Credits,
		$VBoxContainer/Exit
	]
	
	for boton in botones:
		var label = boton.get_node("Label")
		label_original_states[boton] = {
			"position": label.position,
			"scale": label.scale
		}
		
		boton.connect("mouse_entered", _on_mouse_entered.bind(boton))
		boton.connect("mouse_exited", _on_mouse_exited.bind(boton))
		boton.connect("button_down", _on_button_down.bind(boton))
		boton.connect("button_up", _on_button_up.bind(boton))
		boton.connect("pressed", _on_boton_pressed)

func _on_mouse_entered(boton: TextureButton):
	if not AudioServer.is_bus_mute(sound_effects_bus):
		$VBoxContainer/HoverSound.play()
	_animate_label(boton, hover_offset, hover_scale, 0.15)

func _on_mouse_exited(boton: TextureButton):
	_animate_label(boton, Vector2.ZERO, Vector2.ONE, 0.15)

func _on_button_down(boton: TextureButton):
	_animate_label(boton, press_offset, press_scale, 0.1)

func _on_button_up(boton: TextureButton):
	_animate_label(boton, hover_offset, hover_scale, 0.1)

func _animate_label(boton: TextureButton, offset: Vector2, scale: Vector2, duration: float):
	var label = boton.get_node("Label")
	var original = label_original_states[boton]
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", original["position"] + offset, duration)
	tween.parallel().tween_property(label, "scale", original["scale"] * scale, duration)

func _on_boton_pressed():
	if not AudioServer.is_bus_mute(sound_effects_bus):
		$VBoxContainer/ClickSound.play()
	
	match get_viewport().gui_get_focus_owner().name:
		"NewGame":
			var loading_instance = loading_screen.instantiate()
			get_tree().root.add_child(loading_instance)
			loading_instance.start_transition("res://scenes/tutorial_stage.tscn")
		
		"LoadGame":
			print("Cargar juego")
		
		"Settings":
			var loading_instance = loading_screen.instantiate()
			get_tree().root.add_child(loading_instance)
			loading_instance.start_transition("res://scenes/SettingsMenu.tscn")
		
		"Credits":
			print("Mostrar créditos")
		
		"Exit":
			get_tree().quit()
