extends CharacterBody3D

@onready var camera: Camera3D = $Camera3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_flash: GPUParticles3D = $Camera3D/pistol/GPUParticles3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var gunshot_sound: AudioStreamPlayer3D = %GunshotSound
@onready var username_label: Label3D = $Username
@onready var killfeed: VBoxContainer = get_node("/root/World/UI/Killfeed")

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

const SPEED = 6.5
const JUMP_VELOCITY = 5.5

var username: String = "Player":
	set = _set_username

func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int())

func _ready() -> void:
	if not is_multiplayer_authority(): return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	position = get_furthest_spawn()

	# Set username from Global
	username = Global.username
	update_username.rpc(username)

func _process(_delta: float) -> void:
	sensitivity = Global.sensitivity
	controller_sensitivity = Global.controller_sensitivity

	rotate_y(-axis_vector.x * controller_sensitivity)
	camera.rotate_x(-axis_vector.y * controller_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority(): return
	
	axis_vector = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * sensitivity)
		camera.rotate_x(-event.relative.y * sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if Input.is_action_just_pressed("shoot") \
			and anim_player.current_animation != "shoot":
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
			hit_player.recieve_damage.rpc_id(
				hit_player.get_multiplayer_authority(),
				1,
				multiplayer.get_unique_id()
			)

	if Input.is_action_just_pressed("respawn"):
		recieve_damage(2)

	if Input.is_action_just_pressed("capture"):
		if mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_captured = false
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			mouse_captured = true

func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null:
		if not is_multiplayer_authority(): return
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "up", "down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor() :
		anim_player.play("move")
	else:
		anim_player.play("idle")

	move_and_slide()

@rpc("call_local")
func play_shoot_effects() -> void:
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("any_peer")
func recieve_damage(damage:= 1, killer_id: int = 0) -> void:
	health -= damage
	if health <= 0:
		if killer_id != 0:
			var killer_name: CharacterBody3D = get_node("/root/World").get_node_or_null(str(killer_id))
			if killer_name and killfeed:
				killfeed.add_kill.rpc(killer_name.username, username)
		health = 2
		position = get_furthest_spawn()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "shoot":
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
