extends CharacterBody3D

const WeaponResource = preload("res://scripts/weapons/weapon_resource.gd")

@onready var camera: Camera3D = $Camera3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_flash: GPUParticles3D = $Camera3D/WeaponHolder/GPUParticles3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var gunshot_sound: AudioStreamPlayer3D = %GunshotSound
@onready var username_label: Label3D = $Username
@onready var killfeed: VBoxContainer = get_node("/root/World/UI/Killfeed")
@onready var hitmarker = preload("res://scenes/ui/hitmarker.tscn").instantiate()
@onready var ammo_label: Label = get_node("/root/World/UI/AmmoDisplay/AmmoLabel")
@onready var health_bar: ProgressBar = get_node_or_null("/root/World/UI/HealthBar")

## Number of shots before a player dies
@export var health : int = 100
## The xyz position of the random spawns, you can add as many as you want!
@export var spawns: PackedVector3Array = ([
	Vector3(-18, 0.2, 0),
	Vector3(18, 0.2, 0),
	Vector3(-2.8, 0.2, -6),
	Vector3(-17,0,17),
	Vector3(17,0,17),
	Vector3(17,0,-17),
	Vector3(-17,0,-17)
])
var sensitivity : float =  .005
var controller_sensitivity : float =  .010

var axis_vector : Vector2
var	mouse_captured : bool = true

const WALK_SPEED = 4.0
const SPRINT_SPEED = 6.5
const JUMP_VELOCITY = 5.5

var username: String = "Player":
	set = _set_username

var current_speed: float = WALK_SPEED
var max_ammo: int = 12
var current_ammo: int = 12
var is_reloading: bool = false

@export var weapons: Array[WeaponResource] = []
var current_weapon_index: int = 0
var current_weapon: WeaponResource
var last_shot_time: float = 0.0

var is_solo_mode: bool = false

# Add this near the top with other variables
var is_shooting: bool = false

# Add max_health for the health bar
@export var max_health : int = 100

# Add this near the top with other variables
@export var default_weapon_index: int = 0  # Default to first weapon

func _enter_tree() -> void:
	if not is_solo_mode:
		set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	if not is_solo_mode and not is_multiplayer_authority(): return
	
	# First verify that our nodes are valid
	if not is_instance_valid(anim_player):
		push_error("Animation player not found!")
		return
	if not is_instance_valid(camera):
		push_error("Camera not found!")
		return
	
	# Add hitmarker to UI only if it doesn't already have a parent
	var ui = get_node_or_null("/root/World/UI")
	if ui and not ui.has_node("Hitmarker"):
		hitmarker.name = "Hitmarker"
		ui.add_child(hitmarker)
		hitmarker.position = get_viewport().size / 2
	
	# Check animations
	print("Checking animations...")
	if anim_player.has_animation("idle"):
		print("Found idle animation")
	else:
		push_error("Missing idle animation!")
	if anim_player.has_animation("shoot"):
		print("Found shoot animation")
	else:
		push_error("Missing shoot animation!")
	if anim_player.has_animation("move"):
		print("Found move animation")
	else:
		push_error("Missing move animation!")
	
	# Load weapons first
	load_weapons()
	
	# Initialize the rest of the player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	position = get_furthest_spawn()
	
	# Set username from Global or use "Player" in solo mode
	username = "Player" if is_solo_mode else Global.username
	if not is_solo_mode:
		update_username.rpc(username)
	else:
		username_label.text = username
	
	# Add hitmarker to UI
	update_ammo_display()
	
	# Initialize health bar if available
	update_health_bar()
	
	# Hide weapon from other players' cameras
	if not is_multiplayer_authority():
		$Camera3D/WeaponHolder.visible = false
	
	if not is_solo_mode:
		add_to_group("players")

	# Add health bar to UI
	if ui and not ui.has_node("HealthBar"):
		var health_bar_scene = preload("res://scenes/ui/health_bar.tscn")
		health_bar = health_bar_scene.instantiate()
		ui.add_child(health_bar)
		update_health_bar()  # Initialize the health bar

func _process(delta: float) -> void:
	if not is_multiplayer_authority() and not is_solo_mode:
		return

