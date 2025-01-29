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

## Number of shots before a player dies
@export var health : int = 2
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
	
	print("Resource loading complete")
	print("Rifle resource: ", rifle)
	print("Pistol resource: ", pistol)
	
	if not (rifle is WeaponResource) or not (pistol is WeaponResource):
		push_error("Resources are not WeaponResource type!")
		return
		
	weapons = [rifle, pistol]
	print("Weapons array populated with size: ", weapons.size())
	
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
	add_child(hitmarker)
	hitmarker.set_as_top_level(true)
	hitmarker.position = get_viewport().size / 2
	update_ammo_display()
	
	# Make sure we have weapons configured and equip the first one
	if weapons.size() > 0:
		print("Attempting to equip initial weapon...")
		equip_weapon(0)
	else:
		push_warning("No weapons configured for player!")

	# Hide the default pistol in the scene
	if $Camera3D/pistol:
		$Camera3D/pistol.queue_free()

	# Hide weapon from other players' cameras
	if not is_multiplayer_authority():
		$Camera3D/WeaponHolder.visible = false

func _process(_delta: float) -> void:
	sensitivity = Global.sensitivity
	controller_sensitivity = Global.controller_sensitivity

	rotate_y(-axis_vector.x * controller_sensitivity)
	camera.rotate_x(-axis_vector.y * controller_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

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
	if not is_solo_mode and multiplayer.multiplayer_peer != null:
		if not is_multiplayer_authority(): return
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle sprint
	if Input.is_action_pressed("sprint") and is_on_floor():
		current_speed = SPRINT_SPEED
	else:
		current_speed = WALK_SPEED

	# Get the input direction and handle the movement/deceleration.
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
func recieve_damage(damage:= 1, killer_id: int = 0, is_headshot: bool = false) -> void:
	health -= damage
	if health <= 0:
		if killer_id != 0:
			var killer_name = get_node("/root/World").get_node_or_null(str(killer_id))
			if killer_name and killfeed:
				killfeed.add_kill.rpc(killer_name.username, username, is_headshot)
				get_node("/root/World/UI/Scoreboard").update_score.rpc(killer_id, is_headshot)
		health = 2
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
	if index < 0 or index >= weapons.size():
		print("Invalid weapon index: ", index)
		return
	
	print("Equipping weapon at index: ", index)
	current_weapon_index = index
	current_weapon = weapons[index]
	
	if current_weapon == null:
		print("ERROR: Weapon at index ", index, " is null!")
		return
		
	if not (current_weapon is WeaponResource):
		push_error("Invalid weapon resource at index ", index)
		return
	
	print("Weapon equipped successfully")
	max_ammo = current_weapon.max_ammo
	current_ammo = current_weapon.max_ammo
	
	var weapon_holder = $Camera3D/WeaponHolder
	if not is_instance_valid(weapon_holder):
		push_error("WeaponHolder not found!")
		return
	
	# Remove existing weapons but keep effects and sound
	for child in weapon_holder.get_children():
		if not (child is GPUParticles3D or child is AudioStreamPlayer3D):
			child.queue_free()
	
	# Instance new weapon model
	var weapon_model = current_weapon.model_scene.instantiate()
	if not weapon_model:
		push_error("Failed to instantiate weapon model!")
		return
		
	weapon_holder.add_child(weapon_model)
	
	# Set visibility based on authority
	weapon_holder.visible = is_multiplayer_authority()
	
	# Handle muzzle flash
	if is_instance_valid(muzzle_flash):
		muzzle_flash.queue_free()
	
	# Create new muzzle flash
	var particles = GPUParticles3D.new()
	
	# Create particle material
	var particle_material = ParticleProcessMaterial.new()
	particle_material.direction = Vector3(0, 0, -1)
	particle_material.spread = 45.0
	particle_material.gravity = Vector3.ZERO
	particle_material.initial_velocity_min = 1.0
	particle_material.initial_velocity_max = 2.0
	particle_material.scale_min = 0.1
	particle_material.scale_max = 0.3
	particle_material.color = Color(1, 0.7, 0.2, 1)  # Orange-yellow color
	
	particles.process_material = particle_material
	
	# Create mesh for particles
	var material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	
	var mesh = PlaneMesh.new()
	mesh.material = material
	mesh.size = Vector2(0.5, 0.5)
	mesh.orientation = PlaneMesh.FACE_Z
	
	particles.draw_pass_1 = mesh
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 16
	particles.lifetime = 0.1
	particles.explosiveness = 1.0
	particles.position = current_weapon.muzzle_flash_position
	$Camera3D/WeaponHolder.add_child(particles)
	muzzle_flash = particles
	
	# Update sound
	if is_instance_valid(gunshot_sound):
		gunshot_sound.stream = current_weapon.shoot_sound
	
	update_ammo_display()

func shoot() -> void:
	if is_reloading:
		return
		
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < current_weapon.fire_rate:
		return
		
	if current_ammo <= 0:
		start_reload()
		return
		
	last_shot_time = current_time
	current_ammo -= 1
	
	update_ammo_display()
	play_shoot_effects.rpc()
	gunshot_sound.play()
	
	# More reliable hit detection
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position - camera.global_transform.basis.z * 50,
		2  # Collision mask
	)
	var result: Dictionary = space_state.intersect_ray(query)
	
	if result and result.collider.is_class("CharacterBody3D"):
		var hit_player: CharacterBody3D = result.collider
		var is_headshot: bool = false
		
		# Check if hit point is in head area
		var hit_height: float = result.position.y - hit_player.global_position.y
		if hit_height > 1.4 and hit_height < 1.9:
			is_headshot = true
		
		hit_player.recieve_damage.rpc_id(
			hit_player.get_multiplayer_authority(),
			2 if is_headshot else 1,
			multiplayer.get_unique_id(),
			is_headshot
		)
		hitmarker.play_hitmarker(is_headshot)

func start_reload() -> void:
	if not current_weapon:  # Check if we have a weapon
		print("No weapon equipped, can't reload")  # Debug print
		return
		
	print("Reload started - Current ammo: ", current_ammo)  # Debug print
	is_reloading = true
	
	# Create timer node since get_tree() might not be valid
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = current_weapon.reload_time
	timer.one_shot = true
	timer.timeout.connect(func():
		current_ammo = current_weapon.max_ammo
		is_reloading = false
		print("Reload complete - New ammo: ", current_ammo)  # Debug print
		update_ammo_display()
		timer.queue_free()
	)
	timer.start()

func update_ammo_display() -> void:
	ammo_label.text = str(current_ammo) + " / " + str(max_ammo)
