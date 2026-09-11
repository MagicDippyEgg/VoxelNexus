extends Node

const BlockTypes := preload("res://scripts/voxel/block_types.gd")
const UITheme := preload("res://scenes/ui_theme.gd")

var root: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_scene()

func _build_scene() -> void:
	root = Control.new()
	root.name = "MainMenuRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Animated starfield background
	var bg := _make_starfield()
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := UITheme.title_label("VOXELNEXUS")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := UITheme.subtitle_label("Sandbox | Physics | Multiplayer")
	vbox.add_child(subtitle)

	vbox.add_child(HSeparator.new())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var single_player := UITheme.make_button("Single Player")
	single_player.pressed.connect(func(): _start_single_player())
	vbox.add_child(single_player)

	var multiplayer := UITheme.make_button("LAN Multiplayer")
	multiplayer.pressed.connect(func(): _open_multiplayer())
	vbox.add_child(multiplayer)

	var settings := UITheme.make_button("Settings")
	settings.pressed.connect(func(): _open_settings())
	vbox.add_child(settings)

	var credits := UITheme.make_button("Credits")
	credits.pressed.connect(func(): _open_credits())
	vbox.add_child(credits)

	var quit := UITheme.make_button("Quit")
	quit.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit)

	var version := Label.new()
	version.text = "v0.1.0 - Procedural Dimensions"
	version.add_theme_font_size_override("font_size", 13)
	version.add_theme_color_override("font_color", Color(0.4, 0.45, 0.6))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(version)

func _make_starfield() -> Control:
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	for i in range(120):
		var star := ColorRect.new()
		var size := randf_range(1.0, 3.0)
		star.custom_minimum_size = Vector2(size, size)
		star.color = Color(0.8, 0.9, 1.0, randf_range(0.5, 1.0))
		star.position = Vector2(randf() * 1280.0, randf() * 720.0)
		star.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bg.add_child(star)
	return bg

func _start_single_player() -> void:
	NetworkManager.player_name = GameSettings.get_setting("player_name", "Player")
	var mode := "creative"
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _open_multiplayer() -> void:
	NetworkManager.player_name = GameSettings.get_setting("player_name", "Player")
	get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")

func _open_settings() -> void:
	var overlay := Control.new()
	overlay.name = "SettingsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(420, 0)
	panel.add_child(vbox)

	vbox.add_child(UITheme.title_label("Settings", 28))
	vbox.add_child(HSeparator.new())

	var name_label := Label.new()
	name_label.text = "Player Name"
	vbox.add_child(name_label)

	var name_input := LineEdit.new()
	name_input.text = GameSettings.get_setting("player_name", "Player")
	name_input.custom_minimum_size = Vector2(0, 36)
	name_input.text_changed.connect(func(new_text: String):
		GameSettings.set_setting("player_name", new_text))
	vbox.add_child(name_input)

	var vol_label := Label.new()
	vol_label.text = "Master Volume: %d%%" % int(GameSettings.get_setting("volume_master", 0.8) * 100)
	vbox.add_child(vol_label)

	var vol_slider := HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.01
	vol_slider.value = GameSettings.get_setting("volume_master", 0.8)
	vol_slider.value_changed.connect(func(value: float):
		GameSettings.set_setting("volume_master", value)
		vol_label.text = "Master Volume: %d%%" % int(value * 100))
	vbox.add_child(vol_slider)

	var rd_label := Label.new()
	rd_label.text = "Render Distance: %d chunks" % GameSettings.get_setting("render_distance", 6)
	vbox.add_child(rd_label)

	var rd_slider := HSlider.new()
	rd_slider.min_value = 2
	rd_slider.max_value = 10
	rd_slider.step = 1
	rd_slider.value = GameSettings.get_setting("render_distance", 6)
	rd_slider.value_changed.connect(func(value: float):
		GameSettings.set_setting("render_distance", int(value))
		rd_label.text = "Render Distance: %d chunks" % int(value))
	vbox.add_child(rd_slider)

	var reset := UITheme.make_button("Reset to Defaults", Vector2(0, 40))
	reset.pressed.connect(func():
		GameSettings.reset_settings()
		get_tree().reload_current_scene())
	vbox.add_child(reset)

	var close := UITheme.make_button("Close", Vector2(0, 40))
	close.pressed.connect(func(): overlay.queue_free())
	root.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_child(close)

func _open_credits() -> void:
	var overlay := Control.new()
	overlay.name = "CreditsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(420, 0)
	panel.add_child(vbox)

	vbox.add_child(UITheme.title_label("VoxelNexus", 28))
	vbox.add_child(UITheme.subtitle_label("A sandbox of dimensional rifts and physics playgrounds.", 16))
	vbox.add_child(HSeparator.new())
	vbox.add_child(UITheme.subtitle_label("Built with Godot 4", 16))
	vbox.add_child(UITheme.subtitle_label("Cross-platform: Windows, Linux, macOS, iOS, Android", 14))

	var close := UITheme.make_button("Close", Vector2(0, 40))
	close.pressed.connect(func(): overlay.queue_free())
	root.add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_child(close)