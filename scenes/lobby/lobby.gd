extends Node

const UITheme := preload("res://scenes/ui_theme.gd")

const GAME_MODES := [
	{"name": "Creative", "desc": "Unlimited blocks, flying, physics playground"},
	{"name": "Survival", "desc": "Gather resources, survive the night, conquer rifts"},
	{"name": "Team Build", "desc": "Race to build the best structure with your team"},
	{"name": "Destruction Derby", "desc": "Destroy the enemy team's base!"},
]

var root: Control
var _player_list: VBoxContainer
var _host_mode_option: OptionButton
var _join_ip_input: LineEdit
var _status_label: Label

func _ready() -> void:
	NetworkManager.player_list_changed.connect(_refresh_player_list)
	NetworkManager.chat_message_received.connect(_on_chat)
	_build_scene()

func _exit_tree() -> void:
	NetworkManager.player_list_changed.disconnect(_refresh_player_list)
	NetworkManager.chat_message_received.disconnect(_on_chat)

func _build_scene() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(560, 0)
	panel.add_child(vbox)

	vbox.add_child(UITheme.title_label("LAN MULTIPLAYER", 32))
	vbox.add_child(UITheme.subtitle_label("Connect with friends on the same network", 15))
	vbox.add_child(HSeparator.new())

	# --- Host section ---
	var host_title := UITheme.title_label("Host a Game", 22)
	vbox.add_child(host_title)

	var mode_row := HBoxContainer.new()
	var mode_label := Label.new()
	mode_label.text = "Game Mode:  "
	mode_label.add_theme_font_size_override("font_size", 18)
	mode_row.add_child(mode_label)
	_host_mode_option = OptionButton.new()
	_host_mode_option.custom_minimum_size = Vector2(220, 36)
	for mode in GAME_MODES:
		_host_mode_option.add_item(mode["name"])
	_host_mode_option.add_theme_font_size_override("font_size", 16)
	mode_row.add_child(_host_mode_option)
	vbox.add_child(mode_row)

	var mode_desc := Label.new()
	mode_desc.name = "ModeDesc"
	mode_desc.text = GAME_MODES[0]["desc"]
	mode_desc.add_theme_font_size_override("font_size", 14)
	mode_desc.add_theme_color_override("font_color", Color(0.6, 0.65, 0.8))
	mode_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(mode_desc)
	_host_mode_option.item_selected.connect(func(index: int):
		mode_desc.text = GAME_MODES[index]["desc"])

	var host_button := UITheme.make_button("Host Game", Vector2(0, 44))
	host_button.pressed.connect(_host_game)
	vbox.add_child(host_button)

	# --- Join section ---
	vbox.add_child(HSeparator.new())
	vbox.add_child(UITheme.title_label("Join a Game", 22))

	var join_row := HBoxContainer.new()
	var join_label := Label.new()
	join_label.text = "Server IP:  "
	join_label.add_theme_font_size_override("font_size", 18)
	join_row.add_child(join_label)
	_join_ip_input = LineEdit.new()
	_join_ip_input.placeholder_text = "e.g. 192.168.1.42"
	_join_ip_input.text = _get_lan_ip()
	_join_ip_input.custom_minimum_size = Vector2(220, 36)
	join_row.add_child(_join_ip_input)
	vbox.add_child(join_row)

	var join_button := UITheme.make_button("Connect to Server", Vector2(0, 44))
	join_button.pressed.connect(_join_game)
	vbox.add_child(join_button)

	vbox.add_child(HSeparator.new())

	var list_title := UITheme.title_label("Players", 20)
	vbox.add_child(list_title)

	var list_panel := PanelContainer.new()
	_player_list = VBoxContainer.new()
	_player_list.add_theme_constant_override("separation", 6)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 200)
	scroll.add_child(_player_list)
	list_panel.add_child(scroll)
	vbox.add_child(list_panel)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	_status_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_status_label)

	var back := UITheme.make_button("Back to Menu", Vector2(0, 40))
	back.pressed.connect(func():
		NetworkManager.disconnect_from_game()
		get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn"))
	vbox.add_child(back)

	_refresh_player_list()

func _get_lan_ip() -> String:
	var addresses := IP.get_local_addresses()
	for addr in addresses:
		if addr.begins_with("192.168.") or addr.begins_with("10.") or addr.begins_with("172."):
			return addr
	return ""

func _host_game() -> void:
	var mode_index := _host_mode_option.get_selected()
	var mode_key := GAME_MODES[mode_index]["name"].to_snake_case()
	var ok := NetworkManager.host_game(NetworkManager.player_name, mode_key)
	if ok:
		_status_label.text = "Hosting on port %d..." % NetworkManager.DEFAULT_PORT
		NetworkManager.send_player_info()
		_start_game(mode_key)
	else:
		_status_label.text = "Failed to host game!"

func _join_game() -> void:
	var ip := _join_ip_input.text.strip_edges()
	if ip.is_empty():
		_status_label.text = "Please enter a server IP"
		return
	var ok := NetworkManager.join_game(ip, NetworkManager.player_name, "creative")
	if ok:
		_status_label.text = "Connecting to %s..." % ip
		await get_tree().create_timer(0.5).timeout
		if NetworkManager.is_connected:
			NetworkManager.send_player_info()
			_start_game("creative")
	else:
		_status_label.text = "Connection failed!"

func _start_game(mode: String) -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")

func _refresh_player_list() -> void:
	if not _player_list:
		return
	for child in _player_list.get_children():
		child.queue_free()

	if NetworkManager.player_info_map.is_empty():
		var empty := Label.new()
		empty.text = "No players yet"
		empty.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		_player_list.add_child(empty)
		return

	for peer_id in NetworkManager.player_info_map:
		var info: Dictionary = NetworkManager.player_info_map[peer_id]
		var row := HBoxContainer.new()
		var name_label := Label.new()
		var suffix := " (You)" if peer_id == multiplayer.get_unique_id() or peer_id == NetworkManager.self_peer_id else ""
		if NetworkManager.is_host and peer_id == NetworkManager.self_peer_id:
			suffix = " (Host/You)"
		elif NetworkManager.is_host:
			suffix = ""
		name_label.text = "• " + info.get("name", "Unknown") + suffix
		name_label.add_theme_font_size_override("font_size", 16)
		var mode_label := Label.new()
		mode_label.text = "  - " + info.get("mode", "creative")
		mode_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.9))
		row.add_child(name_label)
		row.add_child(mode_label)
		_player_list.add_child(row)

func _on_chat(sender: String, message: String) -> void:
	pass