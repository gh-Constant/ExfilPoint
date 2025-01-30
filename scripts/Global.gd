extends Node

var sensitivity : float =  .005:
	set(value):
		_sensitivity = value
		SettingsManager.save_settings()
	get:
		return _sensitivity

var controller_sensitivity : float =  .010:
	set(value):
		_controller_sensitivity = value
		SettingsManager.save_settings()
	get:
		return _controller_sensitivity

var username: String = "Player":
	set(value):
		_username = value
		SettingsManager.save_settings()
	get:
		return _username

# Add debug settings with setters/getters
var debug_show_backtrack: bool = false:
	set(value):
		_debug_show_backtrack = value
		SettingsManager.save_settings()
	get:
		return _debug_show_backtrack

var debug_show_raycasts: bool = false:
	set(value):
		_debug_show_raycasts = value
		SettingsManager.save_settings()
	get:
		return _debug_show_raycasts

var debug_bot_paths: bool = false:
	set(value):
		_debug_bot_paths = value
		SettingsManager.save_settings()
	get:
		return _debug_bot_paths

var debug_bot_targets: bool = false:
	set(value):
		_debug_bot_targets = value
		SettingsManager.save_settings()
	get:
		return _debug_bot_targets

var debug_bot_reaction_time: float = 0.2:
	set(value):
		_debug_bot_reaction_time = value
		SettingsManager.save_settings()
	get:
		return _debug_bot_reaction_time

var debug_bot_view_distance: float = 30.0:
	set(value):
		_debug_bot_view_distance = value
		SettingsManager.save_settings()
	get:
		return _debug_bot_view_distance

# Private variables
var _sensitivity : float =  .005
var _controller_sensitivity : float =  .010
var _username: String = "Player"
var _debug_show_backtrack: bool = false
var _debug_show_raycasts: bool = false
var _debug_bot_paths: bool = false
var _debug_bot_targets: bool = false
var _debug_bot_reaction_time: float = 0.2
var _debug_bot_view_distance: float = 30.0

func _ready() -> void:
	SettingsManager.load_settings()
