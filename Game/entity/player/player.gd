extends CharacterBody2D

# 320 x 180

# floor check raycast
@onready var floorCast = $RayCast2D
@onready var anim = $AnimationPlayer
@onready var floorParticles = $groundParticles
@onready var timer = $stateTimer

@export var SPEED : float= 100
@export var AIRSPEED : float = 150
@export var ROLLSPEED: float=150
@export var ACCEL : float = 30
@export var ROLLACCEL : float = 60
@export var AIRACCEL : float = 4
@export var FRICTION : float = 2
@export var JUMP_VELOCITY : float = -80

# relative velocity, what rotation applies to to get global velocity
var relVel = Vector2(0, 0)

var facingL : bool = false
var standHeightOffset : int = 3
var reqMove : Vector2 = Vector2.ZERO
var reqJump : bool = false
var state = IDLE
var floored = false
var reqRoll = false
var changeState = true

var timerState = state

var states = ["IDLE", "RUN", "SKID", "JUMP", "AIR", "LAND", "ROLL", "AIRROLL"]
enum {IDLE, RUN, SKID, JUMP, AIR, LAND, ROLL, AIRROLL}

# Get the gravity from the project settings to be synced with RigidBody nodes.
var GRAV = 2
var FALLGRAV = 7


func _physics_process(delta):
	floored = isOnFloor()
	relVel = velocity.rotated(-rotation)
	reqMove = Input.get_vector("l", "r", "d", "u")
	reqJump = Input.is_action_just_pressed("jump")
	reqRoll = Input.is_action_pressed("roll")
	
	
	if(abs(velocity.x) > SPEED and floored):
		floorParticles.emitting = true
	else:
		floorParticles.emitting = false
	
	if(reqMove.x < 0):
		facingL = true
	if(reqMove.x > 0):
		facingL = false
	# state machine
	# states are set when another one is run
	
	match state:
		IDLE:
			idle(delta)
		RUN:
			run(delta)
		SKID:
			skid(delta)
		JUMP:
			jump(delta)
		AIR:
			air(delta)
		LAND:
			land(delta)
		ROLL:
			roll(delta)
		AIRROLL:
			airroll(delta)
	
	velocity = relVel.rotated(rotation)
	up_direction = Vector2.UP.rotated(rotation)
	
	move_and_slide()

# ----- STATES -----------------------------------------------------------------

func idle(delta) -> void:
	if(floored):
		
		# move
		
		relVel.x = move_toward(relVel.x, 0, FRICTION)
		snapToFloor(delta)
		rotToFloor(delta, .05 * relVel.length())
		relVel.y = 0
		
		# state management
		
		
		if(reqMove.x != 0):
			state = RUN
		if(reqJump == true):
			state = JUMP
	else:
		state = AIR
	
	
	# Animation
	if(facingL):
		anim.play("idleL")
	else:
		anim.play("idleR")

func run(delta) -> void:
	if(floored):
		
		# move
		relVel.x = move_toward(relVel.x, reqMove.x * SPEED, ACCEL)
		if(!reqJump):
			relVel.x *= 1.1
			snapToFloor(delta)
			rotToFloor(delta, .05 * relVel.length())
		
		relVel.y = 0
		
		# state management
		if(abs(relVel.x) > SPEED):# if speed is greater than desired
			if(sign(relVel.x) != sign(reqMove.x)):
				state = SKID
				return
		if(reqMove.x == 0):
			state = IDLE
			return
		if(reqJump == true):
			state = JUMP
			return
	else:
		state = AIR
	
	# Animation
	
	anim.set_speed_scale(relVel.length() * .03)
	if(facingL):
		anim.play("runL")
	else:
		anim.play("runR")

