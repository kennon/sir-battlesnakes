POSSIBLE_MOVES = %w[up down left right]
ME_SYMBOL = 'I'
ENEMY_SYMBOLS = %w[A B C D E F G H]
FOOD_SYMBOL = '.'
HAZARD_SYMBOL = 'X'

def find_next_move(gamestate)
  board = !!gamestate && gamestate[:board]
  return nil unless board
  snake_name = gamestate[:you][:name]

  map, current_loc = find_map(gamestate)
  # puts_map(map)

  puts "#{snake_name}: current_loc: (%i,%i)" % current_loc.reverse

  sir_robin(gamestate, map, current_loc)
end

def sir_robin(gamestate, map, current_loc)
  # pseudocode:
  # 1. if health < 20, go towards food
  # 1. else find nearest enemy
  # 1. avoid it!

  health = gamestate[:you][:health]

  if health >= 50
    return avoid_enemies(gamestate, map, current_loc)

  elsif health < 20
    food_loc, _ = find_nearest(map, current_loc, [FOOD_SYMBOL])

    if !food_loc
      move = avoid_enemies(gamestate, map, current_loc)
      puts "!! No food available, so using avoid_enemies: %s" % move
      return move
    end

    puts "nearest food_loc: (%i,%i)" % food_loc.reverse

    # valid move towards food
    move = find_valid_heading(map, current_loc, food_loc)

    if move.nil?
      move = find_escape(map, current_loc)
      puts "!!! Can't find valid path to food, so trying to escape to the: %s" % move
      return move
    end

    return move
  else
    return seek_food(gamestate, map, current_loc)
  end
end

# pseudocode:
# 1. find nearest food
# 1. plot path to food
# 1. if enemy head is adjacent to target square, avoid enemy to prevent head-to-head collision
def seek_food(gamestate, map, current_loc)
  food_loc, _ = find_nearest(map, current_loc, [FOOD_SYMBOL])

  if !food_loc
    move = random_move
    puts "!! Can't find food, punting with %s" % move
    return move
  end

  puts "nearest food_loc: (%i,%i)" % food_loc.reverse

  # valid move towards food
  move = find_valid_heading(map, current_loc, food_loc)

  if move.nil?
    move = find_escape(map, current_loc)
    puts "!!! Can't find valid path to food, so trying to escape to the: %s" % move
    return move
  end

  next_loc = find_next_loc(map, current_loc, move)

  enemy_loc, distance = find_nearest(map, next_loc, ENEMY_SYMBOLS)

  if enemy_loc && distance < 1.5 # i.e. 1 square diagonal distance
    move = find_valid_heading(map, current_loc, enemy_loc, true)
    puts "!!!!! ENEMY PROXMITY ALERT! avoiding to the: %s" % move
  end

  if move.nil?
    move = find_escape(map, current_loc)
    puts "!!! Can't find valid path to food, so trying to escape to the: %s!" % move
    return move
  end

  move
end

def avoid_enemies(gamestate, map, current_loc)
  # pseudocode:
  # 1. find nearest enemy
  # 1. avoid it!

  enemy_loc, _ = find_nearest(map, current_loc, ENEMY_SYMBOLS)
  
  if enemy_loc
    move = find_valid_heading(map, current_loc, enemy_loc, true)
  end



  if move.nil?
    move = find_escape(map, current_loc)
    puts "!!! Can't find valid path away from enemies, so trying to escape to the %s!" % move
    return move
  end

  move
end


def find_map(gamestate)
  board = gamestate[:board]
  height = board[:height]
  width = board[:width]

  # matrix = Matrix.build(height, width) { 0 }
  map = Array.new(width) { Array.new(height, nil) }
  current_loc = nil

  snakes = {}

  # add food
  board[:food].each do |loc|
    map[loc[:y]][loc[:x]] = FOOD_SYMBOL
  end

  # add hazards
  board[:hazards].each do |loc|
    map[loc[:y]][loc[:x]] = HAZARD_SYMBOL
  end

  me_snake = gamestate[:you]
  current_loc = add_snake_to_map!(map, me_snake, ME_SYMBOL)

  board[:snakes].each_with_index do |snake, i|
    next if snake[:id] == me_snake[:id]
    add_snake_to_map!(map, snake, ENEMY_SYMBOLS[i])
  end

  [map, current_loc]
