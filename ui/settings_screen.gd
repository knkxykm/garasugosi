extends Control
## 設定画面（設計書 §21, §22, §34）

signal closed

var settings: Node
var logger: Node
var partner := {}
var _confirm: Control
var _about: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.theme()
	add_child(UIStyle.screen_panel())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", int(24.0 + UIStyle.safe_top(get_viewport())))
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 18)
	scroll.add_child(col)
	var head := HBoxContainer.new()
	var back := UIStyle.icon_button("res://assets/icons/back.svg", 56)
	back.modulate = Color(1, 1, 1, 0.8)
	back.pressed.connect(func(): closed.emit())
	head.add_child(back)
	var title := UIStyle.label("設定", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(56, 56)
	head.add_child(sp)
	col.add_child(head)
	col.add_child(UIStyle.hairline())
	col.add_child(_section("触れたとき"))
	col.add_child(_toggle("振動", "手が届いた瞬間に、一度だけ", "vibration"))
	col.add_child(_toggle("効果音", "「こつ」と小さく鳴る（マナーモード中は鳴らない）", "sound"))
	col.add_child(_volume())
	col.add_child(_section("記録"))
	col.add_child(_toggle("触れ合いを記録する", "端末の中にだけ残る。オフにすると、何も書き込まない", "record"))
	var del := Button.new()
	del.text = "すべての記録を削除"
	del.pressed.connect(func(): _confirm.visible = true)
	col.add_child(del)
	col.add_child(_section("このアプリについて"))
	_about = UIStyle.label("硝子越し\n" + "硝子の向こうの%sと、そっと触れ合うための小さな居場所。\n" % String(partner.get("display_name", "パートナー")) + "通信はしない。記録はこの端末の中にだけ残る。\n\n" + _credit_line() + "原案：真宵家\n" + "VRM読み込み：godot-vrm（V-Sekai, MIT License）\n" + "書体：しっぽり明朝（SIL Open Font License 1.1）\n" + "エンジン：Godot Engine（MIT License）", 22, Color(Palette.YUKIKAGE_BLUE, 0.95))
	col.add_child(_about)
	_confirm = _make_confirm()
	add_child(_confirm)
	_confirm.visible = false

func _credit_line() -> String:
	var c := String(partner.get("credit", "")).strip_edges()
	return c + "\n" if c != "" else ""

func _section(text: String) -> Control:
	var v := VBoxContainer.new()
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	v.add_child(gap)
	v.add_child(UIStyle.label(text, 24, Palette.USUFUJI))
	return v

func _toggle(title: String, note: String, key: String) -> Control:
	var row := HBoxContainer.new()
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UIStyle.label(title, 28))
	texts.add_child(UIStyle.label(note, 20, Color(Palette.YUKIKAGE_BLUE, 0.9)))
	row.add_child(texts)
	var t := CheckButton.new()
	t.button_pressed = settings.get(key)
	t.toggled.connect(func(on): settings.set_value(key, on))
	row.add_child(t)
	return row

func _volume() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var l := UIStyle.label("音量", 28)
	l.custom_minimum_size = Vector2(120, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = settings.volume
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 48)
	s.value_changed.connect(func(v): settings.set_value("volume", v))
	row.add_child(s)
	return row

func _make_confirm() -> Control:
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.55)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(center)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.TSUKIYO_KON.darkened(0.35)
	sb.border_color = Color(Palette.YUKIKAGE_BLUE, 0.4)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(36)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	card.add_child(v)
	var msg := UIStyle.label("記録をすべて削除します。\nこの操作は元に戻せません。", 28)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(msg)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 24)
	var cancel := Button.new()
	cancel.text = "キャンセル"
	cancel.pressed.connect(func(): veil.visible = false)
	var ok := Button.new()
	ok.text = "削除"
	ok.add_theme_color_override("font_color", Palette.HOUYOU_SAKURA)
	ok.pressed.connect(func():
		logger.clear_all()
		veil.visible = false)
	btns.add_child(cancel)
	btns.add_child(ok)
	v.add_child(btns)
	return veil
