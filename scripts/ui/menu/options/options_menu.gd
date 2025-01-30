extends PanelContainer

@onready var bot_count_spinbox: SpinBox = %BotCount
@onready var debug_bot_paths: CheckButton = %DebugBotPaths
@onready var debug_bot_targets: CheckButton = %DebugBotTargets
@onready var debug_show_backtrack: CheckButton = %DebugBacktrack
@onready var debug_show_raycasts: CheckButton = %DebugRaycasts

func _ready() -> void:
	# Initialize settings from Global
	bot_count_spinbox.value = get_parent().get_parent().max_bots
	debug_bot_paths.button_pressed = Global.debug_bot_paths
	debug_bot_targets.button_pressed = Global.debug_bot_targets
	debug_show_backtrack.button_pressed = Global.debug_show_backtrack
	debug_show_raycasts.button_pressed = Global.debug_show_raycasts

func _on_bot_count_value_changed(value: float) -> void:
	get_parent().get_parent().max_bots = int(value)

func _on_debug_bot_paths_toggled(button_pressed: bool) -> void:
	Global.debug_bot_paths = button_pressed

func _on_debug_bot_targets_toggled(button_pressed: bool) -> void:
	Global.debug_bot_targets = button_pressed

func _on_debug_backtrack_toggled(button_pressed: bool) -> void:
	Global.debug_show_backtrack = button_pressed

func _on_debug_raycasts_toggled(button_pressed: bool) -> void:
	Global.debug_show_raycasts = button_pressed 