extends RefCounted
## Presentation-only bindings. Gameplay role IDs are stable; art can be replaced.
const THEME = preload("res://theme/possess.tres")
const MODELS := {
	"soldier": {"path": "res://assets/characters/skeletons/Skeleton_Rogue.glb", "scale": 0.79, "idle": "Idle_Combat", "walk": "Walking_A", "attack": "2H_Ranged_Shoot"},
	"brute": {"path": "res://assets/characters/skeletons/Skeleton_Warrior.glb", "scale": 0.88, "idle": "Idle_Combat", "walk": "Walking_A", "attack": "2H_Melee_Attack_Chop"},
	"shotgun": {"path": "res://assets/characters/skeletons/Skeleton_Warrior.glb", "scale": 0.79, "idle": "Idle_Combat", "walk": "Walking_A", "attack": "2H_Ranged_Shoot"},
	"archer": {"path": "res://assets/characters/skeletons/Skeleton_Rogue.glb", "scale": 0.79, "idle": "Idle_Combat", "walk": "Walking_A", "attack": "2H_Ranged_Shoot"},
	"mage": {"path": "res://assets/characters/skeletons/Skeleton_Mage.glb", "scale": 0.79, "idle": "Idle_Combat", "walk": "Walking_A", "attack": "2H_Ranged_Shoot"},
	"storm": {"path": "res://assets/characters/skeletons/Skeleton_Mage.glb", "scale": 0.79, "idle": "Idle_Combat", "walk": "Walking_A", "attack": "2H_Ranged_Shoot"}
}
const BOSS_SCALE := 1.4

static func host(kind: String) -> Dictionary:
	return MODELS.get(kind, MODELS.soldier)
