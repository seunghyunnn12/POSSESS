extends RefCounted
## Narrative follows the existing seven-room expedition; no gameplay decisions.
const ART = preload("res://assets/ui/illustrations/bell_gate.png")

static func chapter(index: int) -> int:
	return clampi(index, 1, 7)

static func tip(index: int) -> String:
	return "PASSAGE_TIP_%d" % chapter(index)
