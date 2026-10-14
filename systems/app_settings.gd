extends Node
## 設定（設計書 §34 Settings）
## 振動・効果音・音量・記録の ON/OFF を user://settings.cfg に保存する。

signal changed

const PATH := "user://settings.cfg"

var vibration := true
var sound := true
var volume := 0.7
var record := true

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		vibration = cfg.get_value("feedback", "vibration", vibration)
		sound = cfg.get_value("feedback", "sound", sound)
		volume = cfg.get_value("feedback", "volume", volume)
		record = cfg.get_value("record", "enabled", record)

func set_value(key: String, value) -> void:
	set(key, value)
	var cfg := ConfigFile.new()
	cfg.set_value("feedback", "vibration", vibration)
	cfg.set_value("feedback", "sound", sound)
	cfg.set_value("feedback", "volume", volume)
	cfg.set_value("record", "enabled", record)
	cfg.save(PATH)
	changed.emit()
