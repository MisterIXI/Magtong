extends Node
class_name GameManager

enum State {
	MENU,
	LOBBY,
	MAP_SELECT,
	GAME,
	PAUSED,
}

var current_state: State = State.MENU
# scenes
@export var menu_scene: PackedScene
@export var lobby_scene: PackedScene
@export var map_select_scene: PackedScene
@export var default_map_scene: PackedScene

var message_log: Array = []

signal state_changed(old_state: State, new_state: State)

@export var message_vbox: VBoxContainer
@export var message_scrollbox: ScrollContainer
@export var message_panel: PanelContainer

@onready var scene_root: SceneRoot = get_node("/root/MainScene/SceneRoot")
@onready var main_menu: MainMenu = get_node("/root/MainScene/MainMenu")

func _ready():
	NetDebug.parse_args()

func _change_state(new_state: State):
	var old_state = current_state
	current_state = new_state
	if new_state == State.LOBBY:
		if old_state == State.MENU:
			main_menu.hide_all()
		scene_root.change_scene(lobby_scene.instantiate())
	elif new_state == State.GAME:
		scene_root.change_scene(default_map_scene.instantiate())
	state_changed.emit(old_state, new_state)

func start_local_game():
	assert(current_state == State.MENU)
	_change_state(State.LOBBY)

func print_message(message: String):
	message_log.append(message)
	print("[gm]: ", message)
	var label = Label.new()
	label.text = message
	message_vbox.add_child(label)
	# wait for the box to change
	await get_tree().process_frame
	await get_tree().process_frame
	# scroll to the bottom
	message_scrollbox.scroll_vertical = int(message_scrollbox.get_v_scroll_bar().max_value)

func _input(event):
	# check if F12 is pressed
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		toggle_message_panel()

func toggle_message_panel():
	message_panel.visible = not message_panel.visible

func start_game():
	_change_state(State.GAME)
