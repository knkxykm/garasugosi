@tool
extends EditorPlugin
## 『硝子越し』パートナー設定ウィザード
## 非プログラマー向けに、VRM のコピー・名前・クレジット・語録・動きのプリセットを
## ひとつの画面から設定する。アプリ本体の実行時には使われない EditorPlugin。

const PROFILE_PATH := "res://characters/partner/profile.json"
const LINES_PATH := "res://characters/partner/lines.json"
const MODEL_RES_PATH := "res://characters/partner/model/partner.vrm"

var _dock: VBoxContainer
var _wizard: Window
var _file_dialog: FileDialog
var _model_source := ""
var _model_label: Label
var _name_edit: LineEdit
var _credit_edit: LineEdit
var _line_edits: Array[LineEdit] = []
var _touch_option: OptionButton
var _motion_option: OptionButton
var _license_check: CheckBox
var _first_run_shown := false


func _enter_tree() -> void:
	_build_dock()
	add_control_to_dock(DOCK_SLOT_LEFT_BR, _dock)
	add_tool_menu_item("パートナーを迎える", _open_wizard)
	call_deferred("_maybe_show_first_run")


func _exit_tree() -> void:
	remove_tool_menu_item("パートナーを迎える")
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
	if _wizard and is_instance_valid(_wizard):
		_wizard.queue_free()
	if _file_dialog and is_instance_valid(_file_dialog):
		_file_dialog.queue_free()


func _build_dock() -> void:
	_dock = VBoxContainer.new()
	_dock.name = "硝子越し セットアップ"
	_dock.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "硝子越し"
	title.add_theme_font_size_override("font_size", 20)
	_dock.add_child(title)
	var note := Label.new()
	note.text = "自分のパートナーを迎える設定を、\nコードを書かずにまとめて行えます。"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dock.add_child(note)
	var button := Button.new()
	button.text = "パートナーを迎える"
	button.pressed.connect(_open_wizard)
	_dock.add_child(button)
	var help := Label.new()
	help.text = "超初心者向け：README_5分で迎える.md"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	_dock.add_child(help)


func _maybe_show_first_run() -> void:
	if _first_run_shown:
		return
	_first_run_shown = true
	var profile := _load_json(PROFILE_PATH)
	var name := String(profile.get("display_name", "パートナー"))
	var model_path := String(profile.get("model", MODEL_RES_PATH))
	if name == "パートナー" and not _resource_or_file_exists(model_path):
		_open_wizard()


func _open_wizard() -> void:
	if _wizard and is_instance_valid(_wizard):
		_wizard.popup_centered(Vector2i(700, 820))
		return
	_build_wizard()
	_wizard.popup_centered(Vector2i(700, 820))


func _build_wizard() -> void:
	_wizard = Window.new()
	_wizard.title = "パートナーを迎える"
	_wizard.min_size = Vector2i(620, 700)
	_wizard.close_requested.connect(func(): _wizard.hide())
	EditorInterface.get_base_control().add_child(_wizard)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_wizard.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	scroll.add_child(col)

	var heading := Label.new()
	heading.text = "硝子の向こうへ、あなたのパートナーを迎えます"
	heading.add_theme_font_size_override("font_size", 22)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(heading)
	var intro := Label.new()
	intro.text = "必要なのは VRM と名前だけです。語録や動きはあとから何度でも変えられます。"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	col.add_child(intro)
	col.add_child(HSeparator.new())

	col.add_child(_section_label("1. VRM"))
	var model_row := HBoxContainer.new()
	_model_label = Label.new()
	_model_label.text = _current_model_label()
	_model_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_model_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	model_row.add_child(_model_label)
	var choose := Button.new()
	choose.text = "VRMを選ぶ"
	choose.pressed.connect(_choose_model)
	model_row.add_child(choose)
	col.add_child(model_row)

	col.add_child(_section_label("2. 名前"))
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "例：月白"
	col.add_child(_name_edit)

	col.add_child(_section_label("3. クレジット（必要な場合だけ）"))
	_credit_edit = LineEdit.new()
	_credit_edit.placeholder_text = "例：モデル制作：〇〇"
	col.add_child(_credit_edit)

	col.add_child(_section_label("4. 手を合わせたあとの一言（空欄でもOK）"))
	for i in range(3):
		var e := LineEdit.new()
		e.placeholder_text = "一言 %d" % (i + 1)
		_line_edits.append(e)
		col.add_child(e)

	col.add_child(_section_label("5. 触れ方"))
	_touch_option = OptionButton.new()
	_touch_option.add_item("指先を合わせる")
	_touch_option.add_item("手のひらを合わせる")
	col.add_child(_touch_option)

	col.add_child(_section_label("6. 動きの雰囲気"))
	_motion_option = OptionButton.new()
	_motion_option.add_item("静か — 間を大切に、ゆっくり")
	_motion_option.add_item("標準 — 既定の動き")
	_motion_option.add_item("活発 — 反応が少し早い")
	_motion_option.select(1)
	col.add_child(_motion_option)
	var motion_note := Label.new()
	motion_note.text = "あとで characters/partner/profile.json から細かく調整できます。"
	motion_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	motion_note.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
	col.add_child(motion_note)

	_license_check = CheckBox.new()
	_license_check.text = "この VRM の利用条件を確認しました"
	col.add_child(_license_check)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	var cancel := Button.new()
	cancel.text = "閉じる"
	cancel.pressed.connect(func(): _wizard.hide())
	buttons.add_child(cancel)
	var save := Button.new()
	save.text = "この子を迎える"
	save.pressed.connect(_save_partner)
	buttons.add_child(save)
	col.add_child(buttons)

	_load_existing_into_form()


