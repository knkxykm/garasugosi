extends Node
## TouchDetector（設計書 §27）
## 指1本だけを追う。二本目以降の指は無視して状態を壊さない（§42）。
## マウスはプロジェクト設定 emulate_touch_from_mouse でタッチとして届く。

signal touch_started(pos: Vector2)
signal touch_moved(pos: Vector2)
signal touch_ended(pos: Vector2, duration_ms: int, kind: String)

const TAP_MAX_MS := 300
const STROKE_MIN_DIST := 40.0
const STROKE_MAX_SPEED := 1500.0

var blocker: Callable
var _finger := -1
var _start_ms := 0
var _start_pos := Vector2.ZERO
var _travel := 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -1:
			if blocker.is_valid() and blocker.call(event.position):
				return
			_finger = event.index
			_start_ms = Time.get_ticks_msec()
			_start_pos = event.position
			_travel = 0.0
			touch_started.emit(event.position)
		elif not event.pressed and event.index == _finger:
			_finish(event.position)
	elif event is InputEventScreenDrag and event.index == _finger:
		_travel += event.relative.length()
		touch_moved.emit(event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _finger != -1:
		_finish(_start_pos)

func _finish(pos: Vector2) -> void:
	var ms := Time.get_ticks_msec() - _start_ms
	var kind := "hold"
	var speed: float = _travel / max(ms / 1000.0, 0.001)
	if _travel >= STROKE_MIN_DIST and speed <= STROKE_MAX_SPEED:
		kind = "stroke"
	elif ms <= TAP_MAX_MS:
		kind = "tap"
	_finger = -1
	touch_ended.emit(pos, ms, kind)
