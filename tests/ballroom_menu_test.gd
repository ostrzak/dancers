extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PrototypeController = load("res://main.tscn").instantiate()
	var floor_art: BallroomFloor = scene.get_node("BallroomFloor")
	var test_path := "user://ballroom_test_%s.cfg" % Time.get_ticks_usec()
	floor_art.preferences_path = test_path
	root.add_child(scene)
	var menu: PauseMenu = scene.get_node("PauseMenu")
	await process_frame
	_expect(paused and menu.visible and menu.entrance.visible, "main opens on the title screen with physics paused")
	_expect(menu.entrance.dance_button.has_focus(), "title starts with Dance focused")
	var before := scene.left_dancer.position
	await create_timer(0.06).timeout
	_expect(scene.left_dancer.position == before, "title does not advance player physics")
	menu._input(_key(KEY_ESCAPE))
	_expect(menu.entrance.visible and paused, "Escape on title does not accidentally enter gameplay")
	menu.entrance.settings_button.grab_focus()
	menu._input(_button(JOY_BUTTON_A))
	_expect(menu.title_context and not menu.entrance.visible and menu.tabs.current_tab == 1, "controller confirm opens title settings")
	_expect(menu.trigger_sensitivity_slider.has_focus(), "settings focus lands on a usable control")
	menu._input(_button(JOY_BUTTON_B))
	_expect(menu.entrance.visible and paused and menu.entrance.settings_button.has_focus(), "Back restores title and original focus")
	root.push_input(_key(KEY_ENTER))
	var release := _key(KEY_ENTER)
	release.pressed = false
	root.push_input(release)
	_expect(not menu.entrance.visible and menu.title_context, "native keyboard Enter activates the focused title button")
	menu.back_button.pressed.emit()
	_expect(menu.entrance.visible and paused, "visible Back button returns to title")
	menu._open_ballroom()
	_expect(menu.tabs.current_tab == menu.ballroom_tab and menu.floor_buttons[0].has_focus(), "ballroom opens with selected floor focused")
	menu.floor_buttons[2].grab_focus()
	menu._input(_button(JOY_BUTTON_A))
	_expect(floor_art.selected_index == 2 and not menu.grid_toggle.disabled, "selecting studio enables its grid")
	menu.grid_toggle.grab_focus()
	menu._input(_button(JOY_BUTTON_A))
	_expect(floor_art.practice_grid, "controller toggles the studio grid")
	var reloaded := BallroomFloor.new()
	reloaded.load_preferences(test_path)
	_expect(reloaded.selected_index == 2 and reloaded.practice_grid, "floor and grid survive preference reload")
	menu.floor_buttons[1].grab_focus()
	menu._input(_button(JOY_BUTTON_A))
	_expect(floor_art.selected_index == 1 and menu.grid_toggle.disabled, "grand ballroom disables practice grid control")
	_expect(menu.floor_preview.texture == BallroomFloor.TEXTURES[1], "picker preview matches the selected floor")
	_expect(scene.left_dancer.position == before, "appearance changes do not move dancers")
	menu._resume()
	_expect(menu.entrance.background.texture == BallroomFloor.TEXTURES[1], "title reflects selected ballroom")
	menu.entrance.dance_button.grab_focus()
	menu._input(_button(JOY_BUTTON_A))
	_expect(not paused and not menu.visible, "Dance enters gameplay")
	menu._input(_button(JOY_BUTTON_START))
	_expect(paused and menu.visible and not menu.title_context, "Start during gameplay opens pause")
	menu._input(_button(JOY_BUTTON_LEFT_SHOULDER))
	_expect(menu.tabs.current_tab == menu.ballroom_tab, "shoulder navigation wraps to ballroom")
	menu._input(_key(KEY_ESCAPE))
	_expect(not paused and not menu.visible, "Escape from gameplay settings resumes gameplay")
	menu._pause()
	var all_panels_fit := true
	for index in menu.tabs.get_tab_count():
		menu.tabs.current_tab = index
		for _frame in 3:
			await process_frame
		all_panels_fit = all_panels_fit and _panel_fits(menu)
	menu.tabs.current_tab = 3
	for index in menu.demonstration.FIGURES.size():
		menu.demonstration.select_figure(index)
		menu._refresh_figure_labels()
		for _frame in 3:
			await process_frame
		all_panels_fit = all_panels_fit and _panel_fits(menu)
	_expect(all_panels_fit, "all tabs and figure descriptions fit inside the viewport")
	menu._show_title()
	_expect(paused and menu.entrance.visible, "return to title preserves the paused session")
	# Malformed settings fall back safely, without corrupting user preferences.
	var malformed := ConfigFile.new()
	malformed.set_value("ballroom", "floor", "invalid")
	malformed.set_value("ballroom", "practice_grid", 123)
	malformed.save(test_path)
	reloaded.load_preferences(test_path)
	_expect(reloaded.selected_index == 0 and not reloaded.practice_grid, "invalid preference types use defaults")
	malformed.set_value("ballroom", "floor", 999)
	malformed.save(test_path)
	reloaded.load_preferences(test_path)
	_expect(reloaded.selected_index == 2, "out-of-range floor preference is bounded")
	reloaded.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	paused = false
	scene.free()
	print("BALLROOM MENU: %d/%d checks passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _button(index: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	return event


func _expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _panel_fits(menu: PauseMenu) -> bool:
	var panel: Control = menu.get_node("Center/Panel")
	return root.get_visible_rect().grow(1).encloses(panel.get_global_rect())
