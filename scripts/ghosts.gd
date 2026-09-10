extends RefCounted
const IDS := ["wanderer", "reaper", "arcanist", "gunslinger"]
const DATA := {
	"wanderer": {"damage": 20.0, "interval": 0.48, "speed": 6.0, "radius": 0.30},
	"reaper": {"damage": 27.0, "interval": 0.65, "speed": 0.0, "radius": 0.0},
	"arcanist": {"damage": 42.0, "interval": 0.3, "speed": 13.0, "radius": 0.22},
	"gunslinger": {"damage": 10.0, "interval": 0.22, "speed": 0.0, "radius": 0.0}
}
static func info(id: String) -> Dictionary:
	return DATA.get(id, DATA.wanderer)
