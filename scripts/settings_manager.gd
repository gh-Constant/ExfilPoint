extends Node

const SETTINGS_FILE = "user://settings.cfg"
const DEFAULT_SETTINGS = {
	"sensitivity": 0.005,
	"controller_sensitivity": 0.010,
	"username": "Player",
	# Add new debug settings
	"debug_show_backtrack": false,
	"debug_show_raycasts": false,
	"debug_bot_paths": false,
	"debug_bot_targets": false,
	"debug_bot_reaction_time": 0.2,
	"debug_bot_view_distance": 30.0
}

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Settings", "sensitivity", Global.sensitivity)
	config.set_value("Settings", "controller_sensitivity", Global.controller_sensitivity)
	config.set_value("Settings", "username", Global.username)
	# Save debug settings
	config.set_value("Debug", "show_backtrack", Global.debug_show_backtrack)
	config.set_value("Debug", "show_raycasts", Global.debug_show_raycasts)
	config.set_value("Debug", "bot_paths", Global.debug_bot_paths)
	config.set_value("Debug", "bot_targets", Global.debug_bot_targets)
	config.set_value("Debug", "bot_reaction_time", Global.debug_bot_reaction_time)
	config.set_value("Debug", "bot_view_distance", Global.debug_bot_view_distance)
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var config = ConfigFile.new()
	var error = config.load(SETTINGS_FILE)
	
	if error != OK:
		# If no settings file exists, create one with defaults
		Global.sensitivity = DEFAULT_SETTINGS.sensitivity
		Global.controller_sensitivity = DEFAULT_SETTINGS.controller_sensitivity
		Global.username = DEFAULT_SETTINGS.username
		Global.debug_show_backtrack = DEFAULT_SETTINGS.debug_show_backtrack
		Global.debug_show_raycasts = DEFAULT_SETTINGS.debug_show_raycasts
		Global.debug_bot_paths = DEFAULT_SETTINGS.debug_bot_paths
		Global.debug_bot_targets = DEFAULT_SETTINGS.debug_bot_targets
		Global.debug_bot_reaction_time = DEFAULT_SETTINGS.debug_bot_reaction_time
		Global.debug_bot_view_distance = DEFAULT_SETTINGS.debug_bot_view_distance
		save_settings()
		return
		
	Global.sensitivity = config.get_value("Settings", "sensitivity", DEFAULT_SETTINGS.sensitivity)
	Global.controller_sensitivity = config.get_value("Settings", "controller_sensitivity", DEFAULT_SETTINGS.controller_sensitivity)
	Global.username = config.get_value("Settings", "username", DEFAULT_SETTINGS.username)
	# Load debug settings
	Global.debug_show_backtrack = config.get_value("Debug", "show_backtrack", DEFAULT_SETTINGS.debug_show_backtrack)
	Global.debug_show_raycasts = config.get_value("Debug", "show_raycasts", DEFAULT_SETTINGS.debug_show_raycasts)
	Global.debug_bot_paths = config.get_value("Debug", "bot_paths", DEFAULT_SETTINGS.debug_bot_paths)
	Global.debug_bot_targets = config.get_value("Debug", "bot_targets", DEFAULT_SETTINGS.debug_bot_targets)
	Global.debug_bot_reaction_time = config.get_value("Debug", "bot_reaction_time", DEFAULT_SETTINGS.debug_bot_reaction_time)
	Global.debug_bot_view_distance = config.get_value("Debug", "bot_view_distance", DEFAULT_SETTINGS.debug_bot_view_distance) 
