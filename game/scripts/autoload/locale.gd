extends Node
## 界面语言：简中为源语言，英文走 localization/strings.en.translation。

signal locale_changed(locale: String)

const CONFIG_PATH := "user://settings.cfg"
const SUPPORTED: Array[String] = ["zh_CN", "en"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var locale := "zh_CN"
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		locale = str(config.get_value("ui", "locale", locale))
	if OS.is_debug_build():
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--lang="):
				locale = arg.trim_prefix("--lang=")
	apply(locale, false)


func apply(locale: String, persist: bool = true) -> void:
	if not SUPPORTED.has(locale):
		locale = "zh_CN"
	TranslationServer.set_locale(locale)
	if persist:
		var config := ConfigFile.new()
		config.load(CONFIG_PATH)
		config.set_value("ui", "locale", locale)
		config.save(CONFIG_PATH)
	locale_changed.emit(locale)


func toggle() -> void:
	apply("en" if current() != "en" else "zh_CN")


func current() -> String:
	return TranslationServer.get_locale()


func is_english() -> bool:
	return current().begins_with("en")


func toggle_label() -> String:
	return "中" if is_english() else "EN"
