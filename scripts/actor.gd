extends CharacterBody3D
## Collision and replicated data only. All decisions belong to Authority.
const Traits = preload("res://scripts/traits.gd")

var kind: String = "soldier"
var hp: float = 100.0
var max_hp: float = 100.0
var alive: bool = true
var claimed: bool = false
var attack_clock: float = 1.0
var windup: float = 0.0
var charge_direction := Vector3.ZERO
var visual: Node3D
var label: Label3D
var animation: AnimationPlayer
var animation_state: String = ""
var flash: float = 0.0
var profile: Dictionary = Traits.profile()
var attributes: Dictionary = {}
var rewarded := false
var home := Vector3.ZERO
var detection := 0.0

func setup(role: String) -> void:
	kind = role
	max_hp = 160.0 if role == "brute" else 100.0
	hp = max_hp
	attributes = Traits.stats(kind, profile)
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.52 if role == "brute" else 0.38
	capsule.height = 2.3 if role == "brute" else 1.85
	shape.shape = capsule
	shape.position.y = capsule.height * 0.5
	add_child(shape)

func chance() -> float:
	return (0.15 + (1.0 - hp / max_hp) * 0.70) * (1.0 - profile.resistance)

func set_profile(individual: Dictionary) -> void:
	profile = individual.duplicate(true)
	attributes = Traits.stats(kind, profile)
	max_hp = attributes.host_health
	hp = max_hp
