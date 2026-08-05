extends CharacterBody2D

const GRAVITY : int = 4200
const JUMP_SPEED : int = -1800
var dive_speed : int = 3000
var diving : bool
var is_dead : bool = false
var is_ready : bool = true
var original_collision_layer : int
var original_collision_mask : int

#Rotation/trick variables
var rotation_speed : float = 360.0  # degrees per second when rotating
var is_rotating : bool = false
var total_rotation : float = 0.0  # tracks cumulative rotation in degrees
var completed_360s : int = 0  # number of full 360s completed this jump
var can_rotate : bool = false  # only rotate when in air
var trick_animation_playing : bool = false # blocks Idle/Jump/Skate from overwriting "Trick"
@export var trick_animations : Array[String] = ["Trick 1", "Trick 2", "Trick 3"]
@export var flash_scale : Vector2 = Vector2(0.3, 0.3)

@export var bounce_grace_time : float = 0.25
var bounce_grace_timer : float = 0.0

signal trick_completed(rotation_count)  # signal to notify main script

func _ready() -> void:
	original_collision_layer = collision_layer
	original_collision_mask = collision_mask
	
	$FlashSprite.top_level = true
	$FlashSprite.z_index = -1 # Draw Trick Flash behind cat
	$FlashSprite.hide()
	$FlashSprite.animation_finished.connect(_on_flash_animation_finished)
	$FlashSprite.animation_finished.connect(_on_sprite_animation_finished)

# Called every frame. "delta" is the elapsed time since the previous frame in game
func _physics_process(delta):
	velocity.y += GRAVITY * delta
	
	if is_dead:
		# skips all animation/state logic/ inputs to only enables gravity/falling
		$CatSprite.rotation_degrees += rotation_speed * delta
		move_and_slide()
		return
	
	if bounce_grace_timer > 0:
		bounce_grace_timer -= delta
	
	if diving:
		velocity.y = min(velocity.y, float(dive_speed))
	
	if is_on_floor():
		diving = false
	# reset rotation when landing
		if can_rotate:
			reset_rotation()
			can_rotate = false
	
		if not get_parent().game_running:
			if not trick_animation_playing:
				$"CatSprite".play("Idle") 
		else:
			if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up"):
				velocity.y = JUMP_SPEED
				$JumpSound.play()
				can_rotate = true # enable rotation when jumping
			elif not trick_animation_playing:
					$"CatSprite".play("Skateboarding") 
	else:
		if not trick_animation_playing:
			$"CatSprite".play("Jump") 
		
		# Handle rotation when in the air (using left/right arrow keys)
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
		
	# Keep the flash locked to our position (not rotation) while it's visible
	if $FlashSprite.visible:
		$FlashSprite.global_position = global_position
		$FlashSprite.rotation = 0
		$FlashSprite.scale = flash_scale
		
	if diving:
		$DiveShapeCast.target_position = Vector2(0, velocity.y * delta)
		$DiveShapeCast.force_shapecast_update()
		if $DiveShapeCast.is_colliding():
			for i in $DiveShapeCast.get_collision_count():
				var collider = $DiveShapeCast.get_collider(i)
				if collider.is_in_group("obstacles"):
					get_parent().hit_obs(self, collider)
					break
	
	move_and_slide()

func rotate_player(delta, direction):
	is_rotating = true
	var rotation_this_frame =  rotation_speed * delta * direction
	
	# Apply visual rotation
	$CatSprite.rotation_degrees += rotation_this_frame
	
	# Track total rotation (absolute value)
	total_rotation += abs(rotation_this_frame)
	
	# Check if we've completed a full 360
	if total_rotation >= 360.0:
		completed_360s += 1
		total_rotation -= 360.0  # keep remainder
		emit_signal("trick_completed", completed_360s)
		play_trick_effect()

func play_trick_effect():
	# Play trick animation of cat itself
	trick_animation_playing = true
	var anim_name = trick_animations[randi() % trick_animations.size()]
	$"CatSprite".play(anim_name)
	
	# Position and show the flash at the current spot, rotation locked to 0
	$FlashSprite.rotation = 0
	$FlashSprite.scale =  flash_scale
	$FlashSprite.global_position = global_position
	$FlashSprite.show()
	$FlashSprite.play("Trick flash")

	
func _on_sprite_animation_finished():
	if $"CatSprite".animation in trick_animations:
		trick_animation_playing = false

func _on_flash_animation_finished():
	$FlashSprite.hide()

func reset_rotation():
	# Snap rotation back to 0 when landing
	$CatSprite.rotation_degrees = 0
	total_rotation = 0.0
	completed_360s = 0
	is_rotating = false

func _on_dive_cooldown_timeout() -> void:
	is_ready = true

func show_hurt() -> void:
	$"CatSprite".play("Got Hit")

func die(momentum: Vector2) -> void:
	is_dead = true
	velocity = momentum
	collision_layer = 0
	collision_mask = 0
	
	$CatSprite.play("Dead")
	
func reset_death_state() -> void:
	is_dead = false
	collision_layer = original_collision_layer
	collision_mask = original_collision_mask
