# 文件名：GameController.gd
extends Node2D

# 使用 @onready 确保在节点树准备好后获取节点引用
# my_tile_map 是棋盘的图块地图节点
@onready var my_tile_map: TileMapLayer = $TileMap/GridLayer
# cursor 是用来指示当前选中格子的光标
@onready var cursor: ColorRect = $Cursor
# action_menu 是当选中单位后弹出的操作菜单
@onready var action_menu = $ActionMenu
# 预加载状态菜单场景
var status_menu_scene = preload("res://scenes/status_menu.tscn") # 假设你的状态菜单场景名为 status_menu.tscn
# 存储当前显示的状态菜单实例，以便管理
var current_status_menu = null

# 存储当前选中的单位
var selected_unit = null
# 存储光标当前的网格坐标
var current_grid_pos: Vector2i = Vector2i.ZERO

# 定义单位的两种状态：准备行动、已移动、和已待机
enum UnitState {READY, MOVED, IDLE}

# 定义游戏状态的枚举，EXPLORING 是自由移动，MENU_ACTIVE 是菜单操作
enum GameState {
	EXPLORING,# 在棋盘上自由移动光标
	MENU_ACTIVE,
	MOVING_UNIT, # 移动单位状态
	ATTACKING_UNIT # 攻击单位状态
}
var current_game_state = GameState.EXPLORING
# 菜单中当前选中的按钮索引
var selected_menu_item_index = 0

# 预加载移动和攻击范围的高亮场景
var highlight_move_scene = preload("res://scenes/highlight_move.tscn")
var highlight_attack_scene = preload("res://scenes/highlight_attack.tscn")
# 用字典存储所有已生成的高亮节点，方便管理
var highlights = {}
# 定义阵营枚举
enum Faction {FACTION_1, FACTION_2}
# 当前行动的阵营
var current_faction = Faction.FACTION_1
# 存储所有单位的数组
var all_units = []

# 节点进入场景树时调用
func _ready():
	# 初始化光标位置为(0,0)
	update_cursor_position(Vector2i.ZERO)
	# 确保游戏开始时菜单是隐藏的
	hide_action_menu()
	# 遍历所有子节点，将单位添加到all_units数组中
	for child in get_children():
		if child is CharacterBody2D:
			all_units.append(child)
	
	# 启动第一个阵营的回合
	start_turn()


# 根据新的网格坐标更新光标在屏幕上的位置
func update_cursor_position(new_pos: Vector2i):
	# 更新当前网格坐标
	current_grid_pos = new_pos
	
	# 将网格坐标转换为世界坐标（即像素坐标）
	var new_world_pos = my_tile_map.map_to_local(new_pos)
	# 获取图块大小的一半，用于居中光标
	var tile_half_size = Vector2(my_tile_map.tile_set.tile_size.x / 2.0, my_tile_map.tile_set.tile_size.y / 2.0)
	
	# 设置光标位置，使其中心对齐到图块中心
	cursor.position = new_world_pos - tile_half_size
	
	print("当前光标网格坐标：", current_grid_pos)

# 显示操作菜单
func show_action_menu(unit):
	# 将菜单位置设置在光标当前位置
	action_menu.position = cursor.position
	# 显示菜单
	action_menu.visible = true
	
	# 获取菜单中的按钮节点
	var move_button = action_menu.get_node("MoveButton")
	var attack_button = action_menu.get_node("AttackButton")
	var idle_button = action_menu.get_node("IdleButton")
	var status_button = action_menu.get_node("StatusButton")

	# 重置所有按钮状态
	for button in action_menu.get_children():
		button.visible = true
		button.disabled = false

	if unit.state == UnitState.IDLE:
		move_button.disabled = true
		attack_button.disabled = true
		idle_button.disabled = true
	elif unit.state == UnitState.MOVED:
		# 单位已移动，直接隐藏移动按钮
		move_button.visible = false
	
	# 隐藏光标，因为焦点已转移到菜单
	cursor.visible = false
	for button in action_menu.get_children():
		# 确保按钮不自动获得焦点
		button.focus_mode = Control.FOCUS_NONE
		# 初始化菜单的选中状态
	selected_menu_item_index = 0
	# 更新菜单的视觉高亮
	update_menu_selection()

# 隐藏操作菜单
func hide_action_menu():
	# 隐藏菜单
	action_menu.visible = false
	# 清空选中的单位
	selected_unit = null
	# 清除所有高亮显示
	clear_highlight()
	# 重新显示光标
	cursor.visible = true
	# 恢复游戏状态为自由探索
	current_game_state = GameState.EXPLORING

