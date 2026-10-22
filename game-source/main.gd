extends Node2D
## Hung Sao Roi - a tiny catching game.
## Move the basket with Left/Right or A/D, or drag with mouse/touch.
## Catch falling stars for points; missing one costs a life (3 lives).

const W := 800.0
const H := 600.0
const PLAYER_W := 130.0
const PLAYER_H := 22.0
const PLAYER_Y := H - 56.0
const PLAYER_SPEED := 460.0

var player: ColorRect
var score_label: Label
var lives_label: Label
var title_label: Label
var overlay: ColorRect
var overlay_label: Label
var overlay_button: Button

var stars: Array = []  # each: {node: Polygon2D, speed: float}
var score := 0
var lives := 3
var playing := true
var spawn_left := 0.4
var fall_speed := 190.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	# Background (plain child of the 2D world, added first so it stays
	# behind everything; a CanvasLayer here would cover the sprites)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.11, 0.22)
	bg.size = Vector2(W, H)
	bg.position = Vector2.ZERO
	add_child(bg)
	# A few static decorative dots (distant stars)
	for i in 60:
		var dot := ColorRect.new()
		dot.color = Color(1, 1, 1, rng.randf_range(0.15, 0.5))
		var s := rng.randf_range(1.5, 3.0)
		dot.size = Vector2(s, s)
		dot.position = Vector2(rng.randf_range(0, W), rng.randf_range(0, H - 120))
		add_child(dot)
	# Player basket
	player = ColorRect.new()
	player.color = Color(0.95, 0.65, 0.15)
	player.size = Vector2(PLAYER_W, PLAYER_H)
	player.position = Vector2(W / 2.0 - PLAYER_W / 2.0, PLAYER_Y)
	add_child(player)
	var rim := ColorRect.new()
	rim.color = Color(1.0, 0.85, 0.3)
	rim.size = Vector2(PLAYER_W, 5)
	player.add_child(rim)
	# HUD
	var hud := CanvasLayer.new()
	add_child(hud)
	score_label = _make_label(hud, "ĐIỂM: 0", Vector2(16, 10), 26)
	lives_label = _make_label(hud, "MẠNG: 3", Vector2(W - 150, 10), 26)
	title_label = _make_label(hud, "HỨNG SAO RƠI", Vector2(W / 2.0 - 110, 8), 28)
	# Game-over overlay (hidden at start)
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(overlay)
	overlay_label = _make_label(overlay, "", Vector2(W / 2.0 - 200, 220), 40)
	overlay_label.size = Vector2(400, 60)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_button = Button.new()
	overlay_button.text = "Chơi lại"
	overlay_button.position = Vector2(W / 2.0 - 70, 310)
	overlay_button.size = Vector2(140, 48)
	overlay_button.add_theme_font_size_override("font_size", 22)
	overlay_button.pressed.connect(_restart)
	overlay.add_child(overlay_button)
	overlay.visible = false

func _make_label(parent: Node, text: String, pos: Vector2, size_px: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	parent.add_child(l)
	return l

func _star_polygon() -> Polygon2D:
	var pts := PackedVector2Array()
	var outer := 15.0
	var inner := 6.5
	for i in 10:
		var ang := -PI / 2.0 + i * PI / 5.0
		var r := outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = Color(1.0, 0.85, 0.25)
	return p

func _spawn_star() -> void:
	var s := _star_polygon()
	s.position = Vector2(rng.randf_range(24, W - 24), -20)
	add_child(s)
	stars.append({"node": s, "speed": fall_speed * rng.randf_range(0.85, 1.2)})

func _process(delta: float) -> void:
	if not playing:
		return
	# Player movement (keyboard)
	var dir := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		dir += 1.0
	player.position.x = clamp(player.position.x + dir * PLAYER_SPEED * delta, 0, W - PLAYER_W)
	# Spawning
	spawn_left -= delta
	if spawn_left <= 0.0:
		_spawn_star()
		spawn_left = rng.randf_range(0.45, 0.8)
		fall_speed = min(fall_speed + 2.5, 420.0)
	# Falling stars
	for i in range(stars.size() - 1, -1, -1):
		var st: Dictionary = stars[i]
		var node: Polygon2D = st["node"]
		node.position.y += float(st["speed"]) * delta
		node.rotation += 1.4 * delta
		var caught := node.position.y > PLAYER_Y - 8 and node.position.y < PLAYER_Y + PLAYER_H + 6 \
			and node.position.x > player.position.x - 12 and node.position.x < player.position.x + PLAYER_W + 12
		if caught:
			score += 1
			score_label.text = "ĐIỂM: %d" % score
			node.queue_free()
			stars.remove_at(i)
		elif node.position.y > H + 20:
			lives -= 1
			lives_label.text = "MẠNG: %d" % lives
			node.queue_free()
			stars.remove_at(i)
			if lives <= 0:
				_game_over()

func _input(event: InputEvent) -> void:
	# Drag / touch to move the basket
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_move_player_to(event.position.x)
	elif event is InputEventScreenDrag:
		_move_player_to(event.position.x)
	elif event is InputEventMouseButton and event.pressed:
		_move_player_to(event.position.x)

func _move_player_to(x: float) -> void:
	if playing and player:
		player.position.x = clamp(x - PLAYER_W / 2.0, 0, W - PLAYER_W)

func _game_over() -> void:
	playing = false
	overlay_label.text = "Hết mạng! Điểm: %d" % score
	overlay.visible = true

func _restart() -> void:
	for st in stars:
		(st["node"] as Node).queue_free()
	stars.clear()
	score = 0
	lives = 3
	fall_speed = 190.0
	spawn_left = 0.4
	score_label.text = "ĐIỂM: 0"
	lives_label.text = "MẠNG: 3"
	overlay.visible = false
	playing = true
