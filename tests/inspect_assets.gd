extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for file in ["Skeleton_Rogue", "Skeleton_Warrior"]:
		var model = load("res://assets/characters/skeletons/" + file + ".glb").instantiate()
		root.add_child(model)
		print("MODEL: ", file)
		inspect(model)
		model.free()
	quit()

func inspect(node: Node) -> void:
	if node is MeshInstance3D:
		print("MESH: ", node.name, " AABB=", node.global_transform * node.get_aabb())
	if node is AnimationPlayer:
		print("ANIMATIONS: ", node.get_animation_list())
	for child in node.get_children():
		inspect(child)