func _unhandled_input(event: InputEvent) -> void:
	if not is_solo_mode and not is_multiplayer_authority(): return
	
	axis_vector = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	# Update shooting state
	if Input.is_action_just_pressed("shoot"):
		is_shooting = true
	elif Input.is_action_just_released("shoot"):
		is_shooting = false

	if Input.is_action_just_pressed("reload") and !is_reloading and current_ammo < max_ammo:
		print("Starting reload...")  # Debug print
		start_reload()

	if Input.is_action_just_pressed("respawn"):
		recieve_damage(2)

	if Input.is_action_just_pressed("capture"):
		if mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_captured = false
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mouse_captured = true

	if Input.is_action_just_pressed("weapon_next"):
		equip_weapon((current_weapon_index + 1) % weapons.size())
	elif Input.is_action_just_pressed("weapon_prev"):
		equip_weapon((current_weapon_index - 1 + weapons.size()) % weapons.size())

func _physics_process(delta: float) -> void:
	# Always apply gravity, even for bots
	if not is_on_floor():
		# Use the built-in gravity from PhysicsBody3D
		velocity += get_gravity() * delta
	
	# Rest of the movement logic only for player-controlled characters
	if not is_solo_mode and multiplayer.multiplayer_peer != null:
		if not is_multiplayer_authority(): 
			move_and_slide()  # Still allow bots to fall with gravity
			return
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Handle sprint
	if Input.is_action_pressed("sprint") and is_on_floor():
		current_speed = SPRINT_SPEED
	else:
		current_speed = WALK_SPEED
	
	# Get the input direction and handle the movement/deceleration
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
	
	# Handle animations more safely
	if is_instance_valid(anim_player):
		var next_anim = "idle"
		
		# Allow movement animation even during shooting
		if input_dir != Vector2.ZERO and is_on_floor():
			next_anim = "move"
			
		# Only play movement animations if we're not shooting
		if anim_player.current_animation != "shoot":
			if anim_player.has_animation(next_anim) and anim_player.current_animation != next_anim:
				anim_player.play(next_anim)
	
	# Handle continuous shooting
	if is_shooting and !is_reloading and current_ammo > 0:
		shoot()
	
	move_and_slide()

@rpc("call_local")
func play_shoot_effects() -> void:
	if not is_instance_valid(anim_player):
		push_error("Animation player is invalid!")
		return
		
	if not anim_player.has_animation("shoot"):
		push_error("Missing 'shoot' animation!")
		return
		
	# Don't stop the current animation if it's already "shoot"
	if anim_player.current_animation != "shoot":
		anim_player.stop()
		anim_player.play("shoot")
	
	if is_instance_valid(muzzle_flash):
		if is_solo_mode:
			muzzle_flash.emitting = true
		else:
			muzzle_flash.restart()
			muzzle_flash.emitting = true

@rpc("any_peer")
func recieve_damage(damage: int, killer_id: int = 0, is_headshot: bool = false) -> void:
	health -= damage
	update_health_bar()
	
	if health <= 0:
		if killer_id != 0:
			var killer_name = get_node("/root/World").get_node_or_null(str(killer_id))
			if killer_name and killfeed:
				killfeed.add_kill.rpc(killer_name.username, username, is_headshot)
				get_node("/root/World/UI/Scoreboard").update_score.rpc(killer_id, is_headshot)
		
		health = max_health
		update_health_bar()
		position = get_furthest_spawn()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if not is_instance_valid(anim_player):
		push_error("Animation player invalid in animation finished callback")
		return
		
	if anim_name == "shoot":
		if anim_player.has_animation("idle"):
			if not anim_player.is_playing():  # Only play idle if no other animation is playing
				anim_player.play("idle")

@rpc("call_local")
func update_username(new_username: String) -> void:
	username = new_username
	username_label.text = username

@rpc("any_peer")
func _set_username(new_username: String) -> void:
	username = new_username
	if username_label:
		username_label.text = username

func get_furthest_spawn() -> Vector3:
	var world: Node = get_node("/root/World")
	
	# For bots or solo mode, just return a random spawn point
	if is_solo_mode or not multiplayer.is_server():
		return spawns[randi() % spawns.size()]
	
	var players: Array[CharacterBody3D] = []
	for child in world.get_children():
		if child is CharacterBody3D and child != self:
			players.append(child)
	
	if players.is_empty():
		return spawns[randi() % spawns.size()]
	
	var best_spawn: Vector3 = spawns[0]
	var max_min_distance: float = 0.0
	
	for spawn in spawns:
		var min_distance: float = INF
		for player in players:
			var dist: float = spawn.distance_to(player.position)
			min_distance = min(min_distance, dist)
		
		if min_distance > max_min_distance:
			max_min_distance = min_distance
			best_spawn = spawn
	
	return best_spawn

