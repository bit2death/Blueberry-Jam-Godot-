extends Camera2D

@onready var player = get_tree().get_nodes_in_group("Player")
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position = getAvgPos(player)

func getAvgPos(itemArr) -> Vector2:
	var avgPos : Vector2 = Vector2(0, 0)
	for i in itemArr:
		avgPos += i.position
	avgPos /= itemArr.size()
	return avgPos
