extends Node
## ContactController（設計書 §4〜§8, §27）
## 触れ合いの状態機械。指の入力を受けて、パートナーの手の重み（0〜1）と目標点を決める。
##
##   IDLE → NOTICE → APPROACH → CONTACT/HOLD → FOLLOW → RETURN → IDLE
##
## - TAP（短く触れて離す）なら手は伸ばさず、視線と瞬きだけ
## - HOLD（押し続ける）と、間を置いてから手を伸ばす
## - 手のひらが硝子に届いた瞬間が Contact Moment（振動＋波紋）
## - 指を離すと、すぐには引かず少し留まり（FOLLOW）、ゆっくり戻る（RETURN）
## どの状態からでも、指が離れれば必ず IDLE へ戻る。

signal contact_started(screen_pos: Vector2)
signal contact_ended(duration_ms: int)
signal state_changed(state: String)

enum S { IDLE, NOTICE, APPROACH, HOLD, FOLLOW, RETURN }

@export var character: Node3D
@export var camera: Camera3D
@export var haptics: Node

var p := {
	"hold_threshold": 0.30,
	"approach_delay": 0.15,
	"approach_time": 0.85,
	"hold_follow": 0.25,
	"follow_duration": 0.35,
	"follow_weight": 0.9,
	"return_time": 0.95,
	"sway_mm": 1.5
}

var state := S.IDLE
var _t := 0.0
var _w := 0.0
var _side := "Right"
var _finger_point := Vector3.ZERO
var _target := Vector3.ZERO
var _pressed := false
var _contact_ms := 0
var _w_at_release := 1.0

func configure(profile: Dictionary) -> void:
	for k in p:
		if profile.has(k):
			p[k] = profile[k]

func on_touch_started(world_point: Vector3) -> void:
	_pressed = true
	_finger_point = world_point
	match state:
		S.IDLE, S.NOTICE:
			_target = world_point
			_set_state(S.NOTICE)
		S.FOLLOW, S.RETURN:
			_side = _pick_side(world_point)
			_set_state(S.APPROACH)
		_:
			pass

func on_touch_moved(world_point: Vector3) -> void:
	_finger_point = world_point

func on_touch_ended() -> void:
	_pressed = false
	match state:
		S.NOTICE:
			_set_state(S.IDLE)
		S.APPROACH:
			_w_at_release = _w
			_set_state(S.RETURN)
		S.HOLD:
			contact_ended.emit(Time.get_ticks_msec() - _contact_ms)
			_set_state(S.FOLLOW)
		_:
			pass

func cancel() -> void:
	if state == S.HOLD:
		contact_ended.emit(Time.get_ticks_msec() - _contact_ms)
	_pressed = false
	_w_at_release = _w
	if state != S.IDLE:
		_set_state(S.RETURN)

func _process(delta: float) -> void:
	_t += delta
	match state:
		S.NOTICE:
			_target = _finger_point
			if _pressed and _t >= p.hold_threshold + p.approach_delay:
				_side = _pick_side(_finger_point)
				_set_state(S.APPROACH)
		S.APPROACH:
			_target = _target.lerp(_finger_point, _k(p.hold_follow, delta))
			_w = min(_w + delta / p.approach_time, 1.0)
			if _w >= 1.0:
				_contact()
		S.HOLD:
			_target = _target.lerp(_finger_point, _k(p.hold_follow, delta))
		S.FOLLOW:
			var f: float = clamp(_t / p.follow_duration, 0.0, 1.0)
			_w = lerp(1.0, float(p.follow_weight), f)
			if f >= 1.0:
				_w_at_release = _w
				_set_state(S.RETURN)
		S.RETURN:
			_w = max(_w - delta * _w_at_release / p.return_time, 0.0)
			if _w <= 0.0:
				_set_state(S.IDLE)

	if character:
		var sway := Vector3.ZERO
		if state == S.HOLD:
			var mm: float = p.sway_mm / 1000.0
			sway = Vector3(sin(_t * 1.7), sin(_t * 2.3 + 1.0), 0.0) * mm
		if _w > 0.0 or state == S.APPROACH:
			character.set_reach(_side, _target + sway, _w)
		elif state == S.IDLE:
			character.set_reach(_side, _target, 0.0)

func _contact() -> void:
	_contact_ms = Time.get_ticks_msec()
	_set_state(S.HOLD)
	if haptics:
		haptics.contact()
	var screen := camera.unproject_position(character.palm_world(_side)) if camera else Vector2.ZERO
	contact_started.emit(screen)

func _pick_side(world_point: Vector3) -> String:
	return "Right" if world_point.x < 0.0 else "Left"

func _k(time: float, delta: float) -> float:
	return 1.0 - exp(-delta / max(time * 0.35, 0.001))

func _set_state(s: int) -> void:
	state = s
	_t = 0.0
	state_changed.emit(S.keys()[s])
