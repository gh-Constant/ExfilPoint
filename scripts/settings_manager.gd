extends Node

const SETTINGS_FILE = "user://settings.cfg"
const DEFAULT_SETTINGS = {
	"sensitivity": 0.005,
	"controller_sensitivity": 0.010,
	"username": "Player",
	"game": {
		"max_bots": 3
	}
}

signal settings_updated(category: String, key: String, value: Variant)

func get_setting(category: String, key: String, default_value: Variant = null) -> Variant:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	
	if err != OK:
		return default_value if default_value != null else DEFAULT_SETTINGS.get(category, {}).get(key)
	
	var value = config.get_value(category, key, default_value)
	return value if value != null else DEFAULT_SETTINGS.get(category, {}).get(key)

func set_setting(category: String, key: String, value: Variant) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_FILE) # Ignore error as we'll save anyway
	
	config.set_value(category, key, value)
	config.save(SETTINGS_FILE)
	
	settings_updated.emit(category, key, value)

func save_settings() -> void:
	var config = ConfigFile.new()
	
	# Save game settings
	config.set_value("game", "max_bots", Global.max_bots)
	
	config.save(SETTINGS_FILE)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	
	if err != OK:
		return
		
	# Load game settings
	Global.max_bots = config.get_value("game", "max_bots", DEFAULT_SETTINGS.game.max_bots) 
