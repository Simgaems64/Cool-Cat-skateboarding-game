extends CharacterBody2D

const GRAVITY : int = 4200
const JUMP_SPEED : int = -1800
var dive_speed : int = 4200
var diving : bool
var is_ready : bool = true

# Rotation/trick variables
var rotation_speed : float = 360.0  # degrees per second when rotating
var is_rotating : bool = false
var total_rotation : float = 0.0  # tracks cumulative rotation in degrees
var completed_360s : int = 0  # number of full 360s completed this jump
var can_rotate : bool = false  # only rotate when in air

signal trick_completed(rotation_count)  # signal to notify main script

# Called every frame. "delta" is the elapsed time since the previous frame in game
func _physics_process(delta):
	velocity.y += GRAVITY * delta
	
	if is_on_floor():
		diving = false
		# Reset rotation when landing
		if can_rotate:
			reset_rotation()
			can_rotate = false
		
		if not get_parent().game_running:
			$"AnimatedSprite2D".play("Idle") 
		else:
			if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up"):
				velocity.y = JUMP_SPEED
				$JumpSound.play()
				can_rotate = true  # enable rotation when jumping
			else: 
				$"AnimatedSprite2D".play("Skateboarding") 
	else:
		$"AnimatedSprite2D".play("Jump")
		
		# Handle rotation in air (using left/right keys)
		if can_rotate:
			if Input.is_action_pressed("ui_left"):
				rotate_player(delta, -2)
			elif Input.is_action_pressed("ui_right"):
				rotate_player(delta, 2)
	
	if Input.is_action_just_pressed("ui_down") && is_ready == true:
		is_ready = false
		diving = true
		velocity.y = dive_speed
		$DiveCooldown.start()
	
	move_and_slide()

func rotate_player(delta, direction):
	is_rotating = true
	var rotation_this_frame = rotation_speed * delta * direction
	
	# Apply visual rotation
	rotation_degrees += rotation_this_frame
	
	# Track total rotation (absolute value)
	total_rotation += abs(rotation_this_frame)
	
	# Check if we've completed a full 360
	if total_rotation >= 360.0:
		completed_360s += 1
		total_rotation -= 360.0  # keep remainder
		emit_signal("trick_completed", completed_360s)

func reset_rotation():
	# Snap rotation back to 0 when landing
	rotation_degrees = 0
	total_rotation = 0.0
	completed_360s = 0
	is_rotating = false

func _on_dive_cooldown_timeout() -> void:
	is_ready = true
