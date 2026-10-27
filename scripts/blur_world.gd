extends CanvasLayer

@onready var shader = $ColorRect

# Variável para acumular o tempo total que passou
var tempo_acumulado: float = 0.0

func _process(delta: float) -> void:
	if shader.material:
		# 1. Acumula o tempo a cada frame
		tempo_acumulado += delta
		
		# 2. Usa o Seno para oscilar. O 'abs()' garante que o valor nunca seja negativo.
		# Multiplicar o tempo por 2.0 muda a VELOCIDADE da oscilação.
		# Multiplicar o resultado final por 4.0 muda a INTENSIDADE máxima do blur.
		var valor_blur = abs(sin(tempo_acumulado * 2.0)) * 2.0
		
		# 3. Aplica o valor calculado ao shader
		shader.material.set_shader_parameter("blur_amount", valor_blur)
