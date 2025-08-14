# unit.gd
extends CharacterBody2D

# 导出的变量可以在编辑器中直接修改
@export var move_range: int = 0
@export var attack_range: int = 0
@export var attack_power: int = 0
@export var is_artillery: bool = false
@export var can_cross_grid: bool = false

# 状态枚举
enum UnitState {READY, IDLE}
var state = UnitState.READY
@onready var animated_sprite = $Sprite2D/AnimatedSprite2D
# 新增：获取单位的网格坐标
func get_grid_position() -> Vector2i:
	# 假设父节点是 TileMap，你可以使用其 `local_to_map` 方法
	# return get_parent().local_to_map(position)
	
	# 更通用的方法是直接计算
	# 瓦片大小是16，所以将世界坐标除以16
	var tile_size = 16
	return Vector2i(floor(position.x / tile_size), floor(position.y / tile_size))

# 新增：播放待机动画
func play_default_animation():
	if animated_sprite:
		animated_sprite.play("default")

# 播放待机动画
func play_idle_animation():
	if animated_sprite:
		animated_sprite.play("idle")