# 清除所有高亮显示
func clear_highlight():
	# 遍历字典中的所有高亮节点，并释放它们
	for highlight in highlights.values():
		highlight.queue_free()
	# 清空字典
	highlights.clear()

# 在指定网格位置查找单位
func get_unit_at_position(grid_pos: Vector2i):
	# 遍历所有子节点
	for child in get_children():
		# 检查子节点是否为CharacterBody2D类型，并且其网格位置与光标位置相同
		if child is CharacterBody2D:
			if child.get_grid_position() == grid_pos:
				return child
	# 如果没有找到，返回null
	return null

# “移动”按钮被按下时调用
func _on_move_button_pressed():
	action_menu.visible = false
	
	if selected_unit:
		# 【修改点】调用新的寻路高亮函数
		highlight_movement_range(selected_unit)
		current_game_state = GameState.MOVING_UNIT
		cursor.visible = true

# “攻击”按钮被按下时调用
func _on_attack_button_pressed():
	action_menu.visible = false
	if selected_unit:
		highlight_attack_range(selected_unit)
		current_game_state = GameState.ATTACKING_UNIT
		cursor.visible = true
		
# "状态"按钮被按下时调用
func _on_status_button_pressed():
	if selected_unit:
		print("显示状态菜单")
		show_status_menu(selected_unit)
	
# “待机”按钮被按下时调用
func _on_idle_button_pressed():
	if selected_unit:
		selected_unit.state = UnitState.IDLE
		selected_unit.play_idle_animation()
		check_turn_end()
	hide_action_menu()

# 启动新回合
func start_turn():
	print("开始阵营 ", current_faction, " 的回合")
	for unit in all_units:
		# 【修复点】确保只有当前阵营的单位状态被设为 READY，其他单位保持 IDLE
		if get_unit_faction(unit) == current_faction:
			unit.state = UnitState.READY
			unit.play_default_animation()
		else:
			unit.state = UnitState.IDLE
			unit.play_idle_animation()


# 检查当前阵营是否所有单位都已行动
func check_turn_end():
	var all_idle = true
	for unit in all_units:
		if get_unit_faction(unit) == current_faction and (unit.state == UnitState.READY or unit.state == UnitState.MOVED):
			all_idle = false
			break
	
	if all_idle:
		end_turn()

# 结束当前回合并切换到下一个回合
func end_turn():
	print("阵营 ", current_faction, " 回合结束")
	if current_faction == Faction.FACTION_1:
		current_faction = Faction.FACTION_2
	else:
		current_faction = Faction.FACTION_1
	
	start_turn()

# 获取单位的阵营
# 【修复点】将你的原始逻辑和我的新逻辑合并，以确保所有情况都能正确处理
func get_unit_faction(unit):
	# 首先检查单位是否有自定义的 faction 属性或方法
	if unit.has_method("get_faction"):
		return unit.get_faction()
	
	# 如果没有，则使用你原来的命名规则来判断
	if unit.name.to_lower().contains("warrior") or unit.name.to_lower().contains("archer"):
		return Faction.FACTION_1
	elif unit.name.to_lower().contains("artillery"):
		return Faction.FACTION_2
	
	# 如果以上都不匹配，返回一个默认值，例如 null
	return null

# 使用 BFS 算法计算可移动的网格
func find_movable_tiles(start_pos: Vector2i, move_range: int, current_unit) -> Dictionary:
	var queue = []
	var visited = {} # 使用字典存储已访问的格子和对应的移动距离
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	
	queue.append([start_pos, 0]) # [位置, 移动距离]
	visited[start_pos] = 0
	
	while !queue.is_empty():
		var current = queue.pop_front()
		var pos = current[0]
		var dist = current[1]
		
		# 如果移动距离已超过最大范围，则停止探索
		if dist >= move_range:
			continue
			
		for dir in directions:
			var next_pos = pos + dir
			
			# 检查是否在地图范围内
			if next_pos.x >= 0 and next_pos.x < 10 and next_pos.y >= 0 and next_pos.y < 10:
				# 检查目标格子是否已访问过，或移动距离更短
				if not visited.has(next_pos) or visited[next_pos] > dist + 1:
					var unit_at_next_pos = get_unit_at_position(next_pos)
					
					# 检查格子是否可通行
					# 如果是空地，或上面是己方单位（但不能停留），则可通行
					if unit_at_next_pos == null or get_unit_faction(unit_at_next_pos) == get_unit_faction(current_unit):
						visited[next_pos] = dist + 1
						queue.append([next_pos, dist + 1])
						
	# 从结果中移除起始位置，因为单位不能移动到原地
	if visited.has(start_pos):
		visited.erase(start_pos)
	
	return visited

