extends CharacterBody3D

# ---------- VARIABLES ---------- #

@export_category("Player Properties")
@export var move_speed : float = 6
@export var jump_force : float = 15
@export var follow_lerp_factor : float = 4
@export var jump_limit : int = 3   # จำนวนครั้งที่สามารถกระโดดได้

@export_group("Game Juice")
@export var jumpStretchSize := Vector3(0.8, 1.2, 0.8)

# Booleans
var is_grounded = false
var jumps_left : int = 0   # ตัวนับจำนวนกระโดดที่เหลือ

# Onready Variables
@onready var model = $gobot
@onready var animation = $gobot/AnimationPlayer
@onready var spring_arm = %Gimbal

@onready var particle_trail = $ParticleTrail
@onready var footsteps = $Footsteps

# Get the gravity from the project settings
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2

# ---------- FUNCTIONS ---------- #

func _process(delta):
	player_animations()
	get_input(delta)
	
	# Smooth follow
	spring_arm.position = lerp(spring_arm.position, position, delta * follow_lerp_factor)
	
	# Player rotation
	if is_moving():
		var look_direction = Vector2(velocity.z, velocity.x)
		model.rotation.y = lerp_angle(model.rotation.y, look_direction.angle(), delta * 12)
	
	# Check grounded
	is_grounded = is_on_floor()
	if is_grounded:
		jumps_left = jump_limit
	
	# Handle Jump
	if Input.is_action_just_pressed("jump") and jumps_left > 0:
		do_jump()
		jumps_left -= 1
	
	velocity.y -= gravity * delta


# เลือกว่าจะเล่น jump ไหน
func do_jump():
	if jumps_left == jump_limit:
		perform_jump()          # กระโดดครั้งแรก
	elif jumps_left == 1:
		perform_flip_jump()     # กระโดดครั้งสุดท้าย
	else:
		perform_mid_jump()      # กระโดดกลางอากาศ


func perform_jump():
	AudioManager.jump_sfx.play()
	AudioManager.jump_sfx.pitch_scale = 1.12
	jumpTween()
	animation.play("Jump")
	velocity.y = jump_force


func perform_mid_jump():
	AudioManager.jump_sfx.play()
	AudioManager.jump_sfx.pitch_scale = 1.0
	jumpTween()
	animation.play("Jump", 0.5)
	velocity.y = jump_force


func perform_flip_jump():
	AudioManager.jump_sfx.play()
	AudioManager.jump_sfx.pitch_scale = 0.8
	animation.play("Flip", -1, 2)
	velocity.y = jump_force
	await animation.animation_finished
	animation.play("Jump", 0.5)


func is_moving():
	return abs(velocity.z) > 0 or abs(velocity.x) > 0


func jumpTween():
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", jumpStretchSize, 0.1)
	tween.tween_property(self, "scale", Vector3(1,1,1), 0.1)


# Get Player Input
func get_input(_delta):
	var move_direction := Vector3.ZERO
	move_direction.x = Input.get_axis("move_left", "move_right")
	move_direction.z = Input.get_axis("move_forward", "move_back")
	
	move_direction = move_direction.rotated(Vector3.UP, spring_arm.rotation.y).normalized()
	velocity = Vector3(move_direction.x * move_speed, velocity.y, move_direction.z * move_speed)
	move_and_slide()


# Handle Player Animations
func player_animations():
	particle_trail.emitting = false
	footsteps.stream_paused = true
	
	if is_on_floor():
		if is_moving():
			animation.play("Run", 0.5)
			particle_trail.emitting = true
			footsteps.stream_paused = false
		else:
			animation.play("Idle", 0.5)
