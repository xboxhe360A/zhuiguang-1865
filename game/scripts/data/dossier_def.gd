class_name DossierDef
extends Resource
## 一档 = 档案桌上一份可进入的卷宗。

@export var id: String = ""
@export var title: String = ""
@export_enum("existence", "annal", "memory", "unfiled") var volume: String = "unfiled"
@export var evidence: Array[EvidenceCard] = []
@export var puzzle_ids: PackedStringArray = []
