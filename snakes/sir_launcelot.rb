require 'benchmark'

class SirLauncelot
  POSSIBLE_MOVES = %w[up down left right]
  ME_SYMBOL = 'I'
  ENEMY_SYMBOLS = %w[A B C D E F G H]
  FOOD_SYMBOL = '.'
  HAZARD_SYMBOL = 'X'

  class Loc
    attr_accessor :x, :y

    def initialize(x,y)
      self.x = x
      self.y = y
    end

    def xy
      [x, y]
    end

    def ==(rhs)
      (self.x == rhs.x) && (self.y == rhs.y)
    end
  end

  def appearance
    {
      apiversion: "1",
      author: "kennon",     # TODO: Your Battlesnake Username
      color: "#009900",     # TODO: Personalize
      head: "evil",       # TODO: Personalize
      tail: "bolt",       # TODO: Personalize
    }
  end

  def start(data)
    # no-op
  end

  def end(data)
    # no-op
  end

  def move(gamestate)
    board = !!gamestate && gamestate[:board]
    return nil unless board
    snake_name = gamestate[:you][:name]
    health = gamestate[:you][:health]
    my_length = gamestate[:you][:body].size

    map, current_loc, enemies = build_map(gamestate)
    puts_map(map)

    puts "[current_loc: (%i,%i), my_length: #{my_length}, health: #{health}]" % current_loc.xy
    #puts "[enemies: #{enemies}"

    ##
    ## main logic
    ##

    # *. Always prevent moving into hazard, wall, or square that a larger enemy could step into
    # 1. If longest snake, attack nearest enemy
    # 2. Else, seek nearest food
    
    open_path_counts = find_open_path_counts(map, current_loc)
    puts "open_path_counts: #{open_path_counts}"

    possible_moves = find_possible_moves(gamestate, map, current_loc, open_path_counts)
    puts "possible_moves: #{possible_moves}"

    # if only 0 or 1 possible moves then skip logic
    if possible_moves.size < 1
      puts "++ NO POSSIBLE MOVES!"
      impossible_moves = find_impossible_moves(gamestate, map, current_loc, open_path_counts)
      return impossible_moves[0]&.first
    elsif possible_moves.size < 2
      puts "++ ONLY ONE POSSIBLE MOVE"
      return possible_moves[0]&.first
    end

    max_enemy_length = enemies.reduce(0) { |max, enemy| [max, enemy[1]].max }
    puts "max_enemy_length: #{max_enemy_length}"

    if max_enemy_length > 0 && my_length > max_enemy_length
      puts "++ Attacking nearest enemy"
      puts "++ my_length #{my_length} > max_enemy_length #{max_enemy_length}"

      target_loc, _ = find_nearest_target(map, current_loc, ENEMY_SYMBOLS)

      if target_loc
        puts "path: #{find_path(map, current_loc, target_loc)}"
      end

      move = attack_nearest_enemy(gamestate, map, current_loc, open_path_counts)

    elsif proximity_alert?(gamestate, map, current_loc, 3)
      puts "++ Avoiding nearest enemy"
      puts "++ enemy proximity alert"
      move = avoid_nearest_enemy(gamestate, map, current_loc, open_path_counts)

    else
      puts "++ Seeking food"
      puts "++ my_length #{my_length} <= max_enemy_length #{max_enemy_length}"

      move = seek_nearest_food(gamestate, map, current_loc, open_path_counts)
    end

    move || best_open_move(possible_moves)
  end

  def find_possible_moves(gamestate, map, current_loc, open_path_counts)
    puts "evaluating possible moves:"
    POSSIBLE_MOVES.collect do |move|
      if collision?(map, current_loc, move)
        puts "  #{move}: collision"
        nil
      elsif head_to_head_loss?(gamestate, map, current_loc, move)
        puts "  #{move}: head to head loss"
        nil
      else
        puts "  #{move}: #{open_path_counts[move]} open"
        [move, open_path_counts[move]]
      end
    end.compact
  end

  def find_impossible_moves(gamestate, map, current_loc, open_path_counts)
    puts "evaluating possible moves:"
    POSSIBLE_MOVES.collect do |move|
      if collision?(map, current_loc, move)
        puts "  #{move}: collision"
        [move, -1]
      else
        puts "  #{move}: #{open_path_counts[move]} open"
        [move, open_path_counts[move]]
      end
    end.compact
  end

  ###
  ### main behavior logic
  ###

  def proximity_alert?(gamestate, map, current_loc, threshold_distance)
    _, distance = find_nearest_target(map, current_loc, ENEMY_SYMBOLS)
    distance && distance < threshold_distance
  end

  def attack_nearest_enemy(gamestate, map, current_loc, open_path_counts)
    target_loc, _ = find_nearest_target(map, current_loc, ENEMY_SYMBOLS)

    if !target_loc
      puts "!! Can't find enemy"
      return
    end

    puts "nearest target_loc: (%i,%i)" % target_loc.xy

    # valid move towards enemy
    move = find_valid_heading(map, current_loc, target_loc, false, open_path_counts)

    if move.nil?
      puts "!!! Can't find valid path to enemy"
      return
    end

    move
  end

  def avoid_nearest_enemy(gamestate, map, current_loc, open_path_counts)
    target_loc, _ = find_nearest_target(map, current_loc, ENEMY_SYMBOLS)

    if !target_loc
      puts "!! Can't find enemy"
      return
    end

    puts "nearest target_loc: (%i,%i)" % target_loc.xy

    # valid move towards enemy
    move = find_valid_heading(map, current_loc, target_loc, true, open_path_counts)

    if move.nil?
      puts "!!! Can't find valid path away from enemy"
      return
    end

    move
  end

  def seek_nearest_food(gamestate, map, current_loc, open_path_counts)
    target_loc, _ = find_nearest_target(map, current_loc, [FOOD_SYMBOL])

    if !target_loc
      puts "!! Can't find food"
      return
    end

    puts "nearest target_loc: (%i,%i)" % target_loc.xy

    # valid move towards food
    move = find_valid_heading(map, current_loc, target_loc, false, open_path_counts)

    if move.nil?
      puts "!!! Can't find valid path to food"
      return
    elsif open_path_counts[move] < my_length(gamestate)
      puts "!!! Found valid path, but would move us into a dead end"
      return
    end

    move
  end

  ##
  ## utilities
  ##

  def build_map(gamestate)
    board = gamestate[:board]
    height = board[:height]
    width = board[:width]

    # matrix = Matrix.build(height, width) { 0 }
    map = Array.new(width) { Array.new(height, nil) }
    current_loc = nil

    snakes = {}

    # add food
    board[:food].each do |loc_h|
      map[loc_h[:x]][loc_h[:y]] = FOOD_SYMBOL
    end

    # add hazards
    board[:hazards].each do |loc_h|
      map[loc_h[:x]][loc_h[:y]] = HAZARD_SYMBOL
    end

    me_snake = gamestate[:you]
    current_loc = add_snake_to_map!(map, me_snake, ME_SYMBOL)
    enemy_snakes = []

    board[:snakes].each_with_index do |snake, i|
      next if snake[:id] == me_snake[:id]
      enemy_snakes << [Loc.new(snake[:head][:x], snake[:head][:y]), snake[:body].size]
      add_snake_to_map!(map, snake, ENEMY_SYMBOLS[i])
    end

    [map, current_loc, enemy_snakes]
  end

  def add_snake_to_map!(map, snake, character)
    size_x, size_y = map_dimensions(map)
    head_loc = nil

    snake[:body].each_with_index do |loc_h, i|
      next unless loc_h && loc_h[:x] && loc_h[:y] && loc_h[:x] >= 0 && loc_h[:y] >= 0 && loc_h[:x] < size_x && loc_h[:y] < size_y
      
      if i == 0
        head_loc = Loc.new(loc_h[:x], loc_h[:y])
        map[loc_h[:x]][loc_h[:y]] ||= character.upcase
      else
        map[loc_h[:x]][loc_h[:y]] ||= character.downcase
      end
    end

    head_loc
  end

  def distance_xy(x1, y1, x2, y2)
    (x2 - x1).abs + (y2 - y1).abs
  end

  def distance(loc1, loc2)
    distance_xy(loc1.x, loc1.y, loc2.x, loc2.y)
  end

  def find_targets(map, target)
    map.each_with_index do |rows, x|
      rows.each_with_index do |cell, y|
        return Loc.new(x,y) if cell == target
      end
    end
  end

  def find_nearest_target(map, current_loc, targets)
    found_targets = []

    map.each_with_index do |rows, x|
      rows.each_with_index do |cell, y|
        if targets.include?(cell)
          loc = Loc.new(x,y)
          found_targets << [loc, distance(current_loc, loc)]
        end
      end
    end

    return [nil, nil] unless found_targets.any?

    found_targets.sort_by do |_, distance|
      distance
    end.first
  end

  def random_move
    POSSIBLE_MOVES.sample
  end

  def heading(loc1, loc2)
    dist_x = (loc2.x - loc1.x).abs
    dist_y = (loc2.y - loc1.y).abs

    # puts "dist_x: %i, dist_y: %i" % [dist_x, dist_y]

    if dist_y > dist_x
      if loc2.y > loc1.y
        return 'up'
      else
        return 'down'
      end
    else
      if loc2.x > loc1.x
        return 'right'
      else
        return 'left'
      end
    end
  end

  def open_path_count(map, origin_loc)
    return 0 unless origin_loc

    ok_cells = [FOOD_SYMBOL, nil]
    max_x, max_y = map_dimensions(map)
    cell_count = max_x * max_y

    spanning_path = Set.new
    to_check = [origin_loc]

    count = 0
    while to_check.size > 0 && count < cell_count
      loc = to_check.shift

      POSSIBLE_MOVES.each do |move|
        next_loc = find_next_loc(map, loc, move)
        next if !next_loc
        next if spanning_path.include?([next_loc.x, next_loc.y])
        next if !map[next_loc.x][next_loc.y].in?(ok_cells)

        spanning_path << [next_loc.x, next_loc.y]
        to_check << next_loc
      end
    end

    spanning_path.size
  end

  def find_path(map, loc1, loc2, visited = {}, steps = [])
    #puts "find_path(map, #{loc1}, #{loc2}, #{steps})"
    return steps if loc1 == loc2
    visited[[loc1.x, loc1.y]] = true

    paths = POSSIBLE_MOVES.collect do |move|
      next if collision?(map, loc1, move)
      next_loc = find_next_loc(map, loc1, move)
      next if !next_loc
      next if visited[[next_loc.x, next_loc.y]]
      find_path(map, next_loc, loc2, visited, (steps + [move]))
    end.compact.sort_by { |path| path.size }.reverse.first
  end

  def find_valid_heading(map, loc1, loc2, avoid = false, open_path_counts = {})
    valid_path = find_path(map, loc1, loc2)
    return nil unless valid_path && valid_path.size > 0

    x1, y1 = loc1.xy
    x2, y2 = loc2.xy
    dist_y = (y2 - y1).abs
    dist_x = (x2 - x1).abs

    puts "(x1,y1): (%i,%i) (x2,y2): (%i,%i)" % [x1,y1,x2,y2]
    puts "dist_x: %i, dist_y: %i" % [dist_x, dist_y]

    valid_moves = [
      ['up', (y2 - y1).to_f],
      ['down', (y1 - y2).to_f],
      ['left', (x1 - x2).to_f],
      ['right', (x2 - x1).to_f],
    ]

    valid_moves.reject! do |(move, _)|
      collision?(map, loc1, move)
    end

    valid_moves.sort_by! do |(move, priority)|
      priority
    end

    if !avoid
      valid_moves = valid_moves.reverse
    end

    move = valid_moves&.first&.first

    puts "valid_heading: %s" % move

    move
  end

  def find_next_loc(map, loc, move)
    return nil unless loc && move

    x, y = loc.xy

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
      puts "!!! find_next_loc: invalid move (#{move}) specified"
      return nil
    end

    size_x, size_y = map_dimensions(map)

    return nil if next_x < 0 || next_x >= size_x
    return nil if next_y < 0 || next_y >= size_y

    Loc.new(next_x, next_y)
  end

  def collision?(map, loc, move)
    ok_cells = [FOOD_SYMBOL, nil]

    next_loc = find_next_loc(map, loc, move)

    return true if next_loc.nil?
    return false if map[next_loc.x][next_loc.y].in?(ok_cells)

    true
  end

  def head_to_head_loss?(gamestate, map, loc, move)
    next_loc = find_next_loc(map, loc, move)
    enemy_loc, enemy_distance_to_next_loc = find_nearest_target(map, next_loc, ENEMY_SYMBOLS)

    if enemy_loc && enemy_distance_to_next_loc <= 1
      # there is an enemy 1 square away from target, so
      # check if we would win assuming they also move into the square
      my_length = find_snake(gamestate, loc)[:length]
      enemy_length = find_snake(gamestate, enemy_loc)[:length]

      return enemy_length >= my_length
    end

    false
  end

  def find_escape_move(map, loc)
    moves = POSSIBLE_MOVES.reject { |move| collision?(map, loc, move) }
    puts "possible escape moves: #{moves}"

    move = moves.sort_by { |move| open_path_count(map, find_next_loc(map, loc, move)) }.reverse.first
    puts "find_escape_move: #{move}"
    move
  end

  # from a particular location, to how many cells is there an open path?
  def open_path_count(map, origin_loc)
    return 0 unless origin_loc

    ok_cells = [FOOD_SYMBOL, nil]
    max_x, max_y = map_dimensions(map)
    cell_count = max_x * max_y

    spanning_path = Set.new
    to_check = [origin_loc]

    count = 0
    while to_check.size > 0 && count < cell_count
      loc = to_check.shift

      POSSIBLE_MOVES.each do |move|
        next_loc = find_next_loc(map, loc, move)
        next if !next_loc
        next if spanning_path.include?([next_loc.x, next_loc.y])
        next if !map[next_loc.x][next_loc.y].in?(ok_cells)

        spanning_path << [next_loc.x, next_loc.y]
        to_check << next_loc
      end
    end

    spanning_path.size
  end

  def find_open_path_counts(map, origin_loc)
    POSSIBLE_MOVES.reduce({}) { |h, move| h[move] = open_path_count(map, find_next_loc(map, origin_loc, move)); h }
  end

  def best_open_move(possible_moves)
    move, _ = possible_moves&.sort_by { |(_, priority)| priority }.reverse.first
    move
  end

  def map_dimensions(map)
    [map.size, map[0].size]
  end

  def puts_map(map)
    size_x, size_y = map_dimensions(map)

    header = '+' + ('-' * size_x) + '+'

    puts header

    # flip y axis since battlesnake has positive Y going up
    (0...size_y).to_a.reverse.each do |y|
      row = '|'
      (0...size_x).each do |x|
        row << (map[x][y].nil? ? ' ' : map[x][y])
      end
      puts row + '|'
    end

    puts header
  end

  def my_length(gamestate)
    gamestate[:you][:length]
  end

  def find_snake(gamestate, loc)
    gamestate[:board][:snakes].each do |snake|
      snake[:body].each do |loc_h|
        return snake if loc.x == loc_h[:x] && loc.y == loc_h[:y]
      end
    end
  end
end