func equip_weapon(index: int) -> void:
	if weapons.is_empty():
		push_error("No weapons available to equip!")
		return
		
	if index < 0 or index >= weapons.size():
		push_error("Invalid weapon index: ", index)
		return
	
	var weapon = weapons[index]
	if not weapon:
		push_error("Weapon at index ", index, " is null!")
		return
		
	if not (weapon is WeaponResource):
		push_error("Invalid weapon resource at index ", index)
		return
	
	print("Equipping weapon: ", weapon.name)
	current_weapon_index = index
	current_weapon = weapon
	max_ammo = weapon.max_ammo
	current_ammo = weapon.max_ammo
	update_ammo_display()
	update_weapon_visibility()

func shoot() -> void:
	if not current_weapon:
		push_error("Attempting to shoot without a weapon equipped!")
		return
		
	if current_ammo <= 0:
		start_reload()
		return
		
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < current_weapon.fire_rate:
		return
		
	last_shot_time = current_time
	current_ammo -= 1
	update_ammo_display()
	
	# Play visual/audio effects locally
	play_shoot_effects.rpc()
	gunshot_sound.play()
	
	# Handle shot logic based on mode
	if is_solo_mode:
		# In solo mode, process hit directly
		process_shot(camera.global_position, -camera.global_transform.basis.z)
	elif multiplayer.is_server():
		# If we're the server, process the shot directly
		process_shot(camera.global_position, -camera.global_transform.basis.z)
	else:
		# If we're a client, send shot to server for validation
		request_shoot.rpc_id(1, current_time, camera.global_position, 
			camera.global_rotation, -camera.global_transform.basis.z)

@rpc("any_peer")
func request_shoot(timestamp: float, shot_origin: Vector3, shot_rotation: Vector3, shot_direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
		
	# Validate the shot
	var shooter_id = multiplayer.get_remote_sender_id()
	var shooter = get_node_or_null(str(shooter_id))
	if not shooter:
		return
		
	# Get world node
	var world = get_node("/root/World")
	if not world:
		return
		
	# Calculate the time to rewind to
	var current_time = Time.get_ticks_msec() / 1000.0
	var client_ping = multiplayer.get_peer(shooter_id).get_rtt() / 1000.0  # Convert to seconds
	var rewind_time = timestamp - (client_ping / 2.0)  # Compensate for half RTT
	
	# Rewind other players to shot time
	var rewound_positions = {}
	
	for player in get_tree().get_nodes_in_group("players"):
		if player.name == str(shooter_id):
			continue
			
		var history = world.player_state_history.get(player.name, [])
		var closest_state = null
		var smallest_time_diff = INF
		
		# Find the closest state to our rewind time
		for state in history:
			var time_diff = abs(state.timestamp - rewind_time)
			if time_diff < smallest_time_diff:
				smallest_time_diff = time_diff
				closest_state = state
		
		# Only rewind if we found a state within a reasonable timeframe (100ms)
		if closest_state and smallest_time_diff < 0.1:
			rewound_positions[player.name] = {
				"original": player.global_position,
				"rewound": closest_state.position
			}
			player.global_position = closest_state.position
			player.global_rotation = closest_state.rotation
	
	# Perform raycast with the rewound positions
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		shot_origin,
		shot_origin + shot_direction * 50,
		0xFFFFFFFF  # Use all collision layers
	)
	var result = space_state.intersect_ray(query)
	
	# Process hit
	if result and result.collider.is_class("CharacterBody3D"):
		var hit_player = result.collider
		var is_headshot = false
		
		# Check headshot with rewound position
		var hit_height = result.position.y - hit_player.global_position.y
		if hit_height > 1.4 and hit_height < 1.9:
			is_headshot = true
			
		# Apply damage
		var damage = current_weapon.headshot_damage if is_headshot else current_weapon.damage
		hit_player.recieve_damage.rpc_id(
			hit_player.get_multiplayer_authority(),
			damage,
			shooter_id,
			is_headshot
		)
		
		# Notify shooter of hit
		confirm_hit.rpc_id(shooter_id, is_headshot)
	
	# Restore original positions
	for player_name in rewound_positions:
		var player = get_node_or_null(player_name)
		if player:
			player.global_position = rewound_positions[player_name]["original"]