func _section_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	return l


func _choose_model() -> void:
	if not _file_dialog or not is_instance_valid(_file_dialog):
		_file_dialog = FileDialog.new()
		_file_dialog.title = "パートナーの VRM を選ぶ"
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = PackedStringArray(["*.vrm ; VRMモデル"])
		_file_dialog.use_native_dialog = true
		_file_dialog.mode_overrides_title = false
		_file_dialog.file_selected.connect(_on_model_selected)
		EditorInterface.get_base_control().add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.75)


func _on_model_selected(path: String) -> void:
	_model_source = path
	_model_label.text = path.get_file()


func _load_existing_into_form() -> void:
	var profile := _load_json(PROFILE_PATH)
	_name_edit.text = String(profile.get("display_name", ""))
	_credit_edit.text = String(profile.get("credit", ""))
	_touch_option.select(1 if String(profile.get("touch_with", "fingertip")) == "palm" else 0)

	var lines_data := _load_json(LINES_PATH)
	var texts: Array[String] = []
	for item in lines_data.get("lines", []):
		if item is Dictionary and String(item.get("area", "")) == "hand" and String(item.get("interaction", "")) == "hold":
			texts.append(String(item.get("text", "")))
	for i in range(min(3, texts.size())):
		_line_edits[i].text = texts[i]


func _save_partner() -> void:
	var display_name := _name_edit.text.strip_edges()
	if display_name == "":
		_show_message("名前を入れてください", "パートナーの表示名をひとつ入れてください。")
		return

	var profile := _load_json(PROFILE_PATH)
	var existing_model := String(profile.get("model", MODEL_RES_PATH))
	if _model_source == "" and not _resource_or_file_exists(existing_model):
		_show_message("VRMを選んでください", "最初にパートナーの VRM ファイルを選んでください。")
		return
	# 新しい VRM を選んだときだけ、利用条件の確認を必須にする。
	# 既存モデルの名前・語録・動きだけ直す場合は、毎回の再確認を求めない。
	if _model_source != "" and not _license_check.button_pressed:
		_show_message("利用条件を確認してください", "VRM の作者・配布元が定めた利用条件を確認してから迎えてください。")
		return

	if _model_source != "":
		if _model_source.get_extension().to_lower() != "vrm":
			_show_message("VRMを選んでください", "拡張子 .vrm のファイルを選んでください。")
			return
		var dest_abs := ProjectSettings.globalize_path(MODEL_RES_PATH)
		var mk_err := DirAccess.make_dir_recursive_absolute(dest_abs.get_base_dir())
		if mk_err != OK:
			_show_message("保存できませんでした", "model フォルダを作れませんでした。\nエラー番号：%d" % mk_err)
			return
		var source_abs := _model_source.simplify_path()
		if source_abs != dest_abs.simplify_path():
			var copy_err := DirAccess.copy_absolute(source_abs, dest_abs)
			if copy_err != OK:
				_show_message("VRMをコピーできませんでした", "選んだ VRM をプロジェクトへコピーできませんでした。\nエラー番号：%d" % copy_err)
				return
		profile["model"] = MODEL_RES_PATH

	profile["id"] = String(profile.get("id", "partner"))
	profile["display_name"] = display_name
	profile["credit"] = _credit_edit.text.strip_edges()
	profile["touch_with"] = "palm" if _touch_option.selected == 1 else "fingertip"
	_apply_motion_preset(profile, _motion_option.selected)

	if not _write_json(PROFILE_PATH, profile):
		_show_message("保存できませんでした", "profile.json を書き込めませんでした。")
		return
	if not _write_lines():
		_show_message("保存できませんでした", "lines.json を書き込めませんでした。")
		return

	EditorInterface.get_resource_filesystem().scan()
	_model_source = ""
	_model_label.text = "partner.vrm（設定済み）"
	_show_message(
		"お迎えできました",
		"%s を迎える設定を保存しました。\n\nGodot の読み込みが終わったら F6 ではなく F5 を押し、画面を長押ししてみてください。" % display_name
	)


