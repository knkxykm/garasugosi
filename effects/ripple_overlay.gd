extends Control
## 硝子に広がる淡い月光の波紋（設計書 §16）
## 画面＝硝子なので、波紋は3D空間ではなく画面上（2D）に描く。

@export var color := Palette.GEPPAKU          # 指が触れた波紋：月白（げっぱく）色
@export var contact_color := Palette.HOUYOU_SAKURA # 手のひらが届いた波紋：抱擁の桜肌（触れたところだけ少し温かい）
@export var duration := 0.9
@export var max_radius := 46.0

var _ripples: Array = [] # [pos, age, strength]


## strength 1.0＝指が触れた波紋 / 1.6＝手のひらが届いた瞬間（Contact Moment）の波紋
func spawn(pos: Vector2, strength := 1.0) -> void:
	_ripples.append([pos, 0.0, strength])


func _process(delta: float) -> void:
	for r in _ripples:
		r[1] += delta
	_ripples = _ripples.filter(func(r): return r[1] < duration * r[2])
	queue_redraw()


func _draw() -> void:
	for r in _ripples:
		var k: float = r[2]
		var col: Color = contact_color if k > 1.2 else color
		var t: float = r[1] / (duration * k)
		var e: float = 1.0 - pow(1.0 - t, 3.0) # ease-out
		var a: float = (1.0 - t) * (0.85 if k > 1.2 else 0.55)
		var rad: float = max_radius * k
		draw_circle(r[0], rad * 0.35 * (1.0 - t), Color(col, a * 0.5))
		draw_arc(r[0], rad * e, 0, TAU, 64, Color(col, a), 1.5, true)
		draw_arc(r[0], rad * e * 0.62, 0, TAU, 48, Color(col, a * 0.5), 1.0, true)
		if k > 1.2:
			draw_arc(r[0], rad * e * 1.25, 0, TAU, 72, Color(col, a * 0.35), 1.0, true)
