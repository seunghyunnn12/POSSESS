extends Node
## Small generated PCM bank: no downloads, no runtime synthesis stalls.
var bank: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var voice_index := 0
var muted := false
var next_hit_msec := 0
var master_gain := 0.8:
	set(value):
		master_gain = clampf(value, 0.0, 1.0)
		for voice in voices: voice.volume_db = linear_to_db(master_gain) - 13.0

func _ready() -> void:
	for i in 12:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -13.0
		add_child(voice)
		voices.append(voice)
	bank.shot = tone(0.12, 630, 130, 0.2)
	bank.rifle = tone(0.10, 180, 48, 0.7)
	bank.shotgun = tone(0.23, 130, 30, 0.8)
	bank.arrow = tone(0.16, 1100, 230, 0.15)
	bank.hit = tone(0.055, 1400, 800, 0.4)
	bank.kill = tone(0.15, 260, 55, 0.55)
	bank.fire = tone(0.28, 90, 350, 0.72)
	bank.storm = tone(0.16, 1700, 160, 0.6)
	bank.possess = tone(0.75, 95, 1100, 0.13)
	bank.inhabit = tone(0.28, 440, 220, 0.05)
	bank.rejected = tone(0.25, 270, 50, 0.45)
	bank.eject = tone(0.38, 120, 28, 0.8)
	bank.swing = tone(0.23, 160, 45, 0.65)
	bank.hurt = tone(0.17, 140, 70, 0.45)
	bank.reload = tone(0.10, 450, 650, 0.5)
	bank.loaded = tone(0.10, 850, 450, 0.35)
	bank.clear = tone(0.7, 330, 660, 0.0)
	bank.dead = tone(0.7, 150, 30, 0.12)
	bank.door = tone(0.65, 75, 30, 0.5)
	bank.bell = bell_tone()

func bell_tone() -> AudioStreamWAV:
	var data := PackedByteArray()
	var rate := 22050
	data.resize(rate * 2 * 2)
	for i in rate * 2:
		var t := float(i) / rate
		var value := (sin(TAU * 110 * t) + 0.4 * sin(TAU * 277 * t) + 0.2 * sin(TAU * 463 * t)) * exp(-t * 3) * minf(t * 120, 1)
		data.encode_s16(i * 2, int(clampf(value * 16000, -32767, 32767)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func tone(duration: float, start: float, end: float, noise: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var random := RandomNumberGenerator.new()
	random.seed = 47
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(start, end, t) / sample_rate
		var envelope := minf(t * 40.0, 1.0) * pow(1.0 - t, 1.7)
		var sample := (sin(phase) * (1.0 - noise) + random.randf_range(-1, 1) * noise) * envelope
		data.encode_s16(i * 2, int(clampf(sample * 22000, -32767, 32767)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = data
	return stream

func play(key: String, volume: float = 0.0) -> void:
	# Headless accelerated QA has no listener and outpaces the audio mixer.
	if muted or DisplayServer.get_name() == "headless" or not bank.has(key):
		return
	# A shotgun pellet or chain hit is not a separate full-volume voice.
	if key == "hit":
		var now := Time.get_ticks_msec()
		if now < next_hit_msec: return
		next_hit_msec = now + 45
	var voice := voices[voice_index % voices.size()]
	voice_index += 1
	voice.stream = bank[key]
	voice.volume_db = -13.0 + volume + linear_to_db(master_gain)
	voice.play()

func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
