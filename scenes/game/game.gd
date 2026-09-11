extends Node3D

const BlockTypes := preload("res://scripts/voxel/block_types.gd")
const UITheme := preload("res://scenes/ui_theme.gd")
const PlayerScript := preload("res://scripts/player/player.gd")
const TouchJoystick := preload("res://scripts/ui/touch_joystick.gd")

var world: Node3D
var players_node: Node3D
var players: Dictionary = {}  # peer_id -> Player
var local_player: Player
var hud: CanvasLayer
var crosshair: Control
var chat_history: Label
var hotbar_hint: Label
var _sync_timer: float = 0.0
var _paused := false
var _day_time: float = 0.45
var _sun: DirectionalLight3D
var _env: Environment
var _chat_open := false

func _ready() -> void:
	_randomize_seed_if_needed()
	_setup_world()
	_setup_lights()
	_setup_hud()
	_spawn_players()
	NetworkManager.player_list_changed.connect(_on_player_list_changed)

	ProgressManager.xp_changed.connect(_on_xp_changed)
	ProgressManager.achievement_unlocked.connect(_on_achievement)
	ProgressManager.add_stats("games_played", 1)
	if local_player:
		local_player.health_changed.connect(_on_health_changed)
		_on_health_changed(local_player.health)
	_on_xp_changed(ProgressManager.level, ProgressManager.xp, ProgressManager.XP_PER_LEVEL)

func _exit_tree() -> void:
	if NetworkManager.player_list_changed.is_connected(_on_player_list_changed):
		NetworkManager.player_list_changed.disconnect(_on_player_list_changed)
	if ProgressManager.xp_changed.is_connected(_on_xp_changed):
		ProgressManager.xp_changed.disconnect(_on_xp_changed)
	if ProgressManager.achievement_unlocked.is_connected(_on_achievement):
		ProgressManager.achievement_unlocked.disconnect(_on_achievement)

func _randomize_seed_if_needed() -> void:
	pass

func _setup_world() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)

	var seed_value: int = -1
	if NetworkManager.is_connected and NetworkManager.is_host:
		seed_value = randi()
		NetworkManager.broadcast_seed(seed_value)
	elif NetworkManager.is_connected and not NetworkManager.is_host:
		seed_value = NetworkManager.pending_world_seed if NetworkManager.pending_world_seed > 0 else randi()
	else:
		seed_value = randi()

	if seed_value <= 0:
		seed_value = randi()

	WorldManager.create_world(world, seed_value)

	# Preload chunks around the spawn point (including the surface chunk) so
	# the player never drops into unresolved terrain before the async loader
	# has generated the landing zone.
	var spawn_point := WorldManager.get_spawn_point()
	var spawn_chunk := WorldManager.world_to_chunk(Vector3i(spawn_point))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for dy in range(maxi(0, spawn_chunk.y - 1), spawn_chunk.y + 2):
				WorldManager.ensure_chunk(spawn_chunk + Vector3i(dx, dy, dz))

func _setup_lights() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55, 30, 0)
	_sun.light_color = Color(1.0, 0.95, 0.85)
	_sun.light_energy = 1.1
	add_child(_sun)

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = _make_sky_material()
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.6
	_env.ambient_light_energy = 0.6
	_sun.shadow_enabled = false
	get_viewport().world_3d.environment = _env

func _make_sky_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type sky;

