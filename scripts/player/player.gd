extends CharacterBody3D
class_name Player

const BlockTypes := preload("res://scripts/voxel/block_types.gd")

signal died(peer_id: int)
signal health_changed(health: float)
signal selected_slot_changed(slot: int)

const WALK_SPEED := 5.0
const SPRINT_SPEED := 8.0
const FLY_SPEED := 12.0
const SPRINT_FLY_SPEED := 20.0
const JUMP_VELOCITY := 7.0
const GRAVITY := 22.0
const MOUSE_SENSITIVITY := 0.003
const REACH_DISTANCE := 6.0
const PLAYER_MASS := 80.0

var peer_id: int = 1
var player_color: Color = Color(0.4, 0.7, 1.0)
var is_bot := false

var camera_pitch: float = 0.0
var is_flying := false
var is_sprinting := false
var mouse_captured := false
var health: float = 100.0
var max_health := 100.0
var alive := true

var camera: Camera3D
var _head: Node3D

var _velocity := Vector3.ZERO
var _vertical_velocity := 0.0
var _build_cooldown := 0.0
var _mine_cooldown := 0.0
var _sync_timer := 0.0
var _awake := true
var _regen_timer := 0.0
var nameplate: Label3D

const HOTBAR_BLOCKS := [
	BlockTypes.Block.GRASS, BlockTypes.Block.DIRT, BlockTypes.Block.STONE,
	BlockTypes.Block.CRYSTAL, BlockTypes.Block.METAL, BlockTypes.Block.GLASS,
	BlockTypes.Block.NEON, BlockTypes.Block.WOOD, BlockTypes.Block.PLASMA,
]
var selected_slot := 0
var _switch_requested := false

func _ready() -> void:
	_build_visuals()
	collision_layer = 2  # player layer
	collision_mask = 1  # collide with world only
	_setup_camera()

func _build_visuals() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	add_child(shape)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.7, 0.5, 0.5)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = player_color
	body_mesh.material = body_mat
	body.mesh = body_mesh
	body.position = Vector3(0, 0.6, 0)
	add_child(body)

	nameplate = Label3D.new()
	nameplate.text = "Player"
	nameplate.font_size = 48
	nameplate.pixel_size = 0.01
	nameplate.outline_size = 8
	nameplate.modulate = Color(1, 1, 1, 0.9)
	nameplate.position = Vector3(0, 2.4, 0)
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(nameplate)

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.current = true
	add_child(camera)

func set_is_local_player(is_local: bool) -> void:
	if is_local:
		camera.current = true
		_awake = true
	else:
		_awake = false
	set_process_input(is_local)

func _physics_process(_delta: float) -> void:
	if not _awake or not alive:
		return

	if is_multiplayer_authority() or is_bot:
		_update_movement(_delta)
		_update_tools(_delta)
		_update_survival(_delta)
		if multipeer_active():
			_sync_timer += _delta
			if _sync_timer >= 0.05:
				_sync_timer = 0.0
				sync_position.rpc(get_multiplayer_authority(), global_position, camera_pitch, is_flying)

func multipeer_active() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.get_unique_id() != 1

