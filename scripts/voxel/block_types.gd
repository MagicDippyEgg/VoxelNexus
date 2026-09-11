extends Object
class_name BlockTypes

enum Block {
	AIR = 0,
	GRASS = 1,
	DIRT = 2,
	STONE = 3,
	CRYSTAL = 4,
	METAL = 5,
	GLASS = 6,
	NEON = 7,
	LAVA = 8,
	VOID_ACID = 9,
	ELECTRIFIED = 10,
	SAND = 11,
	WATER = 12,
	FLOATING = 13,
	WOOD = 14,
	LEAVES = 15,
	SNOW = 16,
	ICE = 17,
	RIFT_CRYSTAL = 18,
	OBSIDIAN = 19,
	PLASMA = 20,
	STEEL = 21,
	CONCRETE = 22,
	NEON_GREEN = 23,
	NEON_BLUE = 24,
	NEON_PURPLE = 25,
	NEON_RED = 26,
	GLOW_BLOCK = 27,
	FORCE_FIELD = 28,
	TECHNOLOGICAL = 29,
	ANCIENT_RUIN = 30,
	GROWTH = 31,
	MUSHROOM = 32,
	BASALT = 33,
	MAGMA = 34,
	CRYSTAL_BLUE = 35,
	CRYSTAL_PURPLE = 36,
	CRYSTAL_YELLOW = 37,
	CRYSTAL_RED = 38,
	CLOUD = 39,
	STARDUST = 40,
	VOID_BRICK = 41,
	COUNT = 42
}

