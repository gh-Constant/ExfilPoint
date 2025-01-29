extends Node

const SETTINGS_FILE = "user://settings.cfg"
const DEFAULT_SETTINGS = {
	"sensitivity": 0.005,
	"controller_sensitivity": 0.010,
	"username": "Player"
}

func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Settings", "sensitivity", Global.sensitivity)
	config.set_value("Settings", "controller_sensitivity", Global.controller_sensitivity)
	config.set_value("Settings", "username", Global.username)
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var config = ConfigFile.new()
	var error = config.load(SETTINGS_FILE)
	
	if error != OK:
		# If no settings file exists, create one with defaults
		Global.sensitivity = DEFAULT_SETTINGS.sensitivity
		Global.controller_sensitivity = DEFAULT_SETTINGS.controller_sensitivity
		Global.username = DEFAULT_SETTINGS.username
		save_settings()
		return
		
	Global.sensitivity = config.get_value("Settings", "sensitivity", DEFAULT_SETTINGS.sensitivity)
	Global.controller_sensitivity = config.get_value("Settings", "controller_sensitivity", DEFAULT_SETTINGS.controller_sensitivity)
	Global.username = config.get_value("Settings", "username", DEFAULT_SETTINGS.username) 