@rpc
func confirm_hit(is_headshot: bool) -> void:
	if not is_multiplayer_authority() and not is_solo_mode:
		return
	
	if is_instance_valid(hitmarker):
		hitmarker.play_hitmarker(is_headshot)

func start_reload() -> void:
	if is_reloading or current_ammo >= max_ammo:
		return
		
	is_reloading = true
	
	# Create a timer for reload
	var timer = get_tree().create_timer(current_weapon.reload_time)
	timer.timeout.connect(_on_reload_timer_timeout)

func _on_reload_timer_timeout() -> void:
	current_ammo = max_ammo
	is_reloading = false
	update_ammo_display()

func update_ammo_display() -> void:
	if ammo_label:
		ammo_label.text = str(current_ammo) + " / " + str(max_ammo)

# Modify the process_shot function to handle self-damage correctly
func process_shot(shot_origin: Vector3, shot_direction: Vector3) -> void:
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		shot_origin,
		shot_origin + shot_direction * 50,
		0xFFFFFFFF  # Use all collision layers
	)
	var result = space_state.intersect_ray(query)
	
	print("Shot fired. Hit something: ", result != null)
	if result:
		print("Hit object type: ", result.collider.get_class())
	
	if result and result.collider.is_class("CharacterBody3D"):
		var hit_player = result.collider
		var is_headshot = false
		
		var hit_height = result.position.y - hit_player.global_position.y
		if hit_height > 1.4 and hit_height < 1.9:
			is_headshot = true
		
		var damage = current_weapon.headshot_damage if is_headshot else current_weapon.damage
		
		# Check if the hit player is a bot or self
		var is_bot = str(hit_player.name).to_int() >= 1000
		var is_self = hit_player == self
		
		if is_bot or is_self:
			# Handle bot/self damage directly without RPC
			hit_player.health -= damage
			if hit_player.health <= 0:
				hit_player.health = max_health
				hit_player.position = hit_player.get_furthest_spawn()
				
				# Update killfeed if available
				if killfeed and not is_self:  # Don't show killfeed for self-damage
					killfeed.add_kill.rpc(username, hit_player.username, is_headshot)
					get_node("/root/World/UI/Scoreboard").update_score.rpc(multiplayer.get_unique_id(), is_headshot)
		else:
			# Normal player damage via RPC
			hit_player.recieve_damage.rpc_id(
				hit_player.get_multiplayer_authority(),
				damage,
				multiplayer.get_unique_id(),
				is_headshot
			)
		
		if is_instance_valid(hitmarker):
			hitmarker.play_hitmarker(is_headshot)

# Add a function to safely update health bar
func update_health_bar() -> void:
	if not health_bar:  # Try to get health bar if we don't have it
		health_bar = get_node_or_null("/root/World/UI/HealthBar")
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

# Separate weapon loading into its own function
func load_weapons() -> void:
	print("Attempting to load weapon resources...")
	
	# Check if weapon resources exist first
	var rifle_path = "res://resources/weapons/rifle.tres"
	var pistol_path = "res://resources/weapons/pistol.tres"
	
	if not ResourceLoader.exists(rifle_path) or not ResourceLoader.exists(pistol_path):
		push_error("Weapon resource files not found! Checking file paths...")
		print("Rifle path exists: ", ResourceLoader.exists(rifle_path))
		print("Pistol path exists: ", ResourceLoader.exists(pistol_path))
		return
	
	# Load weapon resources
	var rifle = load(rifle_path)
	var pistol = load(pistol_path)
	
	if not (rifle is WeaponResource) or not (pistol is WeaponResource):
		push_error("Resources are not WeaponResource type!")
		return
		
	weapons = [rifle, pistol]
	print("Weapons array populated with size: ", weapons.size())
	
	# Equip default weapon
	if weapons.size() > 0:
		equip_weapon(default_weapon_index)

# Add this function to handle weapon visibility
func update_weapon_visibility() -> void:
	if not current_weapon:
		return
		
	var rifle = $Camera3D/rifle
	var pistol = $Camera3D/pistol
	
	if not is_instance_valid(rifle) or not is_instance_valid(pistol):
		push_error("Weapon models not found in scene!")
		return
	
	# Hide all weapons first
	rifle.visible = false
	pistol.visible = false
	
	# Show the selected weapon only if we're the authority
	if is_multiplayer_authority() or is_solo_mode:
		match current_weapon.name:
			"Rifle":
				rifle.visible = true
			"Pistol":
				pistol.visible = true
