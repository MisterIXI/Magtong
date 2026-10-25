class_name MainMenu
extends Control
@export var start_menu: Control
@export var start_entry_focus: Control
@export var settings_menu: Control
@export var settings_entry_focus: Control
@export var mm_background: PackedScene
@export var address_edit: LineEdit
@export var host_steam_button: Button
@export var message_panel: Control
@export var message_label: Label
@export var message_ok_button: Button
var curr_mm_bg: MMBackground
var previous_menu: Control
var current_menu: Control

func _ready() -> void:
	hide_message()
	host_steam_button.disabled = not globSteamHandler.is_initialized
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
	globGameManager.start_local_game()

func _on_host_steam_pressed() -> void:
	globGameManager.host_steam()

func _on_host_direct_pressed() -> void:
	globGameManager.host_direct()

func _on_join_direct_pressed() -> void:
	var address := address_edit.text.strip_edges()
	globGameManager.join_direct(address if address != "" else "127.0.0.1")

func show_message(message: String, with_ok_button: bool = true) -> void:
	message_label.text = message
	message_ok_button.visible = with_ok_button
	message_panel.show()
	if with_ok_button:
		message_ok_button.grab_focus.call_deferred()

func hide_message() -> void:
	message_panel.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()
