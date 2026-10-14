extends Node3D
## 硝子越し — 双方向接触のしくみ
## 画面（硝子）に触れると、硝子の向こうのパートナーが気づき、手を伸ばし、指先が硝子越しに重なる。
## Phase 0〜6：パートナーの表示・硝子へのタッチ・視線・手を伸ばす・Contact Moment・秒数・余韻
## Phase 7〜8：触れ合いの記録（端末内）・語録・履歴画面・設定画面・「こつ」の効果音

const PARTNER_DIR := "res://characters/partner/"
const MOONLIGHT_DIR := Vector3(-0.3, -0.35, -1.0)
const ICON_ALPHA := 0.5
const ICON_ALPHA_TOUCH := 0.12
const CAMERA_PITCH_DEG := -2.3

const HistoryScreen := preload("res://ui/history_screen.gd")
const SettingsScreen := preload("res://ui/settings_screen.gd")

@onready var camera: Camera3D = $Camera
@onready var character: Node3D = $Character
@onready var ripple: Control = $UI/Ripple
@onready var debug_label: Label = $UI/Debug
@onready var marker: MeshInstance3D = $GlassMarker
@onready var touch: Node = $InteractionSystem/TouchDetector
@onready var contact: Node = $InteractionSystem/ContactController
@onready var haptics: Node = $InteractionSystem/HapticController
@onready var sfx: Node = $InteractionSystem/SfxController
@onready var logger: Node = $Data/InteractionLogger
@onready var line_book: Node = $Data/LineBook
@onready var settings: Node = $Systems/AppSettings
@onready var ui: CanvasLayer = $UI

var show_debug := not OS.has_feature("mobile")
var partner := {}
var glass_distance := 1.14
var _state := "IDLE"
var _last := "触れてみてください。"
var _icons: Control
var _screen: Control
var _icon_tween: Tween

func _ready() -> void:
	$WorldEnvironment.environment.background_color = Palette.night_bg()
	$Moonlight.global_transform = Transform3D(Basis.looking_at(MOONLIGHT_DIR.normalized(), Vector3.UP), Vector3.ZERO)
	partner = _load_json(PARTNER_DIR + "profile.json")
	var model_path := String(partner.get("model", PARTNER_DIR + "model/partner.vrm"))
	if not ResourceLoader.exists(model_path):
		_show_missing_model(model_path)
		return
	var vrm: Node3D = load(model_path).instantiate()
	character.add_child(vrm)
	character.setup(vrm, partner)
	_frame_partner()
	line_book.load_from(PARTNER_DIR + "lines.json")
	contact.configure(character.profile)
	contact.contact_started.connect(_on_contact_started)
	contact.contact_ended.connect(_on_contact_ended)
	contact.state_changed.connect(_on_state_changed)
	touch.blocker = _is_ui_at
	touch.touch_started.connect(_on_touch_started)
	touch.touch_moved.connect(_on_touch_moved)
	touch.touch_ended.connect(_on_touch_ended)
	settings.changed.connect(_apply_settings)
	_apply_settings()
	_build_icons()
	marker.visible = false
	_refresh_debug()

func _frame_partner() -> void:
	var head: Vector3 = character.head_position()
	var shoulder: Vector3 = character.shoulder_position()
	var top: float = _model_top(character)
	var span: float = max(top - shoulder.y, 0.05)
	var view_h: float = span * float(partner.get("frame_scale", 2.2))
	var frame_top: float = top + view_h * float(partner.get("frame_top_margin", 0.06))
	var dist: float = view_h * 0.5 / tan(deg_to_rad(camera.fov * 0.5))
	var cam_pos := Vector3(0.0, frame_top - view_h * 0.5, head.z + dist)
	camera.global_transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(CAMERA_PITCH_DEG)), cam_pos)
	var glass_z: float = shoulder.z + character.reach_length() * float(partner.get("glass_reach", 0.7))
	glass_distance = max(cam_pos.z - glass_z, camera.near * 2.0)

static func _model_top(root: Node) -> float:
	var top := -INF
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		top = max(top, box.end.y)
	return top

