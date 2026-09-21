class_name GoblinArrow extends EnemyProjectile

@export var arrow_speed: float = 420.0

func _ready() -> void:
	speed = arrow_speed
	super._ready()
	rotation = direction.angle()

func launch(value: Vector2, owner_enemy: Node2D = null) -> void:
	super.launch(value, owner_enemy)
	rotation = direction.angle()

func deflect() -> bool:
	var succeeded: bool = super.deflect()
	if succeeded: rotation = direction.angle()
	return succeeded

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	rotation = direction.angle()
