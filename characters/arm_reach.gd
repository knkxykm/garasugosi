extends RefCounted
## 片腕の「硝子へ手を伸ばす」IK（設計書 §37〜§39）
## 肩・肘・手首の2ボーンIKを解析的に解き、手のひらを硝子へ向ける。
## 待機姿勢（idle）とIK姿勢を weight で混ぜるので、0→1 で伸ばし、1→0 で戻す。
## 座標はすべて Skeleton3D のローカル空間で扱う。

var skeleton: Skeleton3D
var side: String          # "Right" / "Left"
var _sh := -1             # Shoulder（鎖骨）
var _ua := -1             # UpperArm
var _la := -1             # LowerArm
var _hd := -1             # Hand
var _len_a := 0.0         # 肩→肘
var _len_b := 0.0         # 肘→手首
var _palm_off := 0.0      # 手首→手のひら中心
var _tip_off := 0.0       # 手首→中指の指先
var touch_with := "fingertip"
var _idle := {}
var _rest_frame: Basis
var _sign := 1.0
var _fingers := {}
var _middle_prox := -1
const FINGER_CLOSE := 0.6
const PALM_THICK := 0.018
const TWIST_SHARE := 0.6
const SHOULDER_RAISE := 9.0
const ARC := 0.12

func _init(sk: Skeleton3D, side_name: String) -> void:
	skeleton = sk
	side = side_name
	_sign = 1.0 if side == "Right" else -1.0
	_sh = sk.find_bone(side + "Shoulder")
	_ua = sk.find_bone(side + "UpperArm")
	_la = sk.find_bone(side + "LowerArm")
	_hd = sk.find_bone(side + "Hand")
	var mid := sk.find_bone(side + "MiddleProximal")
	var p_ua := sk.get_bone_global_rest(_ua).origin
	var p_la := sk.get_bone_global_rest(_la).origin
	var p_hd := sk.get_bone_global_rest(_hd).origin
	var hand_len := p_la.distance_to(p_hd) * 0.4
	var p_mid := sk.get_bone_global_rest(mid).origin if mid != -1 else p_hd + (p_hd - p_la).normalized() * hand_len * 0.5
	_middle_prox = mid
	for f in ["Index", "Ring", "Little"]:
		_fingers[f] = [sk.find_bone(side + f + "Proximal"), sk.find_bone(side + f + "Intermediate")]
	_len_a = p_ua.distance_to(p_la)
	_len_b = p_la.distance_to(p_hd)
	_palm_off = p_hd.distance_to(p_mid) * 0.55
	var mid_dist := sk.find_bone(side + "MiddleDistal")
	var p_dist := sk.get_bone_global_rest(mid_dist).origin if mid_dist != -1 else p_hd + (p_mid - p_hd).normalized() * hand_len * 0.85
	var mid_int := sk.find_bone(side + "MiddleIntermediate")
	var seg: float = p_dist.distance_to(sk.get_bone_global_rest(mid_int).origin) if mid_int != -1 else 0.02
	_tip_off = p_hd.distance_to(p_dist) + seg * 0.9
	_rest_frame = _frame((p_mid - p_hd).normalized(), Vector3.DOWN)

func capture_idle() -> void:
	for b in [_sh, _ua, _la, _hd]:
		if b != -1:
			_idle[b] = skeleton.get_bone_pose_rotation(b)
	for f in _fingers:
		var b: int = _fingers[f][0]
		if b != -1:
			_idle[b] = skeleton.get_bone_pose_rotation(b)

func arm_length() -> float:
	return _len_a + _len_b

func contact_offset() -> float:
	return _contact_off()

func can_reach(target_sk: Vector3) -> bool:
	var s := skeleton.get_bone_global_pose(_ua).origin
	var low: float = clamp((s.y - target_sk.y) / 0.25, 0.0, 1.0)
	var finger := Basis(Vector3.BACK, deg_to_rad(lerp(10.0, -28.0, low)) * _sign) * Vector3.UP
	var wrist := target_sk - finger * _contact_off()
	return s.distance_to(wrist) <= (_len_a + _len_b) * 0.97

func clamp_to_reach(target_sk: Vector3, toward_sk: Vector3) -> Vector3:
	if can_reach(target_sk):
		return target_sk
	var n := toward_sk.normalized()
	var s := skeleton.get_bone_global_pose(_ua).origin + Vector3.UP * _contact_off()
	var anchor := s - n * n.dot(s - target_sk)
	if not can_reach(anchor):
		return anchor
	var lo := 0.0
	var hi := 1.0
	for i in 14:
		var mid := (lo + hi) * 0.5
		if can_reach(anchor.lerp(target_sk, mid)):
			lo = mid
		else:
			hi = mid
	return anchor.lerp(target_sk, lo)

func reach_length() -> float:
	return _len_a + _len_b + _contact_off()

func _contact_off() -> float:
	return _tip_off if touch_with == "fingertip" else _palm_off

func _thick() -> float:
	return PALM_THICK * (0.5 if touch_with == "fingertip" else 1.0)

static func _frame(finger: Vector3, palm: Vector3) -> Basis:
	var y := finger.normalized()
	var z := (palm - y * palm.dot(y)).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)

