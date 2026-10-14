extends Node
## Contact Moment の「こつ」を、振動と同じ瞬間に一度だけ鳴らす。
## バイナリ音源を同梱せず、起動時に短いPCM波形を生成する。通信はしない。

@export var enabled := true
@export_range(0.0, 1.0) var volume := 0.7

var _player: AudioStreamPlayer

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = _make_kotsu()
	add_child(_player)

func _make_kotsu() -> AudioStreamWAV:
	var sample_rate := 22050
	var seconds := 0.075
	var frames := int(sample_rate * seconds)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in range(frames):
		var time := float(i) / sample_rate
		var env := exp(-time * 58.0)
		var body := sin(TAU * 560.0 * time) * 0.72
		var overtone := sin(TAU * 1180.0 * time) * 0.22
		var value := clamp((body + overtone) * env, -1.0, 1.0)
		var s := int(value * 32767.0)
		bytes[i * 2] = s & 0xff
		bytes[i * 2 + 1] = (s >> 8) & 0xff
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav

func contact() -> void:
	if not enabled or volume <= 0.0:
		return
	_player.volume_db = linear_to_db(volume)
	_player.pitch_scale = randf_range(0.97, 1.03)
	_player.play()
