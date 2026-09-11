extends Node
## GameSettings - Persists user settings (name, volume, graphics, binds).

const SETTINGS_PATH := "user://settings.cfg"

var settings: Dictionary = {
	"player_name": "Player",
	"volume_master": 0.8,
	"volume_music": 0.7,
	"volume_sfx": 0.9,
	"render_distance": 6,
	"view_bobbing": true,
	"show_fps": false,
	"language": "en",
}

func _ready() -> void:
	load_settings()

func set_setting(key: String, value) -> void:
	settings[key] = value
	save_settings()

func get_setting(key: String, fallback = null):
	return settings.get(key, fallback)

func reset_settings() -> void:
	settings = {}
	save_settings()

func save_settings() -> void:
	var config := ConfigFile.new()
	for key in settings:
		config.set_value("settings", key, settings[key])
	config.save(SETTINGS_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key in settings:
		if config.has_section_key("settings", key):
			settings[key] = config.get_value("settings", key)
	apply_settings()

func apply_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(settings["volume_master"], 0.0001, 1.0)))
	var music_bus := AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(clampf(settings["volume_music"], 0.0001, 1.0)))
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(clampf(settings["volume_sfx"], 0.0001, 1.0)))