const BLOCK_DATA: Dictionary = {
	Block.AIR: {"name": "Air", "solid": false, "transparent": true, "color": Color(0, 0, 0, 0)},
	Block.GRASS: {"name": "Grass", "solid": true, "transparent": false, "color": Color(0.27, 0.65, 0.27), "hardness": 0.5},
	Block.DIRT: {"name": "Dirt", "solid": true, "transparent": false, "color": Color(0.45, 0.32, 0.2), "hardness": 0.4},
	Block.STONE: {"name": "Stone", "solid": true, "transparent": false, "color": Color(0.45, 0.45, 0.47), "hardness": 1.0},
	Block.CRYSTAL: {"name": "Crystal", "solid": true, "transparent": true, "color": Color(0.0, 0.7, 1.0, 0.6), "hardness": 0.7, "glow": true},
	Block.METAL: {"name": "Metal", "solid": true, "transparent": false, "color": Color(0.55, 0.55, 0.55), "hardness": 1.5, "conductive": true},
	Block.GLASS: {"name": "Glass", "solid": true, "transparent": true, "color": Color(0.8, 0.9, 1.0, 0.3), "hardness": 0.3},
	Block.NEON: {"name": "Neon", "solid": true, "transparent": false, "color": Color(1.0, 0.9, 0.2), "hardness": 0.4, "glow": true},
	Block.LAVA: {"name": "Lava", "solid": false, "transparent": true, "color": Color(1.0, 0.3, 0.0, 0.85), "hazard": true, "fluid": true},
	Block.VOID_ACID: {"name": "Void Acid", "solid": false, "transparent": true, "color": Color(0.5, 0.0, 0.9, 0.7), "hazard": true, "fluid": true},
	Block.ELECTRIFIED: {"name": "Electrified", "solid": true, "transparent": false, "color": Color(0.2, 0.4, 1.0, 0.4), "hazard": true, "conductive": true},
	Block.SAND: {"name": "Sand", "solid": true, "transparent": false, "color": Color(0.85, 0.75, 0.55), "hardness": 0.3, "gravity": true},
	Block.WATER: {"name": "Water", "solid": false, "transparent": true, "color": Color(0.1, 0.4, 0.9, 0.6), "fluid": true},
	Block.FLOATING: {"name": "Floating", "solid": true, "transparent": false, "color": Color(0.9, 0.9, 1.0, 0.5), "hardness": 0.6},
	Block.WOOD: {"name": "Wood", "solid": true, "transparent": false, "color": Color(0.55, 0.36, 0.18), "hardness": 0.9},
	Block.LEAVES: {"name": "Leaves", "solid": true, "transparent": true, "color": Color(0.18, 0.55, 0.2, 0.85), "hardness": 0.2},
	Block.SNOW: {"name": "Snow", "solid": true, "transparent": false, "color": Color(0.95, 0.95, 1.0), "hardness": 0.2},
	Block.ICE: {"name": "Ice", "solid": true, "transparent": true, "color": Color(0.7, 0.9, 1.0, 0.5), "hardness": 0.4},
	Block.RIFT_CRYSTAL: {"name": "Rift Crystal", "solid": true, "transparent": true, "color": Color(0.9, 0.1, 1.0, 0.7), "hardness": 2.0, "glow": true, "portal_source": true},
	Block.OBSIDIAN: {"name": "Obsidian", "solid": true, "transparent": false, "color": Color(0.15, 0.1, 0.2), "hardness": 3.0},
	Block.PLASMA: {"name": "Plasma", "solid": false, "transparent": true, "color": Color(0.8, 0.1, 0.9, 0.7), "hazard": true, "fluid": true, "glow": true},
	Block.STEEL: {"name": "Steel", "solid": true, "transparent": false, "color": Color(0.42, 0.48, 0.55, 0.4), "hardness": 2.0, "conductive": true},
	Block.CONCRETE: {"name": "Concrete", "solid": true, "transparent": false, "color": Color(0.6, 0.6, 0.61), "hardness": 1.2},
	Block.NEON_GREEN: {"name": "Neon Green", "solid": true, "transparent": false, "color": Color(0.0, 1.0, 0.4), "hardness": 0.4, "glow": true},
	Block.NEON_BLUE: {"name": "Neon Blue", "solid": true, "transparent": false, "color": Color(0.2, 0.5, 1.0), "hardness": 0.4, "glow": true},
	Block.NEON_PURPLE: {"name": "Neon Purple", "solid": true, "transparent": false, "color": Color(0.7, 0.2, 1.0), "hardness": 0.4, "glow": true},
	Block.NEON_RED: {"name": "Neon Red", "solid": true, "transparent": false, "color": Color(1.0, 0.2, 0.2), "hardness": 0.4, "glow": true},
	Block.GLOW_BLOCK: {"name": "Glow Block", "solid": true, "transparent": false, "color": Color(1.0, 1.0, 0.9), "hardness": 0.8, "glow": true},
	Block.FORCE_FIELD: {"name": "Force Field", "solid": true, "transparent": true, "color": Color(0.3, 0.9, 1.0, 0.2), "hardness": 2.5},
	Block.TECHNOLOGICAL: {"name": "Tech Plate", "solid": true, "transparent": false, "color": Color(0.25, 0.35, 0.5), "hardness": 1.4, "conductive": true},
	Block.ANCIENT_RUIN: {"name": "Ancient Ruin", "solid": true, "transparent": false, "color": Color(0.5, 0.4, 0.25), "hardness": 1.8},
	Block.GROWTH: {"name": "Growth", "solid": true, "transparent": true, "color": Color(0.1, 0.7, 0.4, 0.8), "hardness": 0.5},
	Block.MUSHROOM: {"name": "Mushroom", "solid": true, "transparent": false, "color": Color(0.9, 0.3, 0.7), "hardness": 0.25},
	Block.BASALT: {"name": "Basalt", "solid": true, "transparent": false, "color": Color(0.2, 0.2, 0.23), "hardness": 1.3},
	Block.MAGMA: {"name": "Magma", "solid": true, "transparent": true, "color": Color(0.9, 0.3, 0.0, 0.9), "hardness": 1.5, "hazard": true, "glow": true},
	Block.CRYSTAL_BLUE: {"name": "Blue Crystal", "solid": true, "transparent": true, "color": Color(0.1, 0.5, 1.0, 0.6), "hardness": 0.7, "glow": true},
	Block.CRYSTAL_PURPLE: {"name": "Purple Crystal", "solid": true, "transparent": true, "color": Color(0.6, 0.1, 1.0, 0.6), "hardness": 0.7, "glow": true},
	Block.CRYSTAL_YELLOW: {"name": "Yellow Crystal", "solid": true, "transparent": true, "color": Color(1.0, 0.8, 0.1, 0.6), "hardness": 0.7, "glow": true},
	Block.CRYSTAL_RED: {"name": "Red Crystal", "solid": true, "transparent": true, "color": Color(1.0, 0.2, 0.1, 0.6), "hardness": 0.7, "glow": true},
	Block.CLOUD: {"name": "Cloud", "solid": true, "transparent": true, "color": Color(1.0, 1.0, 1.0, 0.7), "hardness": 0.1},
	Block.STARDUST: {"name": "Stardust", "solid": true, "transparent": true, "color": Color(1.0, 0.9, 0.7, 0.5), "hardness": 0.3, "glow": true},
	Block.VOID_BRICK: {"name": "Void Brick", "solid": true, "transparent": false, "color": Color(0.1, 0.08, 0.15), "hardness": 2.2},
}

