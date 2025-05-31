#settingMenu.gd
extends Control

# Ajusta estos índices según tu configuración de buses
const MUSIC_BUS = 2
const SFX_BUS = 1

var is_fullscreen: bool = false

var sound_effects_bus := 1

# Animación labels
var label_original_states = {}
@export var hover_offset := Vector2(0, 3)
@export var hover_scale := Vector2(0.97, 0.97)
@export var press_offset := Vector2(0, 5)
@export var press_scale := Vector2(0.95, 0.95)

func _ready() -> void:
	# Configuración pantalla completa
	is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	$VBoxContainer/HBoxContainer/fullScreenMode.set_pressed_no_signal(is_fullscreen)
	
	# Inicializar controles de audio
	$VBoxContainer/soundMusicSlider.value = AudioServer.get_bus_volume_db(MUSIC_BUS)
	$VBoxContainer/muteMusic.set_pressed_no_signal(AudioServer.is_bus_mute(MUSIC_BUS))
	
	$VBoxContainer/soundEfectSlider.value = AudioServer.get_bus_volume_db(SFX_BUS)
	$VBoxContainer/muteEfect.set_pressed_no_signal(AudioServer.is_bus_mute(SFX_BUS))
	$VBoxContainer/muteEfect.connect("toggled", Callable(self, "_on_mute_sound_toggled"))
	
	$VBoxContainer/brightnessSlider.value = DisplayManager.brightness * 100.0
	$VBoxContainer/brightnessSlider.connect("value_changed", Callable(self, "_on_brightness_slider_value_changed"))
	
	DisplayManager._update_brightness()
	
	_conectar_botones()

func _conectar_botones():
	var botones = $VBoxContainer/applyChanges
	var label = botones.get_node("Label")
	label_original_states[botones] = {
		"position": label.position,
		"scale": label.scale
	}

	botones.connect("mouse_entered", _on_mouse_entered.bind(botones))
	botones.connect("pressed", _on_boton_pressed)

func _on_apply_changes_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_boton_pressed():
	if not AudioServer.is_bus_mute(sound_effects_bus):
		$AudioStreamPlayer2DSounds.play()
	
func _on_mouse_entered(boton: TextureButton):
	if not AudioServer.is_bus_mute(sound_effects_bus):
		$AudioStreamPlayer2DSounds.play()
	_animate_label(boton, hover_offset, hover_scale, 0.15)

func _animate_label(boton: TextureButton, offset: Vector2, scale: Vector2, duration: float):
	var label = boton.get_node("Label")
	var original = label_original_states[boton]
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", original["position"] + offset, duration)
	tween.parallel().tween_property(label, "scale", original["scale"] * scale, duration)

func _on_full_screen_mode_toggled(toggled_on: bool):
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if toggled_on 
		else DisplayServer.WINDOW_MODE_WINDOWED
	)

# Música
func _on_sound_music_slider_value_changed(value: float):
	AudioServer.set_bus_volume_db(MUSIC_BUS, value)

func _on_mute_music_toggled(toggled_on: bool):
	AudioServer.set_bus_mute(MUSIC_BUS, toggled_on)

# SFX
func _on_sound_efect_slider_value_changed(value: float):
	AudioServer.set_bus_volume_db(SFX_BUS, value)
	if not AudioServer.is_bus_mute(SFX_BUS):
		$AudioStreamPlayer2DSounds.play()

func _on_mute_sound_toggled(toggled_on: bool):
	AudioServer.set_bus_mute(SFX_BUS, toggled_on)
	
	
#Brillo
func _on_brightness_slider_value_changed(value: float):
	DisplayManager.set_brightness(value / 100.0)
