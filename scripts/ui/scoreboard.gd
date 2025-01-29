extends Control

@onready var scores_container = $Panel/VBoxContainer/ScoresContainer/Scores

var player_scores = {}
var player_headshots = {}

func _ready() -> void:
	hide()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_pressed("scoreboard"):
		show()
	elif Input.is_action_just_released("scoreboard"):
		hide()

func _on_peer_disconnected(id: int) -> void:
	if player_scores.has(id):
		player_scores.erase(id)
	update_scoreboard()

@rpc("any_peer", "call_local")
func update_score(killer_id: int, is_headshot: bool = false) -> void:
	if !player_scores.has(killer_id):
		player_scores[killer_id] = 0
		player_headshots[killer_id] = 0
	player_scores[killer_id] += 1
	if is_headshot:
		player_headshots[killer_id] += 1
	update_scoreboard()

func update_scoreboard() -> void:
	# Clear existing scores
	for child in scores_container.get_children():
		child.queue_free()
	
	# Sort players by score
	var sorted_scores = []
	for id in player_scores.keys():
		sorted_scores.append({
			"id": id, 
			"score": player_scores[id],
			"headshots": player_headshots[id]
		})
	sorted_scores.sort_custom(func(a, b): return a.score > b.score)
	
	# Add scores to scoreboard
	for score_data in sorted_scores:
		var player = get_node_or_null("/root/World/" + str(score_data.id))
		if player:
			var score_label = Label.new()
			score_label.add_theme_font_size_override("font_size", 24)
			score_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			var headshot_text = " (🎯: %d)" % score_data.headshots if score_data.headshots > 0 else ""
			score_label.text = "%s: %d%s" % [player.username, score_data.score, headshot_text]
			scores_container.add_child(score_label) 
