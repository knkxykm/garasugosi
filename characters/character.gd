extends Node3D
## Character（設計書 §27 CharacterAnimator の最小版）
## - T字立ちから腕を下ろした待機姿勢にする
## - 呼吸（胸のわずかな上下）と、ランダムな瞬き
## - notice()：少し遅れて、目→首→頭の順に触れた点を向く（NOTICE）
## - release()：ゆっくり正面へ戻る
## - set_reach()：硝子へ手を伸ばす（ArmReach によるIK。重みは ContactController が決める）
## 時間や角度の値は characters/partner/profile.json（§29）から読む（main.gd が読んで setup() に渡す）。
## 特定のモデルに依存しないよう、骨は VRM の人型ボーン名（Hips, Head, RightUpperArm …）でだけ探す。

const ArmReach := preload("res://characters/arm_reach.gd")

var skeleton: Skeleton3D
var profile := {
	"notice_delay": 0.15, "eye_follow": 0.08, "head_follow": 0.35, "head_return": 0.9,
	"eye_max_deg": 10.0, "head_max_deg": 18.0, "arm_down_deg": 72.0,
	"breath_period": 4.2, "blink_interval_min": 2.5, "blink_interval_max": 6.0,
	"lean_deg": 7.0, "touch_with": "fingertip"
}

var arms := {}               # "Right"/"Left" -> ArmReach
var _reach_side := ""
var _reach_target := Vector3.ZERO   # ワールド座標
var _reach_weight := 0.0
var _reach_reached := Vector3.ZERO  # 実際に手を当てている点（届かないときは指より手前）

var _bones := {}     # name -> index
var _rest := {}      # index -> 初期ローカル回転
var _target_dir := Vector3.ZERO   # 触れた点への向き（ゼロなら正面）
var _look_head := Quaternion.IDENTITY
var _look_eye := Quaternion.IDENTITY
var _notice_timer := -1.0
var _pending_point := Vector3.ZERO
var _t := 0.0

# 瞬き：VRMの "blink" 表情を、ブレンドシェイプへ直接 0〜1 で掛ける
var _blink_shapes: Array = []  # [MeshInstance3D, shape_index, full_value]
var _blink_timer := 2.0
var _blink_t := -1.0
const BLINK_CLOSE := 0.06
const BLINK_OPEN := 0.12


func setup(vrm: Node3D, prof: Dictionary = {}) -> void:
	profile.merge(prof, true)
	if _vrm_spec(vrm).begins_with("1"):
		_fix_mtoon_shading(vrm)
	skeleton = vrm.find_children("*", "Skeleton3D", true, false)[0]
	for n in ["Spine", "Neck", "Head", "LeftEye", "RightEye", "UpperChest", "Chest"]:
		_bones[n] = skeleton.find_bone(n)
	if _bones["UpperChest"] == -1:
		_bones["UpperChest"] = _bones["Chest"]
	for side in ["Right", "Left"]:
		arms[side] = ArmReach.new(skeleton, side)
	_relax_arms()
	for side in arms:
		arms[side].capture_idle()
		arms[side].touch_with = profile.touch_with
	for n in ["Spine", "Neck", "Head", "LeftEye", "RightEye", "UpperChest"]:
		var i: int = _bones[n]
		if i != -1:
			_rest[i] = skeleton.get_bone_pose_rotation(i)
	var anim: AnimationPlayer = vrm.find_child("AnimationPlayer", true, false)
	if anim:
		_collect_blink(vrm, anim)


## VRM 1.0 のモデルだけに掛ける補正。
## godot-vrm は VRM1.0 の shadingShift / shadingToony を、そのまま旧MToon(0.x)シェーダーへ渡している。
## 両者は式が違うため、顔（shift 0.71）がほぼ全面「陰」になり、ピンクの斑が出ていた。
## 1.0 の式 linearstep(-1+T1, 1-T1, NdotL+S1) と一致するよう 0.x の値へ換算する：
##   S0 = -1 + T1 - S1
##   T0 = (T1 + S1) / (1 - S0)
func _fix_mtoon_shading(vrm: Node3D) -> void:
	for m in vrm.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as ShaderMaterial
			if mat == null or mat.get_shader_parameter("_ShadeShift") == null or mat.has_meta("mtoon10_fixed"):
				continue
			var s1: float = mat.get_shader_parameter("_ShadeShift")
			var t1: float = mat.get_shader_parameter("_ShadeToony")
			var s0: float = clamp(-1.0 + t1 - s1, -1.0, 1.0)
			var t0: float = clamp((t1 + s1) / max(1.0 - s0, 0.0001), 0.0, 1.0)
			mat.set_shader_parameter("_ShadeShift", s0)
			mat.set_shader_parameter("_ShadeToony", t0)
			mat.set_meta("mtoon10_fixed", true)


