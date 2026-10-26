extends Node2D
## Splice Stack — FULL MVP (Godot). Spec: 9-Android-Game-Specs.md Game 2 + Roadmap P2.
## Features at MVP parity with the web build: Endless + Daily Tower (date-seeded spawn
## sequence, per-mode bests, daily floor record), falling-slice knock-loose physics,
## PERFECT streaks with width restore, CLOSE bonus, floor counter.
## Command surface (frozen): cmd_start(), cmd_restart(), cmd_tap(pos), cmd_set_mode(mode).
## Mode keys: 1 = Endless, 2 = Daily. Not in Godot build: share card image, settings
## screen (web build has them; see docs/PARITY.md).

const VIEW_W := 720.0
const BLOCK_H := 52.0
const START_W := 376.0
const BASE_Y := 1100.0
const PERFECT_PX := 7.0
const CLOSE_PX := 24.0

var mode := "endless"
var state := "ready" # ready | play | dead
var stack: Array = [] # {x:float, w:float} bottom-first
var score := 0
var best := 0
var streak := 0
var closes := 0
var knocked := 0
var chipped := 0
var cur := {"x": 0.0, "w": START_W, "dir": 1.0}
var cur_jitter := 1.0
var falling: Array = [] # {x,w,origin_level:int,fall_px:float,vy:float,debris:bool}
var popups: Array = [] # {node:Label, t:float}
var _tap_frame := -1
var cam_y := 0.0
var rng := RandomNumberGenerator.new()
var daily_rng := RandomNumberGenerator.new()

@onready var score_label: Label = $ScoreLabel
@onready var msg_label: Label = $MsgLabel

func _floor() -> int:
	return stack.size() - 1

func _today() -> String:
	var t := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(t["year"]), int(t["month"]), int(t["day"])]

func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	rng.randomize()
	best = _load_best(mode)
	_reset()
	msg_label.text = "SPLICE STACK — %s\nTap to start" % mode.to_upper()
	_update_labels()

func _reset() -> void:
	if mode == "daily":
		daily_rng.seed = int(("splice-daily-" + _today()).hash())
	stack = [{"x": (VIEW_W - START_W) / 2.0, "w": START_W}]
	score = 0
	streak = 0
	closes = 0
	knocked = 0
	chipped = 0
	falling.clear()
	cam_y = 0.0
	_new_block()

func _spawn_rng() -> RandomNumberGenerator:
	return daily_rng if mode == "daily" else rng

func _new_block() -> void:
	var top: Dictionary = stack[stack.size() - 1]
	var r := _spawn_rng()
	var from_left := r.randf() < 0.5
	cur_jitter = 0.94 + r.randf() * 0.12 if mode == "daily" else 1.0
	if from_left:
		cur = {"x": 0.0, "w": float(top["w"]), "dir": 1.0}
	else:
		cur = {"x": VIEW_W - float(top["w"]), "w": float(top["w"]), "dir": -1.0}

func _speed() -> float:
	return minf(890.0, 308.0 + float(_floor()) * 14.0) * cur_jitter

func cmd_set_mode(m: String) -> void:
	if m == mode:
		return
	mode = m
	best = _load_best(mode)
	_reset()
	state = "ready"
	msg_label.text = "SPLICE STACK — %s\nTap to start" % mode.to_upper()
	_update_labels()

func cmd_start() -> void:
	if state == "ready":
		state = "play"
		msg_label.text = ""

func cmd_restart() -> void:
	_reset()
	state = "play"
	msg_label.text = ""
	_update_labels()

