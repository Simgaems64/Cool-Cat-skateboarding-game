extends CharacterBody2D

const GRAVITY : int = 4200
const JUMP_SPEED : int = -1800
var dive_speed : int = 4200

# Called every frame. "delta" is the elapsed time since the previous frame in game
func _physics_process(delta):
	velocity.y += GRAVITY * delta
	if is_on_floor():
		if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("ui_up"):
			velocity.y = JUMP_SPEED
			$JumpSound.play()
	else:
		#eventually replace with proper jumping animation
		$AnimatedSprite2D.play("Skateboarding") 
		if Input.is_action_pressed("ui_down"): 
			velocity.y = dive_speed
		
	move_and_slide()