## VRM の版（"0.0" / "1.0"）。分からなければ ""
static func _vrm_spec(vrm: Node3D) -> String:
	var meta = vrm.get("vrm_meta")
	if meta != null and meta.get("spec_version") != null:
		return String(meta.spec_version)
	return ""


## 頭のボーンのワールド座標（画面の構図を決めるのに使う）
func head_position() -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(_bones["Head"]).origin


## 肩（上腕の付け根）のワールド座標と、腕を伸ばしきったときの長さ
func shoulder_position() -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("RightUpperArm")).origin


func reach_length() -> float:
	return min(arms["Right"].reach_length(), arms["Left"].reach_length()) * skeleton.global_transform.basis.get_scale().x


func _collect_blink(vrm: Node3D, anim: AnimationPlayer) -> void:
	if not anim.has_animation("blink"):
		return
	var a := anim.get_animation("blink")
	var base := anim.get_node(anim.root_node)
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_BLEND_SHAPE or a.track_get_key_count(t) == 0:
			continue
		var path := a.track_get_path(t)
		var mesh := base.get_node_or_null(NodePath(path.get_concatenated_names())) as MeshInstance3D
		if mesh == null:
			continue
		var idx := mesh.find_blend_shape_by_name(path.get_concatenated_subnames())
		if idx != -1:
			_blink_shapes.append([mesh, idx, float(a.track_get_key_value(t, a.track_get_key_count(t) - 1))])


## 腕をワールドZ軸まわりに回して下ろす。ボーンの軸向きに依存しないよう、グローバル姿勢で計算する。
func _relax_arms() -> void:
	var a: float = deg_to_rad(profile.arm_down_deg)
	_rotate_bone_global("RightUpperArm", Basis(Vector3.BACK, a))
	_rotate_bone_global("LeftUpperArm", Basis(Vector3.BACK, -a))
	_rotate_bone_global("RightLowerArm", Basis(Vector3.UP, deg_to_rad(-12)))
	_rotate_bone_global("LeftLowerArm", Basis(Vector3.UP, deg_to_rad(12)))


func _rotate_bone_global(bone_name: String, rot: Basis) -> void:
	var i := skeleton.find_bone(bone_name)
	if i == -1:
		return
	var parent := skeleton.get_bone_parent(i)
	var parent_g: Transform3D = skeleton.get_bone_global_pose(parent) if parent != -1 else Transform3D()
	var g := skeleton.get_bone_global_pose(i)
	g.basis = rot * g.basis
	var local := parent_g.affine_inverse() * g
	skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())


func notice(world_point: Vector3) -> void:
	_pending_point = world_point
	if _target_dir == Vector3.ZERO and _notice_timer < 0.0:
		_notice_timer = profile.notice_delay # 最初の一回だけ「間」を置く
	elif _notice_timer < 0.0:
		_set_target(world_point)


## 手を伸ばす：side は "Right"/"Left"、target は手のひらを当てる点（ワールド）、weight 0〜1
func set_reach(side: String, target: Vector3, weight: float) -> void:
	if side != _reach_side and _reach_side != "":
		arms[_reach_side].apply(Vector3.ZERO, Vector3.BACK, 0.0)
	_reach_side = side
	_reach_target = target
	_reach_weight = clamp(weight, 0.0, 1.0)



## 硝子に合わせている場所（指先 or 手のひら）のワールド座標
func palm_world(side: String) -> Vector3:
	return skeleton.global_transform * (arms[side].palm_position() as Vector3)


func release() -> void:
	_notice_timer = -1.0
	_target_dir = Vector3.ZERO


func _set_target(world_point: Vector3) -> void:
	var head_pos: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(_bones["Head"])).origin
	_target_dir = (world_point - head_pos).normalized()


func _goal(max_deg: float) -> Quaternion:
	if _target_dir == Vector3.ZERO:
		return Quaternion.IDENTITY
	var fwd: Vector3 = (skeleton.global_transform.basis * Vector3.BACK).normalized()
	var q := Quaternion(fwd, _target_dir)
	if q.get_angle() < 0.001:
		return Quaternion.IDENTITY
	return Quaternion(q.get_axis().normalized(), min(q.get_angle(), deg_to_rad(max_deg)))


