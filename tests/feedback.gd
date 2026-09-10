extends "res://tests/journey.gd"

func run() -> void:
	await fresh()
	var view = game.presentation
	var actor = sim.actors[0]
	view.on_feedback("impact", {"actor": actor})
	var previous: Tween = view.impact_tweens[actor.get_instance_id()]
	view.on_feedback("impact", {"actor": actor})
	check(not previous.is_valid() and view.impact_tweens.size() == 1, "repeat impact replaces competing rotation tween")
	view.on_feedback("fallen", {"actor": actor})
	check(view.impact_tweens.is_empty() and actor.visual.rotation.z == 0, "death cancels surviving hit reaction")
	view.beam(Vector3.ZERO, Vector3.FORWARD, Color.WHITE, 1.0)
	view.burst(Vector3.ZERO, Color.WHITE, 1.0)
	view.on_feedback("fragment", {"id": 999, "position": Vector3.ZERO})
	check(view.transient_root.get_child_count() == 2 and view.fragments.size() == 1, "world effects have explicit transient ownership")
	sim.paused = true
	view._process(0.016)
	check(view.fx_paused.size() > 0, "pause freezes live death and world effects")
	view.on_feedback("load_room", {})
	check(view.fx_tweens.is_empty() and view.fx_paused.is_empty() and view.fragments.is_empty(), "room load clears paused tweens and fragment references")
	await process_frame
	check(view.transient_root.get_child_count() == 0, "room load removes transient world geometry")
	sim.paused = false
	view._process(0.016)
	check(view.sound.bank.fire.data != view.sound.bank.rifle.data and view.sound.bank.storm.data != view.sound.bank.fire.data, "element attacks use distinct audio waveforms")
	check(view.sound.bank.kill.data != view.sound.bank.hit.data, "kill has distinct confirmation sound")
	game.queue_free()
	await process_frame
	print("FEEDBACK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
