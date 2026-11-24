class_name HudZona
extends CanvasLayer

@onready var _anchor: Control = $Anchor
@onready var _title_label: Label = $Anchor/Margin/Center/Stack/TitleLabel
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_anchor.visible = false
	_anchor.modulate.a = 0.0
	_anim.animation_finished.connect(_on_animation_finished)


func exibir_zona(titulo: String) -> void:
	if titulo.strip_edges().is_empty():
		return

	_title_label.text = titulo
	_anchor.visible = true
	_anim.stop()
	_anim.play(&"RESET")
	_anim.advance(0.0)
	_anim.play(&"exibir")


func esconder_imediato() -> void:
	_anim.stop()
	_anchor.visible = false
	_anchor.modulate.a = 0.0


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"exibir":
		_anchor.visible = false
