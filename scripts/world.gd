extends Node

@onready var main_menu: PanelContainer = $Menu/MainMenu
@onready var options_menu: PanelContainer = $Menu/Options
@onready var pause_menu: PanelContainer = $Menu/PauseMenu
@onready var address_entry: LineEdit = %AddressEntry
@onready var menu_music: AudioStreamPlayer = %MenuMusic
@onready var username_input: LineEdit = %UsernameInput

const Player = preload("res://player.tscn")
const PORT = 9999
var enet_peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var paused: bool = false
var options: bool = false
var controller: bool = false

const BotPlayer = preload("res://scripts/bot_player.gd")
@export var max_bots: int = 3
var current_bots: int = 0

class PlayerState:
	var position: Vector3
	var rotation: Vector3
	var timestamp: float

var player_state_history = {}
const HISTORY_LENGTH = 1.0  # Store 1 second of history

func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_pressed("pause") and !main_menu.visible and !options_menu.visible:
		paused = !paused
	if event is InputEventJoypadMotion:
		controller = true
	elif event is InputEventMouseMotion:
		controller = false

func _process(_delta: float) -> void:
	if paused:
		$Menu/Blur.show()
		pause_menu.show()
		if !controller:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_resume_pressed() -> void:
	if !options:
		$Menu/Blur.hide()
	$Menu/PauseMenu.hide()
	if !controller:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	paused = false
	
func _on_options_pressed() -> void:
	_on_resume_pressed()
	$Menu/Options.show()
	$Menu/Blur.show()
	%Fullscreen.grab_focus()
	if !controller:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	options = true

func _on_back_pressed() -> void:
	if options:
		$Menu/Blur.hide()
		if !controller:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		options = false

func _ready() -> void:
	username_input.text = Global.username
	username_input.text_changed.connect(_on_username_changed)
	
	# Remove the old bot control code and let the options menu handle it

func _on_username_changed(new_text: String) -> void:
	Global.username = new_text if new_text.length() > 0 else "Player"

#func _ready() -> void:
func _on_host_button_pressed() -> void:
	main_menu.hide()
	$Menu/DollyCamera.hide()
	$Menu/Blur.hide()
	menu_music.stop()

	# Set up networking first
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	if options_menu.visible:
		options_menu.hide()

	# Create host player immediately without going through add_player
	var player = Player.instantiate()
	player.name = str(multiplayer.get_unique_id())
	add_child(player)

	# Set up UPNP in the background
	_setup_upnp.call_deferred()

	# Add initial bots
	for i in range(max_bots):
		add_bot()

func _setup_upnp() -> void:
	var upnp: UPNP = UPNP.new()
	
	var discover_result = upnp.discover()
	if discover_result == UPNP.UPNP_RESULT_SUCCESS:
		upnp.add_port_mapping(PORT)
		
		var ip: String = upnp.query_external_address()
		if ip == "":
			print("Failed to establish upnp connection!")
		else:
			print("Success! Join Address: %s" % ip)
	else:
		print("UPNP Discovery failed!")

func _on_join_button_pressed() -> void:
	main_menu.hide()
	$Menu/Blur.hide()
	menu_music.stop()
	
	enet_peer.create_client(address_entry.text, PORT)
	if options_menu.visible:
		options_menu.hide()
	multiplayer.multiplayer_peer = enet_peer

func _on_options_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		options_menu.show()
	else:
		options_menu.hide()
		
func _on_music_toggle_toggled(toggled_on: bool) -> void:
	if !toggled_on:
		menu_music.stop()
	else:
		menu_music.play()

func add_player(peer_id: int) -> void:
	var player: Node = Player.instantiate()
	player.name = str(peer_id)
	add_child(player)
	
	# Adjust bot count when real player joins
	if multiplayer.is_server():
		var player_count = get_tree().get_nodes_in_group("players").size() - current_bots
		var desired_bots = max(0, max_bots - player_count)
		while current_bots > desired_bots:
			remove_bot()

func remove_player(peer_id: int) -> void:
	var player: Node = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
		
	# Add bot when real player leaves
	if multiplayer.is_server():
		var player_count = get_tree().get_nodes_in_group("players").size() - current_bots
		var desired_bots = max(0, max_bots - player_count)
		while current_bots < desired_bots:
			add_bot()

func _on_solo_button_pressed() -> void:
	main_menu.hide()
	$Menu/DollyCamera.hide()
	$Menu/Blur.hide()
	menu_music.stop()
	
	# Create solo player without networking
	var player = Player.instantiate()
	player.is_solo_mode = true  # Set the solo mode flag
	player.name = "SoloPlayer"
	add_child(player)
	
	if options_menu.visible:
		options_menu.hide()

func _physics_process(_delta: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Store states for all players
	for player in get_tree().get_nodes_in_group("players"):
		if not player_state_history.has(player.name):
			player_state_history[player.name] = []
			
		var state = PlayerState.new()
		state.position = player.global_position
		state.rotation = player.global_rotation
		state.timestamp = current_time
		
		player_state_history[player.name].append(state)
		
		# Cleanup old states
		while player_state_history[player.name].size() > 0:
			var oldest = player_state_history[player.name][0]
			if current_time - oldest.timestamp > HISTORY_LENGTH:
				player_state_history[player.name].pop_front()
			else:
				break

func add_bot() -> void:
	if not multiplayer.is_server():
		return
		
	var bot = Player.instantiate()
	bot.set_script(BotPlayer)
	bot.name = str(multiplayer.get_unique_id() + 1000 + current_bots)  # Use high IDs for bots
	add_child(bot)
	current_bots += 1

func remove_bot() -> void:
	if not multiplayer.is_server():
		return
		
	var bots = get_tree().get_nodes_in_group("players").filter(func(p): return p.get_script() == BotPlayer)
	if bots.size() > 0:
		bots[0].queue_free()
		current_bots -= 1
