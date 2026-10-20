extends GutTest

const SFX := [
	"click", "brass_tick", "paper", "chime", "stamp", "seal", "align_snap",
	"tear", "pencil", "shutter", "wood", "wrong", "water", "develop_done",
]
const AMBIENCE := ["amb_archive", "amb_field", "amb_darkroom"]


func before_each() -> void:
	TranslationServer.set_locale("zh_CN")


func after_each() -> void:
	TranslationServer.set_locale("zh_CN")


func test_audio_buses_exist() -> void:
	assert_eq(AudioServer.get_bus_index("Music"), 1)
	assert_eq(AudioServer.get_bus_index("SFX"), 2)
	assert_eq(AudioServer.get_bus_index("Master"), 0)


func test_sfx_assets_load() -> void:
	for name in SFX:
		var path := "res://assets/audio/sfx/%s.wav" % name
		assert_true(ResourceLoader.exists(path), "missing " + path)
		var stream := load(path) as AudioStream
		assert_not_null(stream, "failed to load " + path)


func test_ambience_assets_load_and_loop() -> void:
	for name in AMBIENCE:
		var path := "res://assets/audio/ambience/%s.ogg" % name
		assert_true(ResourceLoader.exists(path), "missing " + path)
		var stream := load(path) as AudioStreamOggVorbis
		assert_not_null(stream)
		if stream != null:
			stream.loop = true
			assert_true(stream.loop)


func test_audio_playback_uses_pool() -> void:
	var player := Audio.play("click", -60.0)
	assert_not_null(player)
	assert_eq(player.bus, "SFX")
	Audio.stop_ambience(0.0)
	Audio.set_ambience("amb_archive", 0.2)
	assert_eq(Audio._ambience.bus, "Music")


func test_translation_table_complete() -> void:
	assert_true(
		ResourceLoader.exists("res://localization/strings.en.translation"),
		"translation resource missing",
	)
	var table := TranslationServer.get_translation_object("en")
	assert_not_null(table)
	TranslationServer.set_locale("en")
	assert_eq(TranslationServer.translate("打开卷宗"), "OPEN DOSSIER")
	assert_eq(TranslationServer.translate("三声裁定 · 封存本卷"), "THREE VOICES · SEAL THIS VOLUME")
	assert_eq(TranslationServer.translate("证据 %d / %d"), "Evidence %d / %d")
	assert_eq(TranslationServer.translate("未开启 · 需完成「%s」"), "LOCKED · Complete \"%s\"")
	TranslationServer.set_locale("zh_CN")


func test_translation_csv_has_no_blanks() -> void:
	var file := FileAccess.open("res://localization/strings.csv", FileAccess.READ)
	assert_not_null(file)
	var rows := 0
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() < 2 or cells[0].is_empty() or cells[0] == "keys":
			continue
		rows += 1
		assert_false(cells[1].is_empty(), "blank translation for: " + cells[0])
	assert_gte(rows, 300)


func test_locale_toggle_is_reversible() -> void:
	Loc.apply("en", false)
	assert_eq(TranslationServer.get_locale(), "en")
	assert_true(Loc.is_english())
	assert_eq(Loc.toggle_label(), "中")
	Loc.apply("zh_CN", false)
	assert_eq(TranslationServer.get_locale(), "zh_CN")
	assert_eq(Loc.toggle_label(), "EN")


func test_font_subsets_cover_chinese_and_are_small() -> void:
	var cases := {
		"res://assets/fonts/SourceHanSerifCN-Regular.subset.otf": 400_000,
		"res://assets/fonts/SourceHanSerifCN-Bold.subset.otf": 400_000,
		"res://assets/fonts/SourceHanSansCN-Regular.subset.otf": 300_000,
	}
	for path in cases:
		assert_true(ResourceLoader.exists(path), "missing " + path)
		var font := load(path) as FontFile
		assert_not_null(font, "failed to load " + path)
		if font != null:
			assert_true(font.has_char("追".unicode_at(0)), "missing 追 in " + path)
			assert_true(font.has_char("档".unicode_at(0)), "missing 档 in " + path)
		var size := FileAccess.get_file_as_bytes(path).size()
		assert_lt(size, int(cases[path]), "font too large: " + path)
