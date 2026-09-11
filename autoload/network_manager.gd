extends Node
## NetworkManager - LAN multiplayer using ENet (UDP).
## Server-authoritative: host runs the world, clients send input/block edits.

signal peer_connected(peer_id: int, player_info: Dictionary)
signal peer_disconnected(peer_id: int, player_info: Dictionary)
signal connection_failed
signal connection_succeeded
signal game_mode_changed(mode: String)
signal chat_message_received(sender: String, message: String)
signal player_list_changed

const DEFAULT_PORT := 7777
const MAX_PLAYERS := 8

var is_host := false
var is_connected := false
var self_peer_id := 1
var player_name: String = "Player"
var player_color: Color = Color(0.4, 0.7, 1.0)
var game_mode: String = "creative"
var server_ip: String = ""
var peer: ENetMultiplayerPeer

var player_info_map: Dictionary = {}  # peer_id -> {name, color, mode}
var pending_world_seed: int = -1

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_load_player_name()

func _load_player_name() -> void:
	var saved: String = GameSettings.get_setting("player_name", "")
	if saved != "":
		player_name = saved

func host_game(host_name: String, mode: String) -> bool:
	player_name = host_name
	game_mode = mode
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if result != OK:
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_connected = true
	self_peer_id = multiplayer.get_unique_id()
	player_info_map[self_peer_id] = {
		"name": player_name,
		"color": player_color,
		"mode": mode,
	}
	return true

func join_game(ip: String, join_name: String, mode: String) -> bool:
	player_name = join_name
	server_ip = ip
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_client(ip, DEFAULT_PORT)
	if result != OK:
		return false
	multiplayer.multiplayer_peer = peer
	is_connected = true
	self_peer_id = multiplayer.get_unique_id()
	player_info_map[self_peer_id] = {
		"name": player_name,
		"color": player_color,
		"mode": mode,
	}
	return true

func disconnect_from_game() -> void:
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
	peer = null
	is_host = false
	is_connected = false
	player_info_map.clear()

func _on_peer_connected(peer_id: int) -> void:
	if is_host:
		# Send existing player list to new player
		rpc_id(peer_id, "receive_player_list", player_info_map)
		# Send world seed if the host is already in a live world
		if is_instance_valid(WorldManager.world_root):
			rpc_id(peer_id, "receive_world_seed", WorldManager.world_seed)

func _on_peer_disconnected(peer_id: int) -> void:
	var info: Dictionary = player_info_map.get(peer_id, {})
	if info.has("name"):
		chat_message_received.emit("[SERVER]", "%s left the game" % info["name"])
	player_info_map.erase(peer_id)
	player_list_changed.emit()
	peer_disconnected.emit(peer_id, info)

@rpc("any_peer", "reliable")
func register_player(info: Dictionary) -> void:
	if is_host:
		var id := multiplayer.get_remote_sender_id()
		info["peer_id"] = id
		player_info_map[id] = info
		player_list_changed.emit()
		rpc("receive_player_list", player_info_map)
		if info.has("name"):
			chat_message_received.emit("[SERVER]", "%s joined the game" % info["name"])

@rpc("any_peer", "reliable")
func receive_player_list(infos: Dictionary) -> void:
	player_info_map = infos
	player_list_changed.emit()

@rpc("any_peer", "reliable")
func receive_world_seed(seed: int) -> void:
	pending_world_seed = seed
	if not is_host:
		if WorldManager.world_root:
			WorldManager.create_world(WorldManager.world_root, seed)

func broadcast_seed(seed: int) -> void:
	pending_world_seed = seed
	if is_host and multiplayer.has_multiplayer_peer():
		receive_world_seed.rpc(seed)

func send_player_info() -> void:
	register_player.rpc({
		"name": player_name,
		"color": player_color,
		"mode": game_mode,
	})

func send_chat_message(message: String) -> void:
	chat_relay.rpc(message, player_name)

@rpc("any_peer", "reliable")
func chat_relay(message: String, sender: String) -> void:
	chat_message_received.emit(sender, message)

func change_game_mode(mode: String) -> void:
	game_mode = mode
	set_game_mode.rpc(mode)

@rpc("any_peer", "reliable")
func set_game_mode(mode: String) -> void:
	game_mode = mode
	game_mode_changed.emit(mode)

func is_server() -> bool:
	return is_host or multiplayer.is_server()