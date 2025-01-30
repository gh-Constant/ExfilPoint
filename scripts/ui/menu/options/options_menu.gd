extends PanelContainer

@onready var bot_count_spinbox: SpinBox = %BotCount

func _ready() -> void:
	# Initialize settings from SettingsManager
	bot_count_spinbox.value = SettingsManager.get_setting("game", "max_bots", 3)
	
	# Connect to settings update signal
	SettingsManager.settings_updated.connect(_on_settings_updated)

func _on_settings_updated(category: String, key: String, value: Variant) -> void:
	if category == "game" and key == "max_bots":
		bot_count_spinbox.value = value

func _on_bot_count_value_changed(value: float) -> void:
	SettingsManager.set_setting("game", "max_bots", int(value))
	get_parent().get_parent().max_bots = int(value)

func _exit_tree() -> void:
	# Disconnect from settings update signal when the node is removed
	if SettingsManager.settings_updated.is_connected(_on_settings_updated):
		SettingsManager.settings_updated.disconnect(_on_settings_updated) 
