extends Control

@onready var animation_player = $AnimationPlayer
@onready var lines = $Lines

const NORMAL_COLOR = Color(1, 1, 1, 1)
const HEADSHOT_COLOR = Color(1, 0.2, 0.2, 1)

func play_hitmarker(is_headshot: bool = false) -> void:
	animation_player.stop()
	for line in lines.get_children():
		line.default_color = HEADSHOT_COLOR if is_headshot else NORMAL_COLOR
	animation_player.play("hit") 
