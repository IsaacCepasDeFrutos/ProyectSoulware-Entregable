extends VBoxContainer
const MUSIC_BUS = 2
const SFX_BUS = 1

var sound_effects_bus := 1

var label_original_states = {}
@export var hover_offset := Vector2(0, 3)
@export var hover_scale := Vector2(0.97, 0.97)
@export var press_offset := Vector2(0, 5)
@export var press_scale := Vector2(0.95, 0.95)

# Called when the node enters the scene tree for the first time.
func _ready():
	_conectar_botones()

func _conectar_botones():
	var botones = [
		$BotonAtacar,
		$BotonSalir,
		$Inventario,
		$Mapa,
		
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
		$HoverSound.play()
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
		$ClickSound.play()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
