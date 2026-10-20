extends Node
## 档案库：显式路径加载卷宗，导出后不依赖目录扫描。证据卡由卷宗引用带入。

const DOSSIER_PATHS: Array[String] = [
	"res://data/dossiers/dossier_wudu.tres",
]

var dossiers: Dictionary = {}
var cards: Dictionary = {}


func _ready() -> void:
	for path in DOSSIER_PATHS:
		var dossier := load(path) as DossierDef
		if dossier == null:
			push_error("dossier load failed: " + path)
			continue
		dossiers[dossier.id] = dossier
		for card in dossier.evidence:
			cards[card.id] = card


func get_dossier(id: String) -> DossierDef:
	return dossiers.get(id)


func get_card(id: String) -> EvidenceCard:
	return cards.get(id)


func cards_for(dossier_id: String) -> Array[EvidenceCard]:
	var empty: Array[EvidenceCard] = []
	var dossier := get_dossier(dossier_id)
	if dossier == null:
		return empty
	return dossier.evidence
