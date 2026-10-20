class_name EvidenceCard
extends Resource
## 一张证据卡。voice 决定它在三声裁定里的立场；is_dissent 的卡可翻面成为下档入口。

@export var id: String = ""
@export var title: String = ""
@export_multiline var body: String = ""
@export_enum("evidence", "editor", "dissent") var voice: String = "evidence"
@export var is_dissent: bool = false
@export var unlocks_entry_id: String = ""
