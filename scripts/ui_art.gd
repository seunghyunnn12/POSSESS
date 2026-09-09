extends RefCounted
## Null is an intentional empty TextureRect; copy art to these paths and restart.
static var cache: Dictionary = {}

static func texture(path: String) -> Texture2D:
	if not cache.has(path):
		cache[path] = load(path) if ResourceLoader.exists(path) else null
	return cache[path]

static func bind(slot: TextureRect, path: String) -> void:
	slot.texture = texture("res://assets/ui/" + path + ".png")