end

def add_snake_to_map!(map, snake, character)
  head_loc = nil

  size_y, size_x = map_dimensions(map)

  snake[:body].each_with_index do |loc, i|
    next unless loc && loc[:y] && loc[:x] && loc[:y] >= 0 && loc[:x] >= 0 && loc[:y] < size_y && loc[:x] < size_x
    
    if i == 0
      head_loc = [loc[:y], loc[:x]]
      map[loc[:y]][loc[:x]] ||= character.upcase
    else
      map[loc[:y]][loc[:x]] ||= character.downcase
    end
  end

  head_loc
end

def distance_xy(x1, y1, x2, y2)
  return Math.sqrt(
    ((x2 - x1) ** 2) + ((y2 - y1) ** 2)
  )
end

def distance(loc1, loc2)
  return Math.sqrt(
    ((loc2[1] - loc1[1]) ** 2) + ((loc2[0] - loc1[0]) ** 2)
  )
end

def find(map, target)
  map.each_with_index do |rows, y|
    rows.each_with_index do |cell, x|
      return [y,x] if cell == target
    end
  end
end

def find_nearest(map, current_loc, targets)
  found_targets = []
  map.each_with_index do |rows, y|
    rows.each_with_index do |cell, x|
      if cell.in?(targets)
        loc = [y,x]
        found_targets << [loc, distance(current_loc, loc)]
      end
    end
  end

  return [nil, nil] unless found_targets.any?

  found_targets.sort_by do |((y, x), distance)|
    distance
  end.first
end

def random_move
  POSSIBLE_MOVES.sample
end

def heading(loc1, loc2)
  dist_y = (loc2[0] - loc1[0]).abs
  dist_x = (loc2[1] - loc1[1]).abs

  puts "dist_x: %i, dist_y: %i" % [dist_x, dist_y]

  if dist_y > dist_x
    if loc2[0] > loc1[0]
      return 'up'
    else
      return 'down'
    end
  else
    if loc2[1] > loc1[1]
      return 'right'
    else
      return 'left'
    end
  end
end

def find_valid_heading(map, loc1, loc2, avoid = false)
  y1, x1 = loc1
  y2, x2 = loc2
  dist_y = (y2 - y1).abs
  dist_x = (x2 - x1).abs

  puts "(x1,y1): (%i,%i) (x2,y2): (%i,%i)" % [x1,y1,x2,y2]
  puts "dist_x: %i, dist_y: %i" % [dist_x, dist_y]

  moves = [
    ['up', (y2 - y1)],
    ['down', (y1 - y2)],
    ['left', (x1 - x2)],
    ['right', (x2 - x1)],
  ]

  valid_moves = moves.select do |(move, _)|
    !collision?(map, loc1, move)
  end.sort_by do |(move, priority)|
    priority
  end

  if !avoid
    valid_moves = valid_moves.reverse
  end

  move = valid_moves&.first&.first

  puts "find_valid_heading: %s" % move

  move
end

def find_next_loc(map, loc, move)
  y, x = loc

  case move
  when 'up'
    next_y = y+1
    next_x = x
  when 'down'
    next_y = y-1
    next_x = x
  when 'left'
    next_y = y
    next_x = x-1
  when 'right'
    next_y = y
    next_x = x+1
  else
    raise ArgumentError, "! invalid move (#{move}) specified"
  end

  size_y, size_x = map_dimensions(map)

  return nil if next_y < 0 || next_y >= size_y
  return nil if next_x < 0 || next_x >= size_x

  [next_y, next_x]
end

def collision?(map, loc, move)
  puts "checking (%i,%i):%s" % [loc[1],loc[0],move]
  ok_cells = [FOOD_SYMBOL]

  next_loc = find_next_loc(map, loc, move)

  return true if next_loc.nil?
  return false if map[next_loc[0]][next_loc[1]].nil?
  return false if map[next_loc[0]][next_loc[1]].in?(ok_cells)

  true
end

def find_escape(map, loc)
  move = POSSIBLE_MOVES.detect { |move| !collision?(map, loc, move) }
  puts "find_escape: %s" % move
  move
end

def map_dimensions(map)
  [map.size, map[0].size]
end

def puts_map(map)
  map.reverse.each do |row|
    puts row.collect { |cell| cell.nil? ? ' ' : cell }.join
  end
end
