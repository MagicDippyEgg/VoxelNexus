extends Object
class_name MeshBuilder

const BlockTypes := preload("res://scripts/voxel/block_types.gd")

const FACES := [
	# +X
	{
		"dir": Vector3i(1, 0, 0),
		"verts": [Vector3(1, 1, 1), Vector3(1, 0, 1), Vector3(1, 0, 0), Vector3(1, 1, 0)],
		"normal": Vector3(1, 0, 0),
	},
	# -X
	{
		"dir": Vector3i(-1, 0, 0),
		"verts": [Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 1)],
		"normal": Vector3(-1, 0, 0),
	},
	# +Y
	{
		"dir": Vector3i(0, 1, 0),
		"verts": [Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1)],
		"normal": Vector3(0, 1, 0),
	},
	# -Y
	{
		"dir": Vector3i(0, -1, 0),
		"verts": [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)],
		"normal": Vector3(0, -1, 0),
	},
	# +Z
	{
		"dir": Vector3i(0, 0, 1),
		"verts": [Vector3(1, 1, 1), Vector3(1, 0, 1), Vector3(0, 0, 1), Vector3(0, 1, 1)],
		"normal": Vector3(0, 0, 1),
	},
	# -Z
	{
		"dir": Vector3i(0, 0, -1),
		"verts": [Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 1, 0)],
		"normal": Vector3(0, 0, -1),
	},
]

const SHADE_FACTORS := {
	BlockTypes.Block.GLOW_BLOCK: 1.0,
	BlockTypes.Block.NEON: 1.0,
	BlockTypes.Block.NEON_GREEN: 1.0,
	BlockTypes.Block.NEON_BLUE: 1.0,
	BlockTypes.Block.NEON_PURPLE: 1.0,
	BlockTypes.Block.NEON_RED: 1.0,
	BlockTypes.Block.RIFT_CRYSTAL: 1.0,
	BlockTypes.Block.CRYSTAL: 1.0,
	BlockTypes.Block.CRYSTAL_BLUE: 1.0,
	BlockTypes.Block.CRYSTAL_PURPLE: 1.0,
	BlockTypes.Block.CRYSTAL_YELLOW: 1.0,
	BlockTypes.Block.CRYSTAL_RED: 1.0,
	BlockTypes.Block.PLASMA: 1.0,
	BlockTypes.Block.MAGMA: 1.0,
	BlockTypes.Block.STARDUST: 1.0,
}

const FACE_LIGHTING := {
	Vector3(0, 1, 0): 1.0,
	Vector3(0, -1, 0): 0.5,
	Vector3(1, 0, 0): 0.75,
	Vector3(-1, 0, 0): 0.75,
	Vector3(0, 0, 1): 0.8,
	Vector3(0, 0, -1): 0.8,
}

static func build_chunk_mesh(
	blocks: PackedInt32Array,
	chunk_x: int, chunk_y: int, chunk_z: int,
	chunk_size: int,
	chunk_map: Dictionary
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var i := 0
	for y in range(chunk_size):
		for z in range(chunk_size):
			for x in range(chunk_size):
				var block := blocks[i]
				i += 1
				if block == BlockTypes.Block.AIR:
					continue

				for face in FACES:
					var local: Vector3i = Vector3i(x, y, z) + face["dir"]
					var neighbor_block: int
					if local.x >= 0 and local.x < chunk_size and \
						local.y >= 0 and local.y < chunk_size and \
						local.z >= 0 and local.z < chunk_size:
						neighbor_block = blocks[local.y * chunk_size * chunk_size + local.z * chunk_size + local.x]
					else:
						neighbor_block = _get_neighbor_block(
							chunk_x, chunk_y, chunk_z, local, chunk_size, chunk_map
						)

					if neighbor_block != BlockTypes.Block.AIR and not BlockTypes.is_transparent(neighbor_block):
						continue

					_add_face(st, block, Vector3(x, y, z), face)

	return st.commit()

static func _get_neighbor_block(
	chunk_x: int, chunk_y: int, chunk_z: int,
	local_pos: Vector3i, chunk_size: int, chunk_map: Dictionary
) -> int:
	var world_x := chunk_x * chunk_size + local_pos.x
	var world_y := chunk_y * chunk_size + local_pos.y
	var world_z := chunk_z * chunk_size + local_pos.z

	var ncx := floori(float(world_x) / chunk_size)
	var ncy := floori(float(world_y) / chunk_size)
	var ncz := floori(float(world_z) / chunk_size)

	var neighbor_chunk := Vector3i(ncx, ncy, ncz)
	var neighbor_blocks: PackedInt32Array = chunk_map.get(neighbor_chunk, PackedInt32Array())
	if neighbor_blocks.size() > 0:
		var lx := posmod(world_x, chunk_size)
		var ly := posmod(world_y, chunk_size)
		var lz := posmod(world_z, chunk_size)
		return neighbor_blocks[ly * chunk_size * chunk_size + lz * chunk_size + lx]
	return BlockTypes.Block.AIR

static func _add_face(st: SurfaceTool, block: int, base_pos: Vector3, face: Dictionary) -> void:
	var verts: Array = face["verts"]
	var normal: Vector3 = face["normal"]
	var color := BlockTypes.get_color(block)
	var shade: float = FACE_LIGHTING.get(normal, 0.75)
	if SHADE_FACTORS.has(block):
		shade = 1.0
	color.r *= shade
	color.g *= shade
	color.b *= shade
	if BlockTypes.is_transparent(block):
		color.a *= 0.85

	var triangle_verts := [
		base_pos + verts[0], base_pos + verts[1], base_pos + verts[2],
		base_pos + verts[0], base_pos + verts[2], base_pos + verts[3],
	]
	for v in triangle_verts:
		st.set_normal(normal)
		st.set_color(color)
		st.set_uv(Vector2(v.x * 0.5 + 0.5, v.z * 0.5 + 0.5))
		st.add_vertex(v)