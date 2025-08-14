extends CharacterBody2D

# 导出的变量可以在编辑器中直接修改
@export var move_range: int = 0
@export var attack_range: int = 0
@export var attack_power: int = 0
# 新增的变量，用于识别炮手
@export var is_artillery: bool = false 
# 这是一个用于跨格攻击的布尔值
@export var can_cross_grid: bool = false

# ... 你的移动和攻击逻辑 ...
