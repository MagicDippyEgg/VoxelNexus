extends Node
## ProgressManager - Tracks XP, unlocks, achievements, and save data.

signal xp_changed(level: int, current_xp: int, xp_to_next: int)
signal unlocked_block(block_id: int)
signal achievement_unlocked(title: String)

const BlockTypes := preload("res://scripts/voxel/block_types.gd")

const SAVE_PATH := "user://progress.save"

const XP_PER_LEVEL := 100

var level: int = 1
var xp: int = 0
var unlocked_blocks: Array = []
var achievements: Dictionary = {}
var stats: Dictionary = {
	"blocks_placed": 0,
	"blocks_broken": 0,
	"games_played": 0,
	"wins": 0,
	"explosions_set": 0,
	"distance_walked": 0.0,
}

const ACHIEVEMENTS := {
	"first_steps": {"name": "First Steps", "desc": "Join your first world", "xp": 10, "icon": "👣"},
	"builder": {"name": "Builder", "desc": "Place 100 blocks", "xp": 25, "icon": "🧱"},
	"architect": {"name": "Architect", "desc": "Place 1000 blocks", "xp": 75, "icon": "🏗️"},
	"explorer": {"name": "Explorer", "desc": "Walk 1km", "xp": 25, "icon": "🧭"},
	"cartographer": {"name": "Cartographer", "desc": "Walk 5km", "xp": 75, "icon": "🗺️"},
	"miner": {"name": "Miner", "desc": "Break 100 blocks", "xp": 25, "icon": "⛏️"},
	"survivor": {"name": "Survivor", "desc": "Survive a full day/night in Survival", "xp": 50, "icon": "🔥"},
	"demolitionist": {"name": "Demolitionist", "desc": "Trigger 10 explosions", "xp": 40, "icon": "💥"},
	"winner": {"name": "Champion", "desc": "Win a competitive mode", "xp": 60, "icon": "🏆"},
	"team_player": {"name": "Team Player", "desc": "Play with 3+ friends", "xp": 50, "icon": "🤝"},
	"collector": {"name": "Collector", "desc": "Unlock 10 block types", "xp": 40, "icon": "💎"},
	"rift_master": {"name": "Rift Master", "desc": "Visit 3 different biomes", "xp": 50, "icon": "🌀"},
}

func _ready() -> void:
	load_game()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= XP_PER_LEVEL:
		xp -= XP_PER_LEVEL
		level += 1
		_check_level_unlocks()
	xp_changed.emit(level, xp, XP_PER_LEVEL)
	save_game()

func add_stats(key: String, amount: float) -> void:
	stats[key] = stats.get(key, 0) + amount
	_check_achievements()

func get_unlocked_blocks() -> Array:
	return unlocked_blocks

func is_block_unlocked(block_id: int) -> bool:
	return block_id in unlocked_blocks

func unlock_block(block_id: int) -> void:
	if block_id == BlockTypes.Block.AIR:
		return
	if not unlocked_blocks.has(block_id):
		unlocked_blocks.append(block_id)
		unlocked_block.emit(block_id)
		add_xp(5)
		save_game()

func unlock_default_blocks() -> void:
	for block_id in BlockTypes.get_creative_palette():
		if BlockTypes.get_unlock_level(block_id) <= level:
			if not unlocked_blocks.has(block_id):
				unlocked_blocks.append(block_id)

func _check_level_unlocks() -> void:
	unlock_default_blocks()

func _check_achievements() -> void:
	if stats["blocks_placed"] >= 100:
		_unlock("builder")
	if stats["blocks_placed"] >= 1000:
		_unlock("architect")
	if stats["blocks_broken"] >= 100:
		_unlock("miner")
	if stats["distance_walked"] >= 1000:
		_unlock("explorer")
	if stats["distance_walked"] >= 10000:
		_unlock("cartographer")
	if stats["explosions_set"] >= 10:
		_unlock("demolitionist")
	if stats["games_played"] >= 1:
		_unlock("first_steps")
	if stats["wins"] >= 1:
		_unlock("winner")
	if unlocked_blocks.size() >= 10:
		_unlock("collector")

func _unlock(key: String) -> void:
	if not achievements.has(key):
		var achievement: Dictionary = ACHIEVEMENTS[key]
		achievements[key] = achievement
		add_xp(achievement.get("xp", 10))
		achievement_unlocked.emit(achievement["name"])
		save_game()

func award_win() -> void:
	add_stats("wins", 1)

func save_game() -> void:
	var data := {
		"level": level,
		"xp": xp,
		"unlocked_blocks": unlocked_blocks,
		"achievements": achievements,
		"stats": stats,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)
		file.close()

func load_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		unlock_default_blocks()
		return
	var data: Dictionary = file.get_var()
	file.close()
	if data.is_empty():
		unlock_default_blocks()
		return
	level = data.get("level", 1)
	xp = data.get("xp", 0)
	unlocked_blocks = data.get("unlocked_blocks", [])
	achievements = data.get("achievements", {})
	stats = data.get("stats", stats)
	unlock_default_blocks()