extends Node2D

## Lille Gårdsliv – first Godot vertical slice.
## The farm state is deliberately kept in one authoritative controller so it can
## later be moved to a dedicated server without rewriting the game rules.

const WORLD_SIZE := Vector2(1536, 1024)
const WALK_SPEED := 135.0
const TRACTOR_SPEED := 235.0
const FIELD_RECT := Rect2(930, 105, 560, 260)
const MARKET_POS := Vector2(1260, 535)
const COOP_POS := Vector2(855, 735)
const TRACTOR_START := Vector2(845, 555)
const TRAILER_START := Vector2(960, 560)

var map_texture: Texture2D
var farmer_texture: Texture2D
var tractor_texture: Texture2D
var trailer_texture: Texture2D

var player_pos := Vector2(755, 550)
var tractor_pos := TRACTOR_START
var trailer_pos := TRAILER_START
var player_heading := Vector2.DOWN
var tractor_heading := Vector2.RIGHT
var destination := Vector2.ZERO
var has_destination := false
var driving := false
var trailer_attached := true
var selected_tool := "seeder"
var field_state := "ploughed"
var crop_timer := 0.0
var eggs := 0
var grain := 0
var money := 1240
var eggs_available := 6
var action_message := "Velkommen til gården"
var message_time := 0.0

var camera: Camera2D
var status_label: Label
var help_label: Label
var connection_label: Label
var tool_button: Button
var tool_cycle := ["seeder", "combine", "trailer", "plow"]

func _ready() -> void:
	_setup_input()
	map_texture = load("res://assets/village-map.webp")
	farmer_texture = load("res://assets/farmer-directions.png")
	tractor_texture = load("res://assets/tractor-directions.png")
	trailer_texture = load("res://assets/trailer-hitch-directions.png")

	camera = Camera2D.new()
	camera.position = player_pos
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.zoom = Vector2(0.78, 0.78)
	add_child(camera)
	camera.make_current()

	_make_ui()
	_set_message("Gå til traktoren og trykk E for å sette deg inn")
	queue_redraw()

func _setup_input() -> void:
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("interact", [KEY_E])
	_add_key_action("use_tool", [KEY_SPACE])
	_add_key_action("exit_vehicle", [KEY_F])

func _add_key_action(action_name: String, keys: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action_name, event)

func _make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	status_label = Label.new()
	status_label.position = Vector2(18, 16)
	status_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(status_label)
	help_label = Label.new()
	help_label.position = Vector2(18, 670)
	help_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(help_label)
	connection_label = Label.new()
	connection_label.position = Vector2(950, 16)
	connection_label.add_theme_font_size_override("font_size", 16)
	layer.add_child(connection_label)
	_add_touch_button(layer, "HANDLING", Vector2(-170, -145), Vector2(150, 58), _interact)
	_add_touch_button(layer, "BRUK", Vector2(-330, -145), Vector2(140, 58), _use_tool)
	_add_touch_button(layer, "GÅ UT", Vector2(-330, -215), Vector2(140, 52), _touch_exit)
	tool_button = _add_touch_button(layer, "REDSKAP", Vector2(-170, -215), Vector2(150, 52), _cycle_tool)

