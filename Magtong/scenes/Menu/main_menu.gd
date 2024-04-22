extends Control
@export var start_menu: Control
@export var start_entry_focus: Control
@export var settings_menu: Control
@export var settings_entry_focus: Control

var previous_menu: Control
var current_menu: Control

func _ready() -> void:
	hide_all()
	current_menu = start_menu
	current_menu.show()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if current_menu == settings_menu:
			switch_to_menu(start_menu)
		
func hide_all() -> void:
	start_menu.hide()
	settings_menu.hide()

func switch_to_menu(menu: Control) -> void:
	if current_menu != null:
		current_menu.hide()
	previous_menu = current_menu
	current_menu = menu
	current_menu.show()
	if current_menu == start_menu:
		if start_entry_focus != null:
			start_entry_focus.call_deferred("grab_focus")
	elif current_menu == settings_menu:
		if settings_entry_focus != null:
			settings_entry_focus.call_deferred("grab_focus")

func settings_close() -> void:
	switch_to_menu(start_menu)

func _on_settings_pressed() -> void:
	if current_menu == start_menu:
		switch_to_menu(settings_menu)

func _on_start_local_pressed() -> void:
	globGameManager.host_game(true)

func _on_host_online_pressed():
	globGameManager.host_game(false)

func boot_to_menu_with_message(_message: String) -> void:
	switch_to_menu(start_menu)


func _on_join_online_pressed():
	globGameManager.join_game("79.241.84.132", 12345)
