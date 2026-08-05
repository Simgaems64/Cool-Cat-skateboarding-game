extends Node

#preload obstacles
var fire_hydrant_scene = preload("res://Scenes/Fire_Hydrant.tscn")
var pigeon_scene = preload("res://Scenes/pigeon.tscn")
var warning_scene = preload("res://Scenes/warning_symbol.tscn")
var traffic_cone_scene = preload("res://Scenes/traffic_cone.tscn")
var obstacle_types := [fire_hydrant_scene, traffic_cone_scene]
var obstacles : Array
var bird_heights := [200, 390]

#game variables
const CAT_START_POS := Vector2i(150,550)
const CAM_START_POS := Vector2i(576,324)
var difficulty
const MAX_DIFFICULTY : int = 2
var speed : float
const START_SPEED : float = 10.0
const MAX_SPEED : int = 25
const SPEED_MODIFIER = 10000
var screen_size : Vector2i
var ground_height : int
var score : int 
var dive_score_bonus : int = 1000
var trick_score_bonus : int = 500  # bonus per 360 rotation
var high_score : int = 0
const SCORE_MODIFIER : int = 30
var game_running : bool
var game_over_triggered : bool = false
var pigeon_warning_pending : bool = false  # blocks a second warning from stacking on the first
var last_obs

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node("RestartButton").pressed.connect(new_game)
	
	# Connect the trick signal from the player
	$"Skateboard Cat".trick_completed.connect(_on_trick_completed)
	
	new_game()
	
func _on_trick_completed(rotation_count):
	# Award points for each completed 360
	score += trick_score_bonus
	show_score()
	# Optional: play a sound effect or show visual feedback
	print("Trick completed! Total 360s this jump: ", rotation_count)
	
