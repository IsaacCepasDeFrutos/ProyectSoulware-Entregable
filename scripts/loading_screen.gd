extends Control

@onready var animation_player: AnimationPlayer = $loadingScreen/AnimationPlayer
@onready var press_to_continue: RichTextLabel = $loadingScreen/RichTextLabel2
@onready var loading: RichTextLabel = $loadingScreen/RichTextLabel
var _next_scene_path: String
var _waiting_for_input: bool = false

func _ready() -> void:
	# Ocultamos el mensaje y deshabilitamos el input al arrancar
	press_to_continue.visible = false
	set_process_unhandled_input(false)
	loading.visible = true
func start_transition(scene_path: String) -> void:
	_next_scene_path = scene_path
	visible = true
	focus_mode = FocusMode.FOCUS_ALL      # permitimos que este Control reciba foco
	grab_focus()                      # robamos el foco inmediatamente
	_waiting_for_input = false

	# Antes de lanzar fade_in, seguimos ignorando el input
	set_process_unhandled_input(false)
	press_to_continue.visible = false

	animation_player.play("fade_in")
	animation_player.animation_finished.connect(
		Callable(self, "_on_animation_finished"),
		CONNECT_ONE_SHOT
	)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "fade_in":
		# Tras fade_in, permitimos input y mostramos el mensaje
		_waiting_for_input = true
		press_to_continue.visible = true
		set_process_unhandled_input(true)
		loading.visible = false
func _unhandled_input(event: InputEvent) -> void:
	if _waiting_for_input and event.is_action_pressed("loading_accept"):
		_waiting_for_input = false
		get_tree().change_scene_to_file(_next_scene_path)
		queue_free()
