extends VBoxContainer

const MAX_MESSAGES = 5
const MESSAGE_DURATION = 5.0

@rpc("any_peer", "call_local")
func add_kill(killer_name: String, victim_name: String) -> void:
	var message := Label.new()
	message.text = "%s killed %s" % [killer_name, victim_name]
	add_child(message)
	
	# Remove oldest message if we exceed MAX_MESSAGES
	if get_child_count() > MAX_MESSAGES:
		get_child(0).queue_free()
	
	# Remove this message after duration
	get_tree().create_timer(MESSAGE_DURATION).timeout.connect(
		func() -> void: if is_instance_valid(message): message.queue_free()
	) 