# 高亮显示单位的移动范围，使用新的寻路算法
func highlight_movement_range(unit):
	clear_highlight()
	
	# 获取可移动的格子
	var movable_tiles = find_movable_tiles(unit.get_grid_position(), unit.move_range, unit)
	
	for cell_pos in movable_tiles.keys():
		var unit_at_pos = get_unit_at_position(cell_pos)
		# 只高亮空地，因为单位不能移动到有其他单位的格子上
		if unit_at_pos == null:
			var new_highlight = highlight_move_scene.instantiate()
			var world_pos = my_tile_map.map_to_local(cell_pos) - Vector2(my_tile_map.tile_set.tile_size.x / 2.0, my_tile_map.tile_set.tile_size.y / 2.0)
			
			new_highlight.position = world_pos
			$HighlightContainer.add_child(new_highlight)
			highlights[cell_pos] = new_highlight

# 高亮显示单位的攻击范围
func highlight_attack_range(unit):
	clear_highlight()
	var grid_pos = unit.get_grid_position()
	var attack_range_value = unit.attack_range
	
	for x in range(-attack_range_value, attack_range_value + 1):
		for y in range(-attack_range_value, attack_range_value + 1):
			if abs(x) + abs(y) <= attack_range_value:
				var cell_pos = grid_pos + Vector2i(x, y)
				if cell_pos.x >= 0 and cell_pos.x < 10 and cell_pos.y >= 0 and cell_pos.y < 10:
					var new_highlight = highlight_attack_scene.instantiate()
					var world_pos = my_tile_map.map_to_local(cell_pos) - Vector2(my_tile_map.tile_set.tile_size.x / 2.0, my_tile_map.tile_set.tile_size.y / 2.0)
					
					new_highlight.position = world_pos
					$HighlightContainer.add_child(new_highlight)
					highlights[cell_pos] = new_highlight
					
# 更新菜单中选中的按钮的视觉状态
func update_menu_selection():
	var visible_menu_items = []
	for button in action_menu.get_children():
		if button.visible:
			visible_menu_items.append(button)
			
	var menu_size = visible_menu_items.size()
	
	if menu_size == 0:
		return

	for i in range(menu_size):
		var button = visible_menu_items[i]
		if i == selected_menu_item_index:
			button.grab_focus()
			button.add_theme_color_override("font_color", Color.YELLOW)
		else:
			button.release_focus()
			button.add_theme_color_override("font_color", Color.WHITE)

