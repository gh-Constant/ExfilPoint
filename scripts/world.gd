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

func remove_player(peer_id: int) -> void:
	var player: Node = get_node_or_null(str(peer_id))
	if player:
		player.queue_free()

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
