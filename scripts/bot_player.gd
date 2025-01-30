extends "res://scripts/player.gd"

var target_player: Node = null
var update_target_timer: float = 0.0
const TARGET_UPDATE_INTERVAL: float = 1.0  # How often to find new target
const REACTION_TIME: float = 0.2  # Seconds before bot shoots after seeing player
const MAX_VIEW_DISTANCE: float = 30.0
const MIN_DISTANCE: float = 5.0  # Minimum distance to keep from target

func _ready() -> void:
	super._ready()
	is_solo_mode = false  # Bots use multiplayer logic
	username = "Bot-" + str(randi() % 999)
	update_username.rpc(username)
	
	# Initialize bot at a random spawn point
	position = spawns[randi() % spawns.size()]
	
	# Initialize health
	health = max_health
	update_health_bar()
	
	# Load and equip weapons for bots on server
	if multiplayer.is_server():
		load_weapons()
		if weapons.size() > 0:
			equip_weapon(default_weapon_index)

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
		
	# Always apply gravity first
	if not is_on_floor():
		velocity += get_gravity() * delta
		
	update_target_timer += delta
	if update_target_timer >= TARGET_UPDATE_INTERVAL:
		update_target_timer = 0.0
		find_nearest_player()
	
	if target_player:
		handle_movement(delta)
		handle_combat(delta)
	
	# Always call move_and_slide to apply physics
	move_and_slide()

func find_nearest_player() -> void:
	var nearest_distance := MAX_VIEW_DISTANCE
	target_player = null
	
	for player in get_tree().get_nodes_in_group("players"):
		if player == self:
			continue
			
		var distance = global_position.distance_to(player.global_position)
		if distance < nearest_distance:
			# Check if we have line of sight
			var space_state = get_world_3d().direct_space_state
			var query = PhysicsRayQueryParameters3D.create(
				global_position,
				player.global_position,
				2  # Collision mask
			)
			var result = space_state.intersect_ray(query)
			
			if result and result.collider == player:
				nearest_distance = distance
				target_player = player

func handle_movement(delta: float) -> void:
	if not target_player:
		return
		
	var direction = (target_player.global_position - global_position).normalized()
	direction.y = 0  # Keep movement on the horizontal plane
	
	# Keep minimum distance from target
	var distance = global_position.distance_to(target_player.global_position)
	if distance < MIN_DISTANCE:
		direction = -direction
	
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.z * WALK_SPEED
	
	# Look at target
	look_at(target_player.global_position, Vector3.UP)
	rotation.x = 0  # Keep bot upright

func handle_combat(delta: float) -> void:
	if not target_player or not current_weapon:
		return
		
	# Add reaction time delay
	if not is_reloading and current_ammo > 0:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			global_position,
			target_player.global_position,
			2  # Collision mask
		)
		var result = space_state.intersect_ray(query)
		
		if result and result.collider == target_player:
			bot_shoot()  # Use bot-specific shoot function
	elif current_ammo <= 0:
		start_reload()

# Override shoot function specifically for bots
func bot_shoot() -> void:
	if not current_weapon:
		return
		
	if current_ammo <= 0:
		start_reload()
		return
		
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_shot_time < current_weapon.fire_rate:
		return
		
	last_shot_time = current_time
	current_ammo -= 1
	
	if target_player:
		var direction = (target_player.global_position - global_position).normalized()
		# Direct damage for bots without RPC
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			global_position,
			target_player.global_position,
			2
		)
		var result = space_state.intersect_ray(query)
		
		if result and result.collider == target_player:
			var hit_player = result.collider
			var is_headshot = false
			
			var hit_height = result.position.y - hit_player.global_position.y
			if hit_height > 1.4 and hit_height < 1.9:
				is_headshot = true
			
			var damage = current_weapon.headshot_damage if is_headshot else current_weapon.damage
			
			# Apply damage directly
			hit_player.health -= damage
			if hit_player.health <= 0:
				hit_player.health = hit_player.max_health
				hit_player.position = hit_player.get_furthest_spawn()
				
				# Update killfeed if available
				if killfeed:
					killfeed.add_kill.rpc(username, hit_player.username, is_headshot)

# Override these functions to prevent UI-related errors
func update_health_bar() -> void:
	pass  # Bots don't need health bars

func update_ammo_display() -> void:
	pass  # Bots don't need ammo display

func play_shoot_effects() -> void:
	pass  # Bots don't need visual effects

# Override update_weapon_visibility for bots
func update_weapon_visibility() -> void:
	if not current_weapon:
		return
		
	# Bots don't show weapons at all
	for weapon in $Camera3D.get_children():
		if weapon is Node3D:
			weapon.visible = false 

func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return

# Remove all debug visualization code 
