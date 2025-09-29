extends CharacterBody2D

const GRAVITY : int = 4200
const JUMP_SPEED : int = -1800
var dive_speed : int = 4200
var diving : bool
var is_ready : bool = true

# Called every frame. "delta" is the elapsed time since the previous frame in game
func _physics_process(delta):
	velocity.y += GRAVITY * delta
	if is_on_floor():
		diving = false
		if not get_parent().game_running:
			$"AnimatedSprite2D".play("Idle") 
		else:
			if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up"):
				velocity.y = JUMP_SPEED
				$JumpSound.play()
			else: 
				$"AnimatedSprite2D".play("Skateboarding") 
	else:
			$"AnimatedSprite2D".play("Jump") 
		
	if Input.is_action_just_pressed("ui_down") && is_ready == true:
		is_ready = false
		diving = true
		velocity.y = dive_speed
		$DiveCooldown.start()
		
		
	move_and_slide()


func _on_dive_cooldown_timeout() -> void:
	is_ready = true