func apply(target_sk: Vector3, toward_sk: Vector3, weight: float) -> void:
	for b in _idle:
		skeleton.set_bone_pose_rotation(b, _idle[b])
	if weight <= 0.001:
		return
	var ik := {}
	if _sh != -1:
		var sh_g := skeleton.get_bone_global_pose(_sh).basis.get_rotation_quaternion()
		_set_global_rot(_sh, Quaternion(Vector3.BACK, -deg_to_rad(SHOULDER_RAISE) * _sign * weight) * sh_g)
		ik[_sh] = skeleton.get_bone_pose_rotation(_sh)
	var rest_hq := skeleton.get_bone_global_rest(_hd).basis.get_rotation_quaternion()
	var idle_hq := skeleton.get_bone_global_pose(_hd).basis.get_rotation_quaternion()
	var start := palm_position()
	var s0 := skeleton.get_bone_global_pose(_ua).origin
	var low: float = clamp((s0.y - target_sk.y) / 0.25, 0.0, 1.0)
	var tilt_deg: float = lerp(10.0, -28.0, low)
	var finger_t := Basis(Vector3.BACK, deg_to_rad(tilt_deg) * _sign) * Vector3.UP
	var palm_t := toward_sk.normalized()
	var hand_frame := _frame(finger_t, palm_t)
	finger_t = hand_frame.y
	palm_t = hand_frame.z
	var r := hand_frame * _rest_frame.inverse()
	var hand_target_q := (r * skeleton.get_bone_global_rest(_hd).basis).get_rotation_quaternion()
	var hand_g := idle_hq.slerp(hand_target_q, weight)
	var hb := Basis(hand_g * rest_hq.inverse())
	var finger_b := (hb * _rest_frame.y).normalized()
	var palm_b := (hb * _rest_frame.z).normalized()
	var path := start.lerp(target_sk, weight) + palm_t * sin(PI * weight) * ARC
	var wrist_t := path - finger_b * _contact_off() - palm_b * _thick()
	var s := skeleton.get_bone_global_pose(_ua).origin
	var to_t := wrist_t - s
	var d: float = clamp(to_t.length(), 0.05, (_len_a + _len_b) * 0.995)
	var n := to_t.normalized()
	var cos_a: float = clamp((_len_a * _len_a + d * d - _len_b * _len_b) / (2.0 * _len_a * d), -1.0, 1.0)
	var sin_a := sqrt(1.0 - cos_a * cos_a)
	var pole := Vector3(-0.35 * _sign, -1.0, -0.25).normalized()
	var p := (pole - n * pole.dot(n)).normalized()
	var elbow := s + n * _len_a * cos_a + p * _len_a * sin_a
	var wrist := s + n * d
	var e0 := skeleton.get_bone_global_pose(_la).origin
	_rotate_toward(_ua, e0 - s, elbow - s)
	ik[_ua] = skeleton.get_bone_pose_rotation(_ua)
	var e1 := skeleton.get_bone_global_pose(_la).origin
	var w1 := skeleton.get_bone_global_pose(_hd).origin
	_rotate_toward(_la, w1 - e1, wrist - e1)
	var axis := (wrist - e1).normalized()
	var cur_h := skeleton.get_bone_global_pose(_hd).basis.get_rotation_quaternion()
	var delta := (hand_g * cur_h.inverse()).normalized()
	var twist := _twist(delta, axis)
	var la_g := skeleton.get_bone_global_pose(_la).basis.get_rotation_quaternion()
	_set_global_rot(_la, Quaternion.IDENTITY.slerp(twist, TWIST_SHARE) * la_g)
	ik[_la] = skeleton.get_bone_pose_rotation(_la)
	_set_global_rot(_hd, hand_g)
	ik[_hd] = skeleton.get_bone_pose_rotation(_hd)
	var mid_dir := _bone_dir(_middle_prox, skeleton.get_bone_children(_middle_prox)) if _middle_prox != -1 else finger_b
	for f in _fingers:
		var b: int = _fingers[f][0]
		var c: int = _fingers[f][1]
		if b == -1 or c == -1:
			continue
		var cur := skeleton.get_bone_global_pose(c).origin - skeleton.get_bone_global_pose(b).origin
		_rotate_toward(b, cur, cur.normalized().slerp(mid_dir, FINGER_CLOSE * weight))
		ik[b] = skeleton.get_bone_pose_rotation(b)
	var blend: float = clamp(weight * 4.0, 0.0, 1.0)
	for b in ik:
		skeleton.set_bone_pose_rotation(b, (_idle[b] as Quaternion).slerp(ik[b], blend))

func palm_position() -> Vector3:
	var g := skeleton.get_bone_global_pose(_hd)
	var r := g.basis.get_rotation_quaternion() * skeleton.get_bone_global_rest(_hd).basis.get_rotation_quaternion().inverse()
	var finger := (Basis(r) * _rest_frame.y).normalized()
	var palm := (Basis(r) * _rest_frame.z).normalized()
	return g.origin + finger * _contact_off() + palm * _thick()

static func _twist(q: Quaternion, axis: Vector3) -> Quaternion:
	var v := Vector3(q.x, q.y, q.z)
	var pr := axis * v.dot(axis)
	var t := Quaternion(pr.x, pr.y, pr.z, q.w)
	if t.length_squared() < 1e-8:
		return Quaternion.IDENTITY
	return t.normalized()

func _bone_dir(bone: int, children: PackedInt32Array) -> Vector3:
	if children.is_empty():
		return Vector3.UP
	return (skeleton.get_bone_global_pose(children[0]).origin - skeleton.get_bone_global_pose(bone).origin).normalized()

func _rotate_toward(bone: int, from_dir: Vector3, to_dir: Vector3) -> void:
	if from_dir.length() < 1e-5 or to_dir.length() < 1e-5:
		return
	var q := Quaternion(from_dir.normalized(), to_dir.normalized())
	var g := skeleton.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	_set_global_rot(bone, q * g)

func _set_global_rot(bone: int, global_q: Quaternion) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var pq := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent != -1 else Quaternion.IDENTITY
	skeleton.set_bone_pose_rotation(bone, (pq.inverse() * global_q).normalized())
