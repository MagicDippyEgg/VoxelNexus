extends Node
## WorldManager - Manages the voxel world: chunk loading, block access,
## mesh building, and physics interactions (explosions, gravity).

signal world_ready
signal chunk_loaded(chunk_pos: Vector3i)
signal chunk_unloaded(chunk_pos: Vector3i)
signal terrain_modified(block_world: Vector3i, block_id: int)
signal explosion_happened(position: Vector3, radius: float)

const BlockTypes := preload("res://scripts/voxel/block_types.gd")
const WorldGenerator := preload("res://scripts/voxel/world_generator.gd")
const ChunkScript := preload("res://scripts/voxel/chunk.gd")

const BIOME_NAMES := ["Plains", "Desert", "Crystal Caves", "Floating Islands", "Neon City", "Void Wastes", "Arctic", "Volcanic"]

const CHUNK_SIZE := 16
const RENDER_DISTANCE := 6
const UNLOAD_DISTANCE := 8

var world_seed: int = 1337
var generator: WorldGenerator
var chunks: Dictionary = {}  # Vector3i -> VoxelChunk
var world_root: Node3D
var players: Array = []
var _chunks_to_mesh: Array = []
var _meshing := false
var day_time: float = 0.5
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func create_world(root: Node3D, seed: int = -1) -> void:
	destroy_world()
	world_root = root
	if seed >= 0:
		world_seed = seed
	else:
		world_seed = randi()
	_rng.seed = world_seed
	generator = WorldGenerator.new(world_seed)
	chunks.clear()
	world_ready.emit()

func destroy_world() -> void:
	if world_root:
		for child in world_root.get_children():
			if is_instance_valid(child):
				child.free()
	chunks.clear()

func get_biome_name(world_pos: Vector3i) -> String:
	if generator == null:
		return "Unknown"
	var biome := generator.get_biome_at(world_pos.x, world_pos.z)
	if biome >= 0 and biome < BIOME_NAMES.size():
		return BIOME_NAMES[biome]
	return "Unknown"

func get_chunk_map() -> Dictionary:
	var map: Dictionary = {"generator": generator}
	for pos in chunks:
		map[pos] = chunks[pos].blocks
	return map

func get_chunk_map_for(chunk_pos: Vector3i) -> Dictionary:
	var map: Dictionary = {"generator": generator}
	for dir in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var np: Vector3i = chunk_pos + dir
		var neighbor: VoxelChunk = chunks.get(np)
		if neighbor:
			map[np] = neighbor.blocks
	return map

func is_chunk_loaded(chunk_pos: Vector3i) -> bool:
	return chunks.has(chunk_pos)

func ensure_chunk(chunk_pos: Vector3i) -> bool:
	if chunks.has(chunk_pos):
		return false
	if world_root == null or generator == null:
		return false
	var chunk := ChunkScript.new()
	chunk.name = "Chunk_%d_%d_%d" % [chunk_pos.x, chunk_pos.y, chunk_pos.z]
	chunk.setup(chunk_pos, generator)
	chunk.world_ref = self
	chunk.chunk_updated.connect(_on_chunk_updated)
	world_root.add_child(chunk)
	world_root.move_child(chunk, 0)
	chunks[chunk_pos] = chunk
	chunk.rebuild_mesh()
	terrain_modified.emit(local_to_world(chunk_pos, Vector3i.ZERO), BlockTypes.Block.AIR)
	return true

func _on_chunk_updated(chunk_pos: Vector3i) -> void:
	chunk_loaded.emit(chunk_pos)

func unload_chunk(chunk_pos: Vector3i) -> void:
	var chunk: VoxelChunk = chunks.get(chunk_pos)
	if chunk:
		chunk.queue_free()
		chunks.erase(chunk_pos)
		chunk_unloaded.emit(chunk_pos)

func get_block(world_pos: Vector3i) -> int:
	var chunk_pos := world_to_chunk(world_pos)
	var chunk: VoxelChunk = chunks.get(chunk_pos)
	if chunk == null:
		if generator:
			return generator.get_block(world_pos.x, world_pos.y, world_pos.z)
		return BlockTypes.Block.AIR
	return chunk.get_block_world(world_pos)

func set_block(world_pos: Vector3i, block_id: int, rebuild_neighbors: bool = true) -> void:
	var chunk_pos := world_to_chunk(world_pos)
	var chunk: VoxelChunk = chunks.get(chunk_pos)
	if chunk == null:
		return
	var block_before := chunk.get_block_world(world_pos)
	if block_before == block_id:
		return
	chunk.set_block_world(world_pos, block_id)
	chunk.rebuild_mesh()
	if rebuild_neighbors:
		# Rebuild neighbor chunks if block was on a border
		var local := chunk.world_to_local(world_pos)
		if local.x == 0:
			_rebuild_neighbor(chunk_pos + Vector3i(-1, 0, 0))
		elif local.x == CHUNK_SIZE - 1:
			_rebuild_neighbor(chunk_pos + Vector3i(1, 0, 0))
		if local.y == 0:
			_rebuild_neighbor(chunk_pos + Vector3i(0, -1, 0))
		elif local.y == CHUNK_SIZE - 1:
			_rebuild_neighbor(chunk_pos + Vector3i(0, 1, 0))
		if local.z == 0:
			_rebuild_neighbor(chunk_pos + Vector3i(0, 0, -1))
		elif local.z == CHUNK_SIZE - 1:
			_rebuild_neighbor(chunk_pos + Vector3i(0, 0, 1))
	terrain_modified.emit(world_pos, block_id)

