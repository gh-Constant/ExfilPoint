extends VBoxContainer

const MAX_MESSAGES = 5
const MESSAGE_DURATION = 5.0

@rpc("any_peer", "call_local")
func add_kill(killer_name: String, victim_name: String, is_headshot: bool = false) -> void:
	var message := Label.new()
	var headshot_text = " (Headshot!)" if is_headshot else ""
	message.text = "%s killed %s%s" % [killer_name, victim_name, headshot_text]
	if is_headshot:
		message.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	add_child(message)
	
	# Remove oldest message if we exceed MAX_MESSAGES
	if get_child_count() > MAX_MESSAGES:
		get_child(0).queue_free()
	
	# Remove this message after duration
	get_tree().create_timer(MESSAGE_DURATION).timeout.connect(
		func() -> void: if is_instance_valid(message): message.queue_free()
	) 
