extends Object
class_name WorldGenerator

const BlockTypes := preload("res://scripts/voxel/block_types.gd")

enum Biome {
	PLAINS,
	DESERT,
	CRYSTAL_CAVES,
	FLOATING_ISLANDS,
	NEON_CITY,
	VOID_WASTES,
	ARCTIC,
	VOLCANIC,
}

const CHUNK_SIZE := 16
const HEIGHT := 64
const MAX_HEIGHT := 96

var _noise_height: FastNoiseLite
var _noise_cave: FastNoiseLite
var _noise_biome: FastNoiseLite
var _noise_crystal: FastNoiseLite
var _noise_neon: FastNoiseLite
var _noise_ruins: FastNoiseLite
var _noise_clouds: FastNoiseLite
var _rng: RandomNumberGenerator

var seed_value: int = 1337

func _init(generator_seed: int = 1337) -> void:
	seed_value = generator_seed
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value

	_noise_height = FastNoiseLite.new()
	_noise_height.seed = seed_value
	_noise_height.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise_height.frequency = 0.012
	_noise_height.fractal_octaves = 5
	_noise_height.fractal_lacunarity = 2.0
	_noise_height.fractal_gain = 0.5
	_noise_height.fractal_weighted_strength = 0.4

	_noise_cave = FastNoiseLite.new()
	_noise_cave.seed = seed_value + 1337
	_noise_cave.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_cave.frequency = 0.06
	_noise_cave.fractal_octaves = 3

	_noise_biome = FastNoiseLite.new()
	_noise_biome.seed = seed_value + 777
	_noise_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_biome.frequency = 0.003

	_noise_crystal = FastNoiseLite.new()
	_noise_crystal.seed = seed_value + 4242
	_noise_crystal.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_crystal.frequency = 0.03

	_noise_neon = FastNoiseLite.new()
	_noise_neon.seed = seed_value + 9090
	_noise_neon.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise_neon.frequency = 0.04

	_noise_ruins = FastNoiseLite.new()
	_noise_ruins.seed = seed_value + 5151
	_noise_ruins.noise_type = FastNoiseLite.TYPE_CELLULAR
	_noise_ruins.frequency = 0.008

	_noise_clouds = FastNoiseLite.new()
	_noise_clouds.seed = seed_value + 3131
	_noise_clouds.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise_clouds.frequency = 0.02
	_noise_clouds.fractal_octaves = 2

func get_biome_at(world_x: int, world_z: int) -> int:
	var shifted := _noise_biome.get_noise_2d(world_x, world_z)
	if shifted > 0.5:
		return Biome.CRYSTAL_CAVES
	elif shifted > 0.25:
		return Biome.NEON_CITY
	elif shifted > 0.0:
		return Biome.PLAINS
	elif shifted > -0.25:
		return Biome.DESERT
	elif shifted > -0.5:
		return Biome.ARCTIC
	else:
		return Biome.VOLCANIC

func get_height_at(world_x: int, world_z: int) -> int:
	var n := _noise_height.get_noise_2d(world_x, world_z)
	var base_height := int(32 + n * 16.0)
	var biome := get_biome_at(world_x, world_z)
	match biome:
		Biome.FLOATING_ISLANDS:
			return 48
		Biome.CRYSTAL_CAVES:
			return 28
		Biome.NEON_CITY:
			return 34
		Biome.ARCTIC:
			return 30
		Biome.VOLCANIC:
			return 20
		Biome.VOID_WASTES:
			return 12
		_:
			return base_height

