extends Node3D
class_name VoxelChunk

const BlockTypes := preload("res://scripts/voxel/block_types.gd")
const MeshBuilder := preload("res://scripts/voxel/mesh_builder.gd")

signal chunk_updated(chunk_position: Vector3i)

const CHUNK_SIZE := 16

var chunk_position: Vector3i
var blocks: PackedInt32Array
var is_mesh_built := false

var mesh_instance: MeshInstance3D
var collision_body: StaticBody3D
var generator: WorldGenerator
var world_ref: Node = null

static var _block_mat: StandardMaterial3D = null

static func get_block_material() -> StandardMaterial3D:
	if _block_mat == null:
		_block_mat = StandardMaterial3D.new()
		_block_mat.vertex_color_use_as_albedo = true
		_block_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_block_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_block_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _block_mat

func _init() -> void:
	mesh_instance = MeshInstance3D.new()
	collision_body = StaticBody3D.new()
	mesh_instance.name = "MeshInstance3D"
	collision_body.name = "Collision"
	mesh_instance.material_override = get_block_material()
	add_child(mesh_instance)
	add_child(collision_body)

func setup(chunk_pos: Vector3i, gen: WorldGenerator) -> void:
	chunk_position = chunk_pos
	generator = gen
	blocks.resize(CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE)
	position = to_world_position(chunk_pos)
	_generate_blocks()

func to_world_position(chunk_pos: Vector3i) -> Vector3:
	return Vector3(chunk_pos.x * CHUNK_SIZE, chunk_pos.y * CHUNK_SIZE, chunk_pos.z * CHUNK_SIZE)

func local_to_world(local: Vector3i) -> Vector3i:
	return chunk_position * CHUNK_SIZE + local

func world_to_local(world: Vector3i) -> Vector3i:
	return Vector3i(
		posmod(world.x, CHUNK_SIZE),
		posmod(world.y, CHUNK_SIZE),
		posmod(world.z, CHUNK_SIZE)
	)

func _generate_blocks() -> void:
	var idx := 0
	for y in range(CHUNK_SIZE):
		for z in range(CHUNK_SIZE):
			for x in range(CHUNK_SIZE):
				var world := Vector3i(
					chunk_position.x * CHUNK_SIZE + x,
					chunk_position.y * CHUNK_SIZE + y,
					chunk_position.z * CHUNK_SIZE + z
				)
				blocks[idx] = generator.get_block(world.x, world.y, world.z)
				idx += 1

func get_block_local(local: Vector3i) -> int:
	if local.x < 0 or local.x >= CHUNK_SIZE or \
		local.y < 0 or local.y >= CHUNK_SIZE or \
		local.z < 0 or local.z >= CHUNK_SIZE:
		return BlockTypes.Block.AIR
	return blocks[local.y * CHUNK_SIZE * CHUNK_SIZE + local.z * CHUNK_SIZE + local.x]

func get_block_world(world: Vector3i) -> int:
	return get_block_local(world_to_local(world))

func set_block_local(local: Vector3i, block_id: int) -> void:
	if local.x < 0 or local.x >= CHUNK_SIZE or \
		local.y < 0 or local.y >= CHUNK_SIZE or \
		local.z < 0 or local.z >= CHUNK_SIZE:
		return
	blocks[local.y * CHUNK_SIZE * CHUNK_SIZE + local.z * CHUNK_SIZE + local.x] = block_id

func set_block_world(world: Vector3i, block_id: int) -> void:
	set_block_local(world_to_local(world), block_id)

func rebuild_mesh() -> void:
	var chunk_map: Dictionary = {}
	if world_ref:
		chunk_map = world_ref.get_chunk_map_for(chunk_position)
	else:
		chunk_map = {"generator": generator}

	var mesh := MeshBuilder.build_chunk_mesh(
		blocks, chunk_position.x, chunk_position.y, chunk_position.z,
		CHUNK_SIZE, chunk_map
	)
	mesh_instance.mesh = mesh
	_build_collision(mesh)
	is_mesh_built = true
	chunk_updated.emit(chunk_position)

func _build_collision(mesh: ArrayMesh) -> void:
	for child in collision_body.get_children():
		collision_body.remove_child(child)
		child.queue_free()

	if mesh == null or mesh.get_surface_count() == 0:
		return

	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[mesh.ARRAY_VERTEX]
	if verts.size() == 0:
		return

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(verts)
	var col_shape := CollisionShape3D.new()
	col_shape.shape = shape
	collision_body.add_child(col_shape)