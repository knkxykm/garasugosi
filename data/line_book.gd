extends Node
## LineBook（設計書 §30）
## パートナーの語録（characters/partner/lines.json）を読み、部位×触れ方に合う一言を選ぶ。直前と同じ一言は続けて選ばない。
## text が空の行は使わない（語録を書き足すまでは、記録に一言は付かない）。

var _lines: Array = []
var _by_id := {}
var _last_id := ""


func load_from(path: String) -> void:
	_lines = []
	_by_id = {}
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary and data.get("lines") is Array):
		return
	for l in data["lines"]:
		if l is Dictionary and String(l.get("text", "")).strip_edges() != "":
			_lines.append(l)
			_by_id[l["id"]] = l


## 合う一言の id を返す（無ければ ""）
func pick(area: String, interaction: String) -> String:
	var pool := _lines.filter(func(l): return l.get("area") == area and l.get("interaction") == interaction)
	if pool.is_empty():
		return ""
	if pool.size() > 1:
		pool = pool.filter(func(l): return l["id"] != _last_id)
	var l: Dictionary = pool[randi() % pool.size()]
	_last_id = l["id"]
	return l["id"]


func text_of(id: String) -> String:
	return String(_by_id.get(id, {}).get("text", ""))
