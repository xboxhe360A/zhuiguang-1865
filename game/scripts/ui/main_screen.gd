extends Control
## Step 1 启动屏：验证自动加载、目录与竖屏设置。后续替换为档案桌 hub。

@onready var status: Label = %Status


func _ready() -> void:
	GameState.completeness_changed.connect(_on_changed)
	GameState.evidence_collected.connect(_on_evidence)
	GameState.verdict_recorded.connect(_on_verdict)
	Palette.saturation_changed.connect(_on_saturation)
	Palette.set_saturation(0.35)
	_refresh()


func _on_changed(_value: int) -> void:
	_refresh()


func _on_evidence(_card_id: String) -> void:
	_refresh()


func _on_verdict(_dossier_id: String, _verdict: String) -> void:
	_refresh()


func _on_saturation(_value: float) -> void:
	_refresh()


func _refresh() -> void:
	status.text = "骨架就绪\n饱和度 %.2f ｜ 已收证据 %d ｜ 裁定 %d\n竖屏 %d×%d" % [
		Palette.saturation,
		GameState.collected.size(),
		GameState.verdicts.size(),
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"),
	]
