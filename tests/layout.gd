extends SceneTree
## Generator sanity over many seeds: every floor is connected, has one boss per
## zone, a reachable exit, keyed treasure rooms and one secret per zone.
const Expedition = preload("res://scripts/expedition.gd")
var failures := 0
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	var sizes := []
	for seed_value in range(1, 201):
		var map = Expedition.generate(seed_value)
		var n: int = map.size()
		sizes.append(n)
		check(map.hubs.size() == 3 and map.bosses.size() == 3, "seed %d: three zones" % seed_value)
		# Connectivity from room 1 through links.
		var seen := {1: true}
		var frontier := [1]
		while not frontier.is_empty():
			var r: int = frontier.pop_back()
			for e in map.links:
				if r in e:
					var o: int = e[1] if e[0] == r else e[0]
					if not seen.has(o):
						seen[o] = true
						frontier.append(o)
		check(seen.size() == n, "seed %d: all %d rooms connected (%d)" % [seed_value, n, seen.size()])
		# Links only join grid neighbours.
		for e in map.links:
			var d: Vector2i = map.cells[e[0] - 1] - map.cells[e[1] - 1]
			check(absi(d.x) + absi(d.y) == 1, "seed %d: link %s adjacent" % [seed_value, e])
		check(map.room_at(map.cells[map.final - 1] + Vector2i.DOWN) == 0, "seed %d: exit corridor free" % seed_value)
		var counts := {}
		for k in map.kinds: counts[k] = counts.get(k, 0) + 1
		check(counts.get("secret", 0) == 3 and counts.get("treasure", 0) == 3 and counts.get("morgue", 0) == 2, "seed %d: special rooms %s" % [seed_value, counts])
		check(map.key_doors.size() == 3 and map.secret_doors.size() == 3, "seed %d: keyed and secret doors" % seed_value)
		for edge in map.key_doors: check(map.kind(map.key_doors[edge]) == "treasure" and map.key_doors[edge] in map.links[edge], "seed %d: key door leads to treasure" % seed_value)
		for edge in map.secret_doors: check(map.kind(map.other(edge, map.secret_doors[edge])) == "combat", "seed %d: secret hangs off a combat room" % seed_value)
		# Cells unique.
		var uniq := {}
		for c in map.cells: uniq[c] = true
		check(uniq.size() == n, "seed %d: no overlapping rooms" % seed_value)
	sizes.sort()
	print("LAYOUT: %d checks, %d failures, rooms min=%d max=%d" % [checks, failures, sizes[0], sizes[-1]])
	var sample = Expedition.generate(17)
	var rows := {}
	for i in sample.size():
		var c: Vector2i = sample.cells[i]
		rows[c.y] = rows.get(c.y, "") + "  (%d,%d)%s" % [c.x, c.y, sample.kinds[i].substr(0, 3)]
	var ys := rows.keys()
	ys.sort()
	for y in ys: print(rows[y])
	quit(1 if failures else 0)