void sky() {
	vec3 top = vec3(0.05, 0.09, 0.2);
	vec3 bottom = vec3(0.25, 0.35, 0.55);
	vec3 col = mix(bottom, top, clamp(EYEDIR.y * 2.0 + 0.5, 0.0, 1.0));
	float star = step(0.9992, fract(sin(dot(floor(EYEDIR * 90.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453 + TIME * 0.01));
	col = mix(col, vec3(0.9, 0.95, 1.0), star * clamp(EYEDIR.y, 0.0, 1.0));
	COLOR = col;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat

func _spawn_players() -> void:
	players_node = Node3D.new()
	players_node.name = "Players"
	add_child(players_node)

	var infos: Dictionary = NetworkManager.player_info_map
	if infos.is_empty():
		# Single player: host identity
		infos = {
			multiplayer.get_unique_id(): {
				"name": NetworkManager.player_name,
				"color": NetworkManager.player_color,
				"mode": NetworkManager.game_mode,
			}
		}

	for peer_id in infos:
		var info: Dictionary = infos[peer_id]
		_spawn_player(peer_id, info.get("name", "Player"), info.get("color", Color(0.4, 0.7, 1.0)))

	# If somehow we have no players at all, spawn a default one
	if players.is_empty():
		_spawn_player(1, "Player", Color(0.4, 0.7, 1.0))

func _spawn_player(peer_id: int, name: String, color: Color) -> Player:
	if players.has(peer_id):
		return players[peer_id]

	var player := PlayerScript.new()
	player.name = str(peer_id)
	player.peer_id = peer_id
	player.player_color = color
	player.set_multiplayer_authority(peer_id)
	players_node.add_child(player)

	player.global_position = WorldManager.get_spawn_point()
	if peer_id == multiplayer.get_unique_id():
		player.camera.current = true
		if not _is_mobile():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			player.mouse_captured = true

	player.set_name_label(name)
	player.set_is_local_player(peer_id == multiplayer.get_unique_id())

	players[peer_id] = player
	if peer_id == multiplayer.get_unique_id():
		local_player = player
	return player

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("chat"):
		_toggle_chat()

func _on_player_list_changed() -> void:
	for peer_id in NetworkManager.player_info_map:
		if not players.has(peer_id):
			var info: Dictionary = NetworkManager.player_info_map[peer_id]
			_spawn_player(peer_id, info.get("name", "Player"), info.get("color", Color(0.4, 0.7, 1.0)))

	# Remove disconnected players
	for peer_id in players.keys():
		if peer_id != multiplayer.get_unique_id() and not NetworkManager.player_info_map.has(peer_id):
			var p: Player = players[peer_id]
			if is_instance_valid(p):
				p.queue_free()
			players.erase(peer_id)

func _process(delta: float) -> void:
	_update_day_night(delta)
	_update_chunk_loading()
	_update_hud(delta)

func _update_day_night(delta: float) -> void:
	_day_time = fmod(_day_time + delta * 0.008, 1.0)
	var daylight := 1.0
	if _sun:
		var ang := _day_time * TAU
		_sun.rotation = Vector3(-ang + PI * 0.5, 0.3, 0)
		daylight = clampf(sin(ang), -0.2, 1.0)
		_sun.light_energy = lerp(0.05, 1.2, daylight)
		_sun.light_color = Color(1.0, 0.9 + 0.1 * daylight, 0.7 + 0.3 * daylight)

func _current_chunk_target() -> Vector3i:
	if local_player:
		return WorldManager.world_to_chunk(Vector3i(local_player.global_position))
	return Vector3i.ZERO

func _update_chunk_loading() -> void:
	if not local_player:
		return
	# Throttle chunk generation to keep the frame budget stable (max 8/frame).
	# Fill columns around the player first (center-out) so nearby surface
	# appears before distant chunks.
	var center := WorldManager.world_to_chunk(Vector3i(local_player.global_position))
	var xz_order: Array = [0]
	for o in range(1, WorldManager.RENDER_DISTANCE + 1):
		xz_order.append(o)
		xz_order.append(-o)

	# Only generate columns the camera can actually see (skip everything behind
	# the near/other frustum planes) so we don't mesh invisible geometry.
	var frustum: Array = []
	if is_instance_valid(local_player.camera):
		frustum = local_player.camera.get_frustum()

	var loaded_this_frame := 0
	for x in xz_order:
		for z in xz_order:
			# Never skip the few columns the player is standing in/near, even if
			# the camera isn't looking at their corners (tall AABBs can bench
			# every corner outside the view cone). Only frustum-cull far columns.
			if absi(x) > WorldManager.CORE_RADIUS or absi(z) > WorldManager.CORE_RADIUS:
				if frustum.size() > 0:
					var minp := Vector3((center.x + x) * WorldManager.CHUNK_SIZE, 0, (center.z + z) * WorldManager.CHUNK_SIZE)
					var maxp := Vector3(minp.x + WorldManager.CHUNK_SIZE, 96, minp.z + WorldManager.CHUNK_SIZE)
					if not _aabb_in_frustum(frustum, minp, maxp):
						continue
			for y in range(0, 5):
				if loaded_this_frame >= 8:
					return
				var cp := center + Vector3i(x, y, z)
				if not WorldManager.is_chunk_loaded(cp):
					loaded_this_frame += 1
					WorldManager.ensure_chunk(cp)

	# Unload distant chunks (Chebyshev distance to avoid load/unload churn)
	for cp in WorldManager.chunks.keys():
		var d: Vector3i = cp - center
		var max_axis := maxi(abs(d.x), maxi(abs(d.y), abs(d.z)))
		if max_axis > WorldManager.RENDER_DISTANCE + 1:
			WorldManager.unload_chunk(cp)

func _aabb_in_frustum(frustum: Array, minp: Vector3, maxp: Vector3) -> bool:
	for x in [minp.x, maxp.x]:
		for y in [minp.y, maxp.y]:
			for z in [minp.z, maxp.z]:
				var p := Vector3(x, y, z)
				var inside := true
				for pl in frustum:
					if pl.distance_to(p) < 0.0:
						inside = false
						break
				if inside:
					return true
	return false

func _update_hud(delta: float) -> void:
	if not hud or not local_player:
		return
	var info := "FPS: %d" % Engine.get_frames_per_second()
	fps_label.text = info

	var player_pos := Vector3i(local_player.global_position)
	var bios := WorldManager.get_biome_name(player_pos)
	position_label.text = "Pos: %.0f, %.0f, %.0f   View: %s" % [local_player.global_position.x, local_player.global_position.y, local_player.global_position.z, bios]

	if local_player.is_flying:
		mode_label.text = "Mode: %s | FLYING" % NetworkManager.game_mode.to_upper()
	else:
		mode_label.text = "Mode: %s" % NetworkManager.game_mode.to_upper()

	# Track walking distance for achievements
	if _last_pos != Vector3.ZERO:
		var step := local_player.global_position.distance_to(_last_pos)
		if step < 50.0 and local_player.is_on_floor():
			ProgressManager.add_stats("distance_walked", step)
	_last_pos = local_player.global_position

	if not is_instance_valid(local_player) or not local_player.alive and health_label:
		pass

	if _toast_timer > 0.0:
		_toast_timer -= delta
		toast_label.modulate.a = clampf(_toast_timer, 0.0, 1.0)
		if _toast_timer <= 0.0:
			toast_label.text = ""

func _on_health_changed(health: float) -> void:
	if health_label:
		health_label.text = "♥ %d" % int(ceil(health))

func _on_xp_changed(level: int, current_xp: int, xp_to_next: int) -> void:
	if xp_label:
		xp_label.text = "Lv %d | XP %d/%d" % [level, current_xp, xp_to_next]

func _on_achievement(title: String) -> void:
	toast_label.text = "Achievement: %s" % title
	toast_label.modulate.a = 1.0
	_toast_timer = 5.0

func get_biome_label() -> String:
	return ""

func _setup_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	var ui_root := Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.name = "Root"
	hud.add_child(ui_root)

	# Crosshair
	crosshair = CenterContainer.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ch := Label.new()
	ch.text = "+"
	ch.add_theme_font_size_override("font_size", 28)
	ch.add_theme_color_override("font_color", Color.WHITE)
	crosshair.add_child(ch)
	ui_root.add_child(crosshair)

	# Top info bar
	var top_bar := HBoxContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = 8
	top_bar.offset_left = 12
	top_bar.offset_right = -12
	top_bar.add_theme_constant_override("separation", 24)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(top_bar)

	position_label = Label.new()
	position_label.add_theme_font_size_override("font_size", 14)
	position_label.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0, 0.9))
	position_label.add_theme_color_override("font_outline_color", Color.BLACK)
	position_label.add_theme_constant_override("outline_size", 4)
	top_bar.add_child(position_label)

	mode_label = Label.new()
	mode_label.add_theme_font_size_override("font_size", 14)
	mode_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6, 0.9))
	mode_label.add_theme_constant_override("outline_size", 4)
	top_bar.add_child(mode_label)

	xp_label = Label.new()
	xp_label.add_theme_font_size_override("font_size", 14)
	xp_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4, 0.9))
	xp_label.add_theme_constant_override("outline_size", 4)
	top_bar.add_child(xp_label)

	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.7, 0.8))
	fps_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_bar.add_child(fps_label)

	# Health bar (survival)
	var health_panel := PanelContainer.new()
	health_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	health_panel.offset_bottom = -70
	health_panel.offset_top = -100
	health_panel.offset_left = -60
	health_panel.offset_right = 60
	health_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(health_panel)
	health_label = Label.new()
	health_label.text = "♥ 100"
	health_label.add_theme_font_size_override("font_size", 22)
	health_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.3))
	health_panel.add_child(health_label)

	# Hotbar
	var hotbar := HBoxContainer.new()
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.offset_bottom = -12
	hotbar.offset_top = -50
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 4)
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hotbar)

	for i in range(PlayerScript.HOTBAR_BLOCKS.size()):
		var slot_panel := PanelContainer.new()
		var block_id: int = PlayerScript.HOTBAR_BLOCKS[i]
		var slot_label := Label.new()
		slot_label.text = "%d\n%s" % [i + 1, BlockTypes.get_block_name(block_id)]
		slot_label.add_theme_font_size_override("font_size", 12)
		slot_label.add_theme_color_override("font_color", Color(1, 1, 1))
		slot_label.add_theme_color_override("font_color", BlockTypes.get_color(block_id) + Color(0.3, 0.3, 0.3))
		slot_panel.custom_minimum_size = Vector2(84, 38)
		slot_panel.add_child(slot_label)
		if i == 0:
			slot_panel.modulate = Color(1.05, 1.05, 1.05)
		hotbar.add_child(slot_panel)

	# Chat history (bottom-left)
	var chat_margin := MarginContainer.new()
	chat_margin.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_margin.offset_bottom = -64
	chat_margin.offset_left = 12
	chat_margin.custom_minimum_size = Vector2(420, 140)
	chat_margin.size_flags_vertical = Control.SIZE_SHRINK_END
	chat_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(chat_margin)

	chat_history = Label.new()
	chat_history.text = ""
	chat_history.add_theme_font_size_override("font_size", 14)
	chat_history.add_theme_color_override("font_color", Color.WHITE)
	chat_history.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	chat_history.add_theme_constant_override("outline_size", 5)
	chat_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(420, 0)
	scroll.add_child(chat_history)
	chat_margin.add_child(scroll)

	hotbar_hint = Label.new()
	hotbar_hint.text = "LMB: Break | RMB: Place | R: Fly | Shift: Sprint | G: Explode | T: Chat"
	hotbar_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_hint.offset_bottom = -56
	hotbar_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotbar_hint.add_theme_font_size_override("font_size", 12)
	hotbar_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hotbar_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(hotbar_hint)

	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 12
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 6)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(toast_label)

	if _is_mobile():
		_setup_touch_controls()

	NetworkManager.chat_message_received.connect(on_chat_message)
	add_message("[SERVER]", "Welcome to VoxelNexus! Seed: " + str(WorldManager.world_seed))

func _is_mobile() -> bool:
	return OS.has_feature("mobile") or DisplayServer.get_name().to_lower() in ["android", "ios"]

func _setup_touch_controls() -> void:
	var root: Control = hud.get_node("Root")

	# Virtual movement joystick (bottom-left thumb zone)
	var joy: Control = TouchJoystick.new()
	joy.anchor_left = 0.0
	joy.anchor_top = 1.0
	joy.anchor_right = 0.0
	joy.anchor_bottom = 1.0
	joy.offset_left = 24
	joy.offset_right = 210
	joy.offset_top = -206
	joy.offset_bottom = -24
	joy.stick_moved.connect(_on_joy_stick)
	root.add_child(joy)

	# Action buttons (bottom-right thumb zone)
	var box := VBoxContainer.new()
	box.anchor_left = 1.0
	box.anchor_top = 1.0
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -176
	box.offset_right = -16
	box.offset_top = -334
	box.offset_bottom = -70
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(box)

	var next_btn := Button.new()
	next_btn.text = "NEXT BLOCK"
	next_btn.custom_minimum_size = Vector2(0, 46)
	next_btn.button_down.connect(_next_block)
	box.add_child(next_btn)

	var fly_btn := Button.new()
	fly_btn.text = "FLY"
	fly_btn.custom_minimum_size = Vector2(0, 46)
	fly_btn.button_down.connect(func(): _dispatch_action("toggle_flight", true))
	box.add_child(fly_btn)

	var place_btn := Button.new()
	place_btn.text = "PLACE"
	place_btn.custom_minimum_size = Vector2(0, 46)
	place_btn.button_down.connect(func():
		if local_player:
			local_player.touch_place = true)
	place_btn.button_up.connect(func():
		if local_player:
			local_player.touch_place = false)
	box.add_child(place_btn)

	var mine_btn := Button.new()
	mine_btn.text = "MINE"
	mine_btn.custom_minimum_size = Vector2(0, 46)
	mine_btn.button_down.connect(func():
		if local_player:
			local_player.touch_mine = true)
	mine_btn.button_up.connect(func():
		if local_player:
			local_player.touch_mine = false)
	box.add_child(mine_btn)

	var jump_btn := Button.new()
	jump_btn.text = "JUMP"
	jump_btn.custom_minimum_size = Vector2(0, 46)
	jump_btn.button_down.connect(func(): _dispatch_action("jump", true))
	jump_btn.button_up.connect(func(): _dispatch_action("jump", false))
	box.add_child(jump_btn)

func _on_joy_stick(stick: Vector2) -> void:
	_input_action("move_left", stick.x < -0.25)
	_input_action("move_right", stick.x > 0.25)
	_input_action("move_forward", stick.y < -0.25)
	_input_action("move_back", stick.y > 0.25)

func _input_action(action_name: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action_name)
	else:
		Input.action_release(action_name)

func _dispatch_action(action_name: String, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _next_block() -> void:
	if local_player:
		local_player.selected_slot = (local_player.selected_slot + 1) % local_player.HOTBAR_BLOCKS.size()
		local_player.selected_slot_changed.emit(local_player.selected_slot)

var position_label: Label
var mode_label: Label
var fps_label: Label
var xp_label: Label
var health_label: Label
var toast_label: Label
var _toast_timer := 0.0
var _last_pos := Vector3.ZERO

func _toggle_chat() -> void:
	_chat_open = not _chat_open
	if _chat_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if local_player:
			local_player.mouse_captured = false
		chat_input = LineEdit.new()
		chat_input.placeholder_text = "Chat (Enter to send)"
		chat_input.custom_minimum_size = Vector2(420, 36)
		chat_input.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		chat_input.offset_bottom = -90
		chat_input.offset_left = 12
		hud.get_node("Root").add_child(chat_input)
		chat_input.text_submitted.connect(_send_chat)
		chat_input.grab_focus()
	else:
		if chat_input:
			chat_input.queue_free()
		chat_input = null
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if local_player:
			local_player.mouse_captured = true

var chat_input: LineEdit

func _send_chat(text: String) -> void:
	if text != "":
		NetworkManager.send_chat_message(text)
	_toggle_chat()

func on_chat_message(sender: String, message: String) -> void:
	add_message(sender, message)

func add_message(sender: String, message: String) -> void:
	var entry := "[%s] %s" % [sender, message]
	chat_history.text += entry + "\n" if not chat_history.text.is_empty() else entry + "\n"
	# Keep last 50 lines
	var lines := chat_history.text.split("\n")
	if lines.size() > 50:
		chat_history.text = "\n".join(lines.slice(lines.size() - 50))

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		NetworkManager.disconnect_from_game()