func new_game():
	$"Skateboard Cat/CatSprite".play("Idle") 
	if score > high_score:
		high_score = score
	score = 0
	show_score()
	game_running = false
	game_over_triggered = false
	pigeon_warning_pending = false
	get_tree().paused = false
	difficulty = 0
	
	#delete all obstacles
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()
	
	#reset the nodes
	$"Skateboard Cat".position = CAT_START_POS 
	$"Skateboard Cat".velocity = Vector2i(0,0)
	$"Skateboard Cat/CatSprite".rotation_degrees = 0  # reset visual spin on new game
	$"Skateboard Cat".reset_death_state()
	$Camera2D.position = CAM_START_POS
	$Ground.position = Vector2i(0,0)
	
	#reset hud and game over screen
	$HUD.get_node("StartLabel").show()
	$GameOver.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Check for input to start the game when not running
	if not game_running:
		if not game_over_triggered and (Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up")):
			game_running = true
			$HUD.get_node("StartLabel").hide()
		return  # Don't execute the rest of the game logic if not running
	
	# Game logic only runs when game_running is true
	#speed up and adjust difficulty
	speed = START_SPEED + score/ SPEED_MODIFIER
	if speed > MAX_SPEED:
		speed = MAX_SPEED
	adjust_difficulty()

	#Generate obstacles
	generate_obs()

	#Move Cat and camera
	$"Skateboard Cat".position.x += speed
	$Camera2D.position.x += speed
		
	#Update score
	score += speed
	show_score()
	
	#update ground position
	if $Camera2D.position.x - $Ground.position.x > screen_size.x * 1.5:
		$Ground.position.x += screen_size.x
		
	#remove obstacles that have gone off screen
	for obs in obstacles:
		if obs.position.x < ($Camera2D.position.x - screen_size.x):
			remove_obs(obs)

func generate_obs():
	#generate ground obstacles
	if obstacles.is_empty() or last_obs.position.x < score + randi_range(300,400):
		var obs_type = obstacle_types[randi() % obstacle_types.size()]
		var obs
		var max_obs = difficulty + 1
		for i in range(randi() % max_obs + 1):
			obs = obs_type.instantiate()
			var obs_height = obs.get_node("Sprite2D").texture.get_height()
			var obs_scale = obs.get_node("Sprite2D").scale
			var obs_x : int = screen_size.x  + score + 100 + (i * 100)
			var obs_y : int = screen_size.y - ground_height - (obs_height *obs_scale.y / 2)
			last_obs = obs
			add_obs(obs, obs_x, obs_y)
		#additionally random chance to spawn a bird - warn the player first.
		#Skip the roll entirely if a warning is already pending, otherwise
		#these fire far more often than a single warning cycle takes to
		#resolve, stacking multiple warnings on top of each other.
		if difficulty == MAX_DIFFICULTY and not pigeon_warning_pending:
			if (randi() % 2) == 0:
				var obs_y : int = bird_heights[randi() % bird_heights.size()]
				warn_and_spawn_pigeon(obs_y)

func warn_and_spawn_pigeon(obs_y : int) -> void:
	pigeon_warning_pending = true
	var warning = warning_scene.instantiate()
	
	# Parent to the camera (not the world) so it stays fixed on-screen at
	# the right edge for its full duration, instead of scrolling away.
	$Camera2D.add_child(warning)
	warning.position = Vector2(screen_size.x / 2.0 - 60, obs_y - $Camera2D.position.y)
	
	await get_tree().create_timer(1.0).timeout
	
	warning.queue_free()
	pigeon_warning_pending = false  # allow the next warning to be scheduled
	
	# Bail out if the run ended (or restarted) while we were waiting
	if not game_running:
		return
	
	# Recompute the spawn x now, using the current score - using the value
	# from a second ago would spawn the bird too close, defeating the warning
	var obs_x : int = screen_size.x + score + 100
	var obs = pigeon_scene.instantiate()
	add_obs(obs, obs_x, obs_y)

func add_obs(obs, x, y):
	obs.position = Vector2i(x,y)
	obs.add_to_group("obstacles")
	obs.body_entered.connect(hit_obs.bind(obs))
	add_child(obs)
	obstacles.append(obs)
	
func remove_obs(obs):
	obs.queue_free()
	obstacles.erase(obs)

func hit_obs(body, obstacle):
	# Prevent double-resolution: the shape cast pre-check and this Area2D
	# signal can both fire for the same obstacle within a frame or two.
	if obstacle.has_meta("resolved"):
		return
	
	var cat = get_node("Skateboard Cat")
	
	# Require the cat to actually be above the obstacle to count as a dive
	# bounce - otherwise pressing dive right before a head-on collision
	# would let players cheese any hit into a free bounce.
	var diving_from_above = cat.global_position.y < obstacle.global_position.y - 10
	
	if (cat.diving or cat.bounce_grace_timer > 0) and diving_from_above:
		obstacle.set_meta("resolved", true)
		score += dive_score_bonus
		cat.velocity.y = -1800
		cat.diving = false
		cat.can_rotate = true  # bounce counts as a new "jump" for trick purposes
		cat.bounce_grace_timer = cat.bounce_grace_time  # refresh the window for the next obstacle in the cluster
	elif body.name == "Skateboard Cat":
		obstacle.set_meta("resolved", true)
		cat.show_hurt()
		game_over()
	

func show_score():
	$HUD.get_node("ScoreLabel").text = "SCORE: " + str(score / SCORE_MODIFIER)
	$HUD.get_node("HighscoreLabel").text = "HIGH SCORE: " + str(high_score / SCORE_MODIFIER )
	
func adjust_difficulty():
	difficulty = score / SPEED_MODIFIER
	if difficulty > MAX_DIFFICULTY:
		difficulty = MAX_DIFFICULTY

func game_over():
	if game_over_triggered:
		return
	game_over_triggered = true
	game_running = false
	death_sequence()

func death_sequence():
	var cat = $"Skateboard Cat"
	
	# Freeze everything in place for a beat - same feel as the old instant
	# pause, except SceneTreeTimer keeps counting down even while paused
	get_tree().paused = true
	await get_tree().create_timer(1.0).timeout
	
	# Unpause so the cat can fall, and launch it with the game's current
	# forward speed as horizontal momentum plus a small upward pop.
	# "speed" is a per-frame pixel amount (added directly to position
	# elsewhere), but velocity here is per-second, so it needs scaling up.
	get_tree().paused = false
	cat.die(Vector2(speed * Engine.physics_ticks_per_second, -1000))
	
	# Wait until the cat has fully dropped below the bottom of the screen
	var bottom_edge = $Camera2D.position.y + (screen_size.y / 2.0) + 150
	while cat.global_position.y < bottom_edge:
		await get_tree().process_frame
	
	# Beat of empty screen before the restart button appears
	await get_tree().create_timer(1.0).timeout
	
	get_tree().paused = true
	$GameOver.show()
