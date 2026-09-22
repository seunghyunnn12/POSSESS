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
const MINION = {"path": "res://assets/characters/skeletons/Skeleton_Minion.glb", "scale": 0.7, "idle": "Idle_Combat", "walk": "Walking_D_Skeletons", "attack": "Unarmed_Melee_Attack_Punch_A"}
const HIT_CLIPS = ["Hit_A", "Hit_B"]
const DEATH_CLIPS = ["Death_A", "Death_B"]
const PROPS = {
	"soldier": "res://assets/props/adventurers/crossbow_2handed.gltf",
	"shotgun": "res://assets/props/skeletons/Skeleton_Crossbow.gltf",
	"brute": "res://assets/props/adventurers/axe_2handed.gltf",
	"archer": "res://assets/props/adventurers/crossbow_1handed.gltf",
	"mage": "res://assets/props/adventurers/staff.gltf"
}

static func host(kind: String) -> Dictionary:
	return MODELS.get(kind, MODELS.soldier)
