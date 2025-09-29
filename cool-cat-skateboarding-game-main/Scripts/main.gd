extends Node

#preload obstacles
var fire_hydrant_scene = preload("res://Scenes/Fire_Hydrant.tscn")
var pigeon_scene = preload("res://Scenes/pigeon.tscn")
var placeholder_pat_scene = preload("res://Scenes/Placeholder_Pat.tscn")
var obstacle_types := [fire_hydrant_scene, placeholder_pat_scene]
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
var high_score : int = 0
const SCORE_MODIFIER : int = 30
var game_running : bool
var last_obs

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_window().size
	ground_height = $Ground.get_node("Sprite2D").texture.get_height()
	$GameOver.get_node("RestartButton").pressed.connect(new_game)
	new_game()
	
	
func new_game():
	$"Skateboard Cat/AnimatedSprite2D".play("Idle") 
	if score > high_score:
		high_score = score
	score = 0
	show_score()
	game_running = false
	get_tree().paused = false
	difficulty = 0
	
	#delete all obstacles
	for obs in obstacles:
		obs.queue_free()
	obstacles.clear()
	
	#reset the nodes
	$"Skateboard Cat".position = CAT_START_POS 
	$"Skateboard Cat".velocity = Vector2i(0,0)
	$Camera2D.position = CAM_START_POS
	$Ground.position = Vector2i(0,0)
	
	#reset hud and game over screen
	$HUD.get_node("StartLabel").show()
	$GameOver.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Check for input to start the game when not running
	if not game_running:
		if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up"):
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
		#additionally random chance to spawn a bird
		if difficulty == MAX_DIFFICULTY:
			if (randi() % 2) == 0:
				#generate bird obstacles
				obs = pigeon_scene.instantiate()
				var obs_x : int = screen_size.x + score + 100
				var obs_y : int = bird_heights[randi() % bird_heights.size()]
				add_obs(obs, obs_x, obs_y)

func add_obs(obs, x, y):
	obs.position = Vector2i(x,y)
	obs.body_entered.connect(hit_obs)
	add_child(obs)
	obstacles.append(obs)
	
func remove_obs(obs):
	obs.queue_free()
	obstacles.erase(obs)

func hit_obs(body):
	if get_node("Skateboard Cat").diving == true:
		score += dive_score_bonus
		$"Skateboard Cat".velocity.y = -1800
	elif body.name == "Skateboard Cat":
		game_over()
	

func show_score():
	$HUD.get_node("ScoreLabel").text = "SCORE: " + str(score / SCORE_MODIFIER)
	$HUD.get_node("HighscoreLabel").text = "HIGH SCORE: " + str(high_score / SCORE_MODIFIER )
	
func adjust_difficulty():
	difficulty = score / SPEED_MODIFIER
	if difficulty > MAX_DIFFICULTY:
		difficulty = MAX_DIFFICULTY

func game_over():
	get_tree().paused = true
	game_running = false
	$GameOver.show()
	
