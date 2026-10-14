extends Node
## InteractionLogger（設計書 §17〜§22, §27）
## 触れ合いの記録を端末内（user://）にだけ保存する。ネットワークには一切出さない。
## - 記録OFFのときは、何も書かないし、メモリにも溜めない（§21）
## - 保存するのは日時・キャラ・姿・触れ方・部位・秒数・語録IDだけ（§17）
## - 上限 MAX_ENTRIES 件。超えたら古いものから消える（§18）

signal changed

const PATH := "user://interaction_log.json"
const MAX_ENTRIES := 10000

var enabled := true
var _entries: Array = []   # 古い順
var _loaded := false


func _ready() -> void:
	_load()


func entries() -> Array:
	_load()
	return _entries


## 触れ合いを1件残す。記録OFFなら何もしない。
func add(character_id: String, form: String, interaction: String, area: String, duration_ms: int, line_id: String = "") -> void:
	if not enabled:
		return
	_load()
	_entries.append({
		"timestamp": local_iso_now(),
		"character_id": character_id,
		"form": form,
		"interaction": interaction,
		"area": area,
		"duration_ms": duration_ms,
		"line_id": line_id,
	})
	if _entries.size() > MAX_ENTRIES:
		_entries = _entries.slice(_entries.size() - MAX_ENTRIES)
	_save()
	changed.emit()


## すべての記録を削除（§22）。ファイルごと消す。
func clear_all() -> void:
	_entries = []
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	changed.emit()


func _load() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if data is Dictionary and data.get("entries") is Array:
		_entries = data["entries"]


func _save() -> void:
	# 途中で落ちても壊れないよう、一時ファイルに書いてから差し替える
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("記録を保存できませんでした: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify({"version": 1, "entries": _entries}))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))


## 端末の時刻で "2026-10-13T21:14:32+09:00" の形
static func local_iso_now() -> String:
	var s := Time.get_datetime_string_from_system(false, false)
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var sign := "+" if bias >= 0 else "-"
	bias = abs(bias)
	return "%s%s%02d:%02d" % [s, sign, bias / 60, bias % 60]