func get_block(world_x: int, world_y: int, world_z: int) -> int:
	if world_y <= 0:
		return BlockTypes.Block.VOID_BRICK
	if world_y >= MAX_HEIGHT:
		return BlockTypes.Block.AIR

	var biome := get_biome_at(world_x, world_z)
	var height_max := get_height_at(world_x, world_z)

	# Floating islands in the sky
	if biome == Biome.FLOATING_ISLANDS:
		var island_noise := _noise_height.get_noise_2d(world_x, world_z)
		if world_y >= 56 and world_y <= 58 and island_noise > 0.2:
			return BlockTypes.Block.FLOATING
		if world_y in [50, 51] and island_noise > 0.45:
			return BlockTypes.Block.STONE
		if world_y in [44, 45, 46, 47] and abs(island_noise) < 0.05 and world_y == 47:
			return BlockTypes.Block.CLOUD
		return BlockTypes.Block.AIR

	if world_y > height_max:
		# Above surface - check for snow, clouds
		if world_y == height_max + 1:
			match biome:
				Biome.ARCTIC:
					return BlockTypes.Block.SNOW
				Biome.CRYSTAL_CAVES:
					if _noise_crystal.get_noise_3d(world_x, world_y, world_z) > 0.6:
						return BlockTypes.Block.CRYSTAL
					return BlockTypes.Block.AIR
				Biome.NEON_CITY:
					if _noise_neon.get_noise_2d(world_x, world_z) > 0.65:
						return BlockTypes.Block.NEON_PURPLE
					return BlockTypes.Block.AIR
		# Clouds above everything
		if world_y == 66 and _noise_clouds.get_noise_2d(world_x, world_z) > 0.65:
			return BlockTypes.Block.CLOUD
		return BlockTypes.Block.AIR

	# Below surface
	if world_y == height_max:
		return get_surface_block(biome)

	if world_y >= height_max - 3:
		return get_underground_block(biome, world_y, height_max)

	# Caves
	var cave_noise := _noise_cave.get_noise_3d(world_x, world_y, world_z)
	if cave_noise > 0.45 and world_y > 8:
		return BlockTypes.Block.AIR

	# Deep stone and ores based on biome
	var deep_block := get_deep_block(biome, world_x, world_y, world_z)

	# Rift crystal spawns (outside normal caves)
	if _noise_crystal.get_noise_3d(world_x, world_y, world_z) > 0.82 and world_y >= 10:
		return BlockTypes.Block.CRYSTAL_PURPLE

	# Ancient ruins scattered
	if _noise_ruins.get_noise_2d(world_x, world_z) > 0.9 and world_y in [height_max, height_max - 1, height_max - 2]:
		return BlockTypes.Block.ANCIENT_RUIN

	return deep_block

func get_surface_block(biome: int) -> int:
	match biome:
		Biome.PLAINS:
			return BlockTypes.Block.GRASS
		Biome.DESERT:
			return BlockTypes.Block.SAND
		Biome.CRYSTAL_CAVES:
			return BlockTypes.Block.CRYSTAL
		Biome.FLOATING_ISLANDS:
			return BlockTypes.Block.FLOATING
		Biome.NEON_CITY:
			return BlockTypes.Block.TECHNOLOGICAL
		Biome.VOID_WASTES:
			return BlockTypes.Block.BASALT
		Biome.ARCTIC:
			return BlockTypes.Block.ICE
		Biome.VOLCANIC:
			return BlockTypes.Block.LAVA
		_:
			return BlockTypes.Block.GRASS

func get_underground_block(biome: int, world_y: int, height_max: int) -> int:
	match biome:
		Biome.PLAINS:
			return BlockTypes.Block.DIRT
		Biome.DESERT:
			return BlockTypes.Block.SAND
		Biome.CRYSTAL_CAVES:
			return BlockTypes.Block.STONE
		Biome.FLOATING_ISLANDS:
			return BlockTypes.Block.STONE
		Biome.NEON_CITY:
			return BlockTypes.Block.TECHNOLOGICAL
		Biome.VOID_WASTES:
			return BlockTypes.Block.BASALT
		Biome.ARCTIC:
			return BlockTypes.Block.DIRT
		Biome.VOLCANIC:
			return BlockTypes.Block.MAGMA
		_:
			return BlockTypes.Block.DIRT

func get_deep_block(biome: int, world_x: int, world_y: int, world_z: int) -> int:
	var n := _noise_height.get_noise_3d(world_x, world_y * 2, world_z)
	match biome:
		Biome.CRYSTAL_CAVES:
			if world_y < 12:
				return BlockTypes.Block.VOID_BRICK
			if n > 0.6:
				return BlockTypes.Block.CRYSTAL_BLUE
			return BlockTypes.Block.STONE
		Biome.NEON_CITY:
			if n > 0.55:
				return BlockTypes.Block.NEON_GREEN
			return BlockTypes.Block.CONCRETE
		Biome.FLOATING_ISLANDS:
			return BlockTypes.Block.CLOUD if _noise_clouds.get_noise_2d(world_x, world_z) > 0.6 else BlockTypes.Block.STONE
		Biome.VOLCANIC:
			return BlockTypes.Block.MAGMA if _noise_crystal.get_noise_3d(world_x, world_y, world_z) > 0.3 else BlockTypes.Block.BASALT
		Biome.VOID_WASTES:
			return BlockTypes.Block.OBSIDIAN if _noise_crystal.get_noise_3d(world_x, world_y, world_z) > 0.5 else BlockTypes.Block.VOID_BRICK
		Biome.ARCTIC:
			if n > 0.5:
				return BlockTypes.Block.ICE
			return BlockTypes.Block.STONE
		Biome.DESERT:
			if n > 0.7:
				return BlockTypes.Block.GLOW_BLOCK
			return BlockTypes.Block.STONE
		_:
			if n > 0.7:
				return BlockTypes.Block.COUNT - 1 if _rng.randf() > 0.99 else BlockTypes.Block.STONE
			return BlockTypes.Block.STONE