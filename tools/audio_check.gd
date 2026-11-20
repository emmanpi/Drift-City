extends SceneTree

## Vérifie en headless que l'autoload Sound charge les deux musiques et les
## effets, que les fondus fonctionnent et que la pause coupe les boucles.
## Les autoloads ne sont pas instanciés par `--script` : on les crée à la main.

func _initialize() -> void:
	# Les autoloads existent déjà, mais leur _ready() n'a pas encore tourné.
	await process_frame
	var game: Node = get_root().get_node_or_null("Game")
	if game == null:
		game = load("res://scripts/game_state.gd").new()
		game.name = "Game"
		get_root().add_child(game)
	var sound: Node = get_root().get_node_or_null("Sound")
	if sound == null:
		sound = load("res://scripts/sound.gd").new()
		sound.name = "Sound"
		get_root().add_child(sound)

	print("game music   : %s (chargée=%s)" % [String(sound.call("music_path")), str(sound.call("has_music", "game"))])
	print("menu music   : chargée=%s" % str(sound.call("has_music", "menu")))
	var menu: AudioStreamPlayer = sound.get_node("Music_menu")
	var music: AudioStreamPlayer = sound.get_node("Music_game")
	var low: AudioStreamPlayer = sound.get_node("SFX_engine_low")
	var high: AudioStreamPlayer = sound.get_node("SFX_engine_high")
	var skid: AudioStreamPlayer = sound.get_node("SFX_skid")
	var crash: AudioStreamPlayer = sound.get_node("SFX_crash")

	sound.call("play_menu_music")
	await process_frame
	await process_frame
	print("[menu ] menu=%s dB=%.1f / game=%s dB=%.1f" % [str(menu.playing), menu.volume_db, str(music.playing), music.volume_db])

	sound.call("play_game_music")
	for _i in 30:
		await process_frame
	# En headless les frames sont très courtes : on force la fin du fondu pour
	# vérifier l'état stable (le fondu lui-même est déjà observé juste avant).
	sound.set("_fade", 1.0)
	sound.call("_update_music_volumes")
	await process_frame
	await process_frame
	print("[jeu  ] menu=%s dB=%.1f / game=%s dB=%.1f" % [str(menu.playing), menu.volume_db, str(music.playing), music.volume_db])

	sound.call("start_car_sounds")
	sound.call("update_engine", 24.0, 1.0, true)
	sound.call("update_skid", 0.8)
	sound.call("play_crash", 1.0)
	await process_frame
	print("[moteur] low=%s dB=%.1f pitch=%.2f / high=%s dB=%.1f pitch=%.2f" % [str(low.playing), low.volume_db, low.pitch_scale, str(high.playing), high.volume_db, high.pitch_scale])
	print("[skid ] playing=%s dB=%.1f / crash playing=%s dB=%.1f" % [str(skid.playing), skid.volume_db, str(crash.playing), crash.volume_db])

	paused = true
	await process_frame
	print("[pause] music dB=%.1f / moteur dB=%.1f / skid dB=%.1f" % [music.volume_db, low.volume_db, skid.volume_db])
	paused = false
	await process_frame
	print("[reprise] music dB=%.1f / moteur dB=%.1f" % [music.volume_db, low.volume_db])

	game.call("set_music_enabled", false)
	game.call("set_sfx_enabled", false)
	await process_frame
	print("[coupé] music=%s / moteur=%s" % [str(music.playing), str(low.playing)])
	game.call("set_music_enabled", true)
	game.call("set_sfx_enabled", true)
	sound.call("stop_car_sounds")
	await process_frame
	print("[fin  ] music=%s dB=%.1f / moteur=%s" % [str(music.playing), music.volume_db, str(low.playing)])
	quit()
