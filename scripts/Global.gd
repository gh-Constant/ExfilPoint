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

var _sensitivity : float =  .005
var _controller_sensitivity : float =  .010
var _username: String = "Player"

func _ready() -> void:
	SettingsManager.load_settings()