func _rebuild_neighbor(chunk_pos: Vector3i) -> void:
	var chunk: VoxelChunk = chunks.get(chunk_pos)
	if chunk:
		chunk.rebuild_mesh()

func world_to_chunk(world_pos: Vector3i) -> Vector3i:
	return Vector3i(
		floori(world_pos.x / float(CHUNK_SIZE)),
		floori(world_pos.y / float(CHUNK_SIZE)),
		floori(world_pos.z / float(CHUNK_SIZE))
	)

func local_to_world(chunk_pos: Vector3i, local: Vector3i) -> Vector3i:
	return chunk_pos * CHUNK_SIZE + local

func update_player_chunks(player_pos: Vector3i) -> void:
	var center_chunk := world_to_chunk(player_pos)
	var to_load: Array[Vector3i] = []
	for x in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
		for y in range(0, 2):
			for z in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
				var chunk_pos := center_chunk + Vector3i(x, y, z)
				if not chunks.has(chunk_pos):
					to_load.append(chunk_pos)
				elif not chunks[chunk_pos].is_mesh_built:
					chunks[chunk_pos].rebuild_mesh()

	for chunk_pos in to_load:
		ensure_chunk(chunk_pos)

	# Unload far chunks (Chebyshev distance to avoid load/unload churn)
	for chunk_pos in chunks.keys():
		var d: Vector3i = chunk_pos - center_chunk
		var max_axis := maxi(abs(d.x), maxi(abs(d.y), abs(d.z)))
		if max_axis > RENDER_DISTANCE + 1:
			unload_chunk(chunk_pos)

func apply_explosion(center: Vector3, radius: float, power: float = 1.0) -> void:
	explosion_happened.emit(center, radius)
	var c := Vector3i(
		floori(center.x - radius), floori(center.y - radius), floori(center.z - radius)
	)
	var max_c := Vector3i(
		ceil(center.x + radius), ceil(center.y + radius), ceil(center.z + radius)
	)
	var destroyed_blocks: Array[Vector3i] = []

	for y in range(c.y, max_c.y + 1):
		for z in range(c.z, max_c.z + 1):
			for x in range(c.x, max_c.x + 1):
				var wp := Vector3i(x, y, z)
				var dist := Vector3(x + 0.5, y + 0.5, z + 0.5).distance_to(center)
				if dist <= radius:
					var block := get_block(wp)
					if block != BlockTypes.Block.AIR:
						var hardness := BlockTypes.get_hardness(block)
						if hardness <= power * 3.0 or dist <= radius * 0.4:
							destroyed_blocks.append(wp)
							set_block(wp, BlockTypes.Block.AIR, false)

	# Rebuild affected chunks once
	var rebuilt := {}
	for wp in destroyed_blocks:
		var cp := world_to_chunk(wp)
		if not rebuilt.has(cp):
			rebuilt[cp] = true
			var chunk: VoxelChunk = chunks.get(cp)
			if chunk:
				chunk.rebuild_mesh()

	# Apply physics force to nearby RigidBody3D
	if world_root:
		for body in world_root.get_tree().get_nodes_in_group("physics_blocks"):
			if body is RigidBody3D:
				var distance: float = (body.global_position - center).length()
				if distance < radius * 4.0:
					var direction: Vector3 = (body.global_position - center).normalized()
					var force: float = (1.0 - distance / (radius * 4.0)) * power * 50.0
					body.apply_central_impulse(direction * force)

func apply_gravity_blocks(area: Vector3i, radius: int) -> void:
	# Physics sand: blocks with "gravity" property fall when unsupported
	for y in range(area.y, area.y + radius):
		for z in range(area.z, area.z + radius):
			for x in range(area.x, area.x + radius):
				var wp := Vector3i(x, y, z)
				var block := get_block(wp)
				if BlockTypes.is_gravity(block):
					var below := wp + Vector3i(0, -1, 0)
					if get_block(below) == BlockTypes.Block.AIR:
						# Spawn falling block physics entity
						_spawn_falling_block(wp, block)

func _spawn_falling_block(wp: Vector3i, block: int) -> void:
	set_block(wp, BlockTypes.Block.AIR)
	if world_root == null:
		return
	var body := RigidBody3D.new()
	body.global_position = Vector3(wp.x + 0.5, wp.y + 0.5, wp.z + 0.5)
	body.add_to_group("physics_blocks")
	var box := BoxShape3D.new()
	box.size = Vector3(0.95, 0.95, 0.95)
	var col := CollisionShape3D.new()
	col.shape = box
	body.add_child(col)
	world_root.add_child(body)
	body.mass = 2.0

func get_highest_block(world_x: int, world_z: int) -> int:
	for y in range(MAX_HEIGHT(), 0, -1):
		if get_block(Vector3i(world_x, y, world_z)) != BlockTypes.Block.AIR:
			return y
	return 0

func MAX_HEIGHT() -> int:
	return WorldGenerator.MAX_HEIGHT

func get_spawn_point() -> Vector3:
	# Find highest terrain near origin for a safe spawn
	var best_height := -9999
	var best := Vector3.ZERO
	for dx in range(-8, 9):
		for dz in range(-8, 9):
			var h := get_highest_block(dx, dz)
			if h > best_height:
				best_height = h
				best = Vector3(dx + 0.5, h + 3.0, dz + 0.5)
	return best if best_height > -9999 else Vector3(0.5, 40.0, 0.5)