func cmd_tap(_pos: Vector2) -> void:
	if state == "ready":
		cmd_start()
	elif state == "dead":
		cmd_restart()
	else:
		_drop()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			cmd_set_mode("endless")
			return
		if event.keycode == KEY_2:
			cmd_set_mode("daily")
			return
	if event is InputEventScreenTouch and event.pressed:
		_handle_tap(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap(event.position)

func _handle_tap(pos: Vector2) -> void:
	# ONE physical tap must cause ONE action. With touch->mouse emulation a
	# single tap delivers BOTH a touch and a mouse event in the same frame,
	# which made every tap start-and-instantly-drop on Android: blocks were
	# cut at the spawn edge and games ended in 1-2 stacks. Emulation is now
	# off in project.godot; this same-frame guard makes it impossible anyway.
	var f := Engine.get_process_frames()
	if f == _tap_frame:
		return
	_tap_frame = f
	cmd_tap(pos)

func _popup(text: String, cx: float, cy: float, col: Color) -> void:
	var l := Label.new()
	l.text = text
	l.size = Vector2(300.0, 44.0)
	l.position = Vector2(cx - 150.0, cy - 58.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 36)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	popups.append({"node": l, "t": 0.0})

func _update_popups(delta: float) -> void:
	var keep: Array = []
	for p in popups:
		p["t"] = float(p["t"]) + delta
		var l: Label = p["node"]
		l.position.y -= 46.0 * delta
		l.modulate.a = clampf(1.0 - float(p["t"]) / 0.9, 0.0, 1.0)
		if float(p["t"]) < 0.9:
			keep.append(p)
		else:
			l.queue_free()
	popups = keep

func _beep(freq: float, dur: float) -> void:
	var sr := 22050
	var n := int(sr * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var env := 1.0 - float(i) / float(n)
		var v := int(sin(TAU * freq * float(i) / float(sr)) * env * 0.25 * 32767.0)
		data.encode_s16(i * 2, v)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sr
	stream.data = data
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = stream
	player.play()
	player.finished.connect(player.queue_free)

func _drop() -> void:
	var below: Dictionary = stack[stack.size() - 1]
	var cx := float(cur["x"])
	var cw := float(cur["w"])
	var left := maxf(cx, float(below["x"]))
	var right := minf(cx + cw, float(below["x"]) + float(below["w"]))
	var overlap := right - left
	var level := stack.size()
	if overlap <= 0.0:
		falling.append({"x": cx, "w": cw, "origin_level": level, "fall_px": 0.0, "vy": 340.0, "debris": true})
		_game_over()
		return
	if cx < left:
		falling.append({"x": cx, "w": left - cx, "origin_level": level, "fall_px": 0.0, "vy": 100.0, "debris": false})
	if cx + cw > right:
		falling.append({"x": right, "w": cx + cw - right, "origin_level": level, "fall_px": 0.0, "vy": 100.0, "debris": false})
	var offset := absf(cx - float(below["x"]))
	var pop_text := "+10"
	var pop_col := Color(1, 1, 1, 0.9)
	var freq := 470.0
	if offset <= PERFECT_PX:
		streak += 1
		score += 10 + 25 * mini(streak, 6) # P1: capped streak scoring
		pop_text = "PERFECT" if streak == 1 else "PERFECT ×%d" % streak
		pop_col = Color(1.0, 0.84, 0.25)
		freq = 700.0 + 80.0 * float(mini(streak, 6))
		if streak % 5 == 0:
			var grow := minf(START_W - overlap, 38.0)
			stack.append({"x": maxf(0.0, left - grow / 2.0), "w": overlap + grow})
		else:
			stack.append({"x": float(below["x"]), "w": float(below["w"])})
	elif offset <= CLOSE_PX:
		streak = 0
		closes += 1
		score += 25
		pop_text = "CLOSE +25"
		pop_col = Color(0.55, 0.9, 1.0)
		freq = 620.0
		stack.append({"x": left, "w": overlap})
	else:
		streak = 0
		score += 10
		stack.append({"x": left, "w": overlap})
	var placed: Dictionary = stack[stack.size() - 1]
	_popup(pop_text, float(placed["x"]) + float(placed["w"]) / 2.0, _block_top_y(level), pop_col)
	_beep(freq, 0.07)
	_new_block()
	_update_labels()

func _ledges(l: int) -> Array:
	var segs: Array = []
	if l < 0 or l >= stack.size():
		return segs
	var b: Dictionary = stack[l]
	if l + 1 >= stack.size():
		segs.append({"x": float(b["x"]), "w": float(b["w"])})
		return segs
	var above: Dictionary = stack[l + 1]
	var bx := float(b["x"])
	var bw := float(b["w"])
	var ax := float(above["x"])
	var aw := float(above["w"])
	if ax > bx:
		segs.append({"x": bx, "w": ax - bx})
	if ax + aw < bx + bw:
		segs.append({"x": ax + aw, "w": (bx + bw) - (ax + aw)})
	return segs.filter(func(s): return float(s["w"]) > 7.0)

func _update_falling(delta: float) -> void:
	var still: Array = []
	for f in falling:
		f["vy"] = minf(2600.0, float(f["vy"]) + 4450.0 * delta)
		f["fall_px"] = float(f["fall_px"]) + float(f["vy"]) * delta
		if not bool(f["debris"]):
			var dir_in := 1.0 if float(f["x"]) + float(f["w"]) / 2.0 < VIEW_W / 2.0 else -1.0
			f["x"] = float(f["x"]) + dir_in * 24.0 * delta # P1: slices tumble slightly inward
		var bottom := float(int(f["origin_level"])) - float(f["fall_px"]) / BLOCK_H
		var consumed := false
		if not bool(f["debris"]):
			var lmax := mini(int(f["origin_level"]) - 1, stack.size() - 1)
			var l := lmax
			while l >= 0 and not consumed:
				if bottom < float(l + 1) and bottom > float(l) - 0.5:
					for seg in _ledges(l):
						var ov := minf(float(f["x"]) + float(f["w"]), float(seg["x"]) + float(seg["w"])) - maxf(float(f["x"]), float(seg["x"]))
						if ov > 30.0:
							var struck: Dictionary = stack[l]
							stack.remove_at(l)
							knocked += 1
							Input.vibrate_handheld(45)
							still.append({"x": float(struck["x"]), "w": float(struck["w"]), "origin_level": l, "fall_px": 0.0, "vy": float(f["vy"]) * 0.6, "debris": true})
							consumed = true
							_update_labels()
							break
						elif ov > 8.0:
							# P1: CHIP — grazing hit narrows the block instead of knocking it out
							var b: Dictionary = stack[l]
							if float(f["x"]) + float(f["w"]) / 2.0 < float(b["x"]) + float(b["w"]) / 2.0:
								b["x"] = float(b["x"]) + ov
							b["w"] = float(b["w"]) - ov
							chipped += 1
							if float(b["w"]) < 52.0:
								var struck2: Dictionary = stack[l]
								stack.remove_at(l)
								knocked += 1
								still.append({"x": float(struck2["x"]), "w": maxf(18.0, float(struck2["w"])), "origin_level": l, "fall_px": 0.0, "vy": float(f["vy"]) * 0.6, "debris": true})
							consumed = true
							_update_labels()
							break
				l -= 1
		if not consumed and bottom > -6.0:
			still.append(f)
	falling = still

func _process(delta: float) -> void:
	_update_falling(delta)
	_update_popups(delta)
	if state != "dead":
		cur["x"] = float(cur["x"]) + float(cur["dir"]) * _speed() * delta
		if float(cur["x"]) < 0.0:
			cur["x"] = 0.0
			cur["dir"] = 1.0
		if float(cur["x"]) > VIEW_W - float(cur["w"]):
			cur["x"] = VIEW_W - float(cur["w"])
			cur["dir"] = -1.0
	var target := maxf(0.0, float(stack.size() - 9) * BLOCK_H)
	cam_y = lerpf(cam_y, target, minf(1.0, delta * 4.0))
	queue_redraw()

func _game_over() -> void:
	state = "dead"
	if score > best:
		best = score
		_save_best()
	if mode == "daily":
		_record_daily(_floor())
	Input.vibrate_handheld(80)
	_beep(150.0, 0.28)
	msg_label.text = "TOWER DOWN\nFloor %d · Score %d · Best %d\nChipped: %d · Knocked loose: %d\nTap to retry" % [_floor(), score, best, chipped, knocked]
	_update_labels()

func _block_top_y(i: int) -> float:
	return BASE_Y - float(i + 1) * BLOCK_H + cam_y

func _draw() -> void:
	draw_rect(Rect2(0, 0, 720, 1280), Color(0.05, 0.06, 0.12))
	for i in range(stack.size()):
		var b: Dictionary = stack[i]
		var y := _block_top_y(i)
		if y < -60.0 or y > 1340.0:
			continue
		var col := Color.from_hsv(fmod(float(i) * 0.067, 1.0), 0.6, 0.85)
		draw_rect(Rect2(float(b["x"]), y, float(b["w"]), BLOCK_H - 5.0), col)
		draw_rect(Rect2(float(b["x"]), y, float(b["w"]), 7.0), Color(1, 1, 1, 0.25))
	for f in falling:
		var y := _block_top_y(int(f["origin_level"])) + float(f["fall_px"])
		if y < 1340.0:
			var col := Color(0.9, 0.3, 0.3, 0.8) if bool(f["debris"]) else Color(0.7, 0.7, 0.7, 0.7)
			draw_rect(Rect2(float(f["x"]), y, float(f["w"]), BLOCK_H - 5.0), col)
	if state != "dead":
		var y := _block_top_y(stack.size())
		draw_rect(Rect2(float(cur["x"]), y, float(cur["w"]), BLOCK_H - 5.0), Color.WHITE)

func _update_labels() -> void:
	var s := ""
	if streak > 0:
		s = "   PERFECT ×%d" % streak
	score_label.text = "%s · SCORE %d · FLOOR %d%s" % [mode.to_upper(), score, _floor(), s]

func _best_path() -> String:
	return "user://splice_best_%s.txt" % mode

func _load_best(m: String) -> int:
	var p := "user://splice_best_%s.txt" % m
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f:
			return int(f.get_as_text().strip_edges())
	return 0

func _save_best() -> void:
	var f := FileAccess.open(_best_path(), FileAccess.WRITE)
	if f:
		f.store_string(str(best))

func _record_daily(fl: int) -> void:
	# user://splice_daily.txt — one "YYYY-MM-DD=floor" per line, best of day kept
	var path := "user://splice_daily.txt"
	var lines: Array = []
	var found := false
	if FileAccess.file_exists(path):
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf:
			for line in rf.get_as_text().split("\n"):
				if line.begins_with(_today() + "="):
					found = true
					var old := int(line.split("=")[1])
					lines.append(_today() + "=" + str(maxi(old, fl)))
				elif line.strip_edges() != "":
					lines.append(line)
	if not found:
		lines.append(_today() + "=" + str(fl))
	var wf := FileAccess.open(path, FileAccess.WRITE)
	if wf:
		wf.store_string("\n".join(lines))