func _smooth(cur: Quaternion, goal: Quaternion, time: float, delta: float) -> Quaternion:
	return cur.slerp(goal, 1.0 - exp(-delta / max(time * 0.35, 0.01)))


func _process(delta: float) -> void:
	if skeleton == null:
		return
	_t += delta

	if _notice_timer >= 0.0:
		_notice_timer -= delta
		if _notice_timer < 0.0:
			_set_target(_pending_point)

	var returning := _target_dir == Vector3.ZERO
	var head_time: float = profile.head_return if returning else profile.head_follow
	var eye_time: float = profile.head_return if returning else profile.eye_follow
	_look_head = _smooth(_look_head, _goal(profile.head_max_deg), head_time, delta)
	_look_eye = _smooth(_look_eye, _goal(profile.eye_max_deg), eye_time, delta)

	# 手を伸ばすときは、背中から少しだけ前へ乗り出す
	var e_w := _ease(_reach_weight)
	_apply_global_rot("Spine", Quaternion(Vector3.RIGHT, deg_to_rad(profile.lean_deg) * e_w))

	# 首3割・頭7割。目は頭の向きに加えて少しだけ先に動く
	_apply_global_rot("Neck", Quaternion.IDENTITY.slerp(_look_head, 0.3))
	_apply_global_rot("Head", Quaternion.IDENTITY.slerp(_look_head, 0.7))
	_apply_global_rot("LeftEye", _look_eye)
	_apply_global_rot("RightEye", _look_eye)

	# 呼吸
	var breath: float = sin(_t * TAU / profile.breath_period) * deg_to_rad(0.8)
	var chest: int = _bones["UpperChest"]
	skeleton.set_bone_pose_rotation(chest, _rest[chest] * Quaternion(Vector3.RIGHT, breath))

	_update_blink(delta)

	# 腕（親の胸・肩が決まった後に解く）
	if _reach_side != "":
		var inv := skeleton.global_transform.affine_inverse()
		var cam := get_viewport().get_camera_3d()
		var target_sk := inv * _reach_target
		var toward_sk := (inv * cam.global_position) - target_sk
		# 腕が届かない所に触れられたら、硝子の上で指にいちばん近い、届く点へ（手が硝子の手前で止まらない）
		target_sk = arms[_reach_side].clamp_to_reach(target_sk, toward_sk)
		_reach_reached = skeleton.global_transform * target_sk
		arms[_reach_side].apply(target_sk, toward_sk, e_w)
		if _reach_weight <= 0.0:
			_reach_side = ""


static func _ease(x: float) -> float:
	# ease-in-out（ゆっくり出て、ゆっくり届く）
	return x * x * (3.0 - 2.0 * x)


## ワールド空間での追加回転 rot を、そのボーンのローカル回転へ変換して rest に掛ける
func _apply_global_rot(bone_name: String, rot: Quaternion) -> void:
	var i: int = _bones.get(bone_name, -1)
	if i == -1:
		return
	var parent := skeleton.get_bone_parent(i)
	var parent_rot: Quaternion = skeleton.global_transform.basis.get_rotation_quaternion() \
		* skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	# 親（頭など）がすでに回っている分を差し引いてから掛ける
	var local_rot: Quaternion = parent_rot.inverse() * rot * parent_rot
	if bone_name.ends_with("Eye"):
		# 目の親は頭。頭がすでに _look_head 分回っているので、その差分だけ回す
		local_rot = parent_rot.inverse() * (rot * _look_head.inverse()) * parent_rot
	skeleton.set_bone_pose_rotation(i, local_rot * _rest[i])


func _update_blink(delta: float) -> void:
	if _blink_shapes.is_empty():
		return
	var w := 0.0
	if _blink_t >= 0.0:
		_blink_t += delta
		if _blink_t < BLINK_CLOSE:
			w = _blink_t / BLINK_CLOSE
		elif _blink_t < BLINK_CLOSE + BLINK_OPEN:
			w = 1.0 - (_blink_t - BLINK_CLOSE) / BLINK_OPEN
		else:
			_blink_t = -1.0
	else:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_t = 0.0
			_blink_timer = randf_range(profile.blink_interval_min, profile.blink_interval_max)
	for s in _blink_shapes:
		(s[0] as MeshInstance3D).set_blend_shape_value(s[1], s[2] * w)


## 外部から瞬きを1回させる（NOTICE時など）
func blink_now() -> void:
	if _blink_t < 0.0:
		_blink_t = 0.0
