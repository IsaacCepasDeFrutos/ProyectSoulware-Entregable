extends TextureProgressBar

#Variable exportada para el manejo del estado de la relacion.
@export var real_time_value: float = 50.0

@onready var point_indicator = $ColorRect

func _ready():
	# Configura los valores iniciales
	self.min_value = 0
	self.max_value = 100
	self.value = real_time_value
	update_point_position()

# Setter para la variable real_time_value
func set_real_time_value(new_value: float) -> void:
	# Actualiza el valor en tiempo real
	real_time_value = clamp(new_value, self.min_value, self.max_value)
	set_indicator_value(real_time_value)

# Actualiza el valor del indicador y la posición del punto
func set_indicator_value(new_value: float) -> void:
	# Ajusta el valor del TextureProgressBar
	self.value = clamp(new_value, self.min_value, self.max_value)
	update_point_position()

# Calcula y actualiza la posición del punto
func update_point_position() -> void:
	# Calcula la proporción del progreso
	var progress_ratio = (self.value - self.min_value) / (self.max_value - self.min_value)
	var texture_width = self.get_size().x
	var point_width = point_indicator.size.x
	# Calcula la posición del punto basado en la proporción
	var point_x = progress_ratio * (texture_width - point_width)
	# Centra el punto horizontalmente y evita que sobresalga
	point_indicator.position = Vector2(point_x, point_indicator.position.y)