func _add_touch_button(layer: CanvasLayer, title: String, bottom_right_offset: Vector2, size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = bottom_right_offset
	button.size = size
	button.add_theme_font_size_override("font_size", 17)
	button.modulate = Color(1, 1, 1, 0.9)
	button.pressed.connect(callback)
	layer.add_child(button)
	return button

func _touch_exit() -> void:
	if driving:
		_exit_vehicle()
	else:
		_set_message("Du er allerede til fots")

func _cycle_tool() -> void:
	var current := tool_cycle.find(selected_tool)
	selected_tool = tool_cycle[(current + 1) % tool_cycle.size()]
	_set_message("Redskap valgt: %s" % _tool_name(selected_tool))

func _tool_name(tool: String) -> String:
	match tool:
		"seeder": return "såmaskin"
		"combine": return "tresker"
		"trailer": return "tilhenger"
		"plow": return "plog"
	return tool

func _process(delta: float) -> void:
	if field_state == "growing":
		crop_timer -= delta
		if crop_timer <= 0.0:
			field_state = "ready"
			_set_message("Kornet er modent og klart til høsting")
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length() > 0.0:
		has_destination = false
		_move_actor(input_vector.normalized(), delta)
	elif has_destination:
		var target := tractor_pos if driving else player_pos
		var direction := target.direction_to(destination)
		if target.distance_to(destination) > 8.0:
			_move_actor(direction, delta)
		else:
			has_destination = false

	if driving and trailer_attached:
		var hitch := tractor_pos - tractor_heading.normalized() * 42.0
		trailer_pos = trailer_pos.lerp(hitch - tractor_heading.normalized() * 58.0, min(delta * 10.0, 1.0))

	if camera:
		camera.position = player_pos if not driving else tractor_pos
	if message_time > 0.0:
		message_time -= delta
	_update_ui()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		destination = get_global_mouse_position()
		has_destination = true
	if event.is_action_pressed("interact"):
		_interact()
	if event.is_action_pressed("use_tool"):
		_use_tool()
	if event.is_action_pressed("exit_vehicle") and driving:
		_exit_vehicle()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			selected_tool = "seeder"
			_set_message("Redskap valgt: såmaskin")
		elif event.keycode == KEY_2:
			selected_tool = "combine"
			_set_message("Redskap valgt: tresker")
		elif event.keycode == KEY_3:
			selected_tool = "trailer"
			_set_message("Redskap valgt: tilhenger")
		elif event.keycode == KEY_4:
			selected_tool = "plow"
			_set_message("Redskap valgt: plog")
		elif event.keycode == KEY_H:
			_host_game()
		elif event.keycode == KEY_J:
			_join_game("127.0.0.1")

func _move_actor(direction: Vector2, delta: float) -> void:
	if direction.length() == 0.0:
		return
	var speed := TRACTOR_SPEED if driving else WALK_SPEED
	var next := (tractor_pos if driving else player_pos) + direction * speed * delta
	if not driving and _can_walk(next):
		player_pos = next
		player_heading = direction
	elif driving and _can_drive(next):
		tractor_pos = next
		tractor_heading = direction

func _can_walk(pos: Vector2) -> bool:
	if pos.x < 20 or pos.y < 20 or pos.x > WORLD_SIZE.x - 20 or pos.y > WORLD_SIZE.y - 20:
		return false
	if Rect2(375, 330, 300, 145).grow(12).has_point(pos):
		return false
	if Rect2(810, 430, 245, 90).grow(12).has_point(pos):
		return false
	if Rect2(1060, 455, 420, 110).grow(10).has_point(pos):
		return false
	return not _in_water(pos)

func _can_drive(pos: Vector2) -> bool:
	if not _can_walk(pos):
		return false
	# The tractor is wider than the person and cannot enter the narrow market stalls.
	if Rect2(1070, 440, 410, 145).grow(30).has_point(pos):
		return false
	return true

func _in_water(pos: Vector2) -> bool:
	return pos.x > 850 and pos.y > 800 or (pos.x < 350 and pos.y < 290)

func _interact() -> void:
	var actor_pos := tractor_pos if driving else player_pos
	if not driving and actor_pos.distance_to(tractor_pos) < 70.0:
		driving = true
		player_pos = tractor_pos + Vector2(0, 20)
		_set_message("Du kjører traktoren. F for å gå ut.")
		return
	if not driving and actor_pos.distance_to(COOP_POS) < 95.0:
		if eggs_available > 0:
			eggs += eggs_available
			_set_message("Du sanket %d egg" % eggs_available)
			eggs_available = 0
		else:
			_set_message("Hønene har ingen flere egg akkurat nå")
		return
	if actor_pos.distance_to(MARKET_POS) < 120.0:
		_sell_goods()
		return
	if driving and actor_pos.distance_to(TRAILER_START) < 100.0 and not trailer_attached:
		trailer_attached = true
		_set_message("Tilhengeren er koblet på")

func _exit_vehicle() -> void:
	driving = false
	player_pos = tractor_pos + Vector2(0, 28)
	_set_message("Du gikk ut av traktoren")

func _use_tool() -> void:
	if not driving:
		_set_message("Du må sitte i riktig kjøretøy for å bruke dette utstyret")
		return
	if not FIELD_RECT.grow(25).has_point(tractor_pos):
		_set_message("Kjør traktoren inn på jordet først")
		return
	if selected_tool == "seeder" and field_state == "ploughed":
		field_state = "growing"
		crop_timer = 12.0
		_set_message("Jordet er sådd")
	elif selected_tool == "combine" and field_state == "ready":
		field_state = "harvested"
		grain = 40
		_set_message("Kornet er høstet – last det på tilhengeren")
	elif selected_tool == "trailer" and field_state == "harvested" and trailer_attached:
		grain = 40
		_set_message("Kornet er lastet på tilhengeren")
	elif selected_tool == "plow" and field_state == "harvested":
		field_state = "ploughed"
		_set_message("Jordet er pløyd og klart for ny såing")
	else:
		_set_message("Dette utstyret passer ikke til jordet nå")

func _sell_goods() -> void:
	var earned := eggs * 12 + grain * 4
	if earned == 0:
		_set_message("Du har ingen egg eller korn å selge")
		return
	money += earned
	_set_message("Solgte varer for %d kr – saldo %d kr" % [earned, money])
	eggs = 0
	grain = 0

func _host_game() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(7000, 4)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		_set_message("Vert opprettet på port 7000")
	else:
		_set_message("Kunne ikke opprette vert: %s" % error)

func _join_game(address: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, 7000)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		_set_message("Kobler til gården…")
	else:
		_set_message("Kunne ikke koble til vert: %s" % error)

func _set_message(text: String) -> void:
	action_message = text
	message_time = 5.0

func _update_ui() -> void:
	var mode := "traktor" if driving else "til fots"
	status_label.text = "%s\n%s | Egg: %d | Korn: %d | Penger: %d kr\nJorde: %s | Redskap: %s" % [action_message, mode, eggs, grain, money, field_state, selected_tool]
	if tool_button:
		tool_button.text = "REDSKAP: %s" % _tool_name(selected_tool).to_upper()
	help_label.text = "WASD/piltaster eller trykk i verden: gå/kjør   E: interaksjon   SPACE: bruk utstyr   1/2/3/4: så/tresk/tilhenger/plog   F: gå ut   H/J: host/join"
	var peer_text := "Offline – lokal prototype"
	if multiplayer.has_multiplayer_peer():
		peer_text = "Vert" if multiplayer.is_server() else "Klient"
	connection_label.text = peer_text

func _draw() -> void:
	if map_texture:
		draw_texture(map_texture, Vector2.ZERO)
	# Highlight the current interaction zones without covering the artwork.
	draw_rect(FIELD_RECT, Color(0.9, 0.65, 0.1, 0.12), true)
	draw_circle(COOP_POS, 42.0, Color(0.95, 0.85, 0.2, 0.18))
	draw_circle(MARKET_POS, 52.0, Color(0.25, 0.65, 0.95, 0.16))
	if trailer_attached:
		_draw_vehicle(trailer_pos, tractor_heading, false)
	_draw_vehicle(tractor_pos, tractor_heading, true)
	_draw_player(player_pos if not driving else tractor_pos + Vector2(0, -22), player_heading if not driving else tractor_heading)

func _draw_player(pos: Vector2, direction: Vector2) -> void:
	draw_ellipse(pos + Vector2(0, 11), Vector2(13, 6), Color(0.05, 0.08, 0.05, 0.45))
	draw_circle(pos - Vector2(0, 18), 11.0, Color("#f1c7a1"))
	draw_rect(Rect2(pos.x - 10, pos.y - 8, 20, 23), Color("#315fbb"), true)
	draw_line(pos - Vector2(0, 2), pos + direction.normalized() * 17.0, Color("#f6e277"), 4.0)

func _draw_vehicle(pos: Vector2, direction: Vector2, is_tractor: bool) -> void:
	var angle := direction.angle()
	var size := Vector2(54, 30) if is_tractor else Vector2(70, 42)
	var poly := PackedVector2Array([Vector2(-size.x / 2, -size.y / 2), Vector2(size.x / 2, -size.y / 2), Vector2(size.x / 2, size.y / 2), Vector2(-size.x / 2, size.y / 2)])
	for i in poly.size():
		poly[i] = pos + poly[i].rotated(angle)
	draw_colored_polygon(poly, Color("#b86b2f") if is_tractor else Color("#9b5124"))
	draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color("#352414"), 3.0)
	if is_tractor:
		draw_circle(pos + direction.normalized() * 20.0, 8.0, Color("#222222"))

func draw_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	draw_colored_polygon(points, color)