func _apply_motion_preset(profile: Dictionary, selected: int) -> void:
	match selected:
		0: # 静か
			profile["notice_delay"] = 0.18
			profile["eye_follow"] = 0.10
			profile["head_follow"] = 0.42
			profile["head_return"] = 1.05
			profile["approach_delay"] = 0.20
			profile["approach_time"] = 1.05
			profile["return_time"] = 1.10
			profile["breath_period"] = 4.8
			profile["blink_interval_min"] = 3.0
			profile["blink_interval_max"] = 7.0
		2: # 活発
			profile["notice_delay"] = 0.10
			profile["eye_follow"] = 0.06
			profile["head_follow"] = 0.25
			profile["head_return"] = 0.75
			profile["approach_delay"] = 0.10
			profile["approach_time"] = 0.65
			profile["return_time"] = 0.75
			profile["breath_period"] = 3.6
			profile["blink_interval_min"] = 2.0
			profile["blink_interval_max"] = 5.0
		_: # 標準
			profile["notice_delay"] = 0.15
			profile["eye_follow"] = 0.08
			profile["head_follow"] = 0.35
			profile["head_return"] = 0.9
			profile["approach_delay"] = 0.15
			profile["approach_time"] = 0.85
			profile["return_time"] = 0.95
			profile["breath_period"] = 4.2
			profile["blink_interval_min"] = 2.5
			profile["blink_interval_max"] = 6.0


func _write_lines() -> bool:
	var data := _load_json(LINES_PATH)
	if data.is_empty():
		data = {
			"_説明": "パートナーの語録。area: hand / head / face / shoulder、interaction: hold / tap / stroke。text を書いた行だけが使われる（空の行は使われない）。id は他と重ならなければ何でもよい。",
			"lines": []
		}
	var lines: Array = data.get("lines", [])
	for i in range(3):
		var target_id := "hand_hold_%02d" % (i + 1)
		var found := false
		for item in lines:
			if item is Dictionary and String(item.get("id", "")) == target_id:
				item["area"] = "hand"
				item["interaction"] = "hold"
				item["text"] = _line_edits[i].text.strip_edges()
				found = true
				break
		if not found:
			lines.append({
				"id": target_id,
				"area": "hand",
				"interaction": "hold",
				"text": _line_edits[i].text.strip_edges()
			})
	data["lines"] = lines
	return _write_json(LINES_PATH, data)


func _current_model_label() -> String:
	var profile := _load_json(PROFILE_PATH)
	var model_path := String(profile.get("model", MODEL_RES_PATH))
	if _resource_or_file_exists(model_path):
		return model_path.get_file() + "（設定済み）"
	return "まだ選ばれていません"


func _resource_or_file_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	if path.begins_with("res://"):
		return FileAccess.file_exists(path)
	return FileAccess.file_exists(path)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _write_json(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  ", false) + "\n")
	f.close()
	return true


func _show_message(title: String, text: String) -> void:
	var d := AcceptDialog.new()
	d.title = title
	d.dialog_text = text
	d.ok_button_text = "OK"
	d.confirmed.connect(func(): d.queue_free())
	d.canceled.connect(func(): d.queue_free())
	EditorInterface.get_base_control().add_child(d)
	d.popup_centered(Vector2i(520, 240))
