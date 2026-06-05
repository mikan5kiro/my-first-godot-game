extends Node

## 全局语言切换（Autoload: LanguageSwitch）：
## - 仅由 UI 按钮触发中/英文切换
## - 切换结果持久化到 user://settings.cfg

const LOCALE_ZH_CN := "zh_CN"
const LOCALE_EN := "en"
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "localization"
const SETTINGS_KEY_LOCALE := "locale"
const SUPPORTED_LOCALES := [LOCALE_ZH_CN, LOCALE_EN]
const TRANSLATION_CSV_SOURCES := [
	"res://localization/zh_CN.csv",
	"res://localization/en.csv",
]

signal language_changed(language: String)

var _translations_ready := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_translations_loaded()
	apply_saved_or_default()


func translate_text(key: String) -> String:
	return TranslationServer.translate(key)


func _ensure_translations_loaded() -> void:
	if _translations_ready:
		return

	for existing in TranslationServer.get_translations():
		TranslationServer.remove_translation(existing)

	for path in TRANSLATION_CSV_SOURCES:
		_add_translation_from_csv(path)

	_translations_ready = true
	if TranslationServer.translate("ui.title.start") == "ui.title.start":
		push_error("LanguageSwitch: translations failed to load; buttons will show raw keys.")


func _add_translation_from_csv(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("LanguageSwitch: cannot open translation csv '%s'" % path)
		return

	var header := file.get_csv_line()
	if header.size() < 2:
		push_warning("LanguageSwitch: invalid csv header in '%s'" % path)
		return

	var locale := header[1].strip_edges()
	var translation := Translation.new()
	translation.locale = locale

	while file.get_position() < file.get_length():
		var row := file.get_csv_line()
		if row.is_empty():
			continue
		var key := row[0].strip_edges()
		if key.is_empty():
			continue
		var value := row[1] if row.size() > 1 else ""
		translation.add_message(key, value)

	TranslationServer.add_translation(translation)


func apply_saved_or_default() -> void:
	var saved := _read_saved_locale()
	apply_locale(saved if _is_supported_locale(saved) else LOCALE_ZH_CN)


func toggle_locale() -> String:
	var current := TranslationServer.get_locale()
	var normalized := _normalize_locale(current)
	var next := LOCALE_EN if normalized == LOCALE_ZH_CN else LOCALE_ZH_CN
	apply_locale(next)
	return next


func apply_locale(locale: String) -> void:
	var normalized := _normalize_locale(locale)
	var target := normalized if _is_supported_locale(normalized) else LOCALE_ZH_CN
	TranslationServer.set_locale(target)
	_save_locale(target)
	language_changed.emit(target)


func get_current_locale() -> String:
	var current := _normalize_locale(TranslationServer.get_locale())
	return current if _is_supported_locale(current) else LOCALE_ZH_CN


func get_language_button_text() -> String:
	var current := get_current_locale()
	if current == LOCALE_EN:
		return translate_text("ui.title.language.current_en")
	return translate_text("ui.title.language.current_zh")


func _normalize_locale(locale: String) -> String:
	if locale.is_empty():
		return ""
	if locale.contains("_"):
		return locale
	if locale.contains("-"):
		return locale.replace("-", "_")
	if locale == "zh":
		return LOCALE_ZH_CN
	if locale == "en":
		return LOCALE_EN
	return locale


func _is_supported_locale(locale: String) -> bool:
	return SUPPORTED_LOCALES.has(locale)


func _read_saved_locale() -> String:
	var cfg := ConfigFile.new()
	var error := cfg.load(SETTINGS_PATH)
	if error != OK:
		return ""
	return str(cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY_LOCALE, ""))


func _save_locale(locale: String) -> void:
	var cfg := ConfigFile.new()
	var _load_error := cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY_LOCALE, locale)
	var save_error := cfg.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("LanguageSwitch: failed saving locale '%s'" % locale)
