extends SceneTree
## MVP verification harness — run: godot --headless --path . -s tests/test_mvp.gd
## Drives the real game node: perfect-climb, knock-loose geometry, daily determinism.

var main: Node
var frame := 0
var phase := 0
var ready_x := -1.0

func _initialize() -> void:
	var ps: PackedScene = load("res://Main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		var mr: Rect2 = main.msg_label.get_rect()
		print("TEST msg-rect ok=", mr.position.x >= 0.0 and mr.position.y >= 0.0 and mr.end.x <= 720.0 and mr.end.y <= 1280.0 and absf(mr.get_center().x - 360.0) < 4.0 and absf(mr.get_center().y - 640.0) < 4.0, " rect=", mr)
		ready_x = float(main.cur["x"])
		var cx := float(main.cur["x"])
		var cw := float(main.cur["w"])
		print("TEST spawn-visible ok=", cx >= 0.0 and cx + cw <= 720.0, " x=", cx, " w=", cw)
	if frame == 4:
		print("TEST ready-motion ok=", absf(float(main.cur["x"]) - ready_x) > 0.5, " dx=", float(main.cur["x"]) - ready_x, " state=", main.state)
	if frame == 5:
		main.cmd_tap(Vector2.ZERO) # ready -> play
	if phase == 0 and frame > 5 and frame % 6 == 0 and main.state == "play":
		# perfect-align and drop
		var below: Dictionary = main.stack[main.stack.size() - 1]
		main.cur["x"] = float(below["x"])
		main._drop()
		if main._floor() >= 30:
			print("TEST perfect-climb floor=", main._floor(), " score=", main.score, " width=", main.stack[main.stack.size() - 1]["w"])
			phase = 1
			# knock-loose geometry test: wide base, narrow top, slice onto base ledge
			main.stack = [{"x": 100.0, "w": 520.0}, {"x": 260.0, "w": 200.0}]
			main.falling = [{"x": 120.0, "w": 100.0, "origin_level": 2, "fall_px": 0.0, "vy": 100.0, "debris": false}]
	elif phase == 1 and frame % 6 == 0:
		if main.knocked >= 1:
			print("TEST knock-loose knocked=", main.knocked, " stack_size=", main.stack.size())
			phase = 2
			# daily determinism: capture spawn sequence twice
			main.cmd_set_mode("daily")
			var seq1 := _seq()
			main._reset()
			var seq2 := _seq()
			print("TEST daily-deterministic=", seq1 == seq2, " seq=", seq1)
			print("TESTS DONE")
			return true
	if frame > 6000:
		print("TEST TIMEOUT phase=", phase, " knocked=", main.knocked if main else -1)
		return true
	return false

func _seq() -> String:
	var parts: Array = []
	for i in range(6):
		main._new_block()
		parts.append("%d:%.3f" % [int(main.cur["dir"]), main.cur_jitter])
	return " ".join(parts)
