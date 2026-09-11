extends Node
## AudioManager - Centralized sound/music playback with procedural audio
## (no external files required, small footprint).

const BlockTypes := preload("res://scripts/voxel/block_types.gd")

var sfx_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_ensure_bus("SFX")
	_ensure_bus("Music")
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	add_child(sfx_player)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.volume_db = -14.0
	add_child(music_player)
	_start_ambience()

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

func _make_tone(frequency: float, duration: float, volume: float, pan: float = 0.0) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 2)
	var max_amp := 32767 * volume
	var fade_samples := int(sample_rate * 0.02)
	for i in num_samples:
		var t := float(i) / sample_rate
		var envelope: float = min(1.0, float(i) / max(fade_samples, 1))
		if i > num_samples - fade_samples:
			envelope = min(envelope, float(num_samples - i) / fade_samples)
		var sample: float = sin(TAU * frequency * t) * envelope * max_amp
		var byte_sample := int(clampf(sample, -32767, 32767))
		data[i * 2] = byte_sample & 0xFF
		data[i * 2 + 1] = (byte_sample >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

func play_sfx(frequency: float = 440.0, duration: float = 0.1, volume: float = 0.3, pan: float = 0.0) -> void:
	var freq := frequency * (0.9 + _rng.randf() * 0.2)
	var wav := _make_tone(freq, duration, volume)
	sfx_player.stream = wav
	sfx_player.pan_stereo = pan
	sfx_player.play()

func play_block_break(block_id: int) -> void:
	match block_id:
		BlockTypes.Block.GLASS, BlockTypes.Block.ICE, BlockTypes.Block.CRYSTAL:
			play_sfx(1200.0, 0.15, 0.5)
		BlockTypes.Block.SAND, BlockTypes.Block.DIRT, BlockTypes.Block.LEAVES:
			play_sfx(200.0, 0.1, 0.4)
		BlockTypes.Block.GRASS:
			play_sfx(300.0, 0.1, 0.4)
		BlockTypes.Block.METAL, BlockTypes.Block.STEEL:
			play_sfx(700.0, 0.12, 0.5)
		_:
			play_sfx(400.0, 0.1, 0.4)

func play_block_place() -> void:
	play_sfx(250.0, 0.08, 0.4)

func play_explosion() -> void:
	play_sfx(60.0, 0.6, 0.8)
	play_sfx(180.0, 0.3, 0.5)

func play_jump() -> void:
	play_sfx(500.0, 0.06, 0.2)

func play_damage() -> void:
	play_sfx(150.0, 0.2, 0.6)

func play_win() -> void:
	play_sfx(523.0, 0.15, 0.5)
	await get_tree().create_timer(0.12).timeout
	play_sfx(659.0, 0.15, 0.5)
	await get_tree().create_timer(0.12).timeout
	play_sfx(784.0, 0.3, 0.5)

func _start_ambience() -> void:
	# Low ambient drone for atmosphere
	var wav := _make_ambience(8.0)
	music_player.stream = wav
	music_player.play()

func _make_ambience(duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(num_samples * 4)  # stereo
	var amplitude := 2000.0
	for i in num_samples:
		var t := float(i) / sample_rate
		var l := sin(TAU * 55.0 * t) * 0.5 + sin(TAU * 110.5 * t) * 0.3 + sin(TAU * 220.7 * t) * 0.2
		var r := sin(TAU * 55.3 * t) * 0.5 + sin(TAU * 110.2 * t) * 0.3 + sin(TAU * 220.4 * t) * 0.2
		var fade: float = min(1.0, float(i) / float(sample_rate * 2))
		if i > num_samples - sample_rate * 2:
			fade = min(fade, float(num_samples - i) / float(sample_rate * 2))
		var li := int(clampf(l * amplitude * fade, -32767, 32767))
		var ri := int(clampf(r * amplitude * fade, -32767, 32767))
		var idx := i * 4
		data[idx] = li & 0xFF
		data[idx + 1] = (li >> 8) & 0xFF
		data[idx + 2] = ri & 0xFF
		data[idx + 3] = (ri >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = true
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	return wav