# 处理玩家输入
func _input(event):
	if event is InputEventKey and event.pressed:
		match current_game_state:
			GameState.EXPLORING:
				var new_pos = current_grid_pos
				
				if event.keycode == KEY_UP:
					new_pos.y -= 1
				elif event.keycode == KEY_DOWN:
					new_pos.y += 1
				elif event.keycode == KEY_LEFT:
					new_pos.x -= 1
				elif event.keycode == KEY_RIGHT:
					new_pos.x += 1
				
				new_pos.x = clamp(new_pos.x, 0, 9)
				new_pos.y = clamp(new_pos.y, 0, 9)

				if new_pos != current_grid_pos:
					update_cursor_position(new_pos)
				
				if event.is_action_pressed("ui_accept"):
					var unit_at_cursor = get_unit_at_position(current_grid_pos)
					if unit_at_cursor:
						if unit_at_cursor.state == UnitState.IDLE:
							print("单位已待机，显示状态")
							show_status_menu(unit_at_cursor)
							current_game_state = GameState.MENU_ACTIVE
						elif get_unit_faction(unit_at_cursor) == current_faction and (unit_at_cursor.state == UnitState.READY or unit_at_cursor.state == UnitState.MOVED):
							selected_unit = unit_at_cursor
							print("选中棋子：", selected_unit.name)
							show_action_menu(selected_unit)
							current_game_state = GameState.MENU_ACTIVE
							selected_menu_item_index = 0
							update_menu_selection()
						else:
							print("该单位不属于当前阵营或已待机")
					else:
						hide_action_menu()
			
			GameState.MENU_ACTIVE:
				if current_status_menu:
					if event.is_action_pressed("ui_cancel"):
						current_status_menu.queue_free()
						current_status_menu = null
						if selected_unit:
							show_action_menu(selected_unit)
						else:
							hide_action_menu()
							cursor.visible = true
							current_game_state = GameState.EXPLORING
				else:
					var visible_menu_items = []
					for button in action_menu.get_children():
						if button.visible:
							visible_menu_items.append(button)
					
					var menu_size = visible_menu_items.size()
					
					if menu_size == 0:
						return

					if event.keycode == KEY_UP:
						selected_menu_item_index = wrapi(selected_menu_item_index - 1, 0, menu_size)
						update_menu_selection()
					elif event.keycode == KEY_DOWN:
						selected_menu_item_index = wrapi(selected_menu_item_index + 1, 0, menu_size)
						update_menu_selection()
					elif event.is_action_pressed("ui_accept"):
						visible_menu_items[selected_menu_item_index].emit_signal("pressed")
					elif event.is_action_pressed("ui_cancel"):
						hide_action_menu()
			
			GameState.MOVING_UNIT:
				var new_pos = current_grid_pos

				if event.keycode == KEY_UP:
					new_pos.y -= 1
				elif event.keycode == KEY_DOWN:
					new_pos.y += 1
				elif event.keycode == KEY_LEFT:
					new_pos.x -= 1
				elif event.keycode == KEY_RIGHT:
					new_pos.x += 1

				if new_pos != current_grid_pos and highlights.has(new_pos):
					update_cursor_position(new_pos)

				if event.is_action_pressed("ui_accept"):
					if highlights.has(current_grid_pos):
						if get_unit_at_position(current_grid_pos) == null:
							move_unit_to(selected_unit, current_grid_pos)
							selected_unit.state = UnitState.MOVED
							clear_highlight()
							show_action_menu(selected_unit)
							current_game_state = GameState.MENU_ACTIVE
						else:
							print("无法移动到有单位的格子。")
					else:
						print("无法移动到该位置。")
					
				elif event.is_action_pressed("ui_cancel"):
					clear_highlight()
					current_game_state = GameState.EXPLORING
					selected_unit = null

			GameState.ATTACKING_UNIT:
				var new_pos = current_grid_pos

				if event.keycode == KEY_UP:
					new_pos.y -= 1
				elif event.keycode == KEY_DOWN:
					new_pos.y += 1
				elif event.keycode == KEY_LEFT:
					new_pos.x -= 1
				elif event.keycode == KEY_RIGHT:
					new_pos.x += 1

				if new_pos != current_grid_pos and highlights.has(new_pos):
					update_cursor_position(new_pos)
				
				if event.is_action_pressed("ui_accept"):
					if highlights.has(current_grid_pos):
						var target_unit = get_unit_at_position(current_grid_pos)
						if target_unit and get_unit_faction(target_unit) != current_faction:
							execute_attack(selected_unit, target_unit)
						else:
							print("无法攻击该位置的单位。")
					else:
						print("无法攻击该位置。")
					
					clear_highlight()
					if selected_unit:
						selected_unit.state = UnitState.IDLE
						selected_unit.play_idle_animation()
					check_turn_end()
					current_game_state = GameState.EXPLORING
					selected_unit = null
					
				elif event.is_action_pressed("ui_cancel"):
					clear_highlight()
					current_game_state = GameState.EXPLORING
					selected_unit = null

func show_status_menu(unit):
	if current_status_menu:
		current_status_menu.queue_free()

	var status_menu_instance = status_menu_scene.instantiate()
	
	action_menu.visible = false
	
	add_child(status_menu_instance)
	print("状态菜单实例已创建并添加到场景树: ", status_menu_instance)

	var status_menu_panel = status_menu_instance.get_node("Panel")
	if status_menu_panel:
		status_menu_panel.position = cursor.position
	
	var unit_name_label = status_menu_instance.get_node("Panel/UnitNameLabel")
	if unit_name_label:
		unit_name_label.text = "单位名称：" + unit.name
	cursor.visible = false

	current_game_state = GameState.MENU_ACTIVE

	current_status_menu = status_menu_instance
	
func move_unit_to(unit, target_pos: Vector2i):
	var new_world_pos = my_tile_map.map_to_local(target_pos)
	unit.position = new_world_pos
	
	print("单位 ", unit.name, " 已移动到 ", target_pos)

func execute_attack(attacker, target):
	print(attacker.name, " 攻击了 ", target.name)
	print("攻击成功！在这里添加伤害计算、生命值扣除等逻辑。")