func _show_missing_model(path: String) -> void:
	var l := UIStyle.label("パートナーのモデルが見つかりません。\n\n%s\nに VRM ファイルを置いて、\nもう一度開いてください。\n\n（場所は characters/partner/profile.json の model で変えられます）" % path.trim_prefix("res://"), 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.offset_left = 40
	l.offset_right = -40
	ui.add_child(l)
	debug_label.visible = false
	set_process_unhandled_key_input(false)
	push_warning("Partner model not found: " + path)

static func _load_json(path: String) -> Dictionary:
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			return data
	return {}

func _apply_settings() -> void:
	haptics.enabled = settings.vibration
	sfx.enabled = settings.sound
	sfx.volume = settings.volume
	logger.enabled = settings.record

func screen_to_glass(screen_pos: Vector2) -> Vector3:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var forward := -camera.global_transform.basis.z
	var plane := Plane(forward, camera.global_position + forward * glass_distance)
	var hit = plane.intersects_ray(origin, dir)
	return hit if hit != null else origin + dir * glass_distance

func _on_touch_started(pos: Vector2) -> void:
	var p := screen_to_glass(pos)
	marker.global_position = p
	marker.visible = show_debug
	ripple.spawn(pos)
	character.notice(p)
	character.blink_now()
	contact.on_touch_started(p)
	_last = "touch %s  glass %s" % [pos.round(), _v(p)]
	_refresh_debug()

func _on_touch_moved(pos: Vector2) -> void:
	var p := screen_to_glass(pos)
	marker.global_position = p
	character.notice(p)
	contact.on_touch_moved(p)

func _on_touch_ended(_pos: Vector2, duration_ms: int, kind: String) -> void:
	marker.visible = false
	character.release()
	contact.on_touch_ended()
	if kind != "hold" or contact.state == contact.S.IDLE:
		_last = "%s  %.2f秒" % [kind, duration_ms / 1000.0]
		_refresh_debug()

func _on_contact_started(screen_pos: Vector2) -> void:
	ripple.spawn(screen_pos, 1.6)
	sfx.contact()
	_last = "こつ。"
	_refresh_debug()

func _on_contact_ended(duration_ms: int) -> void:
	var line_id: String = line_book.pick("hand", "hold")
	logger.add(String(partner.get("id", "partner")), "human", "hold", "hand", duration_ms, line_id)
	_last = "硝子越しに、手を合わせた  %.1f秒" % (duration_ms / 1000.0)
	_refresh_debug()

func _on_state_changed(st: String) -> void:
	_state = st
	_refresh_debug()
	if _icons == null:
		return
	var a := ICON_ALPHA if st == "IDLE" or st == "NOTICE" else ICON_ALPHA_TOUCH
	if _icon_tween:
		_icon_tween.kill()
	_icon_tween = create_tween()
	_icon_tween.tween_property(_icons, "modulate:a", a, 0.4)

func _build_icons() -> void:
	_icons = HBoxContainer.new()
	_icons.add_theme_constant_override("separation", 18)
	_icons.anchor_left = 1.0
	_icons.anchor_right = 1.0
	_icons.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_icons.offset_right = -28
	_icons.offset_top = 28 + UIStyle.safe_top(get_viewport())
	_icons.modulate.a = ICON_ALPHA
	var rec := UIStyle.icon_button("res://assets/icons/record.svg", 60)
	rec.tooltip_text = "記録"
	rec.pressed.connect(func(): _open(HistoryScreen))
	var st := UIStyle.icon_button("res://assets/icons/settings.svg", 60)
	st.tooltip_text = "設定"
	st.pressed.connect(func(): _open(SettingsScreen))
	_icons.add_child(rec)
	_icons.add_child(st)
	ui.add_child(_icons)

func _open(script: Script) -> void:
	if _screen:
		return
	contact.cancel()
	var s: Control = script.new()
	if "logger" in s:
		s.logger = logger
	if "line_book" in s:
		s.line_book = line_book
	if "settings" in s:
		s.settings = settings
	if "partner" in s:
		s.partner = partner
	s.modulate.a = 0.0
	s.closed.connect(_close)
	ui.add_child(s)
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen = s
	_icons.visible = false
	debug_label.visible = false
	create_tween().tween_property(s, "modulate:a", 1.0, 0.25)

func _close() -> void:
	if not _screen:
		return
	var s := _screen
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		s.queue_free()
		_screen = null
		_icons.visible = true
		_refresh_debug())

func _is_ui_at(pos: Vector2) -> bool:
	if _screen:
		return true
	return _icons != null and _icons.visible and _icons.get_global_rect().grow(16).has_point(pos)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _screen:
		_close()

func _refresh_debug() -> void:
	if debug_label == null:
		return
	debug_label.visible = show_debug and _screen == null
	debug_label.text = "%s\n[%s]" % [_last, _state]

func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		show_debug = not show_debug
		_refresh_debug()
