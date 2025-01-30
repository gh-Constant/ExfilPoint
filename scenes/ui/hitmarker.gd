extends Control

const NORMAL_COLOR = Color(1, 1, 1, 1)
const HEADSHOT_COLOR = Color(1, 0, 0, 1)

@onready var animation_player = $AnimationPlayer
@onready var lines = $Lines

func _ready() -> void:
	# Verify that we have the required nodes
	if not animation_player:
		push_error("Hitmarker: AnimationPlayer node not found!")
		return
	if not lines:
		push_error("Hitmarker: Lines node not found!")
		return

func play_hitmarker(is_headshot: bool = false) -> void:
	# Check if animation player is valid before using it
	if not is_instance_valid(animation_player):
		push_error("Hitmarker: Invalid AnimationPlayer!")
		return
		
	# Only stop if currently playing
	if animation_player.is_playing():
		animation_player.stop()
	
	# Update colors
	if is_instance_valid(lines):
		for line in lines.get_children():
			if line is Line2D:
				line.default_color = HEADSHOT_COLOR if is_headshot else NORMAL_COLOR
	
	# Play animation if it exists
	if animation_player.has_animation("hit"):
		animation_player.play("hit")
	else:
		push_error("Hitmarker: Missing 'hit' animation!") 