static func get_block_name(block_id: int) -> String:
	if block_id == Block.AIR:
		return "Air"
	return BLOCK_DATA.get(block_id, BLOCK_DATA[Block.STONE]).get("name", "Unknown")

static func get_color(block_id: int) -> Color:
	if block_id == Block.AIR:
		return Color(0, 0, 0, 0)
	return BLOCK_DATA.get(block_id, BLOCK_DATA[Block.STONE]).get("color", Color.WHITE)

static func is_solid(block_id: int) -> bool:
	return BLOCK_DATA.get(block_id, {}).get("solid", false)

static func is_transparent(block_id: int) -> bool:
	return BLOCK_DATA.get(block_id, {}).get("transparent", false)

static func get_hardness(block_id: int) -> float:
	return BLOCK_DATA.get(block_id, {}).get("hardness", 1.0)

static func is_hazard(block_id: int) -> bool:
	return BLOCK_DATA.get(block_id, {}).get("hazard", false)

static func is_fluid(block_id: int) -> bool:
	return BLOCK_DATA.get(block_id, {}).get("fluid", false)

static func is_gravity(block_id: int) -> bool:
	return BLOCK_DATA.get(block_id, {}).get("gravity", false)

static func has_glow(block_id: int) -> bool:
	return BLOCK_DATA.get(block_id, {}).get("glow", false)

static func is_conductive(block_id: int) -> bool:
	return BLOCK_DATA.get(block_id, {}).get("conductive", false)

static func is_portal_source(block_id: int) -> bool:
	return BLOCK_DATA.get(block_id, {}).get("portal_source", false)

static func is_placeable(block_id: int) -> bool:
	return block_id != Block.AIR

static func is_buildable(block_id: int) -> bool:
	return is_solid(block_id) and block_id not in [Block.LAVA, Block.VOID_ACID, Block.WATER, Block.PLASMA]

static func get_creative_palette() -> Array[int]:
	return [
		Block.GRASS, Block.DIRT, Block.STONE, Block.SAND, Block.WOOD,
		Block.LEAVES, Block.METAL, Block.STEEL, Block.CONCRETE,
		Block.GLASS, Block.ICE, Block.SNOW, Block.CRYSTAL,
		Block.CRYSTAL_BLUE, Block.CRYSTAL_PURPLE, Block.CRYSTAL_YELLOW, Block.CRYSTAL_RED,
		Block.NEON, Block.NEON_GREEN, Block.NEON_BLUE, Block.NEON_PURPLE, Block.NEON_RED,
		Block.GLOW_BLOCK, Block.OBSIDIAN, Block.BASALT, Block.MAGMA,
		Block.PLASMA, Block.VOID_ACID, Block.LAVA, Block.WATER,
		Block.FLOATING, Block.FORCE_FIELD, Block.TECHNOLOGICAL,
		Block.CLOUD, Block.STARDUST, Block.VOID_BRICK, Block.ANCIENT_RUIN,
		Block.GROWTH, Block.MUSHROOM, Block.RIFT_CRYSTAL
	]

static func get_unlock_level(block_id: int) -> int:
	match block_id:
		Block.STONE, Block.DIRT, Block.GRASS, Block.SAND, Block.WOOD:
			return 1
		Block.LEAVES, Block.GLASS, Block.ICE, Block.SNOW, Block.MUSHROOM, Block.GROWTH:
			return 2
		Block.METAL, Block.CONCRETE, Block.CRYSTAL, Block.MAGMA, Block.BASALT:
			return 3
		Block.STEEL, Block.TECHNOLOGICAL, Block.NEON, Block.GLOW_BLOCK, Block.FLOATING:
			return 4
		Block.NEON_GREEN, Block.NEON_BLUE, Block.NEON_PURPLE, Block.NEON_RED:
			return 6
		Block.CRYSTAL_BLUE, Block.CRYSTAL_PURPLE, Block.CRYSTAL_YELLOW, Block.CRYSTAL_RED:
			return 7
		Block.PLASMA, Block.VOID_ACID, Block.FORCE_FIELD, Block.CLOUD, Block.STARDUST:
			return 8
		Block.RIFT_CRYSTAL, Block.VOID_BRICK, Block.OBSIDIAN, Block.ANCIENT_RUIN:
			return 10
		_:
			return 1