func _update_movement(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if is_multiplayer_authority():
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	if Input.is_key_pressed(KEY_Q) and is_multiplayer_authority() and not is_flying:
		pass

	if is_flying:
		var fly_dir := _velocity
		var speed := SPRINT_FLY_SPEED if is_sprinting else FLY_SPEED
		var basis := global_transform.basis

		var move_dir := Vector3.ZERO
		move_dir += basis.z * input_dir.y
		move_dir += basis.x * input_dir.x

		if is_multiplayer_authority():
			if Input.is_action_pressed("fly_up"):
				move_dir += Vector3.UP
			if Input.is_action_pressed("fly_down"):
				move_dir += Vector3.DOWN
			if Input.is_action_pressed("sprint"):
				is_sprinting = true
			else:
				is_sprinting = false

		if move_dir.length() > 0:
			move_dir = move_dir.normalized()
		_velocity = move_dir * speed
		move_and_slide()
	else:
		var gravity_scale := 1.0
		_vertical_velocity -= GRAVITY * gravity_scale * delta

		if is_multiplayer_authority() and Input.is_action_just_pressed("jump") and is_on_floor():
			_vertical_velocity = JUMP_VELOCITY
			AudioManager.play_jump()

		var speed := SPRINT_SPEED if is_sprinting else WALK_SPEED
		if is_multiplayer_authority():
			is_sprinting = Input.is_action_pressed("sprint")

		var basis := global_transform.basis
		var move_dir := Vector3.ZERO
		move_dir += basis.z * input_dir.y
		move_dir += basis.x * input_dir.x
		if move_dir.length() > 0:
			move_dir = move_dir.normalized()

		var horizontal := move_dir * speed
		velocity.x = horizontal.x
		velocity.z = horizontal.z
		velocity.y = _vertical_velocity

		move_and_slide()

		if is_on_floor():
			var impact := -_vertical_velocity
			if impact > 14.0 and NetworkManager.game_mode == "survival":
				take_damage((impact - 14.0) * 2.0)
			_vertical_velocity = -0.5

		# Gravity blocks fall beneath player
		if is_platform_mobile() and is_multiplayer_authority():
			pass

func _update_survival(delta: float) -> void:
	if NetworkManager.game_mode != "survival" or not alive:
		return
	_regen_timer += delta
	if _regen_timer >= 3.0 and health < max_health and is_on_floor():
		health = minf(health + 4.0 * delta, max_health)
		health_changed.emit(health)

func is_platform_mobile() -> bool:
	return DisplayServer.get_name() in ["Android", "iOS"]

func _unhandled_input(event: InputEvent) -> void:
	if not _awake or not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera_pitch = clampf(camera_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.45, 1.45)
		camera.rotation.x = camera_pitch

	if event.is_action_pressed("toggle_flight"):
		if NetworkManager.game_mode == "creative":
			is_flying = not is_flying
			_vertical_velocity = 0.0
			AudioManager.play_sfx(600.0, 0.1, 0.2)

	if event.is_action_pressed("use_left_click"):
		_mine_block()

	if event.is_action_pressed("use_right_click"):
		_place_block()

	if event.is_action_pressed("pause"):
		get_tree().quit()
		# get_tree().get_first_node_in_group("game_root").toggle_pause()

	if event.is_action_pressed("explode"):
		_explode()

	# Hotbar selection
	for slot in range(10):
		if event.is_action_pressed("slot%d" % slot):
			selected_slot = slot
			selected_slot_changed.emit(slot)
			_switch_requested = true

	if event.is_action_pressed("hotbar_scroll_up"):
		selected_slot = (selected_slot + 1) % 10
		selected_slot_changed.emit(selected_slot)
		_switch_requested = true
	if event.is_action_pressed("hotbar_scroll_down"):
		selected_slot = (selected_slot - 1 + 10) % 10
		selected_slot_changed.emit(selected_slot)
		_switch_requested = true

func get_current_block() -> int:
	return HOTBAR_BLOCKS[selected_slot % HOTBAR_BLOCKS.size()]

func _update_tools(delta: float) -> void:
	if _mine_cooldown > 0:
		_mine_cooldown -= delta
	if _build_cooldown > 0:
		_build_cooldown -= delta

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _mine_cooldown <= 0:
		_mine_block()
		_mine_cooldown = 0.18

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _build_cooldown <= 0:
		_place_block()
		_build_cooldown = 0.18

func _raycast_from_camera() -> Dictionary:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * REACH_DISTANCE
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [self]
	return space_state.intersect_ray(query)

func _mine_block() -> void:
	var hit := _raycast_from_camera()
	if hit.is_empty():
		return
	var position_hit: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var target := Vector3i(
		floori(position_hit.x - normal.x * 0.5),
		floori(position_hit.y - normal.y * 0.5),
		floori(position_hit.z - normal.z * 0.5)
	)
	_request_block_edit(target, BlockTypes.Block.AIR)

func _place_block() -> void:
	var hit := _raycast_from_camera()
	if hit.is_empty():
		return
	if hit["collider"] == self:
		return
	var position_hit: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var target := Vector3i(
		floori(position_hit.x + normal.x * 0.5),
		floori(position_hit.y + normal.y * 0.5),
		floori(position_hit.z + normal.z * 0.5)
	)
	# Don't place into player capsule
	if _player_overlaps(target):
		AudioManager.play_sfx(100.0, 0.1, 0.2)
		return
	var block := get_current_block()
	if block == BlockTypes.Block.AIR:
		return
	_request_block_edit(target, block)

func _player_overlaps(block_target: Vector3i) -> bool:
	var player_pos := global_position
	var block_center := Vector3(block_target.x + 0.5, block_target.y + 0.5, block_target.z + 0.5)
	return player_pos.distance_to(block_center) < 1.2

func _request_block_edit(target: Vector3i, block_id: int) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		request_block_edit.rpc_id(1, target, block_id)
		return
	# Server or single player: apply directly and broadcast
	_apply_block_edit(target, block_id)

func _on_block_edited(pos: Vector3i, block_id: int) -> void:
	var existing_before := WorldManager.get_block(pos)
	var is_break := block_id == BlockTypes.Block.AIR and existing_before != BlockTypes.Block.AIR
	if is_break:
		ProgressManager.add_stats("blocks_broken", 1)
		AudioManager.play_block_break(existing_before)
	else:
		ProgressManager.add_stats("blocks_placed", 1)
		AudioManager.play_block_place()
	ProgressManager.add_xp(1)
	ProgressManager.unlock_block(block_id)

func _apply_block_edit(target: Vector3i, block_id: int) -> void:
	WorldManager.set_block(target, block_id)
	if multiplayer.has_multiplayer_peer():
		apply_block_edit.rpc(target, block_id)
	_on_block_edited(target, block_id)

@rpc("any_peer", "reliable")
func request_block_edit(target: Vector3i, block_id: int) -> void:
	if not multiplayer.is_server():
		return
	var current := WorldManager.get_block(target)
	if current == block_id:
		return
	if block_id != BlockTypes.Block.AIR:
		if not BlockTypes.is_placeable(block_id):
			return
	_apply_block_edit(target, block_id)

@rpc("any_peer", "reliable")
func apply_block_edit(target: Vector3i, block_id: int) -> void:
	WorldManager.set_block(target, block_id)
	if is_multiplayer_authority():
		_on_block_edited(target, block_id)

@rpc("any_peer", "reliable", "call_local")
func apply_explosion_rpc(center: Vector3, radius: float = 3.5) -> void:
	WorldManager.apply_explosion(center, radius)
	ProgressManager.add_stats("explosions_set", 1)

func _explode() -> void:
	var center := camera.global_position - camera.global_transform.basis.z * REACH_DISTANCE
	var hit := _raycast_from_camera()
	if not hit.is_empty():
		center = hit["position"]
	if not multiplayer.has_multiplayer_peer():
		apply_explosion_rpc(center, 3.5)
	elif multiplayer.is_server():
		apply_explosion_rpc(center, 3.5)
	else:
		apply_explosion_rpc.rpc_id(1, center, 3.5)

@rpc("any_peer", "unreliable")
func sync_position(authority: int, pos: Vector3, pitch: float, flying: bool) -> void:
	if authority == get_multiplayer_authority():
		return
	global_position = pos
	camera_pitch = pitch
	is_flying = flying

func take_damage(amount: float) -> void:
	if not alive:
		return
	health -= amount
	health_changed.emit(max(health, 0))
	if health <= 0:
		_die()

func _die() -> void:
	alive = false
	died.emit(peer_id)
	AudioManager.play_damage()
	if is_multiplayer_authority():
		_respawn()

func _respawn() -> void:
	health = max_health
	alive = true
	global_position = WorldManager.get_spawn_point()
	health_changed.emit(health)

func set_health_bar(value: float) -> void:
	pass

func set_name_label(text: String) -> void:
	if nameplate:
		nameplate.text = text