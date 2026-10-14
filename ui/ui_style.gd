class_name UIStyle
## 画面の見た目（月雪の体温パレット × しっぽり明朝）
## パートナーの姿を邪魔しないよう、線は細く、色は淡く、数字は小さく。

const FONT_PATH := "res://assets/fonts/ShipporiMincho-Regular.ttf"

static var _theme: Theme

static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	var font: Font
	if ResourceLoader.exists(FONT_PATH):
		font = load(FONT_PATH)
	else:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Shippori Mincho", "Hiragino Mincho ProN", "YuMincho", "serif"])
		font = system_font
	t.default_font = font
	t.default_font_size = 28
	t.set_color("font_color", "Label", Palette.SHINSETSU_WHITE)
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.border_color = Color(Palette.YUKIKAGE_BLUE, 0.45)
	flat.set_border_width_all(1)
	flat.set_corner_radius_all(14)
	flat.content_margin_left = 24
	flat.content_margin_right = 24
	flat.content_margin_top = 14
	flat.content_margin_bottom = 14
	var hover := flat.duplicate() as StyleBoxFlat
	hover.bg_color = Color(Palette.GEPPAKU, 0.06)
	var pressed := flat.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(Palette.GEPPAKU, 0.12)
	for s in ["normal", "focus", "disabled"]:
		t.set_stylebox(s, "Button", flat)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_color("font_color", "Button", Palette.SHINSETSU_WHITE)
	t.set_color("font_hover_color", "Button", Palette.SHINSETSU_WHITE)
	t.set_color("font_pressed_color", "Button", Palette.SHINSETSU_WHITE)
	var none := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(s, "CheckButton", none)
	t.set_icon("checked", "CheckButton", load("res://assets/icons/toggle_on.svg"))
	t.set_icon("unchecked", "CheckButton", load("res://assets/icons/toggle_off.svg"))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "CheckButton", Palette.SHINSETSU_WHITE)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(Palette.YUKIKAGE_BLUE, 0.3)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = Palette.USUFUJI
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var bar := StyleBoxFlat.new()
	bar.bg_color = Color(Palette.YUKIKAGE_BLUE, 0.25)
	bar.set_corner_radius_all(2)
	t.set_stylebox("grabber", "VScrollBar", bar)
	t.set_stylebox("grabber_highlight", "VScrollBar", bar)
	t.set_stylebox("grabber_pressed", "VScrollBar", bar)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	_theme = t
	return t

static func label(text: String, size := 28, color := Palette.SHINSETSU_WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func icon_button(path: String, size := 64) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = load(path)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(size, size)
	return b

static func hairline() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(Palette.YUKIKAGE_BLUE, 0.18)
	r.custom_minimum_size = Vector2(0, 1)
	return r

static func safe_top(vp: Viewport) -> float:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.y <= 0 or safe.size.y <= 0:
		return 0.0
	return float(safe.position.y) / float(screen.y) * vp.get_visible_rect().size.y

static func screen_panel() -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme()
	var bg := ColorRect.new()
	bg.color = Palette.night_bg()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	return root