func skid(delta) -> void:
	
	# move
	if floored:
		relVel.x = move_toward(relVel.x, reqMove.x, FRICTION * 8)
		snapToFloor(delta)
		rotToFloor(delta, .05 * relVel.length())
		
	# state management
	
		if(abs(relVel.x) < abs(reqMove.x) * SPEED / 2):
			state = RUN
			return
		if(abs(relVel.x) < FRICTION):
			state = IDLE
			return
	else:
		state = AIR
		return
	# Animation
	if(facingL):# invert sprite based on input
		anim.play("skidR")
	else:
		anim.play("skidL")

func jump(delta) -> void:
	# there's a much better way to store data for this type of thing
	# move
	rotation = move_toward(rotation, 0, delta * 10)
	# state management
	if(timer.is_stopped() and timerState == JUMP):
		timerState = -1
		position -= Vector2(0, 6).rotated(rotation)
		relVel.y = JUMP_VELOCITY
		relVel.x = reqMove.x * SPEED
		state = AIR
		return
	else:
		relVel.x = move_toward(relVel.x, max(relVel.x, reqMove.x * SPEED), FRICTION)
	
	if(timerState != JUMP):
		timerState = JUMP
		timer.wait_time = .05
		timer.start()
	# Animation
	if(facingL):
		if(anim.current_animation != "jumpL"):
			anim.play("jumpL")
	else:
		if(anim.current_animation != "jumpR"):
			anim.play("jumpR")

func air(delta) -> void:
	# move
	if(sign(reqMove.x) - sign(relVel.x) == 0):
		relVel.x = move_toward(relVel.x, reqMove.x * AIRSPEED, AIRACCEL)
	else:
		relVel.x = move_toward(relVel.x, reqMove.x * AIRSPEED, AIRACCEL * 2.5)
	rotation = move_toward(rotation, 0, delta * 6)
	if(is_on_ceiling()):
		relVel.y = max(JUMP_VELOCITY, abs(relVel.y))
	if(Input.is_action_pressed("jump") and relVel.y < 20):
		relVel.y += GRAV
	else:
		relVel.y += FALLGRAV
	
	# state stuff -----
	if(floored):
		if(relVel.y > 0 or !reqJump):
			state = LAND
			return
	
	# ----- Animation -----
	anim.set_speed_scale(4)
	anim.stop()
	if(facingL):
		anim.play("airL")
		anim.seek(.001 * relVel.y + .2, true)
	else:
		anim.play("airR")
		anim.seek(.001 * relVel.y + .2, true)

func land(delta) -> void:
	
	relVel.y = 0
	snapToFloor(delta)
	if(timerState != JUMP):
		timerState = JUMP
		timer.wait_time = .1
		timer.start()
		
	# states
	if(abs(reqMove.x) > 0):
		relVel.x += sqrt(abs(relVel.y) * SPEED) * sign(reqMove.x)
		timerState = -1
		state = RUN
		return
	elif(reqJump):
		timerState = -1
		state = JUMP
		return
	else:
		if(timer.is_stopped() and timerState == JUMP):
			timerState = -1
			state = IDLE
			return
	
	# Animation
	
	if(facingL):
		anim.play("landL")
	else:
		anim.play("landR")

func roll(delta) -> void:
	if(abs(relVel.x) < SPEED):
		state = AIRROLL
		relVel.x = move_toward(relVel.x, ROLLSPEED * reqMove.x, ROLLACCEL)
		relVel.y = -1/relVel.x * 10

func airroll(delta) -> void:
	pass

# ----- MISC FUNCTIONS ---------------------------------------------------------
func snapToFloor(delta) -> void:
	#if(floorCast.get_collision_point.distance_to(position)):
	position += (floorCast.target_position.length() - standHeightOffset - floorCast.global_position.distance_to(floorCast.get_collision_point()))  * floorCast.get_collision_normal()

func rotToFloor(delta, speed) -> void:
	rotation = move_toward(rotation, floorCast.get_collision_normal().rotated(PI).angle() - PI/2, delta * speed)
	up_direction = Vector2(0, -1).rotated(rotation)

func isOnFloor() -> bool:
	# checks if raycast hits anything
	return floorCast.global_position.distance_to(floorCast.get_collision_point()) < floorCast.target_position.length()
