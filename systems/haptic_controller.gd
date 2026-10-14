extends Node
## HapticController（設計書 §15, §27）

@export var enabled := true
@export var contact_ms := 22

func contact() -> void:
	if not enabled:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(contact_ms)
