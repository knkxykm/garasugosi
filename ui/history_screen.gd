extends Control
## 履歴画面「硝子越しの記録」（設計書 §19）
## 文章だけで並べる。回数・連続日数・ランキングは出さない。

signal closed

var logger: Node
var line_book: Node
var partner := {}
var _list: VBoxContainer
var _empty: Label

func _ready() -> void:
	var base := UIStyle.screen_panel()
	add_child(base)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := 24.0 + UIStyle.safe_top(get_viewport())
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", int(top))
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)
	var head := HBoxContainer.new()
	var back := UIStyle.icon_button("res://assets/icons/back.svg", 56)
	back.modulate = Color(1, 1, 1, 0.8)
	back.pressed.connect(func(): closed.emit())
	head.add_child(back)
	var title := UIStyle.label("硝子越しの記録", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(56, 56)
	head.add_child(spacer)
	col.add_child(head)
	col.add_child(UIStyle.hairline())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_empty = UIStyle.label("まだ、なにも残っていません。\n\n触れたときのことが、ここに静かに残ります。", 26, Color(Palette.YUKIKAGE_BLUE, 0.9))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size = Vector2(0, 400)
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if logger:
		logger.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		if c == _empty:
			_list.remove_child(c)
		else:
			c.queue_free()
	var entries: Array = logger.entries() if logger else []
	if entries.is_empty():
		_list.add_child(_empty)
		return
	var last_day := ""
	for i in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[i]
		var ts := String(e.get("timestamp", ""))
		var day := ts.substr(0, 10)
		if day != last_day:
			last_day = day
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 18)
			_list.add_child(gap)
			_list.add_child(UIStyle.label(_day_label(day), 30, Palette.USUFUJI))
			_list.add_child(UIStyle.hairline())
		_list.add_child(_entry_row(e))

func _entry_row(e: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 8)
	box.add_child(pad)
	var row := HBoxContainer.new()
	var time := UIStyle.label(String(e.get("timestamp", "")).substr(11, 5), 24, Palette.YUKIKAGE_BLUE)
	time.custom_minimum_size = Vector2(96, 0)
	row.add_child(time)
	var what := UIStyle.label(_describe(e), 28)
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(what)
	box.add_child(row)
	var sub := HBoxContainer.new()
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(96, 0)
	sub.add_child(indent)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	info.add_child(UIStyle.label("%.1f秒" % (float(e.get("duration_ms", 0)) / 1000.0), 24, Palette.YUKIKAGE_BLUE))
	var line: String = line_book.text_of(String(e.get("line_id", ""))) if line_book else ""
	if line != "":
		info.add_child(UIStyle.label("「%s」" % line, 26, Palette.GEPPAKU))
	sub.add_child(info)
	box.add_child(sub)
	return box

func _describe(e: Dictionary) -> String:
	var who: String = String(partner.get("display_name", "パートナー"))
	var area := String(e.get("area", ""))
	var kind := String(e.get("interaction", ""))
	match [area, kind]:
		["hand", "hold"]:
			return "硝子越しに、手を合わせた"
		["head", "stroke"]:
			return "%sの頭を撫でた" % who
		["face", _]:
			return "%sの頬に触れた" % who
		_:
			return "硝子越しに、触れた"

func _day_label(day: String) -> String:
	var p := day.split("-")
	if p.size() < 3:
		return day
	var today := Time.get_date_string_from_system()
	var s := "%d月%d日" % [int(p[1]), int(p[2])]
	return s + "　今日" if day == today else s
