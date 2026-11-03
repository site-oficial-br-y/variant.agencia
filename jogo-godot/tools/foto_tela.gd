extends Node
## teste: abre uma tela (arg tela=Nome), espera e salva user://tela_<Nome>.png. Arg clique=x,y toca nesse ponto antes.
func _ready() -> void:
	var tela := "Menu"
	var cliques: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tela="):
			tela = a.substr(5)
		if a.begins_with("clique="):
			var v := a.substr(7).split(",")
			cliques.append(Vector2(float(v[0]), float(v[1])))
	var c: Node = load("res://levels/%s.tscn" % tela).instantiate()
	get_tree().root.add_child.call_deferred(c)
	await get_tree().create_timer(1.2).timeout
	for p in cliques:
		for pressed in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = pressed
			e.position = p
			e.global_position = p
			Input.parse_input_event(e)
			await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("user://tela_%s.png" % tela)
	get_tree().quit()
