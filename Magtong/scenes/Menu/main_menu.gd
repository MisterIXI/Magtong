class_name MainMenu
extends Control
@export var start_menu: Control
@export var start_entry_focus: Control
@export var settings_menu: Control
@export var settings_entry_focus: Control
@export var ip_edit_field: TextEdit
@export var mm_background: PackedScene
var curr_mm_bg: MMBackground
var previous_menu: Control
var current_menu: Control

func _ready() -> void:
	hide_all()
	current_menu = start_menu
	current_menu.show()
	spawn_mm_background()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if current_menu == settings_menu:
			switch_to_menu(start_menu)
		
func hide_all() -> void:
	start_menu.hide()
	settings_menu.hide()
	if curr_mm_bg != null:
		curr_mm_bg.queue_free()


func switch_to_menu(menu: Control) -> void:
	if current_menu != null:
		current_menu.hide()
	if curr_mm_bg == null:
		spawn_mm_background()
	previous_menu = current_menu
	current_menu = menu
	current_menu.show()
	if current_menu == start_menu:
		spawn_mm_background()
		if start_entry_focus != null:
			start_entry_focus.call_deferred("grab_focus")
	elif current_menu == settings_menu:
		if settings_entry_focus != null:
			settings_entry_focus.call_deferred("grab_focus")

func spawn_mm_background() -> void:
	if mm_background != null:
		var mm_bg = mm_background.instantiate()
		add_child(mm_bg)
		move_child(mm_bg, -1)
		curr_mm_bg = mm_bg as MMBackground

func settings_close() -> void:
	switch_to_menu(start_menu)

func _on_settings_pressed() -> void:
	if current_menu == start_menu:
		switch_to_menu(settings_menu)

func _on_start_local_pressed() -> void:
	globGameManager.host_game(true)

func _on_host_online_pressed():
	# globGameManager.host_game(false)
	globSteamHandler.create_debug_lobby()

func boot_to_menu_with_message(_message: String) -> void:
	switch_to_menu(start_menu)


func _on_join_online_pressed():
	# globGameManager.join_game(ip_edit_field.text, 12345)
	globSteamHandler.join_first_lobby()

func _on_join_local_pressed():
	globGameManager.join_game("127.0.0.1", 12345)

func _on_quit_pressed() -> void:
	get_tree().quit()
