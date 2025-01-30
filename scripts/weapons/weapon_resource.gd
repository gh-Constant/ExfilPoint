class_name WeaponResource
extends Resource

@export var name: String = "Base Weapon"
@export var damage: int = 25  # Base damage
@export var headshot_damage: int = 100  # Instant kill on headshot
@export var max_ammo: int = 12
@export var fire_rate: float = 0.5  # Time between shots in seconds
@export var reload_time: float = 1.5
@export var model_scene: PackedScene
@export var muzzle_flash_position: Vector3 = Vector3(0.0, 0.0394075, -0.282182)
@export var shoot_sound